' MicLock Event Hidden Launcher
' Prevents empty Windows Terminal windows on modern Windows 11
Set WshShell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & scriptDir & "\mic_lock_event.ps1"""
WshShell.Run cmd, 0, False
