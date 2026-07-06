. "$PSScriptRoot\common.ps1"

$ErrorActionPreference = "Stop"

$projectRoot = Get-ProjectRoot
$launcherScript = Join-Path $projectRoot "scripts\launch-with-codex.ps1"
$pwsh = (Get-Command powershell.exe -ErrorAction Stop).Source

# ── Find all Codex shortcuts ─────────────────────────────
$shortcutDirs = @(
  [Environment]::GetFolderPath("StartMenu") + "\Programs",
  [Environment]::GetFolderPath("CommonStartMenu") + "\Programs",
  [Environment]::GetFolderPath("Desktop"),
  [Environment]::GetFolderPath("CommonDesktop")
)

$found = @()
foreach ($dir in $shortcutDirs) {
  if (-not (Test-Path $dir)) { continue }
  $items = Get-ChildItem -Path $dir -Filter "*codex*.lnk" -Recurse -ErrorAction SilentlyContinue
  foreach ($item in $items) {
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($item.FullName)
    if ($shortcut.TargetPath -match "codex" -or $shortcut.Description -match "codex|Codex") {
      $found += $item.FullName
    }
  }
}

if ($found.Count -eq 0) {
  Write-Output "[shortcut] No Codex shortcuts found. Creating one in Start Menu..."
  $startMenu = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs\Codex"
  New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
  $lnkPath = Join-Path $startMenu "Codex.lnk"
  $WshShell = New-Object -ComObject WScript.Shell
  $lnk = $WshShell.CreateShortcut($lnkPath)
  $lnk.TargetPath = $pwsh
  $lnk.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherScript`""
  $lnk.WorkingDirectory = $projectRoot
  $lnk.IconLocation = (Get-CodexExe) + ",0"
  $lnk.Description = "Codex + DeepSeek Bridge"
  $lnk.Save()
  Write-Output "[shortcut] Created: $lnkPath"
  Write-Output "[shortcut] Pin this to taskbar manually if needed."
  exit 0
}

Write-Output "[shortcut] Found $($found.Count) Codex shortcut(s):"
foreach ($f in $found) { Write-Output "  $f" }
Write-Output ""

# ── Backup ───────────────────────────────────────────────
$backupDir = Join-Path $projectRoot "shortcut-backups"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

foreach ($f in $found) {
  $backupName = [System.IO.Path]::GetFileNameWithoutExtension($f) + "_" + (Get-Date -Format "yyyyMMddHHmmss") + ".lnk"
  $backupPath = Join-Path $backupDir $backupName
  Copy-Item $f $backupPath -Force
  Write-Output "[shortcut] Backup: $backupPath"
}

# ── Replace ──────────────────────────────────────────────
foreach ($f in $found) {
  $codexExe = Get-CodexExe -ErrorAction SilentlyContinue
  $icon = if ($codexExe) { "$codexExe,0" } else { "imageres.dll,10" }
  
  $WshShell = New-Object -ComObject WScript.Shell
  $lnk = $WshShell.CreateShortcut($f)
  $lnk.TargetPath = $pwsh
  $lnk.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$launcherScript`""
  $lnk.WorkingDirectory = $projectRoot
  $lnk.IconLocation = $icon
  $lnk.Description = "Codex + DeepSeek Bridge"
  $lnk.Save()
  
  Write-Output "[shortcut] Replaced: $f"
}

Write-Output ""
Write-Output "[shortcut] Done. From now on, clicking Codex = auto bridge + Codex."
Write-Output "[shortcut] Backup saved to: $backupDir"
