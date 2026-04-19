@echo off
setlocal EnableDelayedExpansion

:: Check for Administrative Privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [MicLock Event Installer] Requesting administrative privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c \"\"%~dp0install.bat\"\"' -Verb RunAs"
    exit /b
)

echo =========================================================
echo   Installing MicLock Event (Zero-Polling WASAPI Task)
echo =========================================================

set "SCRIPT_DIR=%~dp0"
set "TARGET_DIR=C:\Scripts\MicLockEvent"

:: 1. Ensure target directory exists
if not exist "%TARGET_DIR%" (
    echo [*] Creating directory %TARGET_DIR%...
    mkdir "%TARGET_DIR%"
)

:: 2. Copy script files
echo [*] Copying mic_lock_event.ps1 and run_hidden.vbs to %TARGET_DIR%...
copy /Y "%SCRIPT_DIR%mic_lock_event.ps1" "%TARGET_DIR%\mic_lock_event.ps1" >nul
copy /Y "%SCRIPT_DIR%run_hidden.vbs" "%TARGET_DIR%\run_hidden.vbs" >nul

:: 3. Register Scheduled Task
echo [*] Registering Windows Scheduled Task 'MicLockEvent'...
schtasks /create /tn "MicLockEvent" /tr "wscript.exe \"%TARGET_DIR%\run_hidden.vbs\"" /sc onlogon /rl highest /f

:: 4. Start the task immediately
echo [*] Starting task 'MicLockEvent'...
schtasks /run /tn "MicLockEvent"

echo.
echo [OK] MicLock Event is now active!
echo      - Zero polling loop / 0%% CPU
echo      - Native WASAPI 0ms volume restoration
echo      - Logs written to %TARGET_DIR%\mic_lock.log
echo.
pause
