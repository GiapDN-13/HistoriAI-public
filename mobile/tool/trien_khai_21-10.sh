#!/usr/bin/env bash
# Triển khai đợt 21/10 lên historiai.org — chạy từ thư mục worktree HistoriAI-phan-hoi:
#   bash mobile/tool/trien_khai_21-10.sh
# Làm: sao lưu backend + CSDL trên VPS → chép backend mới (nhánh phat-hanh-21-10) →
# khởi động lại API → kiểm → dựng + đưa web (tool/phat_hanh.py web) → chép trang /tai-app.
# Không đụng: .env, media/, audio_cache/, data/seed_lam_giau.json (kết quả đường ống).
set -euo pipefail
VPS=giapdn@100.65.123.107
NHANH=${1:-phat-hanh-21-10}   # bash mobile/tool/trien_khai_21-10.sh <nhánh>
NGAY=$(date +%d-%m-%H%M)
cd "$(git rev-parse --show-toplevel)"

echo "== 1. Sao lưu trên VPS"
ssh "$VPS" "export NGAY=$NGAY;"' set -e; cd ~/historiai; mkdir -p ~/backups
  tar czf ~/backups/backend-truoc-$NGAY.tgz --exclude=__pycache__ backend/app backend/tools backend/data backend/static backend/requirements.txt
  cd data && python3 -c "import sqlite3;s=sqlite3.connect(\"historiai.db\");d=sqlite3.connect(\"historiai.db.truoc-$NGAY\");s.backup(d);print(\"  CSDL:\",d.execute(\"select count(*) from users\").fetchone()[0],\"tài khoản\")"
  ls -la ~/backups/backend-truoc-$NGAY.tgz'

echo "== 2. Chép backend mới ($NHANH)"
git archive "$NHANH" backend/app backend/tools backend/data backend/static backend/requirements.txt \
  | ssh "$VPS" 'tar xf - --strip-components=1 -C ~/historiai/backend'

echo "== 3. Khởi động lại API (systemd tự bật lại tiến trình)"
ssh "$VPS" 'kill $(systemctl show -p MainPID --value historiai); for i in $(seq 1 30); do sleep 2; c=$(curl -s -o /dev/null -w "%{http_code}" 127.0.0.1:8081/api/v1/events); [ "$c" = 200 ] && break; done; echo "  /events $c"'

echo "== 4. Kiểm API mới"
curl -s -o /dev/null -w "  /lo-trinh %{http_code}\n" https://historiai.org/api/v1/lo-trinh
curl -s -X POST https://historiai.org/api/v1/quiz/check -H 'Content-Type: application/json' \
  -d '{"question_id":1,"selected_option":""}' | grep -q correct_option && echo "  /quiz/check có đáp án đúng ✓"
curl -s -o /dev/null -w "  /ban-tin (link sai → 404) %{http_code}\n" https://historiai.org/api/v1/ban-tin/thu

echo "== 5. Dựng + đưa web"
(cd mobile && python tool/phat_hanh.py web)

echo "== 6. Trang /tai-app (mục iPhone) — phat_hanh.py không chép thư mục này"
scp -q mobile/web/tai-app/index.html "$VPS":/home/giapdn/historiai/web/tai-app/index.html
curl -s https://historiai.org/tai-app/ | grep -q 'id="iphone"' && echo "  /tai-app có mục iPhone ✓"

echo "== Xong. Quay lại bản cũ nếu cần:"
echo "   ssh $VPS 'cd ~/historiai && tar xzf ~/backups/backend-truoc-$NGAY.tgz && kill \$(systemctl show -p MainPID --value historiai)'"
