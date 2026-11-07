@echo off
REM ==================================================
REM   GitPigeon - delivers your Git commits on schedule
REM
REM   Developed by : EMR Industries
REM   Version      : 1.1.3
REM   Built date   : 2026.11.07
REM ==================================================
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0GitPigeon.ps1"
