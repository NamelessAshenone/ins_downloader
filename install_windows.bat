@echo off
REM Launcher for install_windows.ps1
REM Bypasses the execution-policy restriction that blocks scripts downloaded
REM from the Internet (Zone.Identifier / "not digitally signed" error).

powershell -ExecutionPolicy Bypass -File "%~dp0install_windows.ps1"
pause
