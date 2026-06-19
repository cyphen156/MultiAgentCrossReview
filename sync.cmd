@echo off
setlocal
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync.ps1"

if errorlevel 1 (
    echo.
    echo [sync] failed
    pause
    exit /b 1
)
echo.
echo [sync] complete
pause
