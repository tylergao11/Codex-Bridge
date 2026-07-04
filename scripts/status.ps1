. "$PSScriptRoot\common.ps1"

$port = Get-ProxyPort
$defaults = Get-DeepSeekCodexDefaults
$processes = Get-ProxyProcesses
if ($processes.Count -eq 0) {
  Write-Output "DeepSeek bridge: stopped"
  exit 0
}

Write-Output "DeepSeek bridge: running"
foreach ($process in $processes) {
  Write-Output "pid=$($process.Id) path=$($process.Path)"
}
try {
  $models = Invoke-RestMethod -Uri "$($defaults.BaseUrl)/models" -Method Get -TimeoutSec 5
  Write-Output "models=$($models.models.slug -join ',')"
} catch {
  Write-Output "models endpoint failed: $($_.Exception.Message)"
}
