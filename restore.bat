@echo off
chcp 65001 >nul
title Comdr - Restore Codex Defaults
echo ========================================
echo   Codex - Restore ChatGPT Defaults
echo ========================================
echo.

:: --- find Codex home ---
if defined CODEX_HOME (set "CODEX_HOME=%CODEX_HOME%") else (set "CODEX_HOME=%USERPROFILE%\.codex")
set "CONFIG=%CODEX_HOME%\config.toml"

if not exist "%CONFIG%" (
    echo [ERROR] config.toml not found at %CONFIG%
    pause
    exit /b 1
)

:: --- kill bridge ---
echo Stopping bridge...
powershell -Command "$p=Get-NetTCPConnection -LocalPort 18081 -ErrorAction SilentlyContinue|Select -ExpandProperty OwningProcess -Unique;if($p){$p|%%{Stop-Process -Id $_ -Force};Write-Output '[OK] Bridge stopped'}else{Write-Output '[OK] No bridge running'}" 2>nul

:: --- restore last backup if available ---
cd /d "%CODEX_HOME%"
for /f "delims=" %%f in ('dir /b /o-d config.toml.bak-* 2^>nul') do (
    copy /Y "%%f" "config.toml" >nul
    echo [OK] Restored from backup: %%f
    goto :done
)

:: --- no backup: revert inline ---
echo No backup found, reverting defaults inline...
powershell -Command ^
  "$cfg=Get-Content '%CONFIG%' -Raw; ^
  $cfg=$cfg -replace '(?m)^model\s*=.*', 'model = \"gpt-5.5\"'; ^
  $cfg=$cfg -replace '(?m)^model_reasoning_effort\s*=.*', 'model_reasoning_effort = \"medium\"'; ^
  $cfg=$cfg -replace '(?m)^model_provider\s*=.*\r?\n?', ''; ^
  $cfg=$cfg -replace '(?s)\[model_providers\.deepseek\].*?(\r?\n\[|\z)', '$1'; ^
  [IO.File]::WriteAllText('%CONFIG%', $cfg, [Text.Encoding]::UTF8)"
echo [OK] Config reverted to ChatGPT defaults

:done
echo.
echo ========================================
echo   Restore complete.
echo ========================================
pause
