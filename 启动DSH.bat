@echo off
chcp 65001 >nul
title DSH Auto Launcher (Debug)
cd /d "%~dp0"
echo ============================================
echo   DSH 自动启动器 - 前台调试模式
echo   平时请双击 启动DSH.vbs（无窗口运行）
echo ============================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0open-dsh.ps1"
echo.
pause
