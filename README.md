# Eldercare App

Flutter app theo doi suc khoe, doc du lieu tu backend FastAPI qua HTTPS REST.

## Cau hinh moi theo server

Backend moi dung JWT cho luong app nguoi dung. `X-API-Key` khong con la header mac dinh cho cac request doc du lieu.

1. Tao file `.env` o root project:

```env
API_BASE_URL=https://api.yourdomain.com
LOGIN_USER_ID=patient-001
LOGIN_PASSWORD=your-password
ADMIN_API_KEY=replace-with-admin-api-key
USER_ID=patient-001
DEVICE_ID=dev-esp-001
REQUEST_TIMEOUT_MS=15000
POLL_INTERVAL_MS=2000
```

Ghi chu:
- `LOGIN_USER_ID` va `LOGIN_PASSWORD` duoc app dung de goi `POST /api/v1/auth/login` va lay `access_token`.
- `access_token` duoc luu bang `SharedPreferences` va duoc restore khi mo lai app.
- `ADMIN_API_KEY`/`API_KEY` chi nen dung cho bootstrap hoac admin flow rieng, khong phai luong doc du lieu chinh cua app.

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
- Sau khi login, app gui `Authorization: Bearer <access_token>` cho cac request doc du lieu.
- ECG on-demand: app goi `POST /api/v1/devices/{device_id}/ecg/request`, sau do poll `GET /api/v1/users/{user_id}/ecg` den khi co ket qua.

## Endpoint dang duoc app su dung

- `GET /health`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/users/{user_id}/latest`
- `GET /api/v1/users/{user_id}/vitals?limit=...`
- `GET /api/v1/users/{user_id}/ecg?limit=...`
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

