param(
  [string]$Prompt = "只输出 OK，不要解释。",
  [string]$Sandbox = "read-only",
  [string]$WorkDir = "",
  [string]$Expect = "OK"
)

. "$PSScriptRoot\common.ps1"

$key = Get-DeepSeekApiKey
if ([string]::IsNullOrWhiteSpace($key)) {
  throw "DEEPSEEK_API_KEY is not set in this process or the user environment."
}

$env:DEEPSEEK_API_KEY = $key
$codexExe = Get-CodexExe
$cwd = if ([string]::IsNullOrWhiteSpace($WorkDir)) { Get-ProjectRoot } else { (Resolve-Path $WorkDir).Path }
$outFile = Join-Path (Get-ProjectRoot) "tmp\codex-smoke.out.txt"
$errFile = Join-Path (Get-ProjectRoot) "tmp\codex-smoke.err.txt"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outFile) | Out-Null
$args = @(
  "-a", "never",
  "-s", $Sandbox,
  "-C", $cwd,
  "exec",
  "--skip-git-repo-check",
  $Prompt
)
$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  & $codexExe @args > $outFile 2> $errFile
  $exitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
}
$stdout = if (Test-Path $outFile) { Get-Content -LiteralPath $outFile -Raw } else { "" }
$stderr = if (Test-Path $errFile) { Get-Content -LiteralPath $errFile -Raw } else { "" }
if ($exitCode -ne 0) {
  Write-Output $stdout
  Write-Output $stderr
  throw "Codex smoke failed with exit code $exitCode."
}
if ($Expect -and $stdout -notmatch [regex]::Escape($Expect)) {
  Write-Output $stdout
  Write-Output $stderr
  throw "Codex smoke output did not contain expected marker: $Expect"
}
Write-Output $stdout
