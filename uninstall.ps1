<#
.SYNOPSIS
    Uninstalls the event-driven PowerShell MicLock task.
#>

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Administrative privileges required to remove task."
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Terminating background mic_lock_event processes..." -ForegroundColor Cyan
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*mic_lock_event*" } | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host "Stopping and deleting task 'MicLockEvent'..." -ForegroundColor Cyan
try { Stop-ScheduledTask -TaskName "MicLockEvent" -ErrorAction SilentlyContinue } catch {}
try { Unregister-ScheduledTask -TaskName "MicLockEvent" -Confirm:$false -ErrorAction Stop } catch {}

if (Test-Path "C:\Scripts\MicLockEvent") {
    Remove-Item "C:\Scripts\MicLockEvent" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed C:\Scripts\MicLockEvent"
}

Write-Host "`n[SUCCESS] MicLock Event completely uninstalled!" -ForegroundColor Green
