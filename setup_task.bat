@echo off
rem Run as administrator. Registers the collector to run every hour, even when nobody is logged in.
schtasks /Create /F /TN "DeltaForce Collector" /SC HOURLY /MO 1 /RU SYSTEM /RL HIGHEST /TR "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"%~dp0collect.ps1\""
schtasks /Query /TN "DeltaForce Collector"
pause
