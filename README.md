# Eldercare App

Flutter app theo dõi sức khỏe, đọc dữ liệu từ backend FastAPI qua HTTPS REST.

## Contract production

App production dùng JWT của người dùng, không phụ thuộc `USER_ID` hay `DEVICE_ID` trong `.env`.

Luồng chính:

1. `POST /api/v1/auth/login`
2. `GET /api/v1/auth/me`
3. `GET /api/v1/me/devices`
4. Chọn `currentDeviceId`
5. Tải toàn bộ dữ liệu chính theo `device_id`

`Authorization: Bearer <access_token>` là cơ chế xác thực mặc định cho flow người dùng.
`X-API-Key` chỉ là fallback dev-only và không được hardcode vào build release.

## Cấu hình môi trường

Tạo file `.env` ở root project:

```env
API_BASE_URL=https://api.eldercare.io.vn
LOGIN_PHONE_NUMBER=0987654321
LOGIN_PASSWORD=your-password
REQUEST_TIMEOUT_MS=15000
POLL_INTERVAL_MS=2000
```

Ghi chú:

- `LOGIN_PHONE_NUMBER` và `LOGIN_PASSWORD` chỉ để tiện cho môi trường dev/test.
- App tự chuẩn hóa số điện thoại trước khi `login/register`, ví dụ `0987654321` sẽ thành `+84987654321`.
- Release/production phải chạy được dù `.env` không có thông tin user hay device cố định.
- App sẽ tự restore session từ secure storage nếu đã đăng nhập trước đó.

## Endpoint chính thức app đang dùng

Auth:

- `GET /health`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/register`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`
- `GET /api/v1/auth/me`

Devices:

- `GET /api/v1/me/devices`
- `POST /api/v1/devices/{device_id}/claim`
- `GET /api/v1/devices/{device_id}/linked-users`
- `POST /api/v1/devices/{device_id}/viewers`
- `DELETE /api/v1/devices/{device_id}/viewers/{user_id}`

Device-based data:

- `GET /api/v1/devices/{device_id}/latest`
- `GET /api/v1/devices/{device_id}/history?limit=...`
- `GET /api/v1/devices/{device_id}/summary?period=24h`
- `GET /api/v1/devices/{device_id}/alerts`
- `GET /api/v1/devices/{device_id}/ecg?limit=...`
- `POST /api/v1/devices/{device_id}/ecg/request`

Alerts action:

- `POST /api/v1/alerts/{alert_id}/acknowledge`

## Claim device

Luồng claim chính thức:

- Form nhập `device_id`
- Form nhập `pairing_code`
- Submit `POST /api/v1/devices/{device_id}/claim`

Payload:

```json
{
  "pairing_code": "PAIR-123456"
}
```

Sau khi claim thành công, app phải:

1. Gọi lại `GET /api/v1/me/devices`
2. Cập nhật `currentDeviceId`
3. Reload các provider đang bám theo device:
   - realtime/latest
   - history
   - alerts
   - ECG scope

Nếu user chưa có thiết bị, UI phải hiện empty state rõ ràng và có nút `Liên kết thiết bị`.

## Device-centric rules

- Home / realtime: dùng `device_id`
- History: dùng `device_id`
- Alerts: dùng `device_id`
- ECG: dùng `device_id`
- Summary: dùng `device_id`
- `user_id` chỉ còn dùng cho hồ sơ user hoặc viewer/share khi thật sự cần

## Xử lý lỗi mong muốn ở UI

- `401`: refresh token nếu có thể, nếu không thì quay lại login
- `403`: báo user không có quyền với thiết bị này
- `404`: thiết bị không tồn tại hoặc chưa có dữ liệu
- `422`: pairing code sai hoặc payload không đúng schema
- `429`: báo thử lại sau và giảm polling
- `500`: báo lỗi máy chủ

## File chính liên quan

- `lib/src/data/api/api_client.dart`: cấu hình Dio, timeout, gắn `Authorization: Bearer ...`
- `lib/src/data/api/auth_api_service.dart`: login/register/me/logout/refresh
- `lib/src/data/api/device_api_service.dart`: `/me/devices`, claim device, viewer management
- `lib/src/data/api/health_api_service.dart`: latest/history/summary/ECG theo `device_id`
- `lib/src/data/api/alerts_api_service.dart`: alerts theo `device_id`
- `lib/src/state/session_provider.dart`: bootstrap session, login, logout, refresh token
- `lib/src/state/device_provider.dart`: đồng bộ danh sách thiết bị và chọn current device
- `lib/src/state/realtime_provider.dart`: latest reading theo device
- `lib/src/state/history_provider.dart`: history theo device
- `lib/src/state/alerts_provider.dart`: alerts theo device
- `lib/src/state/ecg_provider.dart`: ECG on-demand theo device
- `lib/src/features/devices/claim_device_page.dart`: form claim với `device_id` + `pairing_code`

## Manual checklist

1. Auth

- Login bằng số điện thoại và mật khẩu hợp lệ
- Kill app và mở lại, xác nhận session được restore
- Logout, xác nhận quay lại màn hình login

2. Devices

- Sau login, app gọi `/api/v1/me/devices`
- Nếu có thiết bị, app chọn `currentDeviceId`
- Nếu chưa có thiết bị, app hiện empty state với nút `Liên kết thiết bị`

3. Claim

- Nhập `device_id`
- Nhập `pairing_code`
- Submit claim
- Xác nhận danh sách thiết bị được reload và thiết bị vừa claim được chọn lại

4. Data

- Realtime/latest tải theo `/api/v1/devices/{device_id}/latest`
- History tải theo `/api/v1/devices/{device_id}/history`
- Alerts tải theo `/api/v1/devices/{device_id}/alerts`
- ECG request/poll theo `/api/v1/devices/{device_id}/ecg...`
