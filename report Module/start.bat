@echo off
REM -------------------------------------------------------------------
REM SolarSense AR — Report Module press-and-play launcher (Windows)
REM
REM   * Creates venv if missing
REM   * Installs requirements (first run only)
REM   * Starts FastAPI backend on 0.0.0.0:8000
REM   * Prints LAN IP so a phone on the same Wi-Fi can reach it
REM -------------------------------------------------------------------

setlocal enabledelayedexpansion
cd /d "%~dp0"

if not exist "venv\Scripts\python.exe" (
  echo [setup] Creating virtual environment...
  python -m venv venv
  if errorlevel 1 (
    echo [error] Could not create venv. Install Python 3.10+ and retry.
    pause
    exit /b 1
  )
  echo [setup] Installing requirements...
  venv\Scripts\python -m pip install --upgrade pip
  venv\Scripts\python -m pip install -r requirements.txt
  if errorlevel 1 (
    echo [error] pip install failed.
    pause
    exit /b 1
  )
) else (
  REM Make sure critical deps are present even if venv is old
  venv\Scripts\python -c "import fastapi, uvicorn, reportlab" 2>nul
  if errorlevel 1 (
    echo [setup] Installing/updating requirements...
    venv\Scripts\python -m pip install -r requirements.txt
  )
)

echo.
echo ===================================================================
echo  SolarSense AR - Report API
echo ===================================================================
echo.
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
  set "ip=%%a"
  set "ip=!ip: =!"
  echo  LAN URL for physical phone:  http://!ip!:8000
)
echo  Android emulator URL:        http://10.0.2.2:8000
echo  Local URL:                   http://127.0.0.1:8000
echo  Swagger docs:                http://127.0.0.1:8000/docs
echo.
if "%OPENAI_API_KEY%"=="" (
  echo  [note] OPENAI_API_KEY not set - PDF will be generated without
  echo         AI-written paragraphs (rest of the report is identical).
  echo         To enable, run: set OPENAI_API_KEY=sk-...
  echo.
)
echo  Press Ctrl+C to stop the server.
echo ===================================================================
echo.

venv\Scripts\python -m uvicorn api:app --host 0.0.0.0 --port 8000

endlocal
