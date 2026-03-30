$ErrorActionPreference = "Stop"

$wallpaperDir = Join-Path $env:USERPROFILE "Pictures\windots-wallpapers"
$stateDir = Join-Path $env:APPDATA "wallpaper-rotator"
$stateFile = Join-Path $stateDir "last-wallpaper.txt"

if (-not (Test-Path $wallpaperDir)) {
    throw "Wallpaper directory not found: $wallpaperDir"
}

$files = Get-ChildItem -Path (Join-Path $wallpaperDir "*") -File -Include *.jpg, *.jpeg, *.png, *.bmp | Sort-Object Name
if (-not $files) {
    throw "No wallpapers found in $wallpaperDir"
}

New-Item -ItemType Directory -Path $stateDir -Force | Out-Null

$lastWallpaper = $null
if (Test-Path $stateFile) {
    $lastWallpaper = (Get-Content -Path $stateFile -Raw).Trim()
}

$nextWallpaper = $null
if ($files.Count -eq 1) {
    $nextWallpaper = $files[0].FullName
} else {
    $candidates = $files | Where-Object { $_.FullName -ne $lastWallpaper }
    if (-not $candidates) {
        $candidates = $files
    }
    $nextWallpaper = Get-Random -InputObject $candidates | Select-Object -ExpandProperty FullName
}

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WallpaperSetter {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@

$SPI_SETDESKWALLPAPER = 20
$SPIF_UPDATEINIFILE = 0x01
$SPIF_SENDCHANGE = 0x02

$desktopKey = "HKCU:\Control Panel\Desktop"
Set-ItemProperty -Path $desktopKey -Name Wallpaper -Value $nextWallpaper
Set-ItemProperty -Path $desktopKey -Name WallpaperStyle -Value "10"
Set-ItemProperty -Path $desktopKey -Name TileWallpaper -Value "0"

$ok = [WallpaperSetter]::SystemParametersInfo(
    $SPI_SETDESKWALLPAPER,
    0,
    $nextWallpaper,
    $SPIF_UPDATEINIFILE -bor $SPIF_SENDCHANGE
)

if (-not $ok) {
    throw "Failed to set wallpaper: $nextWallpaper"
}

rundll32.exe user32.dll,UpdatePerUserSystemParameters

Set-Content -Path $stateFile -Value $nextWallpaper -NoNewline
