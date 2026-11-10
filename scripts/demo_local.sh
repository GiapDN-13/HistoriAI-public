#!/usr/bin/env bash
# =============================================================
# HistoriAI - Khởi động DEMO LOCAL có GIỌNG NÓI (viXTTS)
# Chạy 1 lệnh:  bash scripts/demo_local.sh
#
# Gồm 3 thành phần:
#   1) viXTTS service  (conda env 'vixtts', GPU)        cổng 8500
#   2) Backend FastAPI (SQLite + LLM thật + TTS=vixtts) cổng 8000
#   3) App web (đã build) phục vụ tĩnh                  cổng 8080
#
# Dừng: nhấn Ctrl+C (script tự tắt cả 3).
# =============================================================
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "================================================="
echo "  HistoriAI - DEMO LOCAL (chat + giọng viXTTS)"
echo "================================================="

PIDS=()
cleanup() {
  echo ""
  echo "[*] Dang tat cac service..."
  for pid in "${PIDS[@]}"; do kill "$pid" 2>/dev/null || true; done
  exit 0
}
trap cleanup INT TERM

# --- 1) viXTTS service (GPU) ---
echo "[1/3] Khoi dong viXTTS (cong 8500) - lan dau nap model ~30-60s..."
(
  cd "$ROOT/vixtts_service"
  conda run --no-capture-output -n vixtts python server.py
) &
PIDS+=($!)

# --- 2) Backend (SQLite + TTS vixtts) ---
echo "[2/3] Khoi dong Backend API (cong 8000)..."
(
  cd "$ROOT/backend"
  export DATABASE_URL="sqlite:///./demo.db"
  export TTS_PROVIDER="vixtts"
  export VIXTTS_URL="http://127.0.0.1:8500"
  export CORS_ORIGINS="*"
  export PYTHONUTF8=1
  export PYTHONIOENCODING=utf-8
  # seed (idempotent) roi chay server
  python -m app.db.seed
  uvicorn app.main:app --host 0.0.0.0 --port 8000
) &
PIDS+=($!)

# --- 3) App web (phuc vu tinh) ---
# QUAN TRONG: API_BASE_URL duoc nhung vao luc BUILD. Ban deploy tro toi Render
# (khong co giong). Demo local can build tro toi localhost:8000 -> dung marker
# de chi build lai khi can.
echo "[3/3] Chuan bi app web (cong 8080)..."
MARKER="$ROOT/mobile/build/web/.local_demo"
if [ ! -f "$MARKER" ]; then
  echo "    [!] Build web cho LOCAL (base / + localhost:8000, 1-2 phut)..."
  # QUAN TRONG: base-href phai la / (khong phai /historiai-app/) de chay o root
  ( cd "$ROOT/mobile" && flutter build web --release \
      --base-href / \
      --dart-define=API_BASE_URL=http://localhost:8000 )
  touch "$MARKER"
fi
(
  cd "$ROOT/mobile/build/web"
  python -m http.server 8080
) &
PIDS+=($!)

sleep 3
echo ""
echo "================================================="
echo "  SAN SANG! Mo trinh duyet (Chrome):"
echo "     http://localhost:8080"
echo ""
echo "  LUU Y:"
echo "   - Cho viXTTS nap model xong (~30-60s) moi co tieng."
echo "   - App web nay tro toi backend LOCAL (co giong)."
echo "   - Nhan Ctrl+C de tat tat ca."
echo "================================================="
wait
