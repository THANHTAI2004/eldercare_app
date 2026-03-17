# Eldercare App

Flutter app theo doi suc khoe, doc du lieu tu backend FastAPI qua HTTPS REST.

## Cau hinh moi theo server

Backend moi dung JWT cho luong app nguoi dung. `X-API-Key` khong con la header mac dinh cho cac request doc du lieu.

1. Tao file `.env` o root project:

```env
API_BASE_URL=https://api.eldercare.io.vn
LOGIN_PHONE_NUMBER=0987654321
LOGIN_PASSWORD=your-password
REQUEST_TIMEOUT_MS=15000
POLL_INTERVAL_MS=2000
```

Ghi chu:
- `LOGIN_PHONE_NUMBER` va `LOGIN_PASSWORD` duoc app dung de goi `POST /api/v1/auth/login` va lay `access_token`.
- Sau khi login, app goi `GET /api/v1/auth/me` de lay user hien tai va `GET /api/v1/me/devices` de tai danh sach thiet bi da lien ket.
- `access_token` va `refresh_token` duoc luu trong secure storage; current user cache duoc luu local de restore session nhanh hon.
- `USER_ID` va `DEVICE_ID` chi con duoc dung lam fallback debug mode, khong phai luong chinh.
- App release cho user thong thuong khong can `ADMIN_API_KEY`; bien nay chi la optional dev-only fallback.
- Release/production can dam bao user van chay duoc khi `.env` khong co `USER_ID` va `DEVICE_ID`.

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
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
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
- `lib/src/data/api/auth_api_service.dart`: register/login/me/logout/refresh va dong bo token voi storage.
- `lib/src/data/local/auth_storage.dart`: luu token trong secure storage va current user cache o local storage.
- `lib/src/data/api/health_api_service.dart`: cac API theo user/device + ECG polling.
- `lib/src/state/realtime_provider.dart`: bootstrap session, login truoc khi load latest/history, request ECG va cap nhat UI.
- `lib/src/data/api/device_api_service.dart`: goi `GET /api/v1/me/devices`.
- `lib/src/state/device_provider.dart`: dong bo linked devices, auto-chon current device, fallback debug mode.
- `lib/src/features/alerts/alerts_page.dart`: danh sach alert, loc severity/trang thai, acknowledge.

## Manual Checklist

1. Auth
- Login bang `LOGIN_PHONE_NUMBER` / `LOGIN_PASSWORD` hoac nhap tay trong app.
- Dang ky tai khoan moi trong app, xac nhan app quay lai man hinh login va tu dien lai so dien thoai.
- Kill app va mo lai, xac nhan session duoc restore.
- Logout, xac nhan app quay lai man hinh login.

2. Device sync
- Sau login, xac nhan app goi `/api/v1/me/devices` va hien linked devices.
- Neu user chi co 1 device, xac nhan device duoc auto-select.
- Neu user co nhieu device, doi device trong selector o `HomePage` va xac nhan latest/history doi theo.

3. Data states
- Kiem tra 4 case UI: chua login, khong co device, device co nhung chua co reading, khong co quyen / server loi.

4. ECG
- Gui request ECG cho device dang chon.
- Xac nhan app poll theo `/public/devices/{device_id}/ecg`.
- Xac nhan UI hien trang thai dang cho ket qua va nhan ket qua moi dung device.

5. Alerts
- Mo man hinh Alerts.
- Loc theo severity va trang thai acknowledge.
- Acknowledge mot alert va xac nhan trang thai cap nhat.

