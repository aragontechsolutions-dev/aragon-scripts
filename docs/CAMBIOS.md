# Registro de cambios

## v1.1.0 (2026-10-24)

### Seguridad
- **Sin auto-actualización ejecutable.** Antes el script descargaba la
  versión de GitHub, se sobrescribía y se relanzaba con
  `-ExecutionPolicy Bypass`, sin firma ni verificación (y también "actualizaba"
  a versiones anteriores). Ahora solo avisa de que hay una versión más nueva
  (comparación numérica real) y muestra el enlace.
- **Contraseña**: la copia en memoria no administrada se borra
  (`ZeroFreeBSTR`) en cuanto se lee y el texto plano se descarta tras armar
  la petición.
- Aviso de que el script recopila datos del equipo y requiere autorización
  del cliente.

### Errores corregidos
- **Login con contraseñas que contienen `"` o `\`**: el JSON se armaba
  concatenando texto y quedaba inválido. Ahora se genera con `ConvertTo-Json`.
- **Windows 7/8**: usaban TLS 1.0 por defecto y GitHub y el backend exigen
  TLS 1.2, así que fallaban login, subida y comprobación de versión. Se
  habilita TLS 1.2.
- Lectura de la contraseña con `PtrToStringBSTR` (la forma correcta de leer
  un BSTR; `PtrToStringAuto` depende de la plataforma).
- Mensajes claros para credenciales incorrectas (401) y demasiados intentos
  (429, el backend limita el login).
- Decía ser compatible con PowerShell 2.0, pero `ConvertTo-Json` necesita
  3.0: en 2.0 guardaba un texto que el backend rechazaba. Ahora lo comprueba
  al arrancar y lo explica.
- Comprobación de internet por HTTPS.

### Verificación (PowerShell 7.4 en Linux; WMI no disponible fuera de Windows)
- Sintaxis validada con el parser de PowerShell.
- Login correcto, contraseña errónea y contraseña con comillas/barras contra
  el backend real.
- Subida de un diagnóstico por código de ticket: guardado y procesado.
- Aviso de versión contra GitHub (al día / hay una nueva).
- **Pendiente de probar en Windows real**: captura WMI y TLS en Windows 7.

### Nota de despliegue
- Las copias v1.0.0 que tengan los técnicos se actualizarán solas a esta
  versión **una última vez** cuando se publique en `main` (es el mecanismo
  antiguo). Desde v1.1.0 ya no ocurre.
- Se eliminó la copia duplicada que había en `aragon-backend/scripts`. Si
  algún técnico usa esa copia, debe descargar esta.
