#!/usr/bin/env bash
# Bỏ cờ "immutable" cho thư mục /assets/ của Flutter.
#
# VẤN ĐỀ
#     Flutter web đặt mọi tài nguyên (font, ảnh, chân dung, icon) dưới /assets/
#     với TÊN CỐ ĐỊNH — đổi nội dung không đổi tên. Nhưng nginx đang trả cả
#     khối này với `max-age=2592000, immutable`, tức 30 ngày và trình duyệt
#     không cần hỏi lại.
#
#     Hệ quả: mọi thay đổi tài nguyên KHÔNG tới được người dùng cũ trong một
#     tháng, mà không có dấu hiệu gì. Đã gặp thật: thêm ba icon mới vào màn
#     Premium, trên đĩa font là 20.772 byte nhưng qua CDN vẫn là bản 19.656
#     byte từ hai ngày trước — ba icon hiện ra vòng tròn rỗng.
#
#     Đây là lần thứ tư cùng một loại bẫy trong dự án (main.dart.js, tệp .apk,
#     model .glb, và giờ là /assets/). Ba cái trước đã vá bằng cách gắn mã băm
#     vào đường dẫn; riêng /assets/ thì Flutter tự sinh đường dẫn nên phải
#     chỉnh ở nginx.
#
# SỬA
#     Cho /assets/ cache 1 ngày kèm must-revalidate: vẫn nhanh cho người dùng,
#     nhưng trình duyệt có hỏi lại máy chủ. Dùng tiền tố `^~` để khối này thắng
#     khối regex ảnh/font bên dưới.
#
# CHẠY:  sudo bash ap-nginx-assets.sh
# Chạy lại nhiều lần không sao.

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
if grep -q "location \^~ /assets/" "$CAU_HINH"; then
    echo "Đã áp từ trước rồi, không làm gì thêm."
    exit 0
fi

SAO_LUU="$CAU_HINH.sao-luu-$(date +%Y%m%d-%H%M%S)"
cp -p "$CAU_HINH" "$SAO_LUU"
echo "Đã sao lưu: $SAO_LUU"

python3 - "$CAU_HINH" <<'PY'
import sys, pathlib

p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding='utf-8')

khoi = """    # Tài nguyên Flutter: tên tệp CỐ ĐỊNH, đổi nội dung không đổi tên, nên
    # tuyệt đối không được đánh dấu immutable. Tiền tố ^~ để khối này thắng
    # khối regex ảnh/font bên dưới.
    location ^~ /assets/ {
        expires 1d;
        add_header Cache-Control "public, must-revalidate";
    }

"""

# Chèn ngay trước khối ảnh/font hiện có.
for neo in ('    # Ảnh, font, model 3D có thể cache lâu\n',
            '    location ~* \\.(png|jpg'):
    i = s.find(neo)
    if i >= 0:
        s = s[:i] + khoi + s[i:]
        break
else:
    sys.exit('Không tìm thấy chỗ chèn — dừng lại, sửa tay cho chắc.')

p.write_text(s, encoding='utf-8')
print('  đã sửa cấu hình')
PY

echo "Kiểm tra cú pháp..."
if nginx -t; then
    systemctl reload nginx
    echo
    echo "XONG. Còn MỘT việc nữa: vào Cloudflare purge cache một lần."
    echo "Không purge thì bản cũ vẫn nằm ở biên tới 30 ngày."
    echo
    echo "Kiểm lại sau khi purge:"
    echo "  curl -sI https://historiai.anhzap.shop/assets/fonts/MaterialIcons-Regular.otf | grep -i cache-control"
    echo "Phải thấy:  Cache-Control: public, must-revalidate"
else
    echo
    echo "CÚ PHÁP SAI — đang khôi phục bản cũ, nginx không bị đụng tới." >&2
    cp -p "$SAO_LUU" "$CAU_HINH"
    exit 1
fi
