#!/usr/bin/env bash
# Tách tệp model 3D (.glb/.gltf/.usdz) ra khỏi khối cache ảnh/font của nginx.
#
# HAI VẤN ĐỀ ĐANG SỬA
#
# 1. KIỂU MIME. nginx đang trả .glb là `application/octet-stream`. Đúng ra phải
#    là `model/gltf-binary`. Scene Viewer của Google tự tải tệp bằng tiến trình
#    riêng của nó, và có thể từ chối tệp sai kiểu — nếu nút "Đặt vào phòng" mở
#    lên rồi báo không đọc được tệp thì đây là nghi phạm số một.
#
# 2. CACHE 30 NGÀY + immutable. Tên tệp model KHÔNG đổi khi nội dung đổi
#    (`trong-dong-dong-son.glb` vẫn là nó sau khi chuẩn hoá tỉ lệ về mét), nên
#    máy nào từng mở Bảo tàng sẽ giữ tỉ lệ cũ suốt một tháng. Đã gặp thật lúc
#    kiểm chứng: trình duyệt dựng lại bản cũ, phải thêm ?v= mới thấy bản mới.
#    Đổi thành 1 ngày + must-revalidate: vẫn cache, nhưng hỏi lại máy chủ.
#
# CHẠY:  sudo bash ap-nginx-glb.sh
# Chạy lại nhiều lần không sao — script tự nhận ra đã áp rồi thì thôi.

set -euo pipefail

CAU_HINH=/etc/nginx/sites-available/zz-historiai

if [ "$(id -u)" -ne 0 ]; then
    echo "Cần chạy bằng sudo:  sudo bash $0" >&2
    exit 1
fi

if [ ! -f "$CAU_HINH" ]; then
    echo "Không thấy $CAU_HINH" >&2
    exit 1
fi

if grep -q 'model/gltf-binary' "$CAU_HINH"; then
    echo "Đã áp từ trước rồi, không làm gì thêm."
    exit 0
fi

SAO_LUU="$CAU_HINH.sao-luu-$(date +%Y%m%d-%H%M%S)"
cp -p "$CAU_HINH" "$SAO_LUU"
echo "Đã sao lưu: $SAO_LUU"

python3 - "$CAU_HINH" <<'PY'
import re, sys, pathlib

p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding='utf-8')

# 1) Bỏ glb|usdz khỏi khối ảnh/font, để chúng rơi xuống khối riêng bên dưới.
cu = r'location ~\* \\\.\(png\|jpg\|jpeg\|gif\|svg\|woff2\?\|ttf\|otf\|wasm\|glb\|usdz\)\$'
moi = r'location ~* \.(png|jpg|jpeg|gif|svg|woff2?|ttf|otf|wasm)$'
s, n = re.subn(cu, moi.replace('\\', '\\\\'), s, count=1)
if n != 1:
    # Khối có thể đã được sửa tay; thử cách nhẹ hơn là chỉ bỏ hai đuôi.
    s2 = s.replace('|wasm|glb|usdz)$', '|wasm)$', 1)
    if s2 == s:
        sys.exit('Không tìm thấy khối ảnh/font quen thuộc — dừng lại, '
                 'sửa tay cho chắc.')
    s = s2

# 2) Chèn khối riêng cho model 3D ngay trước khối "luôn tươi".
neo = '    location ~* /(index\\.html|main\\.dart\\.js'
khoi = """    # Model 3D: kiểu MIME đúng để Scene Viewer nhận, và KHÔNG immutable vì
    # tên tệp không đổi khi nội dung đổi.
    location ~* \\.(glb|gltf|usdz)$ {
        types {
            model/gltf-binary   glb;
            model/gltf+json     gltf;
            model/vnd.usdz+zip  usdz;
        }
        expires 1d;
        add_header Cache-Control "public, must-revalidate";
    }

"""
i = s.find(neo)
if i < 0:
    sys.exit('Không tìm thấy chỗ chèn — dừng lại, sửa tay cho chắc.')
s = s[:i] + khoi + s[i:]

p.write_text(s, encoding='utf-8')
print('  đã sửa cấu hình')
PY

echo "Kiểm tra cú pháp..."
if nginx -t; then
    systemctl reload nginx
    echo
    echo "XONG. Kiểm lại từ máy khác:"
    echo "  curl -sI https://historiai.anhzap.shop/models/trong-dong-dong-son.glb | grep -i 'content-type\\|cache-control'"
    echo "Phải thấy:  Content-Type: model/gltf-binary"
    echo "            Cache-Control: public, must-revalidate"
else
    echo
    echo "CÚ PHÁP SAI — đang khôi phục bản cũ, nginx không bị đụng tới." >&2
    cp -p "$SAO_LUU" "$CAU_HINH"
    exit 1
fi
