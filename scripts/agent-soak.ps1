param(
  [int]$Count = 5
)

. "$PSScriptRoot\common.ps1"

$ErrorActionPreference = "Stop"
$projectRoot = Get-ProjectRoot
$codexExe = Get-CodexExe
$key = Get-DeepSeekApiKey
if ([string]::IsNullOrWhiteSpace($key)) {
  throw "DEEPSEEK_API_KEY is not set in this process or the user environment."
}

for ($i = 1; $i -le $Count; $i++) {
  $env:DEEPSEEK_API_KEY = $key
  $expected = "SOAK-$i-OK"
  $prompt = "Only output $expected and nothing else."
  $outFile = Join-Path $projectRoot "tmp\agent-soak-$i.out.txt"
  $errFile = Join-Path $projectRoot "tmp\agent-soak-$i.err.txt"
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outFile) | Out-Null
  $args = @(
    "-a", "never",
    "-s", "read-only",
    "-C", $projectRoot,
    "exec",
    "--skip-git-repo-check",
    $prompt
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
    throw "Soak iteration $i failed with exit code $exitCode."
  }
  if ($stdout -notmatch [regex]::Escape($expected)) {
    Write-Output $stdout
    Write-Output $stderr
    throw "Soak iteration $i missing expected marker $expected."
  }
  Write-Output "PASS soak $i/$Count"
}

Write-Output "agent soak passed"
