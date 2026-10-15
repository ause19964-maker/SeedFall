@echo off
REM Stops the SEEDFALL backend and frontend windows started by START_SEEDFALL.bat.
REM It only closes windows titled "SEEDFALL backend" / "SEEDFALL frontend" - no other programs,
REM and it never touches the database.
setlocal
echo Stopping SEEDFALL...
taskkill /FI "WINDOWTITLE eq SEEDFALL backend*" /T /F >nul 2>nul && echo   Backend stopped. || echo   Backend window not found (already stopped?).
taskkill /FI "WINDOWTITLE eq SEEDFALL frontend*" /T /F >nul 2>nul && echo   Frontend stopped. || echo   Frontend window not found (already stopped?).
echo Done. Your data is kept in backend\data\seedfall.db
timeout /t 3 >nul
