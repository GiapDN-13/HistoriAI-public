"""Dựng ảnh xem trước khi chia sẻ link (og:image) 1200×630 theo bộ nhận diện Imperial Light.

Chạy lại khi đổi khẩu hiệu:  python tool/tao_anh_chia_se.py  → web/og-image.png

Facebook và Zalo KHÔNG chạy JavaScript khi dựng bản xem trước, nên ảnh này phải là tệp
tĩnh khai trong web/index.html — app Flutter không tự sinh được.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

GOC = Path(__file__).resolve().parents[1]
FONT = GOC / "assets" / "fonts"
BRAND = GOC / "assets" / "brand"
RA = GOC / "web" / "og-image.png"

KEM, KEM_DAM = "#FDF9F4", "#FBF3E6"
DO, DO_DAM = "#BA2323", "#7A2218"
VANG, CHU, CHU_NHAT = "#D4AF37", "#2B1410", "#7C5A4A"
W, H = 1200, 630


def to_mau(duong_dan: Path, mau: str, co: int, do_mo: float = 1.0) -> Image.Image:
    """Hoạ tiết trong assets/brand chỉ giữ kênh alpha — tô màu tại chỗ."""
    goc = Image.open(duong_dan).convert("LA")
    a = goc.getchannel("A").point(lambda v: int(v * do_mo))
    lop = Image.new("RGBA", goc.size, mau)
    lop.putalpha(a)
    ti_le = co / max(goc.size)
    return lop.resize((int(goc.width * ti_le), int(goc.height * ti_le)), Image.LANCZOS)


def main() -> None:
    anh = Image.new("RGBA", (W, H), KEM)
    ve = ImageDraw.Draw(anh)

    # Mặt trống đồng mờ, tràn khỏi mép phải — hoạ tiết nền, không lấn chữ
    trong = to_mau(BRAND / "dong_son_drum.png", VANG, 760, 0.28)
    anh.alpha_composite(trong, (W - 520, (H - trong.height) // 2))

    # Dải đỏ son dưới đáy
    ve.rectangle([0, H - 96, W, H], fill=DO)
    ve.rectangle([0, H - 100, W, H - 96], fill=VANG)

    logo = Image.open(BRAND / "logo.png").convert("RGBA")
    logo = logo.resize((150, int(150 * logo.height / logo.width)), Image.LANCZOS)
    anh.alpha_composite(logo, (72, 70))

    tieu_de = ImageFont.truetype(str(FONT / "PlayfairDisplay-Bold.ttf"), 112)
    phu = ImageFont.truetype(str(FONT / "Inter-Regular.ttf"), 38)
    nhan = ImageFont.truetype(str(FONT / "Montserrat-SemiBold.ttf"), 30)

    ve.text((72, 240), "HistoriAI", font=tieu_de, fill=DO)
    ve.text((76, 380), "Học sử Việt bằng cách trò chuyện", font=phu, fill=CHU)
    ve.text((76, 428), "với vĩ nhân, đấu quiz và ngắm cổ vật 3D", font=phu, fill=CHU)
    ve.text((72, H - 72), "HISTORIAI.ORG", font=nhan, fill="#FDD141")
    chu_phai = "Cho học sinh THCS & THPT"
    rong = ve.textlength(chu_phai, font=nhan)
    ve.text((W - 72 - rong, H - 72), chu_phai, font=nhan, fill=KEM)

    anh.convert("RGB").save(RA, optimize=True)
    print(f"đã ghi {RA} ({RA.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
