#!/usr/bin/env bash
# Mở đường WebSocket cho chế độ THI TRỰC TIẾP của lớp học (giai đoạn 2) — 27/09/2026.
#
# VÌ SAO CẦN
#   Khối `location /api/` hiện có không chuyển tiếp header Upgrade/Connection → nginx nói
#   HTTP thường với uvicorn, bắt tay WebSocket hỏng (trình duyệt báo lỗi 400/426). App vẫn
#   chạy nhờ đường dự phòng (hỏi lại trạng thái 2 giây/lần) nhưng câu mới tới chậm, và 40
#   em hỏi liên tục thì tốn tải hơn hẳn một kết nối mở sẵn.
#   Cloudflare Tunnel chuyển WebSocket sẵn, không phải sửa gì bên đó.
#
# THÊM GÌ
#   Một khối `location /api/v1/ws/` đứng TRƯỚC `location /api/` (nginx chọn tiền tố dài
#   nhất nên thứ tự không bắt buộc, đặt trước cho dễ đọc). Thời gian chờ 1 giờ: sảnh chờ
#   có thể im cả phút; app gửi "ping" 25 giây/lần nên kết nối không bị cắt oan.
#
# CHẠY:  sudo bash ap-websocket-lop-hoc.sh
# Chạy lại nhiều lần không sao (đã có khối thì bỏ qua). nginx -t lỗi thì tự khôi phục.
# Chạy xong nhớ chép lại /etc/nginx/sites-available/zz-historiai về docs/nginx-historiai.conf.

set -euo pipefail

CAU_HINH=/etc/nginx/sites-available/zz-historiai

if [ "$(id -u)" -ne 0 ]; then
    echo "Cần chạy bằng sudo:  sudo bash $0" >&2
    exit 1
fi
[ -f "$CAU_HINH" ] || { echo "Không thấy $CAU_HINH" >&2; exit 1; }

if grep -q "location /api/v1/ws/" "$CAU_HINH"; then
    echo "Đã có khối WebSocket — không làm gì."
    exit 0
fi

SAO_LUU="$CAU_HINH.sao-luu-$(date +%Y%m%d-%H%M%S)"
cp -p "$CAU_HINH" "$SAO_LUU"
echo "Đã sao lưu: $SAO_LUU"

python3 - "$CAU_HINH" <<'PY'
import sys, pathlib

p = pathlib.Path(sys.argv[1])
chu = p.read_text(encoding="utf-8")
khoi = """    # Thi trực tiếp (lớp học GĐ2): WebSocket — do docs/ap-websocket-lop-hoc.sh thêm
    location /api/v1/ws/ {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }

"""
moc = "    location /api/ {"
if chu.count(moc) != 1:
    sys.exit(f"Không thấy đúng một dòng '{moc}' — sửa tay theo khối trong kịch bản này.")
p.write_text(chu.replace(moc, khoi + moc), encoding="utf-8")
print("Đã thêm khối location /api/v1/ws/")
PY

if nginx -t; then
    systemctl reload nginx
    echo "Xong. Thử:  curl -i -N -H 'Connection: Upgrade' -H 'Upgrade: websocket' \\"
    echo "  -H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \\"
    echo "  https://historiai.org/api/v1/ws/phong/000000     # mong đợi: HTTP/1.1 101"
else
    echo "nginx -t lỗi — khôi phục bản sao lưu." >&2
    cp -p "$SAO_LUU" "$CAU_HINH"
    exit 1
fi
