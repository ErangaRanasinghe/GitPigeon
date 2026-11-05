<#
  make-release.ps1  -  builds GitPigeon.exe, then packs dist\GitPigeon-v<version>.zip.
  The version is read from $AppVersion in GitPigeon.ps1.

  Usage (from the repo folder):
    powershell -ExecutionPolicy Bypass -File tools\make-release.ps1

  Developed by : EMR Industries
#>

$root    = Split-Path $PSScriptRoot -Parent
$appFile = Join-Path $root "GitPigeon.ps1"

$match = Select-String -Path $appFile -Pattern '^\$AppVersion\s*=\s*"([^"]+)"' | Select-Object -First 1
if (-not $match) { Write-Error "Could not find `$AppVersion in GitPigeon.ps1"; exit 1 }
$version = $match.Matches[0].Groups[1].Value

# 1. Build the launcher so the exe always matches the current version
& (Join-Path $PSScriptRoot "build-launcher.ps1")
if (-not $?) { Write-Error "Launcher build failed"; exit 1 }

# 2. Files and folders that go into the release
$items = @(
    "GitPigeon.exe",
    "Start GitPigeon.bat",
    "GitPigeon.ps1",
    "gitpigeon-push.ps1",
    "assets",
    "README.md",
    "CHANGELOG.md"
)

$dist    = Join-Path $root "dist"
$staging = Join-Path $dist "GitPigeon"
$zip     = Join-Path $dist "GitPigeon-v$version.zip"

if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path $staging -Force | Out-Null

foreach ($f in $items) {
    $src = Join-Path $root $f
    if (-not (Test-Path $src)) { Write-Error "Missing: $f"; exit 1 }
    Copy-Item $src $staging -Recurse
}

if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path $staging -DestinationPath $zip
Remove-Item $staging -Recurse -Force

Write-Output "Built $zip"
