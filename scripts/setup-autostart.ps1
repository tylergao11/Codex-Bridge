. "$PSScriptRoot\common.ps1"

$ErrorActionPreference = "Stop"

$shortcutPath = Join-Path ([Environment]::GetFolderPath("Startup")) "CodexDeepSeekBridge.lnk"

param(
  [switch]$Remove
)

if ($Remove) {
  if (Test-Path $shortcutPath) {
    Remove-Item $shortcutPath -Force
    Write-Output "[autostart] Removed: $shortcutPath"
  } else {
    Write-Output "[autostart] Not installed."
  }
  exit 0
}

# Check if already installed
if (Test-Path $shortcutPath) {
  Write-Output "[autostart] Already installed: $shortcutPath"
  exit 0
}

# Resolve paths
$projectRoot = Get-ProjectRoot
$startScript = Join-Path $projectRoot "scripts\start.ps1"
$pwsh = (Get-Command powershell.exe -ErrorAction Stop).Source

# Create shortcut
$WshShell = New-Object -ComObject WScript.Shell
$shortcut = $WshShell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $pwsh
$shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$startScript`""
$shortcut.WorkingDirectory = $projectRoot
$shortcut.WindowStyle = 7  # Minimized
$shortcut.Description = "Codex DeepSeek Bridge (auto-start)"
$shortcut.Save()

Write-Output "[autostart] Installed: $shortcutPath"
Write-Output "[autostart] Bridge will start automatically when you log in."
Write-Output "[autostart] To remove: powershell -File scripts\setup-autostart.ps1 -Remove"
