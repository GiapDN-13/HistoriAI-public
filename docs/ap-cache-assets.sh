#!/usr/bin/env bash
# Sửa cache cho thư mục /assets/ của Flutter web — 27/09/2026.
#
# LỖI ĐANG SỬA
#   Flutter "tỉa" font biểu tượng (MaterialIcons-Regular.otf) mỗi lần dựng: chỉ giữ
#   các biểu tượng app đang dùng. Tên tệp KHÔNG đổi. Mà khối ảnh/font của nginx đặt
#   "30 ngày + immutable" → Cloudflare và trình duyệt giữ bản font CŨ, biểu tượng mới
#   thêm hiện ô trống (màn Hồ sơ bản 0.3.0). Ảnh trong assets/ cũng cùng bẫy: sửa ảnh
#   mà giữ tên là người dùng thấy ảnh cũ cả tháng.
#
# CÁCH SỬA
#   Khối riêng `location ^~ /assets/` (dấu ^~ làm nginx dùng khối này thay cho khối
#   regex theo đuôi tệp): giữ 1 giờ và phải hỏi lại máy chủ (must-revalidate). Tệp
#   không đổi thì máy chủ trả 304, gần như không tốn băng thông.
#   Ảnh bìa, model 3D, video ở ngoài /assets/ — không đụng tới.
#
# SAU KHI CHẠY: vào Cloudflare → historiai.org → Caching → Configuration →
#   "Purge Everything" MỘT LẦN, để bỏ bản font cũ Cloudflare đang giữ.
#
# CHẠY:  sudo bash ap-cache-assets.sh     (chạy lại nhiều lần không sao)

set -euo pipefail

CAU_HINH=/etc/nginx/sites-available/zz-historiai

if [ "$(id -u)" -ne 0 ]; then
    echo "Cần chạy bằng sudo:  sudo bash $0" >&2
    exit 1
fi
[ -f "$CAU_HINH" ] || { echo "Không thấy $CAU_HINH" >&2; exit 1; }

if grep -q 'location \^~ /assets/' "$CAU_HINH"; then
    echo "Đã áp từ trước rồi, không làm gì thêm."
    exit 0
fi

SAO_LUU="$CAU_HINH.sao-luu-$(date +%Y%m%d-%H%M%S)"
cp -p "$CAU_HINH" "$SAO_LUU"
echo "Đã sao lưu: $SAO_LUU"

python3 - "$CAU_HINH" <<'PY'
import sys, pathlib

p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
moc = "    # Flutter web là SPA"
if moc not in s:
    sys.exit("Không thấy mốc '# Flutter web là SPA' — dừng, sửa tay cho chắc.")
khoi = """    # Tài nguyên Flutter (font biểu tượng, ảnh, manifest) — tên KHÔNG đổi khi nội dung
    # đổi, nên không được immutable. Xem docs/ap-cache-assets.sh.
    location ^~ /assets/ {
        expires 1h;
        add_header Cache-Control "public, max-age=3600, must-revalidate";
        include snippets/historiai-bao-mat.conf;
    }

"""
p.write_text(s.replace(moc, khoi + moc, 1), encoding="utf-8")
print("Đã thêm khối /assets/")
PY

if nginx -t; then
    systemctl reload nginx
    echo "nginx đã nạp lại."
else
    echo "nginx -t LỖI — khôi phục bản sao lưu." >&2
    cp -p "$SAO_LUU" "$CAU_HINH"
    nginx -t && systemctl reload nginx
    exit 1
fi

sleep 2
echo
echo "Kiểm tra (phải thấy max-age=3600, must-revalidate):"
curl -sI -H "Host: historiai.org" http://127.0.0.1/assets/fonts/MaterialIcons-Regular.otf | grep -i "cache-control" || true
echo
echo "NHỚ: Cloudflare → Caching → Configuration → Purge Everything (một lần)."
