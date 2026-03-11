@echo off
REM Launcher for install_windows.ps1
REM Bypasses the execution-policy restriction that blocks scripts downloaded
REM from the Internet (Zone.Identifier / "not digitally signed" error).
REM Tries pwsh (PowerShell 7) first; falls back to powershell (5.1).

where pwsh >nul 2>nul
if %ERRORLEVEL% equ 0 (
    pwsh -ExecutionPolicy Bypass -File "%~dp0install_windows.ps1"
) else (
    powershell -ExecutionPolicy Bypass -File "%~dp0install_windows.ps1"
)
pause
