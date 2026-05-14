# ⚡ MicLock Event: Event-Driven Windows Microphone Volume Lock

[![License: MIT](https://img.shields.io/badge/License-MIT-emerald.svg)](LICENSE)
[![Platform: Windows 10 / 11](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-blue.svg)](https://microsoft.com/windows)
[![PowerShell 5.1 / 7+](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://microsoft.com/powershell)

> **A zero-polling, event-triggered PowerShell + Batch utility that uses Windows native WASAPI callbacks to permanently protect your microphone recording volume from auto-adjusting apps (Discord, Zoom, Steam, WebRTC).**

---

## ⚡ The Problem with Traditional Polling Scripts

Most PowerShell scripts for locking microphone volume rely on a timer loop:
```powershell
while ($true) {
    # Query volume every 2 to 10 seconds
    Start-Sleep -Seconds 2
}
```

### Why Polling Fails:
- **Audible Lag:** During a call, Discord or Zoom lowers your volume. For up to 2–10 seconds, nobody can hear you until the timer wakes up.
- **CPU Spikes:** Constantly waking up the PowerShell runtime every few seconds wastes battery and CPU cycles.
- **Dependency Heaviness:** Requires installing external modules like `AudioDeviceCmdlets`.

---

## 🚀 How MicLock Event Solves This

**MicLock Event** uses inline C# COM interop to hook directly into Windows WASAPI (`IAudioEndpointVolumeCallback`):
1. **Zero Polling Loop:** The script sleeps indefinitely (`Timeout.Infinite`). Idle CPU usage is strictly **0.00%**.
2. **Instant Reversion (< 1 millisecond):** The microsecond an external program lowers the volume slider, the Windows audio engine fires the native callback and MicLock snaps it back immediately.
3. **Zero Module Dependencies:** Uses only Windows built-in CoreAudio APIs. No `Install-Module` required.
4. **Clean Hidden Execution:** Wrapped with `run_hidden.vbs` to eliminate flashing terminal tabs on Windows 11.

---

## 📦 Installation & Setup

### Quick Install (One-Click)
1. Right-click **`install.bat`** and select **Run as Administrator** (or double-click; it will prompt for elevation).
2. The installer will:
   - Copy scripts to `C:\Scripts\MicLockEvent\`.
   - Register the scheduled task `MicLockEvent` in Windows Task Scheduler.
   - Start the event listener immediately.

---

## 🗑️ Uninstallation

Right-click **`uninstall.bat`** and select **Run as Administrator**.
This stops background processes, removes the task from Task Scheduler, and removes script files.

---

## ⚙️ Manual Command Line Usage

You can also run the listener directly in any terminal:
```powershell
# Lock volume at 100% (default)
powershell.exe -ExecutionPolicy Bypass -File .\mic_lock_event.ps1

# Lock volume at custom percentage (e.g. 80%)
powershell.exe -ExecutionPolicy Bypass -File .\mic_lock_event.ps1 -TargetVolume 80
```

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
