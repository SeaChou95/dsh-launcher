@echo off
chcp 65001 >nul
title DSH Auto Launcher
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0open-dsh.ps1"
echo.
pause
