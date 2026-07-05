@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title Comdr - Codex DeepSeek Bridge Setup
echo ========================================
echo   Codex DeepSeek Bridge - Setup
echo ========================================
echo.

:: --- find project root (where this .bat lives) ---
set "PROJECT_ROOT=%~dp0"

:: --- find Codex home ---
if defined CODEX_HOME (set "CODEX_HOME=%CODEX_HOME%") else (set "CODEX_HOME=%USERPROFILE%\.codex")
if not exist "%CODEX_HOME%" mkdir "%CODEX_HOME%"

:: --- check API key ---
if defined DEEPSEEK_API_KEY goto :key_ok
echo [WARN] DEEPSEEK_API_KEY not set in environment.
echo Checking user environment variable...
powershell -Command "$k=[Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY','User'); if($k){Write-Output $k}else{Write-Output ''}" > "%TEMP%\ds_key.txt" 2>nul
set /p DS_KEY=<"%TEMP%\ds_key.txt"
del "%TEMP%\ds_key.txt" 2>nul
if not "%DS_KEY%"=="" (
    set "DEEPSEEK_API_KEY=%DS_KEY%"
    goto :key_ok
)
echo.
echo Please enter your DeepSeek API key (from https://platform.deepseek.com/api_keys):
set /p DEEPSEEK_API_KEY="API Key: "
if "%DEEPSEEK_API_KEY%"=="" (
    echo [ERROR] API key is required.
    pause
    exit /b 1
)
powershell -Command "[Environment]::SetEnvironmentVariable('DEEPSEEK_API_KEY','%DEEPSEEK_API_KEY%','User')"
echo [OK] API key saved.
:key_ok

:: --- deploy proxy.js ---
set "PROXY_DIR=%CODEX_HOME%\deepseek-responses-proxy"
if not exist "%PROXY_DIR%" mkdir "%PROXY_DIR%"
copy /Y "%PROJECT_ROOT%src\proxy.js" "%PROXY_DIR%\proxy.js" >nul
echo [OK] proxy.js deployed

:: --- backup config ---
set "CONFIG=%CODEX_HOME%\config.toml"
if not exist "%CONFIG%" type nul > "%CONFIG%"
for /f "tokens=1-3 delims=/ " %%a in ('date /t') do set "TS=%%a%%b%%c"
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set "TS=%TS%-%%a%%b"
copy /Y "%CONFIG%" "%CONFIG%.bak-%TS%" >nul
echo [OK] config backed up

:: --- kill existing bridge if running ---
powershell -Command "$p=Get-NetTCPConnection -LocalPort 18081 -ErrorAction SilentlyContinue|Select -ExpandProperty OwningProcess -Unique;if($p){$p|%%{Stop-Process -Id $_ -Force};Write-Output '[OK] old bridge stopped'}else{Write-Output '[OK] no old bridge'}" 2>nul

:: --- modify config.toml ---
powershell -Command ^
  "$cfg=Get-Content '%CONFIG%' -Raw; ^
  $cfg=$cfg -replace '(?m)^model\s*=.*', 'model = \"deepseek-v4-pro\"'; ^
  $cfg=$cfg -replace '(?m)^model_provider\s*=.*', 'model_provider = \"deepseek\"'; ^
  $cfg=$cfg -replace '(?m)^model_reasoning_effort\s*=.*', 'model_reasoning_effort = \"max\"'; ^
  $block=\"`r`n[model_providers.deepseek]`r`nname = \""DeepSeek Pro (local proxy)\"\"`r`nbase_url = \""http://127.0.0.1:18081/v1\"\"`r`nenv_key = \""DEEPSEEK_API_KEY\"\"`r`nwire_api = \""responses\"\"`r`n\"; ^
  if($cfg -match '\[model_providers\.deepseek\]'){ ^
    $cfg=$cfg -replace '(?s)\[model_providers\.deepseek\].*?(\r?\n\[|\z)', ($block+'$1') ^
  } else { ^
    $cfg=$cfg.TrimEnd()+$block ^
  }; ^
  [IO.File]::WriteAllText('%CONFIG%', $cfg, [Text.Encoding]::UTF8)"
echo [OK] config updated

:: --- start bridge ---
set "NODE=node"
for /r "%LOCALAPPDATA%\OpenAI\Codex\runtimes" %%f in (node.exe) do set "NODE=%%f"
start /B "" "%NODE%" "%PROXY_DIR%\proxy.js"
timeout /t 2 >nul
echo [OK] bridge starting...

:: --- verify ---
powershell -Command "try{$r=Invoke-RestMethod 'http://127.0.0.1:18081/v1/models' -TimeoutSec 3;Write-Output '[OK] Bridge is LIVE - models available'}catch{Write-Output '[WARN] Bridge not ready yet, wait a moment'}" 2>nul

echo.
echo ========================================
echo   Setup complete!
echo   Proxy: %PROXY_DIR%\proxy.js
echo   Config: %CONFIG%
echo   Log: %PROXY_DIR%\proxy.log
echo ========================================
pause
