# Thanh toán Premium qua SePay

Một gói duy nhất: **39.000đ cho 30 ngày Premium**, trả bằng chuyển khoản ngân hàng quét mã VietQR. Không tự gia hạn, không trừ tiền định kỳ. Premium chỉ mở một thứ: hỏi vĩ nhân **không giới hạn lượt mỗi ngày** (bản miễn phí: 10 câu AI/ngày cho tài khoản, 5 câu/ngày cho khách; câu gợi ý soạn sẵn không tính).

## Luồng chạy

1. App gọi `POST /api/v1/thanh-toan/don` → nhận mã đơn (dạng `HAI4K7Q2`), số tiền, chuỗi VietQR. Đơn sống 30 phút.
2. Người dùng quét mã, chuyển khoản **với nội dung = mã đơn**.
3. SePay thấy tiền vào tài khoản → gọi webhook `POST /api/v1/thanh-toan/sepay`.
4. Máy chủ tìm mã đơn trong nội dung, đủ tiền thì đơn sang `da_tra` và `users.premium_den` cộng 30 ngày (cộng nối vào hạn cũ nếu còn).
5. App hỏi `GET /api/v1/thanh-toan/don/{ma_don}` tới khi thấy `da_tra`.

Đơn đã hết hạn 30 phút mà tiền vẫn về đúng số thì **vẫn kích hoạt** (người ta đã trả thật). Gửi lại cùng giao dịch không cộng thêm ngày.

## 1. Đăng ký SePay và liên kết ngân hàng

1. Tạo tài khoản tại <https://sepay.vn> và đăng nhập vào trang quản lý.
2. Thêm tài khoản ngân hàng nhận tiền theo hướng dẫn của SePay (mỗi ngân hàng có cách liên kết riêng: ứng dụng ngân hàng, hoặc cấp quyền đọc biến động số dư). Làm theo đúng màn hình hướng dẫn trên SePay.
3. Kiểm biểu phí và hạn mức của gói đang dùng **trực tiếp trên trang SePay** trước khi mở bán — tài liệu này không ghi giá dịch vụ.

## 2. Đặt webhook

Trong SePay: Tích hợp webhooks → Thêm webhooks.

| Trường | Giá trị |
|---|---|
| URL | `https://historiai.org/api/v1/thanh-toan/sepay` |
| Sự kiện | Có tiền vào (nên chọn chỉ tiền vào; tiền ra nếu có gửi thì máy chủ cũng bỏ qua) |
| Kiểu chứng thực | **API Key** |
| API Key | một chuỗi ngẫu nhiên dài (ví dụ `python -c "import secrets; print(secrets.token_urlsafe(32))"`) |
| Tài khoản áp dụng | tài khoản nhận tiền của nhóm |

SePay sẽ gửi header `Authorization: Apikey <khoá>`. Sai hoặc thiếu khoá → máy chủ trả 401. Chưa đặt `SEPAY_WEBHOOK_KEY` thì máy chủ từ chối **mọi** lời gọi webhook.

## 3. Biến `.env` trên VPS

Chỉ đặt trong `backend/.env` trên máy chủ, **không commit, không ghi vào tài liệu**.

```
THANH_TOAN_BIN=<mã BIN 6 số của ngân hàng theo NAPAS, ví dụ 970422 là MB Bank>
THANH_TOAN_TEN_NH=<tên ngân hàng hiện cho người chuyển>
THANH_TOAN_SO_TK=<số tài khoản nhận tiền>
THANH_TOAN_CHU_TK=<tên chủ tài khoản, viết hoa không dấu>
SEPAY_WEBHOOK_KEY=<API Key đã đặt bên SePay>

# Tuỳ chọn — hạn mức hỏi vĩ nhân mỗi ngày của bản miễn phí
CHAT_MIEN_PHI_NGAY=10
CHAT_KHACH_NGAY=5
```

Thiếu một trong ba biến `THANH_TOAN_BIN`, `THANH_TOAN_SO_TK`, `THANH_TOAN_CHU_TK` thì thanh toán coi như **chưa bật**: `GET /thanh-toan/goi` trả `bat=false`, `POST /thanh-toan/don` trả 503, app giữ màn cũ. Khởi động lại dịch vụ `historiai` sau khi sửa `.env`. Cột `users.premium_den` được thêm tự động khi khởi động (`migrate_nhe.py`), bảng mới do `create_all` tạo.

## 4. Thử bằng gói 2.000đ

Gói `thu` (2.000đ, 1 ngày) chỉ tài khoản quản trị thấy và tạo được, để thử trọn đường tiền thật trước khi mở cho phụ huynh.

1. Đăng nhập bằng tài khoản quản trị (`GET /thanh-toan/goi` sẽ có thêm gói `thu`).
2. `POST /thanh-toan/don` với `{"goi": "thu"}` → lấy `ma_don`, `qr_chuoi` (hoặc chuyển tay: đúng số tài khoản, 2.000đ, nội dung = mã đơn).
3. Chuyển 2.000đ từ một tài khoản khác. Vài giây sau `GET /thanh-toan/don/{ma_don}` phải trả `da_tra`, và `GET /auth/me` có `la_premium: true`.
4. Nếu không thấy: xem mục SePay → Lịch sử webhook (có gọi chưa, mã trả về), rồi `GET /thanh-toan/giao-dich-chua-khop`.

Chưa bật SePay vẫn thử được phần còn lại bằng `POST /thanh-toan/xac-nhan-tay` (mục 5).

## 5. Xử lý giao dịch chưa khớp

Mọi giao dịch SePay gửi tới đều được lưu (bảng `giao_dich_ngan_hang`, kèm JSON gốc). Giao dịch không khớp đơn nào (sai mã, thiếu tiền, chuyển lần hai cùng mã) có trạng thái `chua_khop`; máy chủ vẫn trả 200 cho SePay để nó không gửi lại.

1. Quản trị gọi `GET /api/v1/thanh-toan/giao-dich-chua-khop` → tối đa 50 giao dịch mới nhất (`so_tien`, `noi_dung`, `ma_don` nếu đoán được, `ngay_gd`).
2. Đối chiếu với sao kê ngân hàng và hỏi người chuyển nếu cần.
   - Người trả đúng nhưng ghi sai mã / thiếu tiền đã bù: tìm đơn của họ rồi xác nhận tay.
   - Chuyển nhầm hoặc chuyển thừa lần hai: hoàn tiền qua ngân hàng, không cần làm gì trong hệ thống.
3. Xác nhận tay: `POST /api/v1/thanh-toan/xac-nhan-tay` với `{"ma_don": "HAI4K7Q2"}` (đăng nhập quản trị). Đơn sang `da_tra`, `nguon = "tay"`, Premium được cộng một lần; gọi lại lần nữa không cộng thêm.

Giao dịch `chua_khop` không tự biến mất khỏi danh sách sau khi xử lý tay; đối chiếu theo `ma_don` của đơn đã `da_tra`.
