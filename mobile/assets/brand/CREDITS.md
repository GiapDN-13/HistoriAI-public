# Nguồn và giấy phép tài nguyên hình ảnh

## `dong_son_drum.png` — hoạ tiết mặt trống đồng Ngọc Lũ

| | |
|---|---|
| **Tác phẩm gốc** | *Trong Dong Ngoc Lu.svg* |
| **Tác giả** | Ebaychatter0 (lấy cảm hứng từ `File:NgocLu.gif`) |
| **Nguồn** | https://commons.wikimedia.org/wiki/File:Trong_Dong_Ngoc_Lu.svg |
| **Giấy phép** | Creative Commons Ghi công – Chia sẻ tương tự 3.0 Quốc tế (CC BY-SA 3.0) |
| **Toàn văn giấy phép** | https://creativecommons.org/licenses/by-sa/3.0/deed.vi |

### Đã sửa đổi những gì

Bản dùng trong app **không phải bản gốc**. Các thay đổi:

1. Kết xuất SVG sang PNG nền trong suốt, 640×640.
2. Cắt bỏ viền trống quanh hình, căn vuông.
3. Bỏ toàn bộ màu gốc, chỉ giữ kênh alpha — màu hiển thị do
   `DongSonBackground.color` quyết định lúc chạy (mặc định đỏ son `#BA2323`).
4. Nén lại: 2.033 KB → 129 KB.

## `chim_lac.png` — hoạ tiết chim Lạc

Cùng nguồn, cùng giấy phép với `dong_son_drum.png` ở trên (Ebaychatter0,
Wikimedia Commons, **CC BY-SA 3.0**).

Trích một con chim ở vành ngoài mặt trống, rồi:

1. Cắt riêng con chim, lật ngang cho mỏ chĩa sang phải.
2. **Làm dày nét** (giãn nở hình thái 15px ở độ phân giải 1200px). Bản vẽ khảo
   cổ gốc là nét mảnh; thu xuống cỡ 38–46px dùng trong app thì nét đứt gãy
   thành lấm tấm, không còn nhận ra con chim.
3. Xuất 600×221, chỉ giữ kênh alpha — màu do `ChimLacMotif.color` quyết định.
4. Dung lượng 23 KB.

### Nghĩa vụ kèm theo

CC BY-SA 3.0 buộc **bản sửa đổi cũng phải mang cùng giấy phép**. Cụ thể với
HistoriAI:

- File `dong_son_drum.png` trong repo này **là CC BY-SA 3.0**, không phải tài
  sản riêng của nhóm. Điều này *không* lan sang phần còn lại của app — mã nguồn
  và các tài nguyên khác giữ nguyên giấy phép của chúng.
- Phải ghi công tác giả ở nơi người dùng thấy được. Hiện app **chưa có màn
  "Về ứng dụng"** để đặt phần ghi công này — cần bổ sung trước khi phát hành
  rộng, nhất là khi sản phẩm có thu phí.
- Ai lấy lại ảnh này từ repo cũng được quyền dùng theo CC BY-SA 3.0.

> Nếu nhóm không muốn ràng buộc share-alike, hai lối thoát: tự vẽ lại hoạ tiết
> bằng vector trong mã nguồn, hoặc thuê/mua một bản đồ hoạ riêng.

## `logo.png`

Logo thương hiệu HistoriAI, do nhóm HistoJourney tự làm.

---

# Mô hình 3D (`web/models/*.glb`)

Tất cả tải từ Sketchfab, **đều mang giấy phép Creative Commons Ghi công (CC BY 4.0)**
— nhẹ hơn CC BY-SA ở trên: chỉ cần ghi công, không buộc bản phái sinh cùng giấy phép.

| Tệp | Tên gốc | Tác giả |
|---|---|---|
| `coc-bach-dang-1288.glb` | Cọc Bạch Đằng Năm 1288 | Atlantic Truong \| Vietnam 3D |
| `nghe-den-vua-dinh.glb` | Nghê đền Vua Đinh | Atlantic Truong \| Vietnam 3D |
| `rong-co-loa.glb` | Rồng bậc thềm Đền Thượng – Cổ Loa | Atlantic Truong \| Vietnam 3D |
| `hu-tien-dong.glb` | Hũ tiền đồng | Atlantic Truong \| Vietnam 3D |
| `thuyen-chien-dong-son.glb` | Dong Son Bronze Age warship | ptdtch |
| `kiem-dong-son.glb` | Dong Son sword in Vietnam | daudinh8888 |
| `trong-dong-dong-son.glb` | Trống đồng Đông Sơn – Việt Nam | ndnguyen3d |
| `trong-dong-hoa-van.glb` | Trống Đồng Đông Sơn (Dong Son bronze drum) | Aaannnn |
| `trong-dong-khai-quat.glb` | Trống đồng Đông Sơn (bản khai quật) | *chưa xác nhận — cần đối chiếu lại trang nguồn* |

Nguồn: https://sketchfab.com · Giấy phép: https://creativecommons.org/licenses/by/4.0/deed.vi

## Đã sửa đổi những gì

Bản trong repo **không phải bản gốc**. Mỗi tệp đều qua `gltf-transform optimize`:
giảm lưới (sai số 0,0008), nén texture sang WebP ở 1024px, nén hình học bằng Draco.

Tổng dung lượng **605 MB → 3,4 MB**. Ví dụ con rồng Cổ Loa: 273 MB còn 509 KB mà
vẫn giữ 77.984 tam giác — phần lớn dung lượng gốc nằm ở texture độ phân giải cao,
thứ không nhìn thấy được trên màn hình điện thoại.

Không giảm lưới thì một model 260 MB là không thể phục vụ cho học sinh qua mạng
di động.

## Nghĩa vụ kèm theo

CC BY buộc **ghi công tác giả ở nơi người dùng thấy được**. Cùng với hai hoạ tiết
CC BY-SA ở trên, đây là lý do thứ hai để bổ sung màn "Về ứng dụng" trước khi phát
hành rộng.

---

# Kích thước thật của cổ vật (`real_scale_meters`)

Trường `real_scale_meters` trong `backend/data/seed_data.json` ghi **chiều lớn
nhất của hiện vật ngoài đời, đơn vị mét**. Nó có hai chỗ dùng, và cả hai đều
hỏng theo kiểu khó phát hiện nếu con số sai:

1. `mobile/tool/chuan_hoa_ti_le.py` co giãn tệp `.glb` sao cho chiều lớn nhất
   của model đúng bằng con số này.
2. Nút **"Đặt vào phòng"** gọi Scene Viewer với `resizable=false`, khoá không
   cho người dùng phóng to thu nhỏ. Nghĩa là app đang **khẳng định** cổ vật
   hiện ra đúng cỡ ngoài đời.

Vì thế: **mỗi con số phải tra được từ nguồn, không ước lượng bằng mắt nhìn
model.** Cổ vật chưa tra được nguồn thì **để trống** — nút "Đặt vào phòng" tự
ẩn đi cho riêng cổ vật đó. Thà thiếu một nút còn hơn dạy người học nhớ sai
kích thước cổ vật.

## Đã tra được

| Cổ vật | `real_scale_meters` | Dựa trên | Nguồn |
|---|---|---|---|
| `trong-dong-dong-son` | **0.793** | Trống đồng **Ngọc Lũ** (Bảo vật quốc gia, Bảo tàng Lịch sử Quốc gia): *"đường kính mặt: 79,3 cm; đường kính chân: 80 cm; cao: 63 cm"*. Chiều lớn nhất là đường kính mặt. | Cục Di sản văn hoá — https://dsvh.gov.vn/trong-dong-ngoc-lu-3014 |
| `trong-dong-khai-quat` | **0.793** | **Kích thước điển hình** của trống Đông Sơn loại I Heger, lấy theo trống Ngọc Lũ. Model là bản dựng một trống khai quật không định danh được (xem ô "chưa xác nhận" ở bảng trên), nên đây là cỡ đại diện chứ không phải số đo của một hiện vật cụ thể. | như trên |
| `trong-dong-hoa-van` | **0.793** | **Kích thước điển hình**, lấy theo trống Ngọc Lũ. Model là bản dựng minh hoạ hoa văn, không phải quét một hiện vật cụ thể. | như trên |
| `kiem-dong-son` | **0.465** | **Kiếm ngắn núi Nưa** (Bảo vật quốc gia, Bảo tàng Thanh Hoá, sưu tầm 1961): *"Dài: 46,5 cm; rộng: 5 cm; cán dài: 18 cm"*. Model là bản dựng chung, nên đây là **kích thước điển hình** lấy theo hiện vật này. | Cục Di sản văn hoá — https://dsvh.gov.vn/kiem-ngan-nui-nua-3044 |
| `coc-bach-dang-1288` | **2.7** | Cọc bãi **Yên Giang** (Quảng Yên, Quảng Ninh): *"Chiều dài thân cọc từ 2,6m đến 2,8m, phần cọc được đẽo nhọn để cắm xuống lòng sông dài từ 0,5m đến 1m"*. Lấy **trung điểm 2,7 m** của dải 2,6–2,8 m. | Cục Di sản văn hoá, hồ sơ *Di tích lịch sử Bạch Đằng* — https://dsvh.gov.vn/di-tich-lich-su-bach-dang-2960 |
| `thuyen-chien-dong-son` | **9.5** | **Kích thước điển hình**, theo ước tính của **TS Nguyễn Việt** dựng lại từ hình khắc trên trống đồng: *"Chiều dài thuyền khoảng 6 thân người (9 - 10m)"*. Lấy trung điểm 9,5 m. Đây là **suy luận từ hình khắc**, không phải số đo một hiện vật. | Bảo tàng Lịch sử Quốc gia — https://baotanglichsu.vn/vi/Articles/3101/74357/nguoi-djong-son-ve-nan-nguoi-djong-son-ky-5-theo-chan-tho-ca-len-mot-chiec-thuyen-djong-son-long-lay.html |

### Đối chiếu tỉ lệ model — cách tự bắt số sai

Con số tra được và **tỉ lệ hình học sẵn có của tệp `.glb`** là hai nguồn độc
lập. Nếu chúng khớp nhau thì gần như chắc chắn cả hai đều đúng; lệch nhiều thì
hoặc số sai, hoặc model không phải hiện vật mình tưởng. Sau khi chuẩn hoá:

| Cổ vật | Model ra | Hiện vật thật | Đánh giá |
|---|---|---|---|
| `trong-dong-dong-son` | ⌀ 79,3 cm · cao 63,5 cm | Ngọc Lũ: ⌀ 79,3 cm · cao 63 cm | **khớp trong 1%** |
| `coc-bach-dang-1288` | dài 2,70 m · ⌀ ~25 cm | Yên Giang: dài 2,6–2,8 m · ⌀ 20–30 cm | **khớp** |
| `kiem-dong-son` | dài 46,5 cm · rộng 5,4 cm | núi Nưa: dài 46,5 cm · rộng 5 cm | **khớp** |
| `trong-dong-khai-quat` | ⌀ 79,3 cm · cao 58,8 cm | trống loại I: cao ≈ 0,75–0,80 lần đường kính | hợp lý |
| `trong-dong-hoa-van` | ⌀ 79,3 cm · cao 71,7 cm | — | **model hơi cao hơn tỉ lệ thật**; chiều lớn nhất (đường kính) vẫn đúng |
| `thuyen-chien-dong-son` | dài 9,50 m · cao 6,48 m · rộng 4,07 m | ước tính: dài 9–10 m · mũi/đuôi cao ~3 m · sạp rộng 1,5–1,6 m | **chỉ chiều dài là đáng tin**; model dựng theo lối cách điệu của hình khắc nên cao và bè hơn thuyền thật |

## Chưa tra được — cố ý để trống

| Cổ vật | Đã tìm ở đâu | Vì sao bỏ trống |
|---|---|---|
| `nghe-den-vua-dinh` | Cục Di sản, Sở VHTT Ninh Bình, nghiên cứu của Trần Hậu Yên Thế về nghê Việt, báo chí về đền Vua Đinh | Không nguồn nào công bố số đo **tượng nghê**. Chỉ tra được long sàng trước Bái đường (*"dài 1,80m, rộng 1,40m kể cả bệ cao 0,95m"*, Sở VHTT Ninh Bình) — đó là hiện vật khác, nghê chỉ chầu hai bên. ⚠ Có con số "nghê cao 118,5 cm" lưu hành trên mạng gắn với đền Vua Đinh: **đó là nghê gỗ đền Lê Thánh Tông ở Bảo tàng Mỹ thuật Việt Nam**, không phải nghê đá Hoa Lư. Đừng dùng. |
| `rong-co-loa` | Cục Di sản (hồ sơ Bảo vật quốc gia đợt 12), Bộ VHTTDL, BQL Khu di tích Cổ Loa, Sở VHTT Hà Nội, 7 báo lớn | Không nguồn công khai nào có số đo. Nghịch lý: chính trang Cục Di sản viết *"Kích thước, cấu trúc và hoa văn trang trí của thành bậc không lặp lại ở bất kỳ di tích nào…"* mà không công bố con số. Số đo nhiều khả năng chỉ nằm trong hồ sơ Bảo vật quốc gia chưa số hoá. |
| `hu-tien-dong` | Báo chí nhà nước dẫn bảo tàng tỉnh | Chỉ có số đo hiện trường của **hai ca phát hiện riêng lẻ, cách nhau cả nghìn năm niên đại**: hũ tiền Bắc Tống ở Quảng Trạch – Quảng Bình *"cao khoảng 30cm, đường kính 15cm"* (VietnamPlus/TTXVN) và ba hũ ở Phong Điền – Thừa Thiên Huế *"cao khoảng 40 cm, đường kính bụng khoảng 35 cm"* (Tuổi Trẻ). Dải 30–40 cm là sai số 33% — quá rộng để khoá `resizable=false`. Thêm nữa tỉ lệ cao/rộng của model (1,55) không khớp cả hai (2,0 và 1,14), nên model không phải hai hiện vật đó. |

> **Quyết định (21/09/2026):** giữ `real_scale_meters` trống nên nút AR vẫn ẩn,
> nhưng phần mô tả cổ vật nay nói thẳng *"cao khoảng 30–40 cm"*. Nói đúng cái
> mình biết — một khoảng — còn hơn giả vờ chính xác tới xăng-ti-mét rồi khoá
> `resizable=false` lên con số đoán.

**Cách lấy nốt ba số còn thiếu:** xin trích phần "Mô tả hiện vật — kích thước"
trong hồ sơ Bảo vật quốc gia đợt 12 từ BQL Khu di tích Cổ Loa (rồng); liên hệ Sở
VHTT Ninh Bình hoặc tra sách *Phác hoạ Nghê — gã linh vật bên rìa* (Trần Hậu Yên
Thế chủ biên, NXB Thế Giới) cho nghê; hỏi Bảo tàng Tổng hợp Quảng Bình số đo
kiểm kê của hũ tiền.

> ⚠ **Không có hiện vật nào tên "Cọc Bạch Đằng" trong danh mục Bảo vật quốc
> gia** (đã rà toàn bộ 357 bảo vật, 14 đợt). Khu di tích lịch sử Bạch Đằng là
> **di tích quốc gia đặc biệt** — là *di tích*, không phải *bảo vật*. Đừng ghi
> nhầm nhãn trên slide hay trong app.
