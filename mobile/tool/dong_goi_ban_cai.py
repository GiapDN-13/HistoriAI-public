#!/usr/bin/env python3
"""Đặt tên và gắn dấu phiên bản cho bản cài, rồi sinh trang tải.

VÌ SAO CẦN:
    Cloudflare cache tệp .apk 4 tiếng (max-age=14400). Nếu bản cài luôn mang
    đúng một tên, thì mỗi lần phát hành bản mới người dùng vẫn tải về bản cũ
    suốt 4 tiếng — mà tệ hơn cả web: họ cài nhầm bản cũ vào máy rồi đi, không
    ai biết.

    Đã gặp thật: xoá tệp khỏi máy chủ rồi mà đường dẫn vẫn trả 200 vì
    Cloudflare còn giữ.

CÁCH LÀM:
    Tên tệp mang số phiên bản (historiai-0.1.0-arm64.apk), và đường dẫn trong
    trang tải mang thêm ?v=<băm nội dung>. Đổi nội dung là đổi URL nên không
    bao giờ trúng cache cũ; không đổi thì vẫn tận dụng được cache.

BÁO BẢN MỚI:
    Sinh thêm phien-ban.json. App Android đọc tệp này lúc mở và hỏi người dùng
    tải bản mới khi số build ở đây lớn hơn số build đang chạy (lib/core/ban_moi.dart).
    => MỖI LẦN PHÁT HÀNH PHẢI TĂNG số sau dấu + trong `version:` của pubspec.yaml,
       không thì máy đã cài không bao giờ được báo.

DÙNG:
    python tool/dong_goi_ban_cai.py [thư_mục_ra] [--ghi-chu "Sửa lỗi…"] [--bat-buoc]
    (mặc định build/tai-app; --bat-buoc: lần mở nào cũng hỏi, không có nút "Để sau")
"""
import datetime
import json
import hashlib
import pathlib
import re
import shutil
import sys

for luong in (sys.stdout, sys.stderr):
    try:
        luong.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass

GOC = pathlib.Path(__file__).resolve().parents[1]
APK_DIR = GOC / "build" / "app" / "outputs" / "flutter-apk"
NGUON_TRANG = GOC / "web" / "tai-app"

BAN = {
    "arm64": "app-arm64-v8a-release.apk",
    "arm32": "app-armeabi-v7a-release.apk",
}


def phien_ban() -> tuple[str, int]:
    m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)",
                  (GOC / "pubspec.yaml").read_text(encoding="utf-8"), re.M)
    if not m:
        raise SystemExit("  LỖI: không đọc được version x.y.z+build trong pubspec.yaml")
    return m.group(1), int(m.group(2))


def main() -> int:
    doi = sys.argv[1:]
    bat_buoc = "--bat-buoc" in doi
    ghi_chu = None
    if "--ghi-chu" in doi:
        i = doi.index("--ghi-chu")
        ghi_chu = doi[i + 1]
        del doi[i:i + 2]
    doi = [d for d in doi if d != "--bat-buoc"]
    ra = pathlib.Path(doi[0] if doi else GOC / "build" / "tai-app")
    ra.mkdir(parents=True, exist_ok=True)
    pb, build = phien_ban()

    trang = (NGUON_TRANG / "index.html").read_text(encoding="utf-8")
    shutil.copy2(NGUON_TRANG / "qr.png", ra / "qr.png")

    apk = {}
    for nhan, ten_goc in BAN.items():
        nguon = APK_DIR / ten_goc
        if not nguon.exists():
            print(f"  LỖI: chưa dựng {nguon.name} — chạy flutter build apk trước.")
            return 1
        bam = hashlib.md5(nguon.read_bytes()).hexdigest()[:8]
        ten = f"historiai-{pb}-{nhan}.apk"
        shutil.copy2(nguon, ra / ten)
        trang = trang.replace(f"historiai-{nhan}.apk", f"{ten}?v={bam}")
        apk[nhan] = {"url": f"https://historiai.org/tai-app/{ten}?v={bam}",
                     "byte": nguon.stat().st_size}
        mb = nguon.stat().st_size / 1048576
        print(f"  {nhan:6s} {ten}?v={bam}   {mb:.1f} MB")

    (ra / "index.html").write_text(trang, encoding="utf-8")
    # "build" ghi theo thang versionCode của bản 64-bit (2000 + n), KHÔNG phải n:
    # dựng --split-per-abi thì Flutter cộng 1000 (arm32) / 2000 (arm64) / 4000 (x86_64)
    # vào versionCode, và app ≤ 0.5.1 so thẳng số này với versionCode của mình
    # (2009, 1009…). Ghi n = 10 thì các bản đó tưởng mình mới hơn, không bao giờ hỏi —
    # lỗi có từ 0.2.0, phát hiện 28/09. 2000 + n > mọi versionCode arm32/arm64 cũ hơn.
    # App từ 0.5.2 so theo phần dư cho 1000 nên đọc được cả hai kiểu.
    thong_tin = {"phien_ban": pb, "build": 2000 + build, "build_goc": build,
                 "link": "https://historiai.org/tai-app/",
                 "ngay": datetime.date.today().isoformat(), "bat_buoc": bat_buoc,
                 # Bản cài theo loại máy — app (từ 0.5.2) tự tải tệp này rồi mở màn cài.
                 "apk": apk}
    if ghi_chu:
        thong_tin["ghi_chu"] = ghi_chu
    (ra / "phien-ban.json").write_text(json.dumps(thong_tin, ensure_ascii=False, indent=1),
                                        encoding="utf-8")
    print(f"  trang tải: {ra / 'index.html'}  (phiên bản {pb}, build {build})")
    print(f"  phien-ban.json: build {build} (ghi {2000 + build}){' — BẮT BUỘC' if bat_buoc else ''}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
