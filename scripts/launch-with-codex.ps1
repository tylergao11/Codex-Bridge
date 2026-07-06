. "$PSScriptRoot\common.ps1"

$ErrorActionPreference = "Stop"

# ── 1. Start bridge ──────────────────────────────────────
Write-Output "[bridge] Starting..."
$codexHome = Get-CodexHome
$proxyDir = Get-ProxyInstallDir $codexHome
$proxyFile = Join-Path $proxyDir "proxy.js"
$sourceProxy = Join-Path (Get-ProjectRoot) "src\proxy.js"
$defaults = Get-DeepSeekCodexDefaults

# Ensure proxy.js is deployed
New-Item -ItemType Directory -Force -Path $proxyDir | Out-Null
Copy-Item -LiteralPath $sourceProxy -Destination $proxyFile -Force

$key = Get-DeepSeekApiKey
if ([string]::IsNullOrWhiteSpace($key)) {
  throw "DEEPSEEK_API_KEY is not set."
}

$node = Get-CodexRuntimeNode
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $node
$psi.Arguments = "`"$proxyFile`""
$psi.WindowStyle = "Hidden"
$psi.UseShellExecute = $false
$psi.EnvironmentVariables["DEEPSEEK_API_KEY"] = $key
$psi.EnvironmentVariables["DEEPSEEK_MODEL"] = $defaults.Model

$bridgeProc = [System.Diagnostics.Process]::Start($psi)
Start-Sleep -Milliseconds 800

if ($bridgeProc.HasExited) {
  throw "Bridge process exited during startup: exitCode=$($bridgeProc.ExitCode)"
}

# Wait for bridge to be ready
$ready = $false
for ($i = 0; $i -lt 20; $i++) {
  try {
    Invoke-RestMethod -Uri "$($defaults.BaseUrl)/models" -Method Get -TimeoutSec 1 | Out-Null
    $ready = $true
    break
  } catch {
    Start-Sleep -Milliseconds 250
  }
}
if (-not $ready) {
  Stop-Process -Id $bridgeProc.Id -Force -ErrorAction SilentlyContinue
  throw "Bridge did not become ready."
}
Write-Output "[bridge] Started (pid=$($bridgeProc.Id))"

# ── 2. Launch Codex ──────────────────────────────────────
try {
  $codexExe = Get-CodexExe
} catch {
  Write-Output "[bridge] Codex not found, keeping bridge alive. Stop manually."
  Write-Output "[bridge] pid=$($bridgeProc.Id) port=$($defaults.BaseUrl)"
  exit 0
}

Write-Output "[codex] Launching $codexExe ..."
$codexProc = Start-Process -FilePath $codexExe -PassThru -WindowStyle Normal

# ── 3. Wait for Codex to exit, then stop bridge ──────────
Write-Output "[watcher] Waiting for Codex to exit (pid=$($codexProc.Id))..."
$codexProc.WaitForExit()

Write-Output "[watcher] Codex exited. Stopping bridge..."
Stop-Process -Id $bridgeProc.Id -Force -ErrorAction SilentlyContinue

# Wait for bridge to actually stop
for ($i = 0; $i -lt 10; $i++) {
  if ($bridgeProc.HasExited) { break }
  Start-Sleep -Milliseconds 300
}
if (-not $bridgeProc.HasExited) {
  Stop-Process -Id $bridgeProc.Id -Force
}

Write-Output "[watcher] Bridge stopped. Done."
