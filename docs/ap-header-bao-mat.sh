#!/usr/bin/env bash
# Thêm các header bảo mật cho historiai.org (và tên miền cũ) — audit 27/09/2026.
#
# THÊM GÌ, VÌ SAO
#   Strict-Transport-Security   Trình duyệt nhớ "trang này chỉ đi HTTPS" trong 180 ngày.
#                               Không có nó, ai đó chung wifi quán cà phê có thể chặn
#                               lần gõ historiai.org đầu tiên (còn là HTTP) và giả trang.
#   X-Content-Type-Options      Trình duyệt không tự "đoán" kiểu tệp — chặn kiểu tấn công
#                               tải lên một tệp trông như ảnh nhưng chạy như mã.
#   X-Frame-Options +           Chỉ chính historiai.org được nhúng trang của mình vào khung
#   CSP frame-ancestors         (viewer.html 3D vẫn nhúng được). Chặn trang lạ lồng app vào
#                               khung trong suốt để lừa người dùng bấm (clickjacking).
#   Referrer-Policy             Khi bấm link ra ngoài, chỉ gửi tên miền, không gửi đường dẫn.
#   Permissions-Policy          Chỉ historiai.org được xin micro/camera; không ai xin vị trí.
#
#   CỐ Ý CHƯA đặt Content-Security-Policy đầy đủ (script-src…): Flutter web nạp
#   CanvasKit/wasm, iframe viewer, Google Fonts, GA4 — siết sai một dòng là app trắng
#   trang. Để khi có thời gian thử kỹ trên bản thử.
#
# CÁCH LÀM
#   nginx có một cái bẫy: khối `location` nào có `add_header` riêng (ở đây là các khối
#   Cache-Control) thì BỎ HẾT add_header của cấp server. Nên các header nằm trong một
#   tệp snippet, và được include ở cấp server lẫn trong từng khối có add_header.
#   Kèm theo: phien-ban.json (báo bản cài mới cho app Android) vào danh sách LUÔN tươi.
#
# CHẠY:  sudo bash ap-header-bao-mat.sh
# Chạy lại nhiều lần không sao. nginx -t lỗi thì tự khôi phục bản sao lưu.

set -euo pipefail

CAU_HINH=/etc/nginx/sites-available/zz-historiai
SNIPPET=/etc/nginx/snippets/historiai-bao-mat.conf

if [ "$(id -u)" -ne 0 ]; then
    echo "Cần chạy bằng sudo:  sudo bash $0" >&2
    exit 1
fi
[ -f "$CAU_HINH" ] || { echo "Không thấy $CAU_HINH" >&2; exit 1; }

mkdir -p /etc/nginx/snippets
cat > "$SNIPPET" <<'NGINX'
# Header bảo mật HistoriAI — do docs/ap-header-bao-mat.sh sinh ra, sửa ở đó.
add_header Strict-Transport-Security "max-age=15552000" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Content-Security-Policy "frame-ancestors 'self'" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "microphone=(self), camera=(self), geolocation=()" always;
NGINX
echo "Đã ghi $SNIPPET"

SAO_LUU="$CAU_HINH.sao-luu-$(date +%Y%m%d-%H%M%S)"
cp -p "$CAU_HINH" "$SAO_LUU"
echo "Đã sao lưu: $SAO_LUU"

python3 - "$CAU_HINH" <<'PY'
import sys, pathlib

p = pathlib.Path(sys.argv[1])
dong = p.read_text(encoding="utf-8").split("\n")
INC = "include snippets/historiai-bao-mat.conf;"
ra, trong_server_chinh = [], False

for i, d in enumerate(dong):
    t = d.strip()
    # Đã include ngay sau dòng này rồi thì thôi (chạy lại lần hai).
    da_co = i + 1 < len(dong) and INC in dong[i + 1]
    ra.append(d)
    if t.startswith("server_name") and "historiai.org" in t and "www." not in t:
        trong_server_chinh = True
    if not trong_server_chinh or da_co:
        continue
    thut = d[: len(d) - len(d.lstrip())]
    if t == "index index.html;":
        ra.append(f"{thut}{INC}")
    elif t.startswith("add_header Cache-Control"):
        ra.append(f"{thut}{INC}")
    if t == "}" and thut == "":
        trong_server_chinh = False

s = "\n".join(ra)
cu = "flutter_service_worker\\.js|manifest\\.json)$"
if "phien-ban" not in s and cu in s:
    s = s.replace(cu, "flutter_service_worker\\.js|manifest\\.json|phien-ban\\.json)$", 1)
p.write_text(s, encoding="utf-8")
print("Số chỗ include:", s.count(INC))
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

echo
echo "Kiểm tra (qua nginx nội bộ):"
curl -sI -H "Host: historiai.org" http://127.0.0.1/ | grep -iE "strict-transport|x-content-type|x-frame|content-security|referrer-policy|permissions-policy" || true
curl -sI -H "Host: historiai.org" http://127.0.0.1/favicon.png | grep -icE "strict-transport" | sed 's/^/  header trên ảnh (phải là 1): /'
