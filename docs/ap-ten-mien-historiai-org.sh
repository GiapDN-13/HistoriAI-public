#!/usr/bin/env bash
# Nối historiai.org vào tunnel + nginx. Chạy: sudo bash ~/ap-ten-mien-historiai-org.sh
#
# - Tunnel: thêm historiai.org và www.historiai.org (trước dòng bắt-tất-cả 404).
# - nginx:  historiai.org phục vụ app như cũ; www → 301 về historiai.org;
#           historiai.anhzap.shop: TRANG WEB → 301 sang historiai.org,
#           nhưng /api/ và /health GIỮ NGUYÊN — bản cài Android đã phát ra
#           được dựng sẵn gọi API ở tên miền cũ, chuyển hướng là chúng hỏng.
# Sao lưu trước; kiểm cú pháp; sai ở đâu thì khôi phục bản cũ ở đó.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Cần chạy bằng sudo"; exit 1; }

CF=/etc/cloudflared/config.yml
NG=/etc/nginx/sites-enabled/zz-historiai
MOC=$(date +%Y%m%d_%H%M%S)
cp -a "$CF" "$CF.bak.$MOC"
cp -a "$NG" "/root/zz-historiai.bak.$MOC"      # KHÔNG để bản sao trong sites-enabled: nginx sẽ nạp cả nó
echo "Đã sao lưu: $CF.bak.$MOC và /root/zz-historiai.bak.$MOC"

# ---------- 1. Tunnel ----------
if grep -q "hostname: historiai.org" "$CF"; then
  echo "Tunnel: đã có historiai.org — bỏ qua"
else
  python3 - "$CF" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
moi = ("  - hostname: historiai.org\n    service: http://127.0.0.1:80\n"
       "  - hostname: www.historiai.org\n    service: http://127.0.0.1:80\n")
cu = "  - service: http_status:404"
assert s.count(cu) == 1, "không thấy dòng bắt-tất-cả 404"
open(p, "w", encoding="utf-8").write(s.replace(cu, moi + cu))
PY
  if ! cloudflared tunnel --config "$CF" ingress validate; then
    echo "Tunnel: cấu hình mới SAI — khôi phục bản cũ"; cp -a "$CF.bak.$MOC" "$CF"; exit 1
  fi
fi

# ---------- 2. nginx ----------
python3 - "$NG" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
if "historiai.org" in s:
    print("nginx: đã có historiai.org — bỏ qua"); sys.exit(0)
cu = "    server_name historiai.anhzap.shop;\n"
assert s.count(cu) == 1, "không thấy server_name cũ"
moi = """    server_name historiai.org historiai.anhzap.shop;

    # Tên miền cũ: trang web chuyển sang historiai.org, còn /api/ và /health giữ
    # nguyên cho các bản cài Android đã phát ra (dựng sẵn gọi API ở tên miền cũ).
    if ($host = historiai.anhzap.shop) {
        rewrite ^/(?!api/|health$)(.*)$ https://historiai.org/$1 permanent;
    }
"""
s = s.replace(cu, moi)
s += """
# www → tên miền chính
server {
    listen 80;
    server_name www.historiai.org;
    return 301 https://historiai.org$request_uri;
}
"""
open(p, "w", encoding="utf-8").write(s)
print("nginx: đã thêm historiai.org")
PY
if ! nginx -t; then
  echo "nginx: cấu hình mới SAI — khôi phục bản cũ"
  cp -a "/root/zz-historiai.bak.$MOC" "$NG"; cp -a "$CF.bak.$MOC" "$CF"; exit 1
fi

# ---------- 3. Áp dụng ----------
systemctl reload nginx
systemctl restart cloudflared
sleep 4
if ! systemctl is-active --quiet cloudflared; then
  echo "cloudflared không lên — khôi phục cấu hình tunnel cũ"
  cp -a "$CF.bak.$MOC" "$CF"; systemctl restart cloudflared; exit 1
fi
echo
echo "XONG. Kiểm nhanh qua nginx nội bộ:"
curl -s -o /dev/null -w "  historiai.org  /           → %{http_code}\n" -H "Host: historiai.org" http://127.0.0.1/
curl -s -o /dev/null -w "  historiai.org  /api/v1/events → %{http_code}\n" -H "Host: historiai.org" http://127.0.0.1/api/v1/events
curl -s -o /dev/null -w "  tên miền cũ    /           → %{http_code} (mong đợi 301)\n" -H "Host: historiai.anhzap.shop" http://127.0.0.1/
curl -s -o /dev/null -w "  tên miền cũ    /api/v1/events → %{http_code} (mong đợi 200)\n" -H "Host: historiai.anhzap.shop" http://127.0.0.1/api/v1/events
curl -s -o /dev/null -w "  www            /           → %{http_code} (mong đợi 301)\n" -H "Host: www.historiai.org" http://127.0.0.1/
