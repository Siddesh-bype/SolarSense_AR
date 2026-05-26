#!/usr/bin/env bash
# -------------------------------------------------------------------
# SolarMitra — Report Module press-and-play launcher (Mac/Linux)
# -------------------------------------------------------------------
set -e
cd "$(dirname "$0")"

if [ ! -x "venv/bin/python" ]; then
  echo "[setup] Creating virtual environment..."
  python3 -m venv venv
  echo "[setup] Installing requirements..."
  venv/bin/python -m pip install --upgrade pip
  venv/bin/python -m pip install -r requirements.txt
else
  if ! venv/bin/python -c "import fastapi, uvicorn, reportlab" 2>/dev/null; then
    echo "[setup] Installing/updating requirements..."
    venv/bin/python -m pip install -r requirements.txt
  fi
fi

LAN_IP=$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')

echo
echo "==================================================================="
echo " SolarMitra - Report API"
echo "==================================================================="
[ -n "$LAN_IP" ] && echo " LAN URL for physical phone:  http://$LAN_IP:8000"
echo " Android emulator URL:        http://10.0.2.2:8000"
echo " Local URL:                   http://127.0.0.1:8000"
echo " Swagger docs:                http://127.0.0.1:8000/docs"
if [ -z "$OPENAI_API_KEY" ]; then
  echo
  echo " [note] OPENAI_API_KEY not set — PDF will be generated without"
  echo "        AI-written paragraphs (rest of the report is identical)."
fi
echo
echo " Press Ctrl+C to stop the server."
echo "==================================================================="
echo

exec venv/bin/python -m uvicorn api:app --host 0.0.0.0 --port 8000
