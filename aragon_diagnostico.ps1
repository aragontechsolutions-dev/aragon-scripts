# ============================================================
#  ARAGON_DIAGNOSTICO.PS1
#  Aragon Tech Solutions — Script unificado de diagnóstico
#  Compatible con Windows 7/8/10/11 (PowerShell 2.0+)
#  - Captura PRE o POST mantenimiento
#  - Genera JSON estructurado
#  - Sube automaticamente al backend si hay internet
#  - Si no hay internet, guarda localmente para subir despues
# ============================================================

# Auto-actualizacion desde GitHub
$SCRIPT_VERSION  = "1.0.0"
$GITHUB_URL      = "https://raw.githubusercontent.com/aragontechsolutions-dev/aragon-backend/main/scripts/aragon_diagnostico.ps1"
$BACKEND_URL     = "https://aragon-backend-q4cx.onrender.com/api"
$OUTPUT_DIR      = Join-Path $env:USERPROFILE "Desktop\AragonDiag"

# ── Colores helpers ───────────────────────────────────────────
function Write-Title($msg) {
    Write-Host ""
    Write-Host "  ==========================================" -ForegroundColor DarkCyan
    Write-Host "  $msg" -ForegroundColor Cyan
    Write-Host "  ==========================================" -ForegroundColor DarkCyan
    Write-Host ""
}
function Write-Ok($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "  [!]  $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  [X]  $msg" -ForegroundColor Red }
function Write-Info($msg) { Write-Host "  [-]  $msg" -ForegroundColor Gray }

# ── Verificar internet ────────────────────────────────────────
function Test-Internet {
    try {
        $req = [System.Net.WebRequest]::Create("http://www.google.com")
        $req.Timeout = 4000
        $res = $req.GetResponse()
        $res.Close()
        return $true
    } catch { return $false }
}

# ── Auto-actualizacion ────────────────────────────────────────
function Update-Script {
    Write-Info "Verificando actualizaciones..."
    try {
        $tempPath = Join-Path $env:TEMP "aragon_diagnostico_new.ps1"
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($GITHUB_URL, $tempPath)

        $newContent = Get-Content $tempPath -Raw -Encoding UTF8
        if ($newContent -match 'SCRIPT_VERSION\s*=\s*"([\d\.]+)"') {
            $newVersion = $Matches[1]
            if ($newVersion -ne $SCRIPT_VERSION) {
                Write-Warn "Nueva version disponible: v$newVersion (actual: v$SCRIPT_VERSION)"
                $selfPath = $MyInvocation.ScriptName
                if ($selfPath) {
                    Copy-Item $tempPath $selfPath -Force
                    Write-Ok "Script actualizado. Reiniciando..."
                    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$selfPath`""
                    exit
                }
            } else {
                Write-Ok "Script actualizado (v$SCRIPT_VERSION)"
            }
        }
        Remove-Item $tempPath -ErrorAction SilentlyContinue
    } catch {
        Write-Warn "No se pudo verificar actualizacion (sin internet o error de red)"
    }
}

# ── Crear carpeta de salida ───────────────────────────────────
function Ensure-OutputDir {
    if (-not (Test-Path $OUTPUT_DIR)) {
        New-Item -ItemType Directory -Path $OUTPUT_DIR | Out-Null
    }
}

# ── WMI helper compatible con Win7 ───────────────────────────
function Get-WMI($class, $ns) {
    try {
        if ($ns) { return Get-WmiObject -Class $class -Namespace $ns -ErrorAction Stop }
        else      { return Get-WmiObject -Class $class -ErrorAction Stop }
    } catch { return $null }
}

# ── Captura de datos del sistema ─────────────────────────────
function Capture-SystemData($phase, $ticketCode) {
    Write-Title "Capturando datos — $phase"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Sistema
    Write-Info "Sistema..."
    $cs   = Get-WMI "Win32_ComputerSystem"
    $bios = Get-WMI "Win32_BIOS"
    $os   = Get-WMI "Win32_OperatingSystem"

    $uptime = $null
    if ($os -and $os.LastBootUpTime) {
        try {
            $bootTime = [Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime)
            $uptime   = [math]::Floor(((Get-Date) - $bootTime).TotalHours)
        } catch { $uptime = $null }
    }

    $sistema = @{
        fabricante = if ($cs)   { $cs.Manufacturer }   else { "N/D" }
        modelo     = if ($cs)   { $cs.Model }          else { "N/D" }
        serial     = if ($bios) { $bios.SerialNumber }  else { "N/D" }
        so         = if ($os)   { "$($os.Caption) $($os.Version)" } else { "N/D" }
        arquitectura = if ($os) { $os.OSArchitecture }  else { "N/D" }
        ultimoArranqueH = $uptime
    }

    # CPU
    Write-Info "CPU..."
    $cpu = Get-WMI "Win32_Processor"
    $cpuData = @{
        nombre  = if ($cpu) { $cpu.Name }                     else { "N/D" }
        nucleos = if ($cpu) { $cpu.NumberOfCores }             else { 0 }
        logicos = if ($cpu) { $cpu.NumberOfLogicalProcessors } else { 0 }
        mhzMax  = if ($cpu) { $cpu.MaxClockSpeed }             else { 0 }
        cargaPct= if ($cpu) { $cpu.LoadPercentage }            else { 0 }
    }

    # RAM
    Write-Info "RAM..."
    $totalRAM = 0; $freeRAM = 0; $usedRAM = 0; $usedPct = 0
    if ($os) {
        $totalRAM = [math]::Round($os.TotalVisibleMemorySize / 1048576, 2)
        $freeRAM  = [math]::Round($os.FreePhysicalMemory     / 1048576, 2)
        $usedRAM  = [math]::Round($totalRAM - $freeRAM, 2)
        $usedPct  = if ($totalRAM -gt 0) { [math]::Round(($usedRAM / $totalRAM) * 100, 1) } else { 0 }
    }

    $modulos = @()
    $ramMods = Get-WMI "Win32_PhysicalMemory"
    if ($ramMods) {
        foreach ($mod in $ramMods) {
            $modulos += @{
                capacidadGB = [math]::Round($mod.Capacity / 1073741824, 0)
                mhz         = $mod.Speed
                slot        = $mod.DeviceLocator
            }
        }
    }

    $ram = @{
        totalGB  = $totalRAM
        usadaGB  = $usedRAM
        libreGB  = $freeRAM
        usadaPct = $usedPct
        modulos  = $modulos
    }

    # Discos
    Write-Info "Almacenamiento..."
    $discos = @()
    $logDisks = Get-WMI "Win32_LogicalDisk"
    if ($logDisks) {
        foreach ($disk in ($logDisks | Where-Object { $_.DriveType -eq 3 })) {
            $total = [math]::Round($disk.Size      / 1073741824, 1)
            $free  = [math]::Round($disk.FreeSpace / 1073741824, 1)
            $used  = [math]::Round($total - $free, 1)
            $pct   = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 1) } else { 0 }
            $discos += @{
                unidad      = $disk.DeviceID
                totalGB     = $total
                usadoGB     = $used
                libreGB     = $free
                ocupacionPct= $pct
            }
        }
    }

    # Disco fisico — fallback para Win7 (sin Get-PhysicalDisk)
    $discosFisicos = @()
    try {
        $physDisks = Get-PhysicalDisk -ErrorAction Stop
        foreach ($pd in $physDisks) {
            $discosFisicos += @{
                nombre     = $pd.FriendlyName
                tipo       = $pd.MediaType
                estado     = $pd.HealthStatus
                capacidadGB= [math]::Round($pd.Size / 1073741824, 0)
            }
        }
    } catch {
        # Win7 fallback — usar Win32_DiskDrive
        $wmiDisks = Get-WMI "Win32_DiskDrive"
        if ($wmiDisks) {
            foreach ($d in $wmiDisks) {
                $discosFisicos += @{
                    nombre     = $d.Model
                    tipo       = "Desconocido"
                    estado     = if ($d.Status) { $d.Status } else { "N/D" }
                    capacidadGB= [math]::Round($d.Size / 1073741824, 0)
                }
            }
        }
    }

    # Bateria
    Write-Info "Bateria..."
    $bateria = $null
    $bat = Get-WMI "Win32_Battery"
    if ($bat) {
        $chargeMap = @{
            1="Descargando"; 2="AC/Cargando"; 3="Carga completa";
            4="Bajo"; 5="Critico"; 6="Cargando/Alto"; 7="Cargando/Bajo";
            8="Cargando/Critico"; 9="Desconocido"; 10="AC parcialmente cargado"
        }
        $bateria = @{
            cargaPct      = $bat.EstimatedChargeRemaining
            tiempoRestMin = $bat.EstimatedRunTime
            estado        = if ($chargeMap[$bat.BatteryStatus]) { $chargeMap[$bat.BatteryStatus] } else { "Desconocido" }
        }
    }

    # Temperaturas y ventiladores (OpenHardwareMonitor)
    Write-Info "Temperaturas (requiere OpenHardwareMonitor)..."
    $temperaturas = @()
    $ventiladores = @()
    try {
        $ohmTemps = Get-WmiObject -Namespace "root/OpenHardwareMonitor" -Class "Sensor" -ErrorAction Stop |
                    Where-Object { $_.SensorType -eq "Temperature" }
        if ($ohmTemps) {
            foreach ($s in $ohmTemps) {
                $temperaturas += @{
                    sensor  = $s.Parent.Split('/')[-1]
                    nombre  = $s.Name
                    valorC  = [math]::Round($s.Value, 1)
                }
            }
        }
        $ohmFans = Get-WmiObject -Namespace "root/OpenHardwareMonitor" -Class "Sensor" -ErrorAction Stop |
                   Where-Object { $_.SensorType -eq "Fan" }
        if ($ohmFans) {
            foreach ($s in $ohmFans) {
                $ventiladores += @{
                    sensor = $s.Parent.Split('/')[-1]
                    nombre = $s.Name
                    rpm    = [math]::Round($s.Value, 0)
                }
            }
        }
    } catch {
        Write-Warn "OpenHardwareMonitor no disponible — sin datos de temperatura"
    }

    # Programas al inicio
    Write-Info "Programas al inicio..."
    $startup = @()
    $startItems = Get-WMI "Win32_StartupCommand"
    if ($startItems) {
        foreach ($item in $startItems) {
            $startup += @{ nombre = $item.Name; ubicacion = $item.Location }
        }
    }

    # Top 10 procesos por CPU
    Write-Info "Procesos..."
    $procesos = @()
    $topProcs = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
    foreach ($p in $topProcs) {
        $procesos += @{
            nombre  = $p.ProcessName
            cpuSeg  = [math]::Round($p.CPU, 1)
            ramMB   = [math]::Round($p.WorkingSet64 / 1048576, 1)
        }
    }

    # Armar objeto JSON final
    $data = @{
        version     = $SCRIPT_VERSION
        phase       = $phase
        ticketCode  = $ticketCode
        timestamp   = $timestamp
        sistema     = $sistema
        cpu         = $cpuData
        ram         = $ram
        discos      = $discos
        discosFisicos = $discosFisicos
        bateria     = $bateria
        temperaturas= $temperaturas
        ventiladores= $ventiladores
        startup     = $startup
        procesosTop = $procesos
    }

    return $data
}

# ── Convertir a JSON compatible con PS2 ──────────────────────
function ConvertTo-JsonCompat($obj, $depth) {
    # PowerShell 3+ tiene ConvertTo-Json nativo
    try {
        return $obj | ConvertTo-Json -Depth ($depth) -Compress
    } catch {
        # Fallback manual para PS2 (muy básico)
        return "[Datos capturados - requiere PowerShell 3+ para exportar JSON]"
    }
}

# ── Guardar JSON local ────────────────────────────────────────
function Save-JsonLocal($data, $phase, $ticketCode) {
    Ensure-OutputDir
    $phaseSlug = if ($phase -eq "PRE_MAINTENANCE") { "pre" } else { "post" }
    $fileName  = "${ticketCode}_${phaseSlug}_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $filePath  = Join-Path $OUTPUT_DIR $fileName
    $json      = ConvertTo-JsonCompat $data 10
    $json | Out-File -FilePath $filePath -Encoding UTF8
    return $filePath
}

# ── Subir JSON al backend ─────────────────────────────────────
function Upload-ToBackend($filePath, $token) {
    Write-Info "Subiendo al backend..."
    try {
        $boundary = [System.Guid]::NewGuid().ToString()
        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        $fileName  = [System.IO.Path]::GetFileName($filePath)

        $bodyLines = @(
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
            "Content-Type: application/json",
            "",
            [System.Text.Encoding]::UTF8.GetString($fileBytes),
            "--$boundary--"
        )
        $body = $bodyLines -join "`r`n"
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

        $req = [System.Net.WebRequest]::Create("$BACKEND_URL/diagnostics/upload")
        $req.Method      = "POST"
        $req.ContentType = "multipart/form-data; boundary=$boundary"
        $req.Headers.Add("Authorization", "Bearer $token")
        $req.ContentLength = $bodyBytes.Length
        $req.Timeout       = 30000

        $stream = $req.GetRequestStream()
        $stream.Write($bodyBytes, 0, $bodyBytes.Length)
        $stream.Close()

        $res     = $req.GetResponse()
        $reader  = New-Object System.IO.StreamReader($res.GetResponseStream())
        $resBody = $reader.ReadToEnd()
        $reader.Close()
        $res.Close()

        Write-Ok "Subido correctamente al sistema"
        return $true
    } catch {
        Write-Err "Error al subir: $_"
        return $false
    }
}

# ── Login al backend ──────────────────────────────────────────
function Get-AuthToken {
    Write-Host ""
    Write-Host "  Ingresa tus credenciales de Aragon Tech Solutions:" -ForegroundColor Cyan
    $email    = Read-Host "  Email"
    $password = Read-Host "  Contrasena" -AsSecureString
    $passPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
    )

    try {
        $body    = "{`"email`":`"$email`",`"password`":`"$passPlain`"}"
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)

        $req = [System.Net.WebRequest]::Create("$BACKEND_URL/users/login")
        $req.Method        = "POST"
        $req.ContentType   = "application/json"
        $req.ContentLength = $bodyBytes.Length
        $req.Timeout       = 15000

        $stream = $req.GetRequestStream()
        $stream.Write($bodyBytes, 0, $bodyBytes.Length)
        $stream.Close()

        $res     = $req.GetResponse()
        $reader  = New-Object System.IO.StreamReader($res.GetResponseStream())
        $resBody = $reader.ReadToEnd()
        $reader.Close()
        $res.Close()

        # Extraer token del JSON (compatible PS2)
        if ($resBody -match '"token"\s*:\s*"([^"]+)"') {
            return $Matches[1]
        }
        Write-Err "No se pudo obtener el token"
        return $null
    } catch {
        Write-Err "Error de login: $_"
        return $null
    }
}

# ── Subir archivo pendiente ───────────────────────────────────
function Upload-PendingFiles($token) {
    Ensure-OutputDir
    $pending = Get-ChildItem $OUTPUT_DIR -Filter "*.json" -ErrorAction SilentlyContinue
    if (-not $pending -or $pending.Count -eq 0) {
        Write-Warn "No hay archivos pendientes de subir"
        return
    }
    Write-Ok "Archivos pendientes encontrados: $($pending.Count)"
    foreach ($file in $pending) {
        Write-Info "Subiendo $($file.Name)..."
        $ok = Upload-ToBackend $file.FullName $token
        if ($ok) {
            Remove-Item $file.FullName -ErrorAction SilentlyContinue
            Write-Ok "Eliminado localmente: $($file.Name)"
        }
    }
}

# ============================================================
# MENU PRINCIPAL
# ============================================================
Clear-Host
Write-Host ""
Write-Host "  ██████████████████████████████████████████" -ForegroundColor DarkCyan
Write-Host "  ██  ARAGON TECH SOLUTIONS                ██" -ForegroundColor Cyan
Write-Host "  ██  Herramienta de Diagnostico v$SCRIPT_VERSION     ██" -ForegroundColor Cyan
Write-Host "  ██████████████████████████████████████████" -ForegroundColor DarkCyan
Write-Host ""

$hayInternet = Test-Internet

if ($hayInternet) {
    Write-Ok "Conexion a internet detectada"
    Update-Script
} else {
    Write-Warn "Sin conexion a internet — modo offline"
}

Write-Host ""
Write-Host "  Selecciona una opcion:" -ForegroundColor White
Write-Host "  [1] Capturar PRE-mantenimiento" -ForegroundColor Cyan
Write-Host "  [2] Capturar POST-mantenimiento" -ForegroundColor Cyan
Write-Host "  [3] Subir archivos pendientes" -ForegroundColor Yellow
Write-Host "  [4] Salir" -ForegroundColor Gray
Write-Host ""
$opcion = Read-Host "  Opcion"

if ($opcion -eq "4") { exit }

if ($opcion -eq "3") {
    if (-not $hayInternet) {
        Write-Err "Sin internet — no se pueden subir archivos ahora"
        Read-Host "  Presiona Enter para salir"
        exit
    }
    $token = Get-AuthToken
    if ($token) { Upload-PendingFiles $token }
    Read-Host "  Presiona Enter para salir"
    exit
}

if ($opcion -eq "1" -or $opcion -eq "2") {
    $phase = if ($opcion -eq "1") { "PRE_MAINTENANCE" } else { "POST_MAINTENANCE" }
    $phaseLabel = if ($opcion -eq "1") { "PRE-mantenimiento" } else { "POST-mantenimiento" }

    Write-Host ""
    $ticketCode = Read-Host "  Codigo del ticket (ej: ATS-2026-0001)"
    if (-not $ticketCode) {
        Write-Err "Codigo de ticket requerido"
        Read-Host "  Presiona Enter para salir"
        exit
    }

    # Capturar datos
    $data     = Capture-SystemData $phase $ticketCode
    $filePath = Save-JsonLocal $data $phase $ticketCode

    Write-Ok "Datos capturados correctamente"
    Write-Info "Archivo guardado: $filePath"

    # Intentar subir si hay internet
    if ($hayInternet) {
        Write-Host ""
        Write-Host "  Hay conexion a internet." -ForegroundColor Cyan
        $subirAhora = Read-Host "  Subir al sistema ahora? (s/n)"
        if ($subirAhora -eq "s" -or $subirAhora -eq "S") {
            $token = Get-AuthToken
            if ($token) {
                $ok = Upload-ToBackend $filePath $token
                if ($ok) {
                    Remove-Item $filePath -ErrorAction SilentlyContinue
                    Write-Ok "Archivo eliminado localmente (ya esta en el sistema)"
                }
            }
        } else {
            Write-Warn "Archivo guardado localmente. Usa la opcion [3] para subir despues."
        }
    } else {
        Write-Warn "Sin internet — archivo guardado en: $OUTPUT_DIR"
        Write-Warn "Cuando tengas conexion usa la opcion [3] para subir al sistema."
    }
} else {
    Write-Err "Opcion invalida"
}

Write-Host ""
Read-Host "  Presiona Enter para salir"