<#
.SYNOPSIS
    Installs and provisions the event-driven PowerShell MicLock task.
#>

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Administrative privileges required to register logon task."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetDir = "C:\Scripts\MicLockEvent"

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
}

Write-Host "Copying event-driven scripts to $targetDir..." -ForegroundColor Cyan
Copy-Item "$scriptDir\mic_lock_event.ps1" "$targetDir\mic_lock_event.ps1" -Force
Copy-Item "$scriptDir\run_hidden.vbs" "$targetDir\run_hidden.vbs" -Force

Write-Host "Registering Scheduled Task 'MicLockEvent'..." -ForegroundColor Cyan
$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$targetDir\run_hidden.vbs`"" -WorkingDirectory $targetDir
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -Hidden -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "MicLockEvent" -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -Force | Out-Null

Write-Host "Starting task 'MicLockEvent'..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName "MicLockEvent"

Write-Host "`n[SUCCESS] MicLock Event is now active!" -ForegroundColor Green
Write-Host "Log: $targetDir\mic_lock.log"
