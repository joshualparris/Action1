# Setup-Action1Controller.ps1
# Installs the PSAction1 module required by DadLAN on Windows.
# No Action1 credentials are stored by this script.

#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Write-Host "DadLAN Action1 controller setup" -ForegroundColor Cyan

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}

$gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
if ($gallery -and $gallery.InstallationPolicy -ne 'Trusted') {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

if (Get-Module -ListAvailable -Name PSAction1) {
    try { Update-Module PSAction1 -Force -ErrorAction Stop }
    catch { Write-Warning "PSAction1 update failed; continuing with installed version: $($_.Exception.Message)" }
}
else {
    Install-Module PSAction1 -Scope AllUsers -Force -AllowClobber
}

Import-Module PSAction1 -Force
$module = Get-Module PSAction1
Write-Host "Installed PSAction1 $($module.Version)" -ForegroundColor Green
Write-Host "No Client ID or Client Secret was saved." -ForegroundColor Green
Write-Host "Launch DadLAN-Control.ps1 and use Connect to authenticate." -ForegroundColor Cyan
