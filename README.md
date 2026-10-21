# Gói bàn giao Notebook (source đã biên dịch)

Image và gói này chạy đủ API, worker Celery, OCR, compare và conflict review. Người nhận không nhận mã nguồn Python/TypeScript. Backend nằm trong extension `.so`, prompt và skill nằm trong file `.enc`.

## Trước khi gửi

1. Thu hồi admin key OpenAI từng được dán vào `check.sh` trên máy build. File đó không nằm trong git và đã được xoá nội dung key, nhưng key từng xuất hiện trên đĩa nên phải rotate trên OpenAI.
2. Không nén cả thư mục git. Chỉ gửi `genote-notebook-release.tar.gz` (hoặc image) và, **tách riêng**, file `release/genote-notebook.release.key`.
3. Không đưa `.env`, `.git`, `check.sh`, `plans/`, `docs/`, `feature_conflict/` vào gói.

## Tạo gói

Trên máy có Docker, từ gốc repo:

```bash
bash scripts/package_release.sh
```

Script biên dịch bằng Python 3.11 của image `node:22-bookworm` (cùng ABI với image chạy), mã hoá prompt/skill, rồi tạo:

- `release/dist/` — context để `docker build`
- `release/genote-notebook-release.tar.gz` — gói gửi đi
- `release/genote-notebook.release.key` — khoá AES-GCM, **không** nằm trong tar hay image

Frontend: nếu đã có `out/` (sau `bun run build`), script copy bản export và xoá `*.map`. Nếu chưa build, gói chỉ có trang thông báo; API vẫn chạy.

## Chạy bằng Docker

```bash
cd release/dist
cp .env.example .env
# điền secret vào .env, gồm RELEASE_ASSET_KEY lấy từ file key
docker build -t genote-notebook:release .
docker compose up -d
curl -fsS http://127.0.0.1:8080/health
```

Compose không mount source lên `/app/backend` hay `/app/doc-ocr`.

Biến bắt buộc thêm so với môi trường dev:

| Biến | Ý nghĩa |
| --- | --- |
| `RELEASE_ASSET_KEY` | Base64 của 32 byte. Thiếu key thì prompt mã hoá không đọc được. |
| `DOCUMENT_STORAGE` | `s3` trên AgentBase. `local` chỉ khi một replica và chấp nhận mất file khi pod bị xoá. |
| `S3_URL`, `S3_BUCKET_NAME`, `S3_ACCESS_KEY`, `S3_SECRET_ACCESS_KEY` | Bắt buộc khi `DOCUMENT_STORAGE=s3`. |
| `PORT` | `8080` trên AgentBase. |

`RUN_CELERY_WORKER=1` chạy worker `genote_studio` cùng process group với gunicorn (mặc định 2 worker API, 1 process Celery). Redis và Postgres phải tới được từ container.

## GreenNode AgentBase

- Image push lên vCR: `vcr.vngcloud.vn/<repo>/genote-notebook:release`, platform `linux/amd64`.
- Container nghe **8080**, `GET /health` trả 200, không auth.
- Sửa `agent.yaml`: image, flavor (không dùng `1x1-general`; cần máy đủ LibreOffice/ffmpeg, khoảng 4 vCPU và 8 GB), và secret.
- `minReplicas=maxReplicas=1` vì job nền và file local không chia sẻ giữa replica. Khi `DOCUMENT_STORAGE=s3`, file upload sống trên S3; vẫn nên giữ 1 replica trừ khi Redis/Postgres đã là dịch vụ ngoài.
- Biến trên portal chỉ để cấu hình không nhạy cảm. `DB_PASSWORD`, `OPENAI_API_KEY`, `JWT_SECRET_KEY`, `LDAP_BIND_CREDENTIALS`, khoá S3 và `RELEASE_ASSET_KEY` đưa qua kênh secret, không commit.

Chưa kiểm chứng được path prefix `/notebook` trên AgentBase từ tài liệu công khai. Sau khi runtime `ACTIVE`, gọi `/health` rồi `/notebook/`.

## Giới hạn

Biên dịch và mã hoá ngăn đọc source và prompt bằng cách mở image. Không ngăn người có quyền chạy container và có `RELEASE_ASSET_KEY` debug bộ nhớ sau khi giải mã. Không có khoá trong `docker history` của image runtime: khoá chỉ vào lúc biên dịch qua secret mount và lúc chạy qua env.

## License

Xem `LICENSE`. Gói này không phải giấy phép phân phối lại source.
