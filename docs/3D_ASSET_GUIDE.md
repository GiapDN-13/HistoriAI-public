# Hướng dẫn bàn giao Asset 3D (Designer ⇄ Tech)

Tài liệu cho **team Design (CDO)** và **team Tech**. Mục tiêu: hai bên thống nhất
**định dạng file** + **cách bàn giao** để không dẫm chân nhau.

## 1. Hai loại "3D" trong app — xuất file KHÁC nhau

| Tính năng | Bản chất | Designer xuất |
|---|---|---|
| **3D Cinematic** (xem trận đánh như phim) | **Video render sẵn** | `.mp4` (H.264, 1080p, ≤ 2 phút) |
| **AR Museum / model xoay 360°** | Model 3D real-time | `.glb` (+ `.usdz` cho iOS) |

> ⚠️ **Cinematic KHÔNG render real-time.** Render ra MP4 trong Blender/Unity rồi
> bỏ lên CDN. Nhẹ, chắc chắn mượt, dễ demo. Chỉ AR mới cần model thật.

## 2. Checklist xuất model cho AR (định dạng GLB)

- [ ] Định dạng **`.glb`** (glTF binary — 1 file, đã nhúng texture)
- [ ] Thêm **`.usdz`** cho iOS (convert từ GLB bằng Reality Converter / `usdzconvert`)
- [ ] Polycount: **10k–50k tris** (KHÔNG để hàng triệu poly như render phim)
- [ ] Texture: **1024² hoặc 2048²**, PNG/JPG
- [ ] Material: **PBR** (Base Color, Normal, Roughness, Metallic)
- [ ] **Scale thật**: 1 unit = 1 mét; pivot đặt ở đáy/giữa vật
- [ ] Nén bằng **Draco** để giảm dung lượng 5–10 lần
- [ ] Tự kiểm tra ở **https://gltf-viewer.donmccurdy.com** (kéo–thả file) trước khi bàn giao

## 3. Quy ước đặt tên (snake_case, không dấu)

```
trong_dong_dong_son.glb       kiem_le_loi.glb
bach_dang_1288.mp4            quang_trung_1789.mp4
```

## 4. Luồng bàn giao

```
Designer (Blender)  ──xuất .glb/.usdz/.mp4──►  Upload Firebase Storage / CDN
                                                      │  (mỗi file 1 URL)
                                                      ▼
                              Dán URL vào DB seed (backend/data/seed_data.json)
                                                      │
                                                      ▼
                              App Flutter tự tải & hiển thị:
                               • .glb  → model_viewer_plus (xoay 360)
                               • AR    → ar_flutter_plugin (ARCore/ARKit)
                               • .mp4  → video_player
```

**Designer KHÔNG cần biết Flutter.** Chỉ cần: (1) xuất đúng định dạng, (2) gửi URL.

## 5. Tech: nơi khai báo URL

Sửa `backend/data/seed_data.json` — các trường:
- Event: `cinematic_video_url`, `thumbnail_url`
- Artifact: `model_glb_url`, `model_usdz_url`, `thumbnail_url`

Dùng placeholder `{ASSET}` → tự thay bằng `ASSET_BASE_URL` lúc seed.
Sau khi sửa, chạy lại `python -m app.db.seed`.

## 6. Flutter — code mẫu hiển thị

```dart
// Xem model 3D xoay 360 (không AR)
import 'package:model_viewer_plus/model_viewer_plus.dart';
ModelViewer(src: artifact.modelGlbUrl!, ar: true, autoRotate: true);

// Phát video Cinematic
import 'package:video_player/video_player.dart';
final c = VideoPlayerController.networkUrl(Uri.parse(event.cinematicVideoUrl!));
```
