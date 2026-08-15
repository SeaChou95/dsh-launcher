@echo off
chcp 65001 >nul
cd /d "%~dp0"
start "" powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0open-dsh.ps1" -Log
