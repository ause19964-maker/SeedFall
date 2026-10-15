@echo off
REM ==========================================================================
REM  SEEDFALL - run ONE preservation alert check (no browser, no server needed)
REM  Schedule this file with Windows Task Scheduler to check alerts even when
REM  SEEDFALL is not running. See README, "Scheduled alert checks on Windows".
REM  It never deletes or resets data. Running it while SEEDFALL is open is safe:
REM  alerts and notifications are unique per event, so nothing is duplicated.
REM ==========================================================================
setlocal EnableExtensions
cd /d "%~dp0"
set "ROOT=%CD%"
set "VPY=%ROOT%\.venv\Scripts\python.exe"
set "LOG=%ROOT%\backend\data\alert-checks.log"
if not exist "%VPY%" (
  echo [ERROR] SEEDFALL is not installed yet. Run START_SEEDFALL.bat once first.
  exit /b 1
)
if not exist "%ROOT%\backend\data" mkdir "%ROOT%\backend\data"
pushd "%ROOT%\backend"
echo ==== %DATE% %TIME% ==== >> "%LOG%"
"%VPY%" -m app.alert_runner %* >> "%LOG%" 2>&1
set "RC=%ERRORLEVEL%"
popd
if not "%RC%"=="0" (
  echo [ERROR] The alert check failed. Details: "%LOG%"
  exit /b %RC%
)
echo Alert check completed. Details: "%LOG%"
exit /b 0
