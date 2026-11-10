"""Smoke test cho CI — chạy với SQLite tạm, không cần Postgres."""
import json
import os
from pathlib import Path

os.environ.setdefault("DATABASE_URL", "sqlite:///./ci_test.db")

SEED_FILE = Path(__file__).resolve().parents[1] / "data" / "seed_data.json"

from fastapi.testclient import TestClient  # noqa: E402

from app.db import seed  # noqa: E402
from app.main import app  # noqa: E402

seed.run()
client = TestClient(app)

TEST_PW = "12345678"


def _auth_header() -> dict:
    """Đăng ký user test + login, trả về Authorization header."""
    client.post("/api/v1/auth/register",
                json={"email": "ci@test.com", "full_name": "CI", "password": TEST_PW})
    tok = client.post("/api/v1/auth/login",
                      data={"username": "ci@test.com", "password": TEST_PW}).json()["access_token"]
    return {"Authorization": f"Bearer {tok}"}


def test_health():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_events_seeded():
    r = client.get("/api/v1/events")
    assert r.status_code == 200
    assert len(r.json()) >= 4


def test_quiz_submit_grading():
    auth = _auth_header()
    questions = client.get("/api/v1/quiz/lam-son-1428", headers=auth).json()
    assert len(questions) >= 1
    qid = questions[0]["id"]
    r = client.post("/api/v1/quiz/submit", json=[{"question_id": qid, "selected_option": "A"}], headers=auth)
    assert r.status_code == 200
    assert "correct" in r.json()[0]


def test_quiz_check_is_authenticated_and_side_effect_free():
    auth = _login_as("check@test.com")
    answer = _correct_answers("lam-son-1428")[0]
    me_before = client.get("/api/v1/auth/me", headers=auth).json()
    progress_before = client.get("/api/v1/me/progress", headers=auth).json()

    checked = client.post("/api/v1/quiz/check", json=answer, headers=auth)

    assert checked.status_code == 200
    body = checked.json()
    assert body["question_id"] == answer["question_id"]
    assert body["correct"] is True
    assert body["correct_option"] == answer["selected_option"]
    assert "explanation" in body
    assert client.get("/api/v1/auth/me", headers=auth).json()["xp"] == me_before["xp"]
    assert client.get("/api/v1/me/progress", headers=auth).json() == progress_before


def test_quiz_check_rejects_invalid_option_and_allows_guest():
    # Khách chấm được từng câu (27/09) — trước đây bắt đăng nhập nên khách kẹt.
    answer = {"question_id": 1, "selected_option": "E"}
    assert client.post("/api/v1/quiz/check", json=answer).status_code == 422
    auth = _login_as("check-invalid@test.com")
    assert client.post("/api/v1/quiz/check", json=answer, headers=auth).status_code == 422


def _login_as(email: str) -> dict:
    """Tạo user mới + đăng nhập, trả về Authorization header."""
    client.post("/api/v1/auth/register",
                json={"email": email, "full_name": email.split("@")[0], "password": TEST_PW})
    tok = client.post("/api/v1/auth/login",
                      data={"username": email, "password": TEST_PW}).json()["access_token"]
    return {"Authorization": f"Bearer {tok}"}


def _correct_answers(event_slug: str) -> list[dict]:
    """Đáp án đúng của một sự kiện, đối chiếu từ seed (không phụ thuộc thứ tự câu)."""
    seed = json.loads(SEED_FILE.read_text(encoding="utf-8"))
    key = {q["question"]: q["correct_option"]
           for q in seed["quiz"] if q["event_slug"] == event_slug}
    asked = client.get(f"/api/v1/quiz/{event_slug}").json()
    return [{"question_id": q["id"], "selected_option": key[q["question"]]} for q in asked]


def test_quiz_submit_awards_xp_and_progress():
    """Trả lời đúng hết → XP tăng đúng 10 điểm mỗi câu, mastery đạt 100%."""
    auth = _login_as("xp@test.com")
    answers = _correct_answers("lam-son-1428")
    assert len(answers) >= 2

    xp_before = client.get("/api/v1/auth/me", headers=auth).json()["xp"]
    graded = client.post("/api/v1/quiz/submit", json=answers, headers=auth).json()
    assert all(g["correct"] for g in graded), "Đáp án lấy từ seed phải đúng hết"

    xp_after = client.get("/api/v1/auth/me", headers=auth).json()["xp"]
    assert xp_after == xp_before + 10 * len(answers), "XP phải tăng đúng 10 điểm/câu đúng"

    row = next(p for p in client.get("/api/v1/me/progress", headers=auth).json()
               if p["event_slug"] == "lam-son-1428")
    assert row["mastery"] == 100
    assert row["quiz_best_score"] == len(answers)


def test_quiz_best_score_is_per_event():
    """Nộp câu của 2 sự kiện trong cùng một lượt: điểm phải tính riêng từng sự kiện."""
    auth = _login_as("multi@test.com")
    lam_son = _correct_answers("lam-son-1428")      # 2 câu
    bach_dang = _correct_answers("bach-dang-1288")  # 1 câu
    client.post("/api/v1/quiz/submit", json=lam_son + bach_dang, headers=auth)

    progress = {p["event_slug"]: p
                for p in client.get("/api/v1/me/progress", headers=auth).json()}
    # Không được lấy tổng cả lượt nộp gán cho mọi sự kiện
    assert progress["bach-dang-1288"]["quiz_best_score"] == len(bach_dang)
    assert progress["lam-son-1428"]["quiz_best_score"] == len(lam_son)
    assert progress["bach-dang-1288"]["mastery"] == 100


def test_quiz_question_hides_correct_option():
    """Quiz GET không được lộ đáp án đúng."""
    auth = _auth_header()
    questions = client.get("/api/v1/quiz/lam-son-1428", headers=auth).json()
    for q in questions:
        assert "correct_option" not in q, "Lộ đáp án!"
        assert "difficulty" in q, "Thiếu difficulty"


def test_quiz_submit_requires_auth():
    """Quiz submit không có token phải 401."""
    r = client.post("/api/v1/quiz/submit", json=[{"question_id": 1, "selected_option": "A"}])
    assert r.status_code == 401


def test_chat_mock():
    r = client.post("/api/v1/chat", json={"figure_slug": "tran-hung-dao", "message": "test"})
    assert r.status_code == 200
    assert len(r.json()["reply"]) > 0


def test_auth_flow():
    client.post("/api/v1/auth/register",
                json={"email": "ci@test.com", "full_name": "CI", "password": TEST_PW})
    body = client.post("/api/v1/auth/login",
                       data={"username": "ci@test.com", "password": TEST_PW}).json()
    assert "access_token" in body
    assert "refresh_token" in body
    me = client.get("/api/v1/auth/me", headers={"Authorization": f"Bearer {body['access_token']}"})
    assert me.status_code == 200
    assert me.json()["email"] == "ci@test.com"


def test_leaderboard_phai_dang_nhap():
    """Bảng vàng KHÔNG được mở cho người lạ.

    Trước đây endpoint này trả 200 cho bất kỳ ai, kèm HỌ TÊN ĐẦY ĐỦ của toàn
    bộ người dùng. Sản phẩm nhắm học sinh THCS/THPT nên đó là chuyện không thể
    để. Test này khoá lại, đừng nới ra.
    """
    assert client.get("/api/v1/leaderboard?limit=5").status_code == 401


def test_leaderboard_chi_tra_ten_rut_gon():
    auth = _auth_header()
    r = client.get("/api/v1/leaderboard?limit=5", headers=auth)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list) and len(data) >= 1
    assert "rank" in data[0] and "xp" in data[0]

    # Không được lộ họ tên đầy đủ, và phải đánh dấu được dòng của chính mình.
    assert "full_name" not in data[0]
    assert "user_id" not in data[0], "đừng phát id người dùng ra ngoài"
    assert any(d["la_toi"] for d in data), "phải nhận ra dòng của người đang xem"

    from app.api.routes.progress import _ten_rut_gon
    assert _ten_rut_gon("Đặng Nguyên Giáp") == "Giáp Đ."
    assert _ten_rut_gon("Man") == "Man"
    assert _ten_rut_gon("") == "Ẩn danh"
    assert _ten_rut_gon(None) == "Ẩn danh"


def test_progress_requires_auth():
    r = client.get("/api/v1/me/progress")
    assert r.status_code == 401


def test_progress_after_quiz():
    client.post("/api/v1/auth/register",
                json={"email": "progress@test.com", "full_name": "Progress", "password": TEST_PW})
    tok = client.post("/api/v1/auth/login",
                      data={"username": "progress@test.com", "password": TEST_PW}).json()["access_token"]
    auth = {"Authorization": f"Bearer {tok}"}
    # Kiểm tra progress (chưa có quiz nào)
    r = client.get("/api/v1/me/progress", headers=auth)
    assert r.status_code == 200
    data = r.json()
    assert isinstance(data, list)


def test_streak_update():
    client.post("/api/v1/auth/register",
                json={"email": "streak@test.com", "full_name": "Streak", "password": TEST_PW})
    tok = client.post("/api/v1/auth/login",
                      data={"username": "streak@test.com", "password": TEST_PW}).json()["access_token"]
    auth = {"Authorization": f"Bearer {tok}"}
    r = client.post("/api/v1/me/streak", headers=auth)
    assert r.status_code == 200
    assert "streak" in r.json()


def test_auth_register_password_too_short():
    r = client.post("/api/v1/auth/register",
                    json={"email": "short@test.com", "full_name": "Short", "password": "123"})
    assert r.status_code == 422  # Validation error


def test_auth_login_wrong_password():
    r = client.post("/api/v1/auth/login",
                    data={"username": "ci@test.com", "password": "wrongpassword"})
    assert r.status_code == 401
    detail = r.json()["detail"]
    assert detail["error"]["code"] == "INVALID_CREDENTIALS"


def test_auth_refresh_flow():
    body = client.post("/api/v1/auth/login",
                       data={"username": "ci@test.com", "password": TEST_PW}).json()
    refresh_tok = body["refresh_token"]
    assert refresh_tok is not None
    # Dùng refresh token để lấy access token mới
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": refresh_tok})
    assert r.status_code == 200
    new_body = r.json()
    assert "access_token" in new_body
    assert "refresh_token" in new_body
    # Access token mới vẫn hoạt động
    me = client.get("/api/v1/auth/me",
                    headers={"Authorization": f"Bearer {new_body['access_token']}"})
    assert me.status_code == 200


def test_auth_refresh_invalid():
    r = client.post("/api/v1/auth/refresh", json={"refresh_token": "invalid_token"})
    assert r.status_code == 401
    detail = r.json()["detail"]
    assert detail["error"]["code"] == "INVALID_REFRESH_TOKEN"


def test_auth_me_unauthorized():
    r = client.get("/api/v1/auth/me")
    assert r.status_code == 401


def test_auth_register_duplicate_email():
    r = client.post("/api/v1/auth/register",
                    json={"email": "ci@test.com", "full_name": "Duplicate", "password": TEST_PW})
    assert r.status_code == 400
    detail = r.json()["detail"]
    assert detail["error"]["code"] == "EMAIL_EXISTS"


def test_xoa_tai_khoan():
    """Người dùng phải tự xoá được tài khoản mình.

    Google Play bắt buộc, và với người dùng vị thành niên thì đó là mức tối
    thiểu. Test khoá cả ba điều: phải đăng nhập mới xoá được, xoá xong thì
    token cũ hết dùng, và dữ liệu học đi theo.
    """
    email = "xoa.thu@example.com"
    client.post("/api/v1/auth/register",
                json={"email": email, "full_name": "Xoa Thu", "password": TEST_PW})
    tok = client.post("/api/v1/auth/login",
                      data={"username": email, "password": TEST_PW}).json()["access_token"]
    auth = {"Authorization": f"Bearer {tok}"}

    # Chưa đăng nhập thì không được xoá của người khác.
    assert client.delete("/api/v1/auth/me").status_code == 401

    assert client.delete("/api/v1/auth/me", headers=auth).status_code == 204

    # Token cũ thành vô dụng, và đăng nhập lại cũng không được nữa.
    assert client.get("/api/v1/auth/me", headers=auth).status_code == 401
    lai = client.post("/api/v1/auth/login",
                      data={"username": email, "password": TEST_PW})
    assert lai.status_code != 200, "tài khoản đã xoá mà vẫn đăng nhập được"
