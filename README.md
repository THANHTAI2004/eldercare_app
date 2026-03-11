# Eldercare App

Flutter app theo doi suc khoe, doc du lieu tu backend FastAPI qua HTTPS REST.

## Cau hinh moi theo server

1. Tao file `.env` o root project:

```env
API_BASE_URL=https://api.yourdomain.com
API_KEY=replace-with-api-key
USER_ID=dev-user-001
DEVICE_ID=dev-esp-001
REQUEST_TIMEOUT_MS=15000
POLL_INTERVAL_MS=2000
```

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
- Moi request app gui header `X-API-Key`.
- ECG on-demand: app goi `POST /ecg/request`, sau do poll `GET /api/v1/users/{user_id}/ecg` den khi co ket qua.

## Endpoint dang duoc app su dung

- `GET /health`
- `GET /api/v1/users/{user_id}/latest`
- `GET /api/v1/users/{user_id}/vitals?limit=...`
- `GET /api/v1/users/{user_id}/ecg?limit=...`
- `GET /api/v1/users/{user_id}/summary?period=24h`
- `POST /api/v1/devices/{device_id}/ecg/request`
- `GET /api/v1/devices/{device_id}/latest`
- `GET /api/v1/devices/{device_id}/history?limit=...`

## Cau truc code lien quan

- `lib/src/data/api/api_client.dart`: tao Dio client, timeout, header `X-API-Key`.
- `lib/src/data/api/health_api_service.dart`: cac API theo user/device + ECG polling.
- `lib/src/state/realtime_provider.dart`: load latest/history qua REST API, request ECG va cap nhat UI.

