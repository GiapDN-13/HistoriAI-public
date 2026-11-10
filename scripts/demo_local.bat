@echo off
REM ============================================================
REM  HistoriAI - DEMO LOCAL co GIONG NOI (viXTTS)
REM  Double-click file nay, hoac chay: scripts\demo_local.bat
REM  Mo 3 cua so: viXTTS (8500) + Backend (8000) + Web (8080)
REM ============================================================
setlocal
cd /d "%~dp0\.."
set ROOT=%cd%

echo =================================================
echo   HistoriAI - DEMO LOCAL (chat + giong viXTTS)
echo =================================================

REM --- 1) viXTTS service (GPU, env vixtts) ---
echo [1/3] Khoi dong viXTTS (cong 8500)...
start "HistoriAI viXTTS" cmd /k "cd /d %ROOT%\vixtts_service && conda activate vixtts && python server.py"

REM --- 2) Backend (SQLite + LLM that + TTS vixtts) ---
echo [2/3] Khoi dong Backend API (cong 8000)...
start "HistoriAI Backend" cmd /k "cd /d %ROOT%\backend && set DATABASE_URL=sqlite:///./demo.db&& set TTS_PROVIDER=vixtts&& set VIXTTS_URL=http://127.0.0.1:8500&& set CORS_ORIGINS=*&& set PYTHONUTF8=1&& set PYTHONIOENCODING=utf-8&& python -m app.db.seed && uvicorn app.main:app --host 0.0.0.0 --port 8000"

REM --- 3) App web (build local + phuc vu tinh) ---
echo [3/3] Chuan bi app web (cong 8080)...
if not exist "%ROOT%\mobile\build\web\.local_demo" (
  echo     [!] Build web cho LOCAL ^(base / + localhost:8000, 1-2 phut^)...
  pushd "%ROOT%\mobile"
  call flutter build web --release --base-href / --dart-define=API_BASE_URL=http://localhost:8000
  popd
  type nul > "%ROOT%\mobile\build\web\.local_demo"
)
start "HistoriAI Web" cmd /k "cd /d %ROOT%\mobile\build\web && python -m http.server 8080"

echo.
echo =================================================
echo   SAN SANG! Mo Chrome:  http://localhost:8080
echo   - Cho viXTTS nap model ~30-60s moi co tieng.
echo   - Dong 3 cua so cmd de tat.
echo =================================================
timeout /t 8 >nul
start http://localhost:8080
endlocal
