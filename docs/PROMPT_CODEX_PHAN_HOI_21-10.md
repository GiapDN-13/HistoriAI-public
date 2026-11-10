# Prompt cho Codex — ảnh minh hoạ cho đợt xử lý phản hồi 21/10

Dán nguyên phần dưới cho Codex. Code đã nối sẵn mọi chỗ dùng ảnh (có hình dự phòng),
nên Codex **chỉ cần vẽ ảnh, đặt đúng tên, khai báo trong `pubspec.yaml`** — không phải
sửa giao diện.

---

## Bối cảnh

HistoriAI là app học Lịch sử Việt Nam cho học sinh THCS/THPT (Flutter web + Android).
Nhánh `feat/xu-ly-phan-hoi` vừa sửa giao diện theo 19 góp ý người dùng. Một số chỗ cần
ảnh minh hoạ. Code đọc ảnh bằng `Image.asset(..., errorBuilder: ...)`: chưa có ảnh thì
hiện biểu tượng dự phòng; có ảnh đúng tên thì tự hiện.

**Làm việc ở worktree riêng**, đừng đụng thư mục `EXE101/HistoriAI` (có thể đang có
người khác làm):

```bash
cd EXE101/HistoriAI
git fetch origin
git worktree add -b feat/anh-phan-hoi ../HistoriAI-anh-phan-hoi origin/feat/xu-ly-phan-hoi
cd ../HistoriAI-anh-phan-hoi/mobile
```

## Phong cách (bắt buộc giống ảnh có sẵn)

Xem mẫu: `mobile/assets/figures3d/item_transparent/*.png` (cúp quiz, mũ trụ + bong bóng
thoại, trống đồng, cuộn thư). Đó là **biểu tượng game dựng 3D, ánh sáng mềm, chất liệu
vàng đồng + đỏ son + giấy dó**, nền trong suốt, vật thể nằm giữa, không đổ bóng ra mép.

Bảng màu "Imperial Light": đỏ son `#BA2323` / `#7A2218`, vàng `#D4AF37` / `#FDD141`,
kem `#FDF9F4`, cam `#E67E22`.

Ràng buộc chung:
- **Không có chữ** trong ảnh (kể cả chữ Hán, chữ Nôm, chữ Việt): AI hay vẽ chữ sai.
- Không vẽ ảnh chụp màn hình app giả, không logo thương hiệu khác.
- Không vẽ khuôn mặt cận cảnh của nhân vật lịch sử có thật (không có chân dung chuẩn —
  vẽ bóng người, dáng xa, hoặc đồ vật thay cho người).
- Trang phục, vũ khí, thuyền… giữ nét thời Ngô–Lý–Trần–Lê–Tây Sơn; đừng lẫn kiểu
  Trung Hoa / Nhật (mũ samurai, kiếm katana, mái chùa Nhật).
- Ghi tên tệp + "ảnh tạo bằng AI" vào `mobile/assets/CREDITS_AI.md` (tạo mới nếu chưa có).

## Việc 1 — ảnh bước 1 của thẻ "Bắt đầu từ đây" (trang chủ)

Thẻ dẫn người mới qua 3 bước: xem phim Bạch Đằng 938 → hỏi Trần Hưng Đạo → làm quiz.
Bước 2 và 3 dùng lại ảnh có sẵn (mũ trụ, cúp). **Bước 1 thiếu ảnh.**

| Tệp | Nội dung | Khổ |
|---|---|---|
| `assets/lo_trinh/buoc_1_xem_phim.png` | Cuộn phim / máy chiếu phim kiểu cổ, trên khung phim thấp thoáng **cọc gỗ nhọn giữa sóng nước** (trận Bạch Đằng) | 512×512, nền trong suốt, ≤ 200 KB |

Hiện ở ô 44×44 px — vật thể phải rõ hình khi thu nhỏ, đừng nhiều chi tiết vụn.

## Việc 2 — huy hiệu 7 danh hiệu học tập

Danh hiệu theo điểm (đọc `lib/core/utils/scholarly_rank.dart`). Đang dùng biểu tượng
Material; có ảnh thì thẻ danh hiệu ở trang chủ và bảng "Điểm, cấp và chuỗi ngày" tự đổi.
Bảy huy hiệu phải **cùng một bộ**: cùng khung tròn/khiên, càng lên cao càng lộng lẫy
(đồng → bạc → vàng → vàng có ngọc).

| Tệp (`assets/danh_hieu/`) | Danh hiệu — nghĩa | Gợi ý vật thể giữa huy hiệu |
|---|---|---|
| `dong_sinh.png` | Đồng Sinh — học trò mới vào học | bút lông + nghiên mực |
| `si_tu.png` | Sĩ Tử — người đang ôn đi thi | chồng sách + lều chõng thu nhỏ |
| `tu_tai.png` | Tú Tài — đỗ thi Hương | cuộn bảng vàng nhỏ |
| `cu_nhan.png` | Cử Nhân — đỗ cao thi Hương | mũ cánh chuồn |
| `tien_si.png` | Tiến Sĩ — đỗ thi lớn ở kinh đô | bia đá trên lưng rùa (Văn Miếu) |
| `bang_nhan_tham_hoa.png` | Bảng Nhãn / Thám Hoa — đỗ nhì, ba cả nước | cờ biển + hoa |
| `trang_nguyen.png` | Trạng Nguyên — đỗ đầu cả nước | mũ trạng nguyên + vòng nguyệt quế vàng |

Khổ 256×256, nền trong suốt, mỗi tệp ≤ 80 KB.

## Việc 3 — ảnh bìa "Phim đang được dựng"

Góp ý: "mới thấy có video về trận Bạch Đằng thôi". Ba trận dưới đây đã có phim gốc, đang
chờ nhóm design xử lý. Trong lúc chờ, màn chi tiết sự kiện hiện khung "Phim đang được
dựng" với ảnh bìa.

| Tệp (`assets/phim_sap_co/`) | Cảnh |
|---|---|
| `quang-trung-1789.jpg` | Đại quân Tây Sơn hành quân thần tốc ra Bắc dịp Tết, voi chiến, sương sớm đồn Ngọc Hồi |
| `lam-son-1428.jpg` | Nghĩa quân Lam Sơn giữa núi rừng Thanh Hoá, cờ đỏ, ánh bình minh |
| `khang-chien-tong-981.jpg` | Thuyền chiến Đại Cồ Việt chặn quân Tống trên sông, cọc và lau sậy |

Khổ 1280×720 (16:9), JPG chất lượng ~80, mỗi tệp ≤ 250 KB. Khung hình điện ảnh, tông
tối ấm để chữ trắng đè lên vẫn đọc được (app phủ thêm dải tối ở dưới). Không chữ.

## Việc 4 — giảm dung lượng ảnh biểu tượng có sẵn

`assets/figures3d/item_transparent/*.png` và `assets/figures3d/item/*.png` mỗi tệp
0,5–1,1 MB, khổ 1024×1024, nhưng chỉ hiện cao ≤ 190 px. Bản web tải hết lúc mở trang chủ —
một phần lý do mạng yếu thấy app "giật, chậm" (góp ý 04/10).

- Thu về 512×512 + lượng tử hoá màu (pngquant / oxipng hoặc Pillow `quantize`) —
  **giữ nguyên tên tệp**, giữ kênh trong suốt.
- Mục tiêu ≤ 150 KB mỗi tệp; so trước/sau bằng mắt ở cỡ 190 px, không được thấy vệt màu.
- Ghi bảng dung lượng trước/sau vào mô tả PR.

## Khai báo và kiểm tra

Thêm vào `mobile/pubspec.yaml`, mục `flutter: assets:`:

```yaml
    - assets/lo_trinh/
    - assets/danh_hieu/
    - assets/phim_sap_co/
```

Rồi chạy (Flutter không nằm trên PATH):

```bash
C:\src\flutter\bin\flutter.bat analyze --no-fatal-infos
C:\src\flutter\bin\flutter.bat test
```

Chụp màn kiểm tra ở khổ 412×900: trang chủ (thẻ "Bắt đầu từ đây" + thẻ danh hiệu), bảng
"Điểm, cấp và chuỗi ngày" (chạm vào chip "Chuỗi … ngày"), màn chi tiết Quang Trung 1789.

Mở PR vào **`feat/xu-ly-phan-hoi`** (không phải `develop`), tiêu đề
"Ảnh minh hoạ đợt phản hồi 21/10". Không sửa tệp `.dart` nào trừ khi ảnh không hiện vì
lỗi đường dẫn — khi đó ghi rõ trong PR đã sửa gì.
