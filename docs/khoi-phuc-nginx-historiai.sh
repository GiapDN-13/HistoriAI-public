#!/usr/bin/env bash
# Khôi phục cấu hình nginx của historiai.org — 30/10/2026.
#
# SỰ CỐ
#   27/10 06:05 apt nâng nginx (1.24.0-2ubuntu7.18 → 7.19) và khởi động lại. Tệp
#   /etc/nginx/sites-available/zz-historiai trên ổ là bản 21/09 — chỉ có
#   historiai.anhzap.shop, không có historiai.org/www, WebSocket, header bảo mật.
#   nginx nạp lại tệp đó → historiai.org không khớp server nào → rơi vào site mặc
#   định `qly` (anhZap). Bản đầy đủ đang chạy từ 28/09 nằm ở docs/nginx-historiai.conf.
#
# CHẠY (trên VPS):  sudo bash ~/khoi-phuc-nginx-historiai.sh
#   cần ~/nginx-historiai.conf (chép từ docs/nginx-historiai.conf) nằm cạnh kịch bản.
# Sao lưu trước; nginx -t sai thì trả lại bản cũ, không reload.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Cần chạy bằng sudo"; exit 1; }

NGUON="$(dirname "$(readlink -f "$0")")/nginx-historiai.conf"
DICH=/etc/nginx/sites-available/zz-historiai
SNIPPET=/etc/nginx/snippets/historiai-bao-mat.conf
MOC=$(date +%Y%m%d_%H%M%S)

[ -f "$NGUON" ] || { echo "Thiếu $NGUON"; exit 1; }
[ -f "$SNIPPET" ] || { echo "Thiếu $SNIPPET (header bảo mật) — chạy lại docs/ap-header-bao-mat.sh trước"; exit 1; }

cp -a "$DICH" "/root/zz-historiai.truoc-khoi-phuc.$MOC"   # KHÔNG để bản sao trong sites-enabled
echo "Đã sao lưu bản đang có: /root/zz-historiai.truoc-khoi-phuc.$MOC"

install -m 664 -o root -g nginx-edit "$NGUON" "$DICH"
if ! nginx -t; then
  echo "nginx -t báo SAI — trả lại bản cũ, không reload"
  cp -a "/root/zz-historiai.truoc-khoi-phuc.$MOC" "$DICH"
  exit 1
fi
systemctl reload nginx
sleep 1

echo
echo "Kiểm qua nginx nội bộ:"
kiem() { curl -s -o /dev/null -w "  %-28s → %{http_code}  (mong đợi $3)\n" -H "Host: $1" "http://127.0.0.1$2"; }
kiem historiai.org /                 200
kiem historiai.org /api/v1/events    200
kiem www.historiai.org /             301
kiem historiai.anhzap.shop /         301
kiem historiai.anhzap.shop /api/v1/events 200
printf "  tiêu đề trang historiai.org: "
curl -s -H "Host: historiai.org" http://127.0.0.1/ | grep -o "<title>[^<]*" | head -1
echo "XONG. Tiêu đề phải là HistoriAI, không phải anhZap."
