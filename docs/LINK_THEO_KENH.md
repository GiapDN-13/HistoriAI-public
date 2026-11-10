# Link theo kênh — biết khách đến từ đâu

Mỗi kênh dùng **một link riêng**. App đọc nhãn trên link lần đầu người đó mở và nhớ
mãi cho máy đó: hôm sau họ gõ thẳng `historiai.org` quay lại thì vẫn tính công cho
kênh ban đầu. Đăng ký tài khoản thì nguồn được lưu kèm tài khoản.

Không gắn nhãn thì app lấy tên miền trang trước (facebook.com → `facebook`). Nhưng
nhiều app (Messenger, Zalo, TikTok) **không gửi trang trước** — nên luôn dùng link
có nhãn, đừng dán link trần.

## Link làm sẵn

| Kênh | Link |
|---|---|
| Fanpage Facebook | `https://historiai.org/?utm_source=facebook&utm_medium=fanpage&utm_campaign=ra-mat` |
| Nhóm Facebook | `https://historiai.org/?utm_source=facebook&utm_medium=nhom&utm_campaign=ra-mat` |
| Zalo (nhóm lớp, phụ huynh) | `https://historiai.org/?utm_source=zalo&utm_medium=nhom&utm_campaign=ra-mat` |
| TikTok (link ở bio) | `https://historiai.org/?utm_source=tiktok&utm_medium=bio` |
| Instagram (link ở bio) | `https://historiai.org/?utm_source=instagram&utm_medium=bio` |
| Google Form khảo sát | `https://historiai.org/?utm_source=google-form&utm_medium=khao-sat` |
| Email | `https://historiai.org/?utm_source=email&utm_campaign=ra-mat` |
| Mã QR trên poster | `https://historiai.org/?ref=qr` |
| Mã QR trên slide thuyết trình | `https://historiai.org/?utm_source=qr&utm_medium=slide&utm_campaign=tuan-10` |
| Demo tại một lớp cụ thể | `https://historiai.org/?ref=lop-10a1` (đổi tên lớp) |

## Seeding trong group Facebook

Dùng **một link cho mỗi group**, ghi tên group vào `utm_content` — dashboard tách
riêng từng group, biết group nào mang người về và group nào chỉ tốn công.

```
https://historiai.org/?utm_source=facebook&utm_medium=seeding&utm_campaign=ra-mat&utm_content=<ten-group>
```

| Group (ví dụ — đổi theo group thật) | Link |
|---|---|
| Ôn thi Lịch sử THPT | `https://historiai.org/?utm_source=facebook&utm_medium=seeding&utm_campaign=ra-mat&utm_content=on-thi-su-thpt` |
| Hội phụ huynh có con học THCS | `https://historiai.org/?utm_source=facebook&utm_medium=seeding&utm_campaign=ra-mat&utm_content=phu-huynh-thcs` |
| Cộng đồng giáo viên Lịch sử | `https://historiai.org/?utm_source=facebook&utm_medium=seeding&utm_campaign=ra-mat&utm_content=giao-vien-su` |
| Góc học tập / chia sẻ tài liệu | `https://historiai.org/?utm_source=facebook&utm_medium=seeding&utm_campaign=ra-mat&utm_content=chia-se-tai-lieu` |

- Tên group: chữ thường, không dấu, gạch ngang, ngắn gọn — đủ để nhóm nhận ra.
- Seeding đợt mới thì đổi `utm_campaign` (vd `tuan-6`), giữ nguyên tên group, để so
  được cùng một group qua các đợt.
- Muốn biết **thành viên nào** seeding hiệu quả: thêm tên viết tắt vào cuối nội dung,
  vd `utm_content=on-thi-su-thpt-giap`.

Link cho **mã QR** nên ngắn (`?ref=…`) để mã ít ô, quét dễ hơn. Viết tắt được hiểu:
`fb` = facebook, `zl` = zalo, `gg` = google, `form` = google-form, `tt` = tiktok,
`ig` = instagram, `yt` = youtube, `qr` = qr, `mail` = email.

## Đặt nhãn thế nào

- **Chữ thường, không dấu, nối bằng gạch ngang**: `ra-mat`, `tuan-10`, `lop-10a1`.
  App tự làm sạch, nhưng có dấu thì chữ có dấu bị bỏ (`Ra Mắt` → `ra-mt`).
- `utm_source` = **nơi** (facebook, zalo…). `utm_campaign` = **đợt** (ra-mat, tuan-10…).
  Cùng một đợt đăng nhiều nơi thì giữ nguyên `utm_campaign`, đổi `utm_source`.
- Muốn so hai bài đăng trên cùng một nơi: thêm `&utm_content=bai-1`, `bai-2`.

## Xem kết quả

`https://historiai.org/api/v1/analytics/dashboard?key=<ANALYTICS_KEY>` → mục
**Khách đến từ đâu**: mỗi dòng là một nguồn + chiến dịch, với số người vào, số đăng
ký, tỉ lệ đăng ký, số làm quiz, chat, bấm mua.

- `truc-tiep` — gõ thẳng địa chỉ, dấu trang, hoặc app không gửi trang trước.
- `chua-ro` — máy chỉ dùng bản app trước khi có đo nguồn (26/09/2026).
- `ban-cai-android` — mở từ bản cài Android (bản cài không có link để đọc nhãn).
