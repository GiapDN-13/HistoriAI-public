# Prompt cho Codex — làm lại giao diện Bảng vàng & Giấy vinh danh
> ⚠ Đã thay bằng `docs/PROMPT_CODEX_LOP_HOC_UI.md` (làm lại toàn bộ phần lớp học, gồm cả bảng vàng).

> Dán nguyên phần dưới đây vào Codex. Repo: `git@github.com:GiapDN-13/HistoriAI.git`,
> nhánh xuất phát **`feat/bang-vang-lop-hoc`**.

---

Bạn là kỹ sư Flutter có gu thiết kế, làm cho **HistoriAI** — app học Lịch sử Việt Nam cho
học sinh THCS/THPT (Flutter web CanvasKit + Android, backend FastAPI). Viết và trao đổi
bằng tiếng Việt.

## Việc cần làm

Làm lại **giao diện** hai thứ học sinh thấy sau khi làm bài kiểm tra trên lớp. Mục tiêu:
học sinh thấy **ấn tượng, muốn chụp lại khoe bố mẹ, gửi nhóm lớp**, và giáo viên thấy
**đủ trang trọng để chiếu lên lớp**.

1. **Bảng vàng của phòng thi.** Hiện là một danh sách có huy chương, còn đơn điệu.
2. **Giấy vinh danh.** Hiện là một tấm giấy tĩnh khổ 420×600, lưu được thành PNG trên web.

Chỉ làm giao diện. **Không đổi API, không đổi luật xếp hạng, không thêm route backend.**

## Mã hiện có (đọc trước khi sửa)

| Tệp | Nội dung |
|---|---|
| `mobile/lib/features/lop_hoc/bang_vang.dart` | `BangVangPhong` (khối bảng vàng), `GiayVinhDanhScreen` (màn có nút "Lưu ảnh để khoe"), `GiayVinhDanh` (tấm giấy), `danhHieu()`, `mauHuyChuong()` |
| `mobile/lib/features/lop_hoc/lam_bai_screen.dart` | `_KetQua`: màn kết quả **bài tập**, gắn `BangVangPhong` dưới khối điểm |
| `mobile/lib/features/lop_hoc/truc_tiep/thi_truc_tiep_screen.dart` | `_ketThuc`: màn kết thúc **thi trực tiếp** (đã có `BucVinhDanh` top 5 + nút mở giấy) |
| `mobile/lib/features/lop_hoc/truc_tiep/widget_truc_tiep.dart` | `BucVinhDanh` (bục 3 bậc), `BangTop` — dùng lại hoặc làm đẹp thêm |
| `mobile/lib/features/lop_hoc/tai_tep_web.dart` / `tai_tep_stub.dart` | `taiAnh(ten, png)`: web tải PNG về máy; bản cài trả `false` (app nhắc chụp màn hình) |
| `mobile/lib/core/theme.dart` | màu `AppColors.*`, `imperialDarkGradient`, kiểu chữ `AppTypography.*` |
| `mobile/lib/core/widgets/vietnamese_decorations.dart` | `ChimLacMotif`, `DongSonWaveDivider`, `ImperialBorderDecoration`, `RoyalSealStamp`, `DongSonBackground`… |
| `mobile/test/bang_vang_test.dart` | test không tràn chữ ở bề ngang 320 và 412 |

## Dữ liệu (GET `/api/v1/phong/{ma}/xep-hang`, gọi qua `LopHocApi.bangVang(ma)`)

```json
{
  "tieu_de": "Ôn tập Bạch Đằng 938", "che_do": "bai_tap" | "truc_tiep",
  "giao_vien": "Cô Nguyễn Thị Lan", "ngay": "2026-10-05T03:00:00+00:00",
  "tong_hoc_sinh": 32, "tong_cau": 10,
  "top": [ {"hang": 1, "ten": "Trần Minh Khoa", "lop": "7A2", "so_dung": 10,
            "giay_lam": 214, "diem": null, "la_toi": false} ],
  "cua_toi": {"ten": "Nguyễn Văn An", "lop": "7A2", "hang": 2, "so_dung": 9,
              "diem": null, "diem_10": 9.0, "vuot_pct": 83}
}
```

- `top` có tối đa 10 dòng. Ai bằng điểm thì **đồng hạng** (1, 2, 2, 4).
- Chế độ `truc_tiep` có `diem` (điểm thi kiểu Kahoot, tính cả tốc độ) và không có `giay_lam`. Chế độ `bai_tap` thì ngược lại.
- Em ngoài top 10 thì không có trong `top`; màn phải tự nối thêm dòng của em ở cuối.
- `vuot_pct` = % số bạn đứng sau em; `null` nếu phòng chỉ có mình em.
- Mọi trường có thể `null` (`lop`, `giao_vien`, `hang`). Không được vỡ giao diện vì thế.

## Hướng thiết kế

- **Bộ nhận diện "Imperial Light"** (bắt buộc):
  - Nền kem `#FDF9F4` / `#FBF3E6`, đỏ son `#BA2323` / `#7A2218`, vàng `#D4AF37` / `#FDD141`, chữ `#2B1410` / `#7C5A4A`.
  - Hoạ tiết **Đông Sơn, chim Lạc**: đã có widget sẵn, dùng lại, đừng vẽ mới bằng emoji.
- **Font chỉ có**: `PlayfairDisplay` (Bold 700), `Montserrat` (SemiBold 600), `Inter` (Regular). Không có weight khác.
  - Đừng dùng Georgia hay serif hệ thống: dấu tiếng Việt bị tách rời.
  - Kiểm tên dài có dấu như "Tôn Nữ Hoàng Phương Thảo Nguyên".
- **Bảng vàng**:
  - Bục 3 người đầu nổi bật: vàng, bạc, đồng.
  - Dòng của em phải nhận ra ngay.
  - Có hiệu ứng khi hiện ra (đếm điểm, huy chương rơi, pháo giấy nhẹ…), nhưng **ngắn, ≤ 1,5 s**.
  - Phải tôn trọng `MediaQuery.disableAnimations` và cài đặt "Hiệu ứng nền" `AppPreferences` (xem `profile_settings_screen.dart`).
- **Giấy vinh danh**:
  - Như một tấm bằng khen thật, để học sinh tự hào.
  - Nên có **hai khổ**: 4:5 cho bài đăng Facebook/Zalo, và 9:16 cho story. Chuyển khổ bằng một nút.
- **Danh hiệu**:
  - Hạng 1/2/3 là Trạng Nguyên / Bảng Nhãn / Thám Hoa, **luôn kèm lời thường** ("Hạng nhất cả phòng").
  - Học sinh đã góp ý là chữ quá cổ thì khó hiểu.
- **Không làm học sinh xấu hổ.** Em đứng nửa dưới thì giấy **không in thứ hạng to**, chỉ ghi số câu đúng, kèm lời động viên. Logic `khoeHang` trong `GiayVinhDanh` hiện đã làm vậy: giữ nguyên ý.
- Ảnh lưu ra phải **giống hệt** cái nhìn thấy, nét (pixelRatio ≥ 3), không có nút hay viền app.

## Ràng buộc kỹ thuật

- **Không thêm gói native mới.** Máy dựng hiện không dựng được APK, nên mọi thứ phải chạy trên web trước.
  - Gói thuần Dart thì được, nhưng phải ghi lý do trong PR.
  - Nút chia sẻ thì dùng `taiAnh` sẵn có.
- **Không hard-code số liệu.** Mọi số trên màn phải lấy từ JSON ở trên.
- Thiết kế ở khổ cố định rồi `FittedBox` thu phóng, như cách hiện tại, để không tràn chữ trên máy hẹp.
- Giữ nguyên chữ "historiai.org" ở chân giấy.
- **Không sửa**: backend, `lop_hoc_api.dart` (trừ khi cần thêm getter), luồng nộp bài, WebSocket thi trực tiếp.

## Cách kiểm tra (phải xanh hết trước khi mở PR)

```bash
cd mobile
C:\src\flutter\bin\flutter.bat analyze --no-fatal-infos     # 0 error, 0 warning
C:\src\flutter\bin\flutter.bat test                         # hiện 168 test, phải xanh hết
```

- **Thêm test**:
  - Không tràn ở bề ngang 320 / 412 / 1280, cho cả hai khổ giấy, với tên dài và khi `lop` / `giao_vien` / `hang` là `null`.
  - Em ngoài top 10 vẫn thấy dòng của mình.
  - Hạng thấp không hiện chữ "Hạng".
- **Chụp màn hình** bảng vàng và từng khổ giấy rồi đính vào PR (dựng web, chạy với dữ liệu giả).

## Bàn giao

- Mở PR vào `feat/bang-vang-lop-hoc`, mô tả ngắn bằng tiếng Việt: đã đổi gì, vì sao, ảnh trước/sau.
- Commit nhỏ, thông điệp tiếng Việt.
