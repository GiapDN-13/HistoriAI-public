#!/usr/bin/env python3
"""Gắn mã băm vào đường dẫn main.dart.js sau khi build web.

VÌ SAO CẦN:
    Flutter không gắn mã băm vào tên `main.dart.js` — tệp chứa toàn bộ ứng dụng
    luôn mang đúng một tên. Cloudflare đứng trước máy chủ thì mặc định cache tệp
    .js bốn tiếng. Hệ quả: deploy xong, người dùng vẫn chạy bản cũ tới 4 giờ,
    trong khi mọi thứ phía máy chủ đều đúng nên rất khó truy ra.

    Đặt `no-store` ở nginx chỉ giúp cho lần sau; bản đã nằm trong cache thì vẫn
    phải purge tay mỗi lần deploy — dễ quên, và quên thì lặng lẽ sai.

    Cùng một cái bẫy với tệp model 3D trong `models/`: tên tệp không đổi khi
    nội dung đổi, nên máy nào từng mở Bảo tàng sẽ giữ model cũ rất lâu. Đã
    dính thật: sau khi nạp cử động vào model nhân vật, trình duyệt vẫn dựng
    bản tĩnh cũ và `availableAnimations` trả về mảng rỗng.

CÁCH LÀM:
    Đổi `mainJsPath` trong flutter_bootstrap.js thành `main.dart.js?v=<băm>`,
    đổi đường dẫn model trong viewer.html thành `models/<slug>.glb?v=<băm>`,
    và đổi từng font trong assets/FontManifest.json thành `<tệp>?v=<băm>`.
    URL đổi theo nội dung nên cache cũ không bao giờ khớp, mà khi code không đổi
    thì URL cũng không đổi — vẫn tận dụng được cache.

    flutter_bootstrap.js tự nó đã nằm trong nhóm no-store của nginx nên luôn tươi.

DÙNG:
    python tool/danh_dau_phien_ban.py [thư_mục_build]      (mặc định build/web)
"""
import hashlib
import json
import pathlib
import re
import sys

# Console Windows mặc định là cp1252, không có chữ tiếng Việt. Thiếu dòng này
# thì script ghi tệp xong vẫn chết ở câu print cuối và trả mã lỗi — đủ để làm
# hỏng mọi lệnh deploy nối sau nó.
for luong in (sys.stdout, sys.stderr):
    try:
        luong.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, OSError):
        pass


def main() -> int:
    goc = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
    bundle = goc / "main.dart.js"
    bootstrap = goc / "flutter_bootstrap.js"

    for f in (bundle, bootstrap):
        if not f.exists():
            print(f"  LỖI: không thấy {f}")
            return 1

    bam = hashlib.md5(bundle.read_bytes()).hexdigest()[:10]
    noi_dung = bootstrap.read_text(encoding="utf-8")

    # Dọn dấu phiên bản cũ trước, để chạy lại nhiều lần không chồng thêm
    noi_dung = re.sub(r'main\.dart\.js\?v=[0-9a-f]+', 'main.dart.js', noi_dung)

    so_lan = noi_dung.count('"main.dart.js"')
    if so_lan == 0:
        print("  LỖI: không tìm thấy tham chiếu \"main.dart.js\" trong bootstrap.")
        print("       Flutter có thể đã đổi cách dựng — kiểm tra lại trước khi deploy.")
        return 1

    noi_dung = noi_dung.replace('"main.dart.js"', f'"main.dart.js?v={bam}"')
    bootstrap.write_text(noi_dung, encoding="utf-8")
    print(f"  đã gắn phiên bản: main.dart.js?v={bam}  ({so_lan} chỗ)")

    _dau_model(goc)
    _dau_font(goc)
    return 0


def _dau_font(goc: pathlib.Path) -> None:
    """Gắn mã băm vào từng font trong assets/FontManifest.json.

    Flutter cắt gọn font biểu tượng (MaterialIcons) theo đúng những biểu tượng app
    dùng — thêm một biểu tượng mới là NỘI DUNG font đổi mà TÊN tệp giữ nguyên. Máy
    nào còn giữ font cũ sẽ vẽ biểu tượng mới thành ô trống. Đã dính thật 27–28/09:
    Cloudflare từng trả font kèm `immutable` 30 ngày, purge xong trình duyệt vẫn
    giữ bản cũ. Đổi URL theo nội dung thì không cache nào khớp nhầm được nữa.
    """
    manifest = goc / "assets" / "FontManifest.json"
    if not manifest.exists():
        print("  (bỏ qua dấu phiên bản font: không thấy FontManifest.json)")
        return
    ds = json.loads(manifest.read_text(encoding="utf-8"))
    so = 0
    for ho in ds:
        for f in ho.get("fonts", []):
            ten = re.sub(r"\?v=[0-9a-f]+$", "", f["asset"])
            tep = goc / "assets" / ten
            if not tep.exists():
                print(f"  CẢNH BÁO: không thấy tệp font {tep}")
                f["asset"] = ten
                continue
            f["asset"] = f"{ten}?v={hashlib.md5(tep.read_bytes()).hexdigest()[:10]}"
            so += 1
    manifest.write_text(json.dumps(ds, ensure_ascii=False, separators=(",", ":")),
                        encoding="utf-8")
    print(f"  đã gắn phiên bản: {so} tệp font trong FontManifest.json")


def _dau_model(goc: pathlib.Path) -> None:
    """Gắn mã băm của thư mục models vào đường dẫn model trong viewer.html."""
    viewer = goc / "viewer.html"
    thu_muc = goc / "models"
    if not viewer.exists() or not thu_muc.is_dir():
        print("  (bỏ qua dấu phiên bản model: không thấy viewer.html hoặc models/)")
        return

    h = hashlib.md5()
    for f in sorted(thu_muc.glob("*.glb")):
        h.update(f.name.encode("utf-8"))
        h.update(str(f.stat().st_size).encode("utf-8"))
        h.update(f.read_bytes())
    bam = h.hexdigest()[:10]

    s = viewer.read_text(encoding="utf-8")
    s = re.sub(r"models/\$\{slug\}\.glb(\?v=[0-9a-f]+)?",
               f"models/${{slug}}.glb?v={bam}", s)
    if f"?v={bam}" not in s:
        print("  CẢNH BÁO: không tìm thấy đường dẫn model trong viewer.html —")
        print("            model mới có thể bị trình duyệt giữ bản cũ.")
        return
    viewer.write_text(s, encoding="utf-8")
    print(f"  đã gắn phiên bản: models/*.glb?v={bam}")


if __name__ == "__main__":
    raise SystemExit(main())
