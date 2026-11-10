/// Prompt cho AI miễn phí (ChatGPT, Gemini, Copilot…) soạn đề ĐÚNG định dạng mà
/// "Dán nhiều câu" đọc được (backend/app/services/nhap_cau.py). Bản đầy đủ kèm hướng
/// dẫn: docs/HUONG_DAN_KIEM_TRA_TREN_LOP.md — sửa ở đây thì sửa cả ở đó.
const promptSoanDe = '''Bạn là giáo viên Lịch sử Việt Nam giàu kinh nghiệm. Hãy soạn [SỐ CÂU, ví dụ 10] câu hỏi trắc nghiệm về: [CHỦ ĐỀ / TÊN BÀI, ví dụ "Bài 15 – Chiến thắng Bạch Đằng năm 938"], cho học sinh lớp [LỚP, ví dụ 7].

YÊU CẦU NỘI DUNG
1. Bám sát sách giáo khoa Lịch sử chương trình GDPT 2018. Chỉ dùng sự kiện, nhân vật, mốc thời gian, địa danh CHẮC CHẮN đúng. Câu nào không chắc thì bỏ, thay câu khác.
2. Mỗi câu có đúng 4 phương án A, B, C, D và CHỈ MỘT đáp án đúng.
3. Phương án sai phải hợp lý và cùng loại với đáp án (cùng là tên người, hoặc cùng là năm, hoặc cùng là địa danh). Không dùng phương án đùa cợt, không dùng "Tất cả các ý trên" hay "Cả A và B".
4. Rải đều đáp án đúng vào A, B, C, D, không dồn vào một chữ.
5. Độ khó: khoảng 4 phần nhận biết, 4 phần thông hiểu, 2 phần vận dụng.
6. Câu hỏi ngắn (dưới 25 từ), phương án ngắn (dưới 12 từ) để chiếu lên màn hình đọc kịp.
7. Mỗi câu có 1–2 câu giải thích vì sao đáp án đúng, viết cho học sinh dễ hiểu.
8. Soạn xong, tự kiểm tra lại từng đáp án một lần nữa.

ĐỊNH DẠNG BẮT BUỘC
Trả về đúng mẫu dưới đây cho từng câu. Không thêm lời dẫn, không kẻ bảng, không in đậm, không đánh dấu sao. Để một dòng trống giữa hai câu.

Câu 1: <nội dung câu hỏi>
A. <phương án A>
B. <phương án B>
C. <phương án C>
D. <phương án D>
Đáp án: <chỉ một chữ A, B, C hoặc D>
Giải thích: <1–2 câu>
''';
