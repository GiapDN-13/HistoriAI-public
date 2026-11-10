#!/usr/bin/env python3
"""Phát hành một lệnh: dựng web + APK, kiểm bản dựng, đưa lên VPS, kiểm lại trên mạng.

VÌ SAO CẦN:
    Trước đây mỗi lần phát hành phải ghép tay một lệnh dài: ba --dart-define, đánh
    dấu phiên bản, dựng APK, kiểm chữ ký, đóng gói, tar qua ssh, scp. 28/09 tham số
    bị ghép nhầm hai lần → bản 0.5.2–0.5.4 chạy không có Sentry suốt hai ngày mà
    không ai hay. Lệnh này đọc tham số từ một tệp cố định và TỪ CHỐI đưa lên nếu
    bản dựng thiếu Sentry hoặc Google.

THAM SỐ DỰNG: mobile/.phat_hanh.local (gitignore, không commit), mỗi dòng KHOÁ=giá trị:
    GOOGLE_CLIENT_ID=...apps.googleusercontent.com
    SENTRY_DSN=https://...@....ingest.de.sentry.io/...
    API_BASE_URL=https://historiai.org

DÙNG (chạy trong thư mục mobile/):
    python tool/phat_hanh.py web                       chỉ web
    python tool/phat_hanh.py apk --ghi-chu "Sửa ..."   tăng build, dựng + phát APK
    python tool/phat_hanh.py ca-hai --ghi-chu "..."    cả hai
    Thêm --khong-dua-len để chỉ dựng và kiểm, không đụng máy chủ.
    Thêm --bat-buoc để mọi máy phải cập nhật (không có nút "Để sau").
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import subprocess
import sys
import time
import urllib.request

for luong in (sys.stdout, sys.stderr):
    try:
        luong.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

GOC = pathlib.Path(__file__).resolve().parents[1]
FLUTTER = r"C:\src\flutter\bin\flutter.bat"
VPS = "giapdn@100.65.123.107"
WEB_VPS = "/home/giapdn/historiai/web"
TRANG = "https://historiai.org"
GIU_LAI = 2          # số phiên bản APK giữ trên máy chủ (mỗi bản ~70 MB cho 2 loại máy)
BAT_BUOC = ("GOOGLE_CLIENT_ID", "SENTRY_DSN", "API_BASE_URL")


def loi(msg: str) -> None:
    print(f"\n  ✗ {msg}")
    raise SystemExit(1)


def chay(lenh: list[str] | str, **kw) -> str:
    vb = lenh if isinstance(lenh, str) else " ".join(lenh)
    print(f"  $ {vb[:150]}")
    r = subprocess.run(lenh, cwd=GOC, capture_output=True, text=True, encoding="utf-8",
                       errors="replace", shell=isinstance(lenh, str), **kw)
    if r.returncode != 0:
        print(r.stdout[-3000:], r.stderr[-3000:])
        loi(f"lệnh hỏng (mã {r.returncode})")
    return r.stdout


def mo(url: str, method: str = "GET"):
    # Cloudflare chặn User-Agent mặc định "Python-urllib" (403).
    return urllib.request.urlopen(urllib.request.Request(
        url, method=method, headers={"User-Agent": "historiai-phat-hanh/1"}), timeout=30)


def doc_tham_so() -> dict[str, str]:
    tep = GOC / ".phat_hanh.local"
    if not tep.exists():
        loi(f"thiếu {tep.name} — xem đầu tệp này để biết cách tạo.")
    ts = {}
    for dong in tep.read_text(encoding="utf-8").splitlines():
        if "=" in dong and not dong.lstrip().startswith("#"):
            k, v = dong.split("=", 1)
            ts[k.strip()] = v.strip()
    thieu = [k for k in BAT_BUOC if not ts.get(k)]
    if thieu:
        loi(f"{tep.name} thiếu: {', '.join(thieu)}")
    if not re.fullmatch(r"\d+-[a-z0-9]+\.apps\.googleusercontent\.com", ts["GOOGLE_CLIENT_ID"]):
        loi("GOOGLE_CLIENT_ID trông không giống client ID thật")
    if not re.fullmatch(r"https://[0-9a-f]+@[\w.]+\.sentry\.io/\d+", ts["SENTRY_DSN"]):
        loi("SENTRY_DSN trông không giống DSN thật")
    return ts


def dart_define(ts: dict[str, str]) -> list[str]:
    return [f"--dart-define={k}={ts[k]}" for k in BAT_BUOC]


def kiem_ban_dung(tep: pathlib.Path, ts: dict[str, str], ten: str) -> None:
    """Chữ cố định của Dart (String.fromEnvironment) nằm nguyên văn trong bản dựng."""
    if ten == "web":
        noi_dung = tep.read_text(encoding="utf-8", errors="replace")
    else:
        # APK: libapp.so nằm trong tệp zip — đọc thẳng từ zip
        import zipfile
        with zipfile.ZipFile(tep) as z:
            so = [n for n in z.namelist() if n.endswith("libapp.so")]
            noi_dung = z.read(so[0]).decode("latin-1") if so else ""
    for k in ("GOOGLE_CLIENT_ID", "SENTRY_DSN"):
        if ts[k] not in noi_dung:
            loi(f"bản dựng {ten} KHÔNG chứa {k} — dừng, không đưa lên.")
    print(f"  ✓ bản dựng {ten} có đủ Google + Sentry")


def tang_build() -> tuple[str, int]:
    p = GOC / "pubspec.yaml"
    s = p.read_text(encoding="utf-8")
    m = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)", s, re.M)
    if not m:
        loi("không đọc được version trong pubspec.yaml")
    a, b, c, n = map(int, m.groups())
    moi = f"{a}.{b}.{c + 1}+{n + 1}"
    p.write_text(s.replace(m.group(0), f"version: {moi}", 1), encoding="utf-8")
    print(f"  ✓ phiên bản {a}.{b}.{c}+{n} → {moi}")
    return f"{a}.{b}.{c + 1}", n + 1


def dung_web(ts: dict[str, str]) -> None:
    chay([FLUTTER, "build", "web", "--release", *dart_define(ts)])
    chay([sys.executable, "tool/danh_dau_phien_ban.py"])
    kiem_ban_dung(GOC / "build/web/main.dart.js", ts, "web")


def dua_web() -> None:
    chay(f'cd build/web && tar czf - --exclude=thumbnails --exclude=videos --exclude=tai-app '
         f'--exclude=noi-bo . | ssh -o BatchMode=yes {VPS} "tar xzf - -C {WEB_VPS}"')
    bs = mo(f"{TRANG}/flutter_bootstrap.js?t={time.time()}").read().decode()
    v = re.search(r"main\.dart\.js\?v=[0-9a-f]+", bs)
    may = (GOC / "build/web/flutter_bootstrap.js").read_text(encoding="utf-8")
    if not v or v.group(0) not in may:
        loi("trang đang chạy chưa trỏ tới bản vừa dựng")
    print(f"  ✓ historiai.org đang chạy bản web mới ({v.group(0)})")


def dung_apk(ts: dict[str, str], ghi_chu: str | None, bat_buoc: bool) -> str:
    pb, _ = tang_build()
    chay([FLUTTER, "build", "apk", "--release", "--split-per-abi", *dart_define(ts)])
    apk = GOC / "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
    kiem_ban_dung(apk, ts, "APK")
    ky = chay(f'"{pathlib.Path.home()}/AppData/Local/Android/Sdk/build-tools/36.0.0/apksigner.bat" '
              f'verify --print-certs "{apk}"')
    if "9324f9a7b45e46c9cfb9109dfba2db8a83af914b" not in ky:
        loi("APK không ký bằng khoá phát hành — máy đã cài sẽ từ chối cập nhật")
    print("  ✓ APK ký đúng khoá phát hành")
    lenh = [sys.executable, "tool/dong_goi_ban_cai.py"]
    if ghi_chu:
        lenh += ["--ghi-chu", ghi_chu]
    if bat_buoc:
        lenh.append("--bat-buoc")
    chay(lenh)
    return pb


def dua_apk(pb: str) -> None:
    chay(f"cd build/tai-app && scp -q -o BatchMode=yes historiai-{pb}-arm64.apk "
         f"historiai-{pb}-arm32.apk index.html qr.png phien-ban.json {VPS}:{WEB_VPS}/tai-app/")
    # Dọn bản cũ, giữ GIU_LAI phiên bản mới nhất (sắp theo số phiên bản, không theo tên)
    don = (f"cd {WEB_VPS}/tai-app && ls historiai-*-arm*.apk | sed -E 's/historiai-(.*)-arm.*/\\1/' "
           f"| sort -u -V | head -n -{GIU_LAI} | while read v; do rm -f historiai-$v-arm*.apk; done; ls *.apk")
    print(chay(["ssh", "-o", "BatchMode=yes", VPS, don]).strip().replace("\n", "  "))
    tt = json.loads(mo(f"{TRANG}/tai-app/phien-ban.json?t={time.time()}").read())
    if tt.get("phien_ban") != pb:
        loi(f"phien-ban.json trên mạng là {tt.get('phien_ban')}, không phải {pb}")
    for loai, ban in tt.get("apk", {}).items():
        r = mo(ban["url"], "HEAD")
        if int(r.headers.get("Content-Length", 0)) != ban["byte"]:
            loi(f"tệp cài {loai} trên mạng sai dung lượng")
    print(f"  ✓ máy đang cài sẽ được báo lên {pb}; tệp cài tải được, đủ dung lượng")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("loai", choices=["web", "apk", "ca-hai"])
    ap.add_argument("--ghi-chu")
    ap.add_argument("--bat-buoc", action="store_true")
    ap.add_argument("--khong-dua-len", action="store_true")
    a = ap.parse_args()
    ts = doc_tham_so()
    pb = None
    if a.loai in ("web", "ca-hai"):
        print("\n[WEB]")
        dung_web(ts)
    if a.loai in ("apk", "ca-hai"):
        print("\n[APK]")
        pb = dung_apk(ts, a.ghi_chu, a.bat_buoc)
    if a.khong_dua_len:
        print("\n  (không đưa lên — chỉ dựng và kiểm)")
        return
    print("\n[ĐƯA LÊN]")
    if a.loai in ("web", "ca-hai"):
        dua_web()
    if pb:
        dua_apk(pb)
    print("\n  XONG. Nhớ commit pubspec.yaml nếu đã tăng phiên bản.")


if __name__ == "__main__":
    main()
