@echo off
setlocal EnableDelayedExpansion

:: Check for Administrative Privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [MicLock Event Uninstaller] Requesting administrative privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c \"\"%~dp0uninstall.bat\"\"' -Verb RunAs"
    exit /b
)

echo =========================================================
echo   Uninstalling MicLock Event
echo =========================================================

:: 1. Stop background processes
echo [*] Terminating mic_lock_event.ps1 processes...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*mic_lock_event*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

:: 2. Stop and delete task
echo [*] Removing 'MicLockEvent' task from Task Scheduler...
schtasks /end /tn "MicLockEvent" >nul 2>&1
schtasks /delete /tn "MicLockEvent" /f

:: 3. Clean up directory
if exist "C:\Scripts\MicLockEvent" (
    echo [*] Cleaning C:\Scripts\MicLockEvent...
    rd /s /q "C:\Scripts\MicLockEvent" >nul 2>&1
)

echo.
echo [OK] MicLock Event has been completely uninstalled!
echo.
pause
