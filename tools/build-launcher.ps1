<#
  build-launcher.ps1  -  builds GitPigeon.exe (the launcher users double-click).

  Uses the C# compiler that comes with Windows (.NET Framework 4.x), so nothing
  extra needs to be installed. Name, version, developer and icon are taken from
  GitPigeon.ps1 and assets\gitpigeon.ico.

  Usage (from the repo folder):
    powershell -ExecutionPolicy Bypass -File tools\build-launcher.ps1

  Developed by : EMR Industries
#>

$root    = Split-Path $PSScriptRoot -Parent
$appFile = Join-Path $root "GitPigeon.ps1"
$source  = Join-Path $root "launcher\GitPigeonLauncher.cs"
$icon    = Join-Path $root "assets\gitpigeon.ico"
$output  = Join-Path $root "GitPigeon.exe"

function Get-AppValue($name) {
    $m = Select-String -Path $appFile -Pattern ('^\$' + $name + '\s*=\s*"([^"]+)"') | Select-Object -First 1
    if (-not $m) { Write-Error "Could not find `$$name in GitPigeon.ps1"; exit 1 }
    return $m.Matches[0].Groups[1].Value
}

$name      = Get-AppValue "AppName"
$tagline   = Get-AppValue "AppTagline"
$developer = Get-AppValue "AppDeveloper"
$version   = Get-AppValue "AppVersion"

# Assembly versions need 4 parts: 1.0 -> 1.0.0.0
$parts = @($version.Split('.') | ForEach-Object { [int]$_ })
while ($parts.Count -lt 4) { $parts += 0 }
$version4 = ($parts[0..3] -join '.')

# Find csc.exe from .NET Framework 4.x (present on every Windows 10/11)
$csc = @(
    "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $csc) { Write-Error "csc.exe (.NET Framework 4.x) not found."; exit 1 }

# Version details shown in GitPigeon.exe > Properties > Details
$info = Join-Path $env:TEMP "GitPigeonAssemblyInfo.cs"
@"
using System.Reflection;
[assembly: AssemblyTitle("$name")]
[assembly: AssemblyDescription("$tagline")]
[assembly: AssemblyCompany("$developer")]
[assembly: AssemblyProduct("$name")]
[assembly: AssemblyCopyright("Copyright (c) $((Get-Date).Year) $developer")]
[assembly: AssemblyVersion("$version4")]
[assembly: AssemblyFileVersion("$version4")]
"@ | Set-Content -Path $info -Encoding ASCII

& $csc /nologo /target:winexe /optimize+ "/out:$output" "/win32icon:$icon" `
    /reference:System.Windows.Forms.dll $source $info
$ok = ($LASTEXITCODE -eq 0)
Remove-Item $info -ErrorAction SilentlyContinue

if (-not $ok) { Write-Error "Build failed."; exit 1 }
Write-Output "Built $output  ($name $version, $developer)"
