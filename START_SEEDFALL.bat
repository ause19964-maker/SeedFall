@echo off
REM ==========================================================================
REM  SEEDFALL - one-click local launcher for Windows
REM  Double-click this file. First run needs internet to install packages.
REM  It never deletes or resets your database.
REM ==========================================================================
setlocal EnableExtensions
title SEEDFALL launcher
cd /d "%~dp0"
set "ROOT=%CD%"
set "BACKEND=%ROOT%\backend"
set "FRONTEND=%ROOT%\frontend"
set "VENV=%ROOT%\.venv"
set "VPY=%VENV%\Scripts\python.exe"
set "API_URL=http://127.0.0.1:8000"
set "WEB_URL=http://127.0.0.1:5173"

echo.
echo   SEEDFALL - The Living Memory of Seeds
echo   Project folder: "%ROOT%"
echo.

REM ---------- 1. Check Python (3.11 or newer) ----------
set "PYCMD="
where py >nul 2>nul && py -3 -c "import sys; sys.exit(0 if sys.version_info>=(3,11) else 1)" >nul 2>nul && set "PYCMD=py -3"
if defined PYCMD goto python_ok
where python >nul 2>nul && python -c "import sys; sys.exit(0 if sys.version_info>=(3,11) else 1)" >nul 2>nul && set "PYCMD=python"
if defined PYCMD goto python_ok
echo [ERROR] Python 3.11 or newer was not found.
echo         Install it from https://www.python.org/downloads/
echo         During setup, tick "Add python.exe to PATH". Then run this file again.
goto fail
:python_ok
for /f "delims=" %%v in ('%PYCMD% -c "import platform; print(platform.python_version())"') do echo   [ok] Python %%v

REM ---------- 2. Check Node.js and npm ----------
where node >nul 2>nul
if errorlevel 1 goto no_node
where npm >nul 2>nul
if errorlevel 1 goto no_node
for /f "delims=" %%v in ('node --version') do echo   [ok] Node.js %%v
goto node_ok
:no_node
echo [ERROR] Node.js (with npm) was not found.
echo         Install the LTS version from https://nodejs.org/ and run this file again.
goto fail
:node_ok

REM ---------- 3. Is SEEDFALL already running? (avoid duplicates) ----------
call :is_seedfall_up
if "%UP%"=="1" goto already_running
netstat -ano | findstr /R /C:":8000 .*LISTENING" >nul
if not errorlevel 1 goto port_8000_busy
netstat -ano | findstr /R /C:":5173 .*LISTENING" >nul
if not errorlevel 1 goto port_5173_busy

REM ---------- 4. Python virtual environment + backend packages ----------
if exist "%VPY%" goto venv_ok
echo   Creating Python virtual environment (first run only)...
%PYCMD% -m venv "%VENV%"
if errorlevel 1 goto venv_fail
:venv_ok
fc /b "%BACKEND%\requirements.txt" "%VENV%\requirements.installed" >nul 2>nul
if not errorlevel 1 goto pip_ok
echo   Installing backend packages (needs internet the first time)...
"%VPY%" -m pip install --disable-pip-version-check -q -r "%BACKEND%\requirements.txt"
if errorlevel 1 goto pip_fail
copy /y "%BACKEND%\requirements.txt" "%VENV%\requirements.installed" >nul
:pip_ok
echo   [ok] Backend packages installed

REM ---------- 5. Frontend packages ----------
fc /b "%FRONTEND%\package-lock.json" "%FRONTEND%\node_modules\.seedfall-lock" >nul 2>nul
if not errorlevel 1 goto npm_ok
echo   Installing frontend packages (needs internet the first time)...
pushd "%FRONTEND%"
call npm ci --no-audit --no-fund
if errorlevel 1 call npm install --no-audit --no-fund
if errorlevel 1 goto npm_fail_pop
popd
copy /y "%FRONTEND%\package-lock.json" "%FRONTEND%\node_modules\.seedfall-lock" >nul
:npm_ok
echo   [ok] Frontend packages installed

REM ---------- 6. Initialise database safely ----------
REM  New install: creates an EMPTY database (no fictional records).
REM  Older (v1) database: a full backup is written to backend\data\backups first, then columns/tables are only added.
pushd "%BACKEND%"
"%VPY%" -m app.bootstrap
if errorlevel 1 goto db_fail_pop
popd

REM ---------- 7. Start backend and frontend in their own windows ----------
echo   Starting backend on %API_URL% ...
start "SEEDFALL backend" /D "%BACKEND%" cmd /k ""%VPY%" -m uvicorn app.main:app --host 127.0.0.1 --port 8000"
call :wait_for "%API_URL%/api/health" 60
if not "%WAITED%"=="1" goto backend_fail
echo   [ok] Backend is running

echo   Starting frontend on %WEB_URL% ...
start "SEEDFALL frontend" /D "%FRONTEND%" cmd /k "npm run dev"
call :wait_for "%WEB_URL%/api/health" 90
if not "%WAITED%"=="1" goto frontend_fail
echo   [ok] Frontend is running

:open
echo.
echo   ===============================================================
echo    SEEDFALL is running.
echo      App:       %WEB_URL%
echo      API docs:  %API_URL%/docs
echo    Close the two "SEEDFALL" windows (or run STOP_SEEDFALL.bat)
echo    to stop it. Your data stays in backend\data\seedfall.db
echo    Backups: backend\data\backups   (Export ^& backup page)
echo    Alerts are checked every 60 min while SEEDFALL runs.
echo    To check while it is closed, schedule RUN_ALERT_CHECK.bat.
echo   ===============================================================
start "" "%WEB_URL%"
echo.
pause
exit /b 0

:already_running
echo   SEEDFALL is already running - opening it instead of starting a second copy.
goto open

:port_8000_busy
echo [ERROR] Port 8000 is used by another program, so the SEEDFALL backend cannot start.
echo         Close that program (or run STOP_SEEDFALL.bat if it is an old SEEDFALL window) and try again.
goto fail
:port_5173_busy
echo [ERROR] Port 5173 is used by another program, so the SEEDFALL frontend cannot start.
echo         Close that program (or run STOP_SEEDFALL.bat) and try again.
goto fail
:venv_fail
echo [ERROR] Could not create the Python virtual environment in "%VENV%".
goto fail
:pip_fail
echo [ERROR] Installing backend packages failed. Check your internet connection and the messages above.
goto fail
:npm_fail_pop
popd
echo [ERROR] Installing frontend packages failed. Check your internet connection and the messages above.
goto fail
:db_fail_pop
popd
echo [ERROR] The database could not be initialised. See the message above. Nothing was deleted.
goto fail
:backend_fail
echo [ERROR] The backend did not start within 60 seconds. Read the "SEEDFALL backend" window for details.
goto fail
:frontend_fail
echo [ERROR] The frontend did not start within 90 seconds. Read the "SEEDFALL frontend" window for details.
goto fail

:fail
echo.
echo   SEEDFALL did not start. Nothing was deleted or reset.
pause
exit /b 1

REM ---------- helpers ----------
:is_seedfall_up
set "UP=0"
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 '%WEB_URL%/api/health'; if ($r.Content -match 'schema_version') { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
if not errorlevel 1 set "UP=1"
exit /b 0

:wait_for
REM %1 = url, %2 = seconds
set "WAITED=0"
powershell -NoProfile -Command "$end=(Get-Date).AddSeconds(%~2); while((Get-Date) -lt $end){ try { $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 '%~1'; if($r.StatusCode -eq 200){ exit 0 } } catch {}; Start-Sleep -Milliseconds 700 }; exit 1" >nul 2>nul
if not errorlevel 1 set "WAITED=1"
exit /b 0
