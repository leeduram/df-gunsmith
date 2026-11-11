@echo off
echo MySQL root password:
"C:\Program Files\MySQL\MySQL Server 9.7\bin\mysql.exe" -u root -p < "%~dp0setup_db.sql"
pause
