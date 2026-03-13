# Eldercare App

Flutter app theo doi suc khoe, doc du lieu tu backend FastAPI qua HTTPS REST.

## Cau hinh moi theo server

Backend moi dung JWT cho luong app nguoi dung. `X-API-Key` khong con la header mac dinh cho cac request doc du lieu.

1. Tao file `.env` o root project:

```env
API_BASE_URL=https://api.eldercare.io.vn
LOGIN_USER_ID=patient-001
LOGIN_PASSWORD=your-password
USER_ID=patient-001
DEVICE_ID=dev-esp-001
REQUEST_TIMEOUT_MS=15000
POLL_INTERVAL_MS=2000
```

Ghi chu:
- `LOGIN_USER_ID` va `LOGIN_PASSWORD` duoc app dung de goi `POST /api/v1/auth/login` va lay `access_token`.
- Sau khi login, app goi `GET /api/v1/auth/me` de lay user hien tai va `GET /api/v1/me/devices` de tai danh sach thiet bi da lien ket.
- `access_token` duoc luu bang `SharedPreferences` va duoc restore khi mo lai app.
- `USER_ID` va `DEVICE_ID` chi con duoc dung lam fallback debug mode, khong phai luong chinh.
- App release cho user thong thuong khong can `ADMIN_API_KEY`; bien nay chi la optional dev-only fallback.

2. Cai dependencies:

```bash
flutter pub get
```

3. Chay app:

```bash
flutter run
```

## Luong ket noi

- Flutter chi doc du lieu qua HTTPS REST, khong truy cap MongoDB truc tiep.
- App login qua `POST /api/v1/auth/login`.
- Sau khi login, app gui `Authorization: Bearer <access_token>` cho cac request doc du lieu va tai linked devices cua session user.
- Realtime/latest/history uu tien query theo `device_id` cua thiet bi dang duoc chon.
- ECG on-demand: app goi `POST /api/v1/devices/{device_id}/ecg/request`, sau do poll `GET /public/devices/{device_id}/ecg` den khi co ket qua moi.

## Endpoint dang duoc app su dung

- `GET /health`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/me/devices`
- `GET /api/v1/users/{user_id}/latest`
- `GET /api/v1/users/{user_id}/vitals?limit=...`
- `GET /public/devices/{device_id}/ecg?limit=...`
- `GET /api/v1/users/{user_id}/summary?period=24h`
- `POST /api/v1/devices/{device_id}/ecg/request`
- `GET /api/v1/devices/{device_id}/latest`
- `GET /api/v1/devices/{device_id}/history?limit=...`

## Cau truc code lien quan

- `lib/src/data/api/api_client.dart`: tao Dio client, timeout, gan dong header `Authorization: Bearer ...`.
- `lib/src/data/api/auth_api_service.dart`: login/me/logout va dong bo token voi storage.
- `lib/src/data/local/auth_storage.dart`: luu, restore va clear access token/current user bang `SharedPreferences`.
- `lib/src/data/api/health_api_service.dart`: cac API theo user/device + ECG polling.
- `lib/src/state/realtime_provider.dart`: bootstrap session, login truoc khi load latest/history, request ECG va cap nhat UI.

