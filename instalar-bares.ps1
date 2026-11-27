<#
 .SYNOPSIS  Instala o ACTUALIZA el Sistema Bares en Windows bajando el paquete de Internet (sin USB).
 Uso (PowerShell como ADMINISTRADOR, en la PC servidor):
     irm https://raw.githubusercontent.com/jefrin-asi/bares-entregas/main/instalar-bares.ps1 | iex
 - Pide la clave del paquete (no queda escrita en el historial ni en pantalla).
 - Baja el paquete cifrado y su huella, lo descifra y verifica que sea el original.
 - Si el sistema NO está instalado: lo instala (servicios, base local, firewall de red privada) con los datos de Shorty's.
 - Si YA está instalado: lo actualiza con respaldo previo; si la versión nueva no responde, vuelve sola a la anterior con su base.
 Los datos (ventas, clientes, inventario) nunca se borran: viven aparte, en C:\ProgramData\SistemaBares.
#>
$ErrorActionPreference = 'Stop'
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force   # Windows 11 trae «Restricted»: sin esto, instalar.ps1/actualizar.ps1 del paquete no corren
$Repo = 'jefrin-asi/bares-entregas'
$Base = if ($env:BARES_ENTREGAS_BASE) { $env:BARES_ENTREGAS_BASE } else { "https://github.com/$Repo/releases/latest/download" }   # la variable solo sirve para probar
$Iter = 200000   # mismas vueltas que tools/entregas/cifrar.sh

function Paso($t) { Write-Host "`n== $t" -ForegroundColor Cyan }
$yo = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $yo.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Abra PowerShell como ADMINISTRADOR (clic derecho > Ejecutar como administrador) y repita el comando.' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$trabajo = Join-Path $env:ProgramData ('SistemaBares-entrega\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $trabajo | Out-Null
$enc = Join-Path $trabajo 'paquete-windows.enc'; $zip = Join-Path $trabajo 'paquete-windows.zip'

Paso 'Bajando el paquete (puede tardar unos minutos)'
$ProgressPreference = 'SilentlyContinue'   # la barra de progreso de PowerShell hace la descarga mucho más lenta
Invoke-WebRequest -UseBasicParsing -Uri "$Base/paquete-windows.enc" -OutFile $enc
$huella = ((Invoke-WebRequest -UseBasicParsing -Uri "$Base/paquete-windows.sha256").Content -split '\s+')[0].Trim().ToLower()

Paso 'Descifrando'
$seg = Read-Host 'Clave del paquete' -AsSecureString
$clave = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($seg))
# Formato de «openssl enc -aes-256-cbc -pbkdf2 -iter N -salt»: «Salted__» + sal de 8 bytes + datos; llave e IV salen de PBKDF2-SHA256.
$fs = [IO.File]::OpenRead($enc)
try {
    $cab = New-Object byte[] 16; [void]$fs.Read($cab, 0, 16)
    if ([Text.Encoding]::ASCII.GetString($cab, 0, 8) -ne 'Salted__') { throw 'El archivo bajado no es un paquete válido.' }
    $sal = $cab[8..15]
    $kdf = New-Object Security.Cryptography.Rfc2898DeriveBytes($clave, [byte[]]$sal, $Iter, [Security.Cryptography.HashAlgorithmName]::SHA256)
    $kv = $kdf.GetBytes(48)
    $aes = [Security.Cryptography.Aes]::Create(); $aes.Mode = 'CBC'; $aes.Padding = 'PKCS7'; $aes.Key = $kv[0..31]; $aes.IV = $kv[32..47]
    $sal2 = [IO.File]::Create($zip)
    try { $cs = New-Object Security.Cryptography.CryptoStream($fs, $aes.CreateDecryptor(), 'Read'); $cs.CopyTo($sal2); $cs.Dispose() }
    catch { throw 'Clave incorrecta o archivo dañado.' }
    finally { $sal2.Dispose() }
} finally { $fs.Dispose(); $clave = $null }
$real = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if ($real -ne $huella) { Remove-Item $trabajo -Recurse -Force; throw 'La huella no coincide: el paquete no es el original o se bajó incompleto. Repita el comando.' }
Write-Host 'Paquete verificado (huella SHA-256 correcta).' -ForegroundColor Green

Paso 'Descomprimiendo'
$dir = Join-Path $trabajo 'paquete'; Expand-Archive -Path $zip -DestinationPath $dir -Force
Remove-Item $enc, $zip -Force

if (Get-Service 'SistemaBares' -ErrorAction SilentlyContinue) {
    Paso 'El sistema ya está instalado: ACTUALIZANDO (con respaldo y regreso automático si falla)'
    & (Join-Path $dir 'actualizar.ps1')
    if ($LASTEXITCODE -ne 0) { Write-Host "`nLa versión nueva NO quedó instalada: el sistema volvió a la versión anterior (revise los mensajes de arriba)." -ForegroundColor Red; return }
} else {
    Paso 'Primera vez en esta PC: INSTALANDO'
    & (Join-Path $dir 'instalar.ps1') -CodigoEmpresa 'SHORTYS' -NombreEmpresa "Shorty's Discotec" -NombreSucursal "Shorty's Discotec"
    if (-not (Get-Service 'SistemaBares' -ErrorAction SilentlyContinue)) { Write-Host "`nLa instalación no terminó (revise los mensajes de arriba)." -ForegroundColor Red; return }
}
Write-Host "`nListo. Las cajas solo deben recargar la página (F5). Paquete usado: $dir" -ForegroundColor Green
