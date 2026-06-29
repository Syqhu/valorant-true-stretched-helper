@echo off
set "SCRIPT=%~dp0GameOptimizer.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
