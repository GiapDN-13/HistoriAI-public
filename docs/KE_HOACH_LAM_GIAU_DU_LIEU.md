# Kế hoạch: thu thập và làm giàu dữ liệu lịch sử cho HistoriAI

Soạn 26/09/2026. Mục tiêu: một đường ống **tự chạy từ đầu tới cuối** — tự thu
thập, tự trích xuất, tự kiểm chứng, tự sinh nội dung và tự nhập vào app — bám
khung **Chương trình GDPT 2018** cho THCS (lớp 6–9) và THPT (lớp 10–12).

---

## 0. Hiện trạng (đo trên bản đang chạy)

| | Số lượng |
|---|---|
| Sự kiện | 5 — Bạch Đằng 938, Chống Tống 981, Bạch Đằng 1288, Lam Sơn 1428, Quang Trung 1789 |
| Câu quiz | 45 — Lam Sơn mới có 5 câu, bốn trận còn lại mỗi trận 10 |
| Vĩ nhân chat được | 2 — Trần Hưng Đạo, Quang Trung |
| Cổ vật 3D | 9 |
| Gắn với lớp / bài trong chương trình | **Không có** — dữ liệu chưa biết mình thuộc lớp mấy |
| Ghi nguồn cho từng nội dung | **Không có** |

Hai dòng cuối mới là chỗ hổng lớn nhất. Thêm nhiều sự kiện mà không gắn được
vào bài học trên lớp thì phụ huynh không thấy lý do để trả tiền.

---

## 1. Ba điều phải nói thẳng trước khi bắt tay

### 1.1 Không lấy từ sách giáo khoa hay các trang lời giải

SGK (Kết nối tri thức, Chân trời sáng tạo, Cánh diều) và các trang như
VietJack, Loigiaihay, Hoc247 đều **có bản quyền**. Thu thập về rồi đưa vào một
sản phẩm thu tiền là rủi ro pháp lý thật, và khó giải thích trước hội đồng.

Thứ **dùng được** là bản thân **Chương trình GDPT 2018** (ban hành kèm Thông tư
32/2018/TT-BGDĐT). Đây là văn bản quy phạm pháp luật, thuộc diện **không được
bảo hộ quyền tác giả** (Luật Sở hữu trí tuệ, Điều 15). Chương trình quy định
*học sinh lớp nào phải đạt được gì*, và đó chính là thứ cần để gắn nội dung vào
bài học. Không cần tới SGK.

### 1.2 "Không động tay" làm được khoảng 90%, không phải 100%

Chạy máy, thu thập, trích xuất, sinh câu hỏi và nhập vào app: tất cả tự động.

Nhưng **sai sử trong một sản phẩm dạy sử là lỗi nặng nhất có thể mắc**, và mô
hình ngôn ngữ vẫn có thể bịa. Kế hoạch dưới đây giảm rủi ro đó bằng kiểm chứng
chéo tự động (mục 4, bước B4 và B6), để **chỉ phần qua được mọi cổng kiểm mới
lên app**. Phần còn lại vào hàng chờ.

Việc duy nhất cần người là **đọc một bản tổng hợp hàng chờ** và bấm duyệt hoặc
loại. Lý tưởng nhất là một giáo viên Sử đọc thử một mẫu ngẫu nhiên. Ghi được
"nội dung đã được giáo viên rà" lên slide có giá trị hơn nhiều so với số câu hỏi.

### 1.3 Phạm vi chưa được nhóm chốt

CLAUDE.md đang chốt mô-đun *"Hào khí Đại Việt"*. Mở rộng ra toàn bộ chương
trình Sử 6–12 là **quyết định của nhóm**, không phải của tôi. Vì vậy kế hoạch
chia làm hai vòng, và vòng 2 chỉ chạy khi nhóm đồng ý:

- **Vòng 1:** làm dày mô-đun đang có (5 sự kiện, 2 vĩ nhân, 9 cổ vật).
- **Vòng 2:** mở rộng theo từng chủ đề của chương trình.

Mọi con số trong tài liệu này đều là **đề xuất để nhóm chốt**, không phải cam kết.

---

## 2. Nguồn dữ liệu

Nguyên tắc: **lấy qua API chính thức, không cào HTML**, và chỉ nhận những nguồn
có giấy phép rõ ràng.

| Nguồn | Giấy phép | Dùng để | Cách lấy |
|---|---|---|---|
| **Chương trình GDPT 2018** — Lịch sử & Địa lý (THCS), Lịch sử (THPT) | Văn bản pháp luật, không bảo hộ | **Khung xương**: lớp → chủ đề → yêu cầu cần đạt | Tải PDF từ Bộ GD&ĐT, trích văn bản |
| **Wikipedia tiếng Việt** | CC BY-SA 4.0 | Tường thuật diễn biến, bối cảnh | MediaWiki API |
| **Wikidata** | CC0 | Dữ kiện có cấu trúc: năm, địa điểm, quan hệ nhân vật–sự kiện | SPARQL |
| **Wikimedia Commons** | Theo từng tệp | Ảnh minh hoạ, bản đồ trận đánh | API, **chỉ nhận PD / CC0 / CC BY / CC BY-SA** |
| **Wikisource tiếng Việt** | Theo từng tác phẩm | Nguyên văn *Nam quốc sơn hà*, *Hịch tướng sĩ*, *Bình Ngô đại cáo*… | API, chỉ lấy bản có ghi phạm vi công cộng |
| ***Việt Nam sử lược*** — Trần Trọng Kim | Hết thời hạn bảo hộ (tác giả mất 1953; luật VN bảo hộ tới 50 năm sau khi mất) | **Nguồn độc lập thứ hai** để kiểm chứng chéo | Bản trên Wikisource |
| **Quyết định công nhận Bảo vật quốc gia** | Văn bản pháp luật | Niên đại, kích thước, nơi lưu giữ cổ vật | Văn bản công khai |

**Không dùng:** ảnh chụp SGK, các trang lời giải, báo điện tử, video YouTube.

**Hệ quả của CC BY-SA:** Wikipedia cho phép dùng lại nhưng **bắt buộc ghi
nguồn**. Nếu nội dung bám sát câu chữ gốc thì phần đó cũng phải mang cùng giấy
phép. Vì vậy app cần hiện nguồn dưới mỗi sự kiện (bước B8), và nội dung sinh ra
phải là **diễn đạt lại theo lứa tuổi**, không chép nguyên đoạn.

---

## 3. Kiến trúc tổng thể

```
data_pipeline/                  ← thư mục mới, tách khỏi backend
├── cau_hinh.yaml               phạm vi, giới hạn tốc độ, ngân sách LLM
├── b0_khung_chuong_trinh.py
├── b1_danh_sach_thuc_the.py
├── b2_thu_thap.py
├── b3_trich_menh_de.py
├── b4_kiem_chung_cheo.py
├── b5_sinh_noi_dung.py
├── b6_cong_chat_luong.py
├── b7_xuat_seed.py
├── chay_het.py                 chạy B0 → B7, bước nào xong rồi thì bỏ qua
├── cache/                      dữ liệu thô  (gitignore)
├── ket_qua/                    JSON từng bước (có trong git, để soát bằng diff)
├── hang_cho/bao_cao.html       bản tổng hợp duy nhất con người cần đọc
└── tests/
```

**Ba nguyên tắc thiết kế:**

1. **Chạy lại không sinh ra bản sao.** Bước nào đã có kết quả và đầu vào không
   đổi thì bỏ qua. Nhờ vậy dừng giữa chừng rồi chạy lại vẫn an toàn.
2. **Mỗi bước ghi ra JSON có trong git.** Muốn biết một câu hỏi đến từ đâu thì
   lần ngược được: câu hỏi → mệnh đề → câu trích nguyên văn → trang nguồn.
3. **Không ghi thẳng vào CSDL đang chạy.** Đầu ra cuối cùng là các tệp seed, rồi
   nhập qua `seed.py` (đã có sẵn cơ chế upsert) giống quy trình hiện tại.

---

## 4. Các bước chi tiết

### B0 — Dựng khung chương trình

- **Vào:** PDF chương trình môn Lịch sử & Địa lý (THCS) và Lịch sử (THPT).
- **Làm:** trích mục lục nội dung theo lớp. Với mỗi chủ đề, giữ **nguyên văn**
  phần *yêu cầu cần đạt*, kèm số trang.
- **Ra:** `khung_chuong_trinh.json`

  ```json
  { "lop": 7, "chu_de": "…", "yeu_cau_can_dat": ["…nguyên văn…"],
    "trang_pdf": 42, "ma": "LS7-05" }
  ```
- **Kiểm:** mỗi lớp 6–12 phải có ít nhất một chủ đề; mỗi yêu cầu phải tìm lại
  được nguyên văn trong PDF. Câu nào không khớp thì coi như trích sai.

Đây là bước duy nhất phải làm cẩn thận nhất. Mọi thứ phía sau đều treo vào `ma`.

### B1 — Lập danh sách thực thể cần có

- Từ khung B0, liệt kê sự kiện, nhân vật và hiện vật mà chương trình nhắc tới.
- Gắn mỗi thực thể một **mã Wikidata (QID)** làm định danh chung giữa các nguồn.
  Ví dụ: trận Bạch Đằng 938 và 1288 là hai thực thể khác nhau, không được gộp.
- Vòng 1 lọc theo 5 sự kiện, 2 vĩ nhân và 9 cổ vật hiện có. Vòng 2 mở ra theo
  danh sách chủ đề nhóm chọn.
- **Ra:** `thuc_the.json` gồm `slug`, `qid`, `loai`, `ma_chuong_trinh[]`.
- **Kiểm:** thực thể nào không tìm được QID thì báo vào hàng chờ, không đoán.

### B2 — Thu thập

- Gọi MediaWiki API, SPARQL Wikidata, API Commons và Wikisource cho từng thực thể.
- **Lịch sự với máy chủ nguồn:**
  - tối đa **1 yêu cầu/giây** cho mỗi nguồn;
  - `User-Agent` ghi tên dự án và địa chỉ liên hệ, đúng chính sách Wikimedia;
  - tôn trọng `robots.txt`, gặp lỗi 429 thì lùi dần;
  - lưu cache: đã tải rồi thì không tải lại.
- Mỗi tài liệu lưu kèm **siêu dữ liệu nguồn**: URL, mã phiên bản trang
  (`revid`), ngày tải, giấy phép, tác giả nếu có. Commons lấy giấy phép từ
  `extmetadata`; tệp nào không rõ giấy phép thì loại.
- **Ra:** `cache/<nguon>/<slug>.json`

### B3 — Trích mệnh đề sự kiện

- LLM đọc từng tài liệu và tách ra các **mệnh đề nguyên tử**, mỗi mệnh đề chỉ
  nói đúng một điều, ví dụ *"Ngô Quyền cho đóng cọc gỗ đầu bịt sắt dưới lòng
  sông Bạch Đằng"*.
- **Luật cứng:** mỗi mệnh đề phải kèm **câu trích nguyên văn** từ tài liệu nguồn,
  và code kiểm lại câu trích đó có thật trong tài liệu. Không có câu trích, hoặc
  câu trích không khớp, thì mệnh đề bị loại. Đây là cái chốt chặn LLM bịa ngay
  từ đầu.
- **Ra:** `menh_de.json` gồm `id`, `thuc_the`, `noi_dung`, `trich_dan`, `nguon`,
  `loai` (niên đại / nhân vật / diễn biến / ý nghĩa / số liệu).

### B4 — Kiểm chứng chéo

Mệnh đề từ các nguồn khác nhau được gom theo nghĩa, rồi xếp hạng:

| Hạng | Điều kiện | Được dùng cho |
|---|---|---|
| **A** | ≥ 2 nguồn **độc lập** cùng xác nhận (vd Wikipedia + *Việt Nam sử lược*, hoặc + Wikidata) | Mọi thứ, kể cả câu hỏi quiz |
| **B** | Chỉ 1 nguồn | Tóm tắt, có ghi nguồn; **không** dùng làm đáp án quiz |
| **C** | Các nguồn **mâu thuẫn** nhau | Không dùng. Vào hàng chờ, ghi "có nhiều ghi chép khác nhau" |

- Niên đại và số liệu so khớp bằng code (năm, ngày, con số), không nhờ LLM phán.
  Wikidata là chuẩn đối chiếu cho niên đại.
- Hạng C không phải lỗi mà là thông tin có giá trị. Năm sinh của nhiều nhân vật
  thời Trần không có ghi chép chắc chắn, và app nên nói đúng như vậy thay vì
  chọn đại một con số.
- **Ra:** `menh_de_da_kiem.json`

### B5 — Sinh nội dung cho app

Chỉ được dùng mệnh đề đã có hạng. Mỗi mẩu nội dung sinh ra phải **trỏ về id
mệnh đề** mà nó dựa vào.

| Loại nội dung | Cách sinh |
|---|---|
| **Tóm tắt sự kiện** | Hai mức: THCS (câu ngắn, ít thuật ngữ) và THPT (thêm bối cảnh, nguyên nhân, ý nghĩa). Diễn đạt lại, không chép nguyên đoạn. |
| **Câu hỏi quiz** | Gắn với một yêu cầu cần đạt (`ma`). Chia ba mức **biết / hiểu / vận dụng**, ánh xạ vào cột `difficulty` 1–3 đã có. Đáp án đúng **chỉ được dựa trên mệnh đề hạng A**. |
| **Đáp án nhiễu** | Lấy từ Wikidata cùng loại, như một năm khác cùng thế kỷ hay một nhân vật cùng thời, để nhiễu hợp lý chứ không vô lý. |
| **Giải thích đáp án** | Một hai câu, kèm nguồn. |
| **"Sử liệu cốt lõi" cho vĩ nhân** | Bổ sung vào `persona_prompt` từ mệnh đề hạng A, kèm danh sách mệnh đề hạng C để nhân vật **biết mình không chắc** mà không bịa. |
| **Cổ vật** | Mô tả, niên đại và kích thước từ quyết định Bảo vật quốc gia. Cổ vật nào có kích thước thật thì mở được nút AR đang bị ẩn. |

### B6 — Cổng chất lượng tự động

Mỗi câu quiz phải qua **tất cả** các cổng dưới đây. Trượt một cổng là vào hàng chờ.

1. **Đúng khuôn dữ liệu:** đủ 4 phương án, đáp án thuộc A–D, không trùng phương án.
2. **Không trùng lặp** với câu đã có (so độ giống nội dung, không chỉ so chữ).
3. **Làm bài mù:** một lượt LLM độc lập làm câu hỏi **mà không thấy đáp án**. Nó
   phải chọn đúng đáp án, và phải xác nhận **chỉ có một** phương án đúng. Máy
   làm sai, hoặc thấy hai phương án cùng đúng, thì câu đó mơ hồ và bị loại.
4. **Truy được nguồn:** đáp án đúng trỏ về mệnh đề hạng A, và mệnh đề đó trỏ về
   câu trích có thật.
5. **Hợp lứa tuổi:** độ dài câu, không dùng "tất cả các đáp án trên", không có từ
   ngữ bạo lực chi tiết quá mức với học sinh THCS.
6. **Cân bằng đáp án:** đáp án đúng không dồn vào một chữ cái.

Tóm tắt sự kiện qua các cổng 1, 2, 4 và 5, cộng thêm một cổng riêng: **mọi năm
và con số xuất hiện trong bài phải khớp một mệnh đề hạng A.**

- **Ra:** `noi_dung_dat.json` (được nhập vào app) và `hang_cho/bao_cao.html`.

### B7 — Nhập vào app

- Xuất `backend/app/db/seed_data/*.json`. Sửa `seed.py` để đọc từ đó thay vì
  viết cứng trong mã.
- Chạy toàn bộ test backend và Flutter. **Đỏ một test là dừng**, không deploy.
- Deploy theo quy trình hiện tại: seed lại CSDL máy chủ, **sao lưu trước khi seed**
  (script sao lưu đã có sẵn).
- Kiểm tra sau deploy: gọi API đếm số sự kiện và số câu hỏi, so với số trong
  `noi_dung_dat.json`.

### B8 — Hiện ra trong app

- **Dòng "Nguồn" dưới mỗi sự kiện**, bấm vào ra danh sách trang nguồn. Đây là
  nghĩa vụ của giấy phép CC BY-SA, không phải trang trí.
- **Nhãn lớp** trên mỗi sự kiện ("Lịch sử 7 · Bài …") và **bộ lọc theo lớp** ở
  dòng thời gian.
- Chọn **mức tóm tắt THCS/THPT** theo lớp người dùng khai khi đăng ký. Hiện đăng
  ký chưa hỏi lớp, nên cần thêm một trường.

---

## 5. Thay đổi cấu trúc dữ liệu

Dự án chưa có Alembic, nên dùng cơ chế `_ensure_column()` đang có trong `seed.py`.

| Bảng | Cột mới | Ý nghĩa |
|---|---|---|
| `historical_events` | `summary_thcs`, `summary_thpt` | Tóm tắt theo cấp. Giữ `summary` cũ làm mặc định |
| | `grades` | Các lớp liên quan, vd `"7,10"` |
| | `curriculum_refs` | Mã chủ đề trong khung chương trình |
| | `sources` (JSON) | URL, giấy phép, `revid` |
| `quiz_questions` | `curriculum_ref`, `source_claims` (JSON), `grade_min` | Truy nguồn, lọc theo lớp |
| `historical_figures` | `sources` (JSON) | Như trên |
| `artifacts` | `sources` (JSON) | Như trên |
| `users` | `grade` | Lớp đang học. **Không bắt buộc**, để không chặn người đang dùng |

Tất cả đều là **thêm cột**, không đổi hay xoá cột cũ. App bản cũ vẫn chạy.

---

## 6. Lộ trình

Thời gian dưới đây là máy chạy cộng với công tôi viết mã, **chưa gồm** thời gian
người duyệt hàng chờ.

### Vòng 1 — làm dày mô-đun "Hào khí Đại Việt"

| Việc | Ước lượng |
|---|---|
| Dựng khung `data_pipeline/`, B0 (khung chương trình), B1 | 1 ngày |
| B2 + B3 + B4, **chạy thử trên đúng 1 sự kiện** (Bạch Đằng 938) | 1 ngày |
| **Điểm dừng:** đo chi phí LLM thật trên 1 sự kiện, rồi mới nhân lên | — |
| B5 + B6 cho cả 5 sự kiện, 2 vĩ nhân, 9 cổ vật | 1 ngày |
| B7 + B8 (nguồn, nhãn lớp), test, deploy | 1 ngày |

**Kết quả vòng 1:** mọi sự kiện có nhãn lớp, có nguồn, có tóm tắt hai cấp; Lam
Sơn được bù đủ câu; kho câu hỏi dày hơn. Số câu mỗi sự kiện tuỳ lượng mệnh đề
hạng A thu được, vì **không nhồi câu cho đủ số**.

### Vòng 2 — mở rộng theo chương trình (chỉ khi nhóm chốt)

Chạy lại cùng đường ống với danh sách chủ đề mới ở B1. Mã không phải viết lại,
chỉ đổi phạm vi trong `cau_hinh.yaml`.

Lưu ý: vòng 2 mở rộng **chữ và câu hỏi**. Thước phim cinematic và mô hình 3D cho
sự kiện mới **không** tự sinh được từ đường ống này.

---

## 7. Rủi ro

| Rủi ro | Cách xử lý |
|---|---|
| **LLM bịa sử liệu** | Chốt trích nguyên văn ở B3, kiểm chứng chéo ở B4, làm bài mù ở B6, và người duyệt hàng chờ |
| **Chi phí và giới hạn tốc độ LLM** | Chạy thử 1 sự kiện để đo trước; đặt trần ngân sách trong `cau_hinh.yaml`, chạm trần thì dừng |
| **Wikipedia tiếng Việt chất lượng không đều** | Đây chính là lý do cần nguồn thứ hai độc lập. Bài nào quá sơ sài thì chỉ cho ra hạng B |
| **Nguồn tự trích dẫn lẫn nhau** (Wikipedia chép *Việt Nam sử lược*) | Không được tính là hai nguồn độc lập. Mệnh đề chỉ khớp nhờ câu chữ giống hệt nhau thì bị hạ hạng |
| **Nghĩa vụ CC BY-SA** | Diễn đạt lại thay vì chép, và hiện nguồn trong app (B8) |
| **Seed lỗi làm hỏng dữ liệu người dùng** | Seed chỉ upsert nội dung, không động tới bảng người dùng và tiến độ; sao lưu trước mỗi lần seed |
| **Khung chương trình trích sai** | Mỗi yêu cầu cần đạt phải khớp nguyên văn với PDF (kiểm ở B0) |

---

## 8. Phần việc của Giáp

Toàn bộ những gì cần Giáp làm là:

1. **Chốt ba quyết định** ở mục 9. Mỗi quyết định trả lời một câu là đủ.
2. **Đọc `hang_cho/bao_cao.html` sau mỗi vòng**, bấm duyệt hoặc loại. Trang này
   hiện sẵn mệnh đề, câu trích và đường dẫn nguồn cạnh nhau, nên không phải tra
   cứu thêm gì.
3. *(Nên có)* Nhờ một giáo viên Sử đọc một mẫu ngẫu nhiên.

Mọi việc khác, từ viết mã, chạy, kiểm thử, commit, deploy cho tới báo cáo, tôi làm.

---

## 9. Quyết định cần nhóm chốt

| # | Câu hỏi | Mặc định tôi đề xuất |
|---|---|---|
| 1 | Chỉ làm vòng 1, hay chốt luôn vòng 2? Nếu vòng 2 thì những chủ đề nào? | Vòng 1 trước, xem kết quả rồi mới quyết vòng 2 |
| 2 | Dùng khoá LLM đang cấu hình cho chat, hay một khoá riêng có trần chi tiêu? | Khoá riêng, để việc sinh dữ liệu không ăn vào hạn mức chat của người dùng thật |
| 3 | Có giáo viên Sử nào duyệt mẫu được không? | Có thì ghi lên slide; không có thì Giáp tự duyệt hàng chờ |

---

## 10. Tiêu chí hoàn thành vòng 1

- [ ] Mỗi sự kiện có ít nhất một mã chủ đề trong chương trình và nhãn lớp.
- [ ] Mỗi sự kiện, câu hỏi, vĩ nhân và cổ vật đều có nguồn, và nguồn hiện được trong app.
- [ ] Mọi đáp án quiz đều truy được về mệnh đề hạng A, rồi về câu trích nguyên văn.
- [ ] Không còn sự kiện nào lệch số câu như Lam Sơn hiện nay.
- [ ] Toàn bộ test backend và Flutter xanh, có thêm test cho đường ống.
- [ ] Hàng chờ đã được người duyệt.
- [ ] Đã deploy, và số liệu API sau deploy khớp với `noi_dung_dat.json`.
