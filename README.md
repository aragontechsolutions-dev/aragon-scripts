# Aragon Tech Solutions — Script de diagnóstico

`aragon_diagnostico.ps1` captura el estado de un equipo Windows antes (PRE)
y después (POST) del mantenimiento, genera un JSON y lo sube al sistema para
comparar ambos en el ticket.

## Requisitos

- Windows 7/8/10/11 con **PowerShell 3.0 o superior** (Windows 7 trae 2.0:
  instalar Windows Management Framework 3.0+).
- Opcional: OpenHardwareMonitor abierto, para temperaturas y ventiladores.
- **Autorización del cliente**: el script recopila hardware, discos,
  temperaturas, programas al inicio y procesos activos.

## Uso

1. Descargar `aragon_diagnostico.ps1` (enlace en el Manual del panel).
2. PowerShell como administrador:
   `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process`
3. Ejecutar el script y elegir:
   - `[1]` PRE-mantenimiento / `[2]` POST-mantenimiento: pide el código del
     ticket (ej. `ATS-2026-0001`), captura y guarda el JSON en
     `Escritorio\AragonDiag`, y ofrece subirlo.
   - `[3]` Subir archivos pendientes (los capturados sin internet).
4. Para subir pide email y contraseña del sistema. El técnico solo puede
   subir diagnósticos de **sus** tickets.

## Actualizaciones

El script **ya no se actualiza solo**: al arrancar compara su versión con
la de GitHub y, si hay una más nueva, avisa y muestra el enlace de descarga.
Antes se sobrescribía y se ejecutaba sin verificar nada, lo que permitía que
quien comprometiera el repositorio ejecutara código en los PC de los
clientes.

Al publicar una versión nueva hay que subir `$SCRIPT_VERSION`.

## Codificación

El archivo se guarda en **UTF-8 con BOM**: PowerShell 5.1 lee como ANSI los
archivos UTF-8 sin BOM y rompe los caracteres especiales. Mantenerlo así al
editarlo.

## Documentación

- [Registro de cambios](docs/CAMBIOS.md)
