param(
    [ValidateSet("Catppuccin", "TokyoNight")]
    [string]$Theme = "Catppuccin"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$backupRoot = Join-Path $env:USERPROFILE ".dotfiles-backup\windows-ui-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

function Backup-IfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $backupTarget = Join-Path $backupRoot $Label
    $backupParent = Split-Path -Parent $backupTarget
    New-Item -ItemType Directory -Force -Path $backupParent | Out-Null
    Copy-Item -LiteralPath $Path -Destination $backupTarget -Recurse -Force
}

function Sync-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination,
        [Parameter(Mandatory = $true)]
        [string]$BackupLabel
    )

    Backup-IfExists -Path $Destination -Label $BackupLabel
    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    Write-Host "Synced file: $Destination"
}

function Sync-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination,
        [Parameter(Mandatory = $true)]
        [string]$BackupLabel
    )

    Backup-IfExists -Path $Destination -Label $BackupLabel
    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
    Write-Host "Synced directory: $Destination"
}

$windowsRoot = Join-Path $repoRoot "windows"
$themeRoot = if ($Theme -eq "TokyoNight") {
    Join-Path $windowsRoot "themes\tokyonight"
} else {
    $windowsRoot
}

$yasbConfigSource = Join-Path $windowsRoot ".config\yasb\config.yaml"
$yasbStylesSource = Join-Path $themeRoot ".config\yasb\styles.css"
$glazewmSource = Join-Path $themeRoot ".glzr\glazewm\config.yaml"
$flowSettingsSource = Join-Path $themeRoot "AppData\Roaming\FlowLauncher\Settings\Settings.json"
$flowPluginSettingsSource = Join-Path $windowsRoot "AppData\Roaming\FlowLauncher\Settings\Plugins"
$flowThemesSource = Join-Path $windowsRoot "AppData\Roaming\FlowLauncher\Themes"
$favoritesPluginSource = Join-Path $windowsRoot "AppData\Roaming\FlowLauncher\Plugins\Flow.Launcher.Plugin.Favorites"
$wallpaperScriptSource = Join-Path $windowsRoot "Scripts\windots-wallpaper-rotator.ps1"

$yasbConfigTarget = Join-Path $env:USERPROFILE ".config\yasb\config.yaml"
$yasbStylesTarget = Join-Path $env:USERPROFILE ".config\yasb\styles.css"
$glazewmTarget = Join-Path $env:USERPROFILE ".glzr\glazewm\config.yaml"
$flowSettingsTarget = Join-Path $env:APPDATA "FlowLauncher\Settings\Settings.json"
$flowPluginSettingsTarget = Join-Path $env:APPDATA "FlowLauncher\Settings\Plugins"
$flowThemesTarget = Join-Path $env:APPDATA "FlowLauncher\Themes"
$favoritesPluginTarget = Join-Path $env:APPDATA "FlowLauncher\Plugins\Flow.Launcher.Plugin.Favorites"
$wallpaperScriptTarget = Join-Path $env:USERPROFILE "Scripts\windots-wallpaper-rotator.ps1"

Sync-File -Source $yasbConfigSource -Destination $yasbConfigTarget -BackupLabel "yasb\config.yaml"
Sync-File -Source $yasbStylesSource -Destination $yasbStylesTarget -BackupLabel "yasb\styles.css"
Sync-File -Source $glazewmSource -Destination $glazewmTarget -BackupLabel "glazewm\config.yaml"
Sync-File -Source $flowSettingsSource -Destination $flowSettingsTarget -BackupLabel "flowlauncher\Settings\Settings.json"
Sync-Directory -Source $flowPluginSettingsSource -Destination $flowPluginSettingsTarget -BackupLabel "flowlauncher\Settings\Plugins"
Sync-Directory -Source $flowThemesSource -Destination $flowThemesTarget -BackupLabel "flowlauncher\Themes"
Sync-Directory -Source $favoritesPluginSource -Destination $favoritesPluginTarget -BackupLabel "flowlauncher\Plugins\Flow.Launcher.Plugin.Favorites"
Sync-File -Source $wallpaperScriptSource -Destination $wallpaperScriptTarget -BackupLabel "Scripts\windots-wallpaper-rotator.ps1"

Write-Host ""
Write-Host "Windows UI restore complete."
Write-Host "Active theme: $Theme"
Write-Host "Backups saved under: $backupRoot"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Restart Flow Launcher"
Write-Host "  2. Restart YASB"
Write-Host "  3. Restart GlazeWM"
Write-Host "  4. Re-enable the wallpaper scheduled task manually if you still want it"
