# Eldercare App

Ứng dụng Flutter theo dõi sức khỏe người dùng theo mô hình thiết bị y tế đeo tay. App kết nối với backend FastAPI qua HTTPS REST, đăng nhập bằng số điện thoại, tải danh sách thiết bị đã được liên kết với tài khoản, và hiển thị dữ liệu sức khỏe theo từng thiết bị.

Giao diện đã được tối ưu để dùng trên điện thoại và desktop. Toàn bộ luồng chính hiện đi theo mô hình `device-centric`: sau khi đăng nhập, app chọn một `currentDeviceId` rồi tải realtime, lịch sử, ECG và cảnh báo theo chính thiết bị đó.

## Mục tiêu dự án

- Hỗ trợ người dùng đăng nhập và quản lý thiết bị theo tài khoản cá nhân.
- Theo dõi chỉ số sức khỏe theo thời gian thực.
- Xem lịch sử dữ liệu theo ngày và theo từng chỉ số.
- Nhận cảnh báo bất thường và xử lý cảnh báo.
- Hỗ trợ mô hình phân quyền theo thiết bị:
  - `Chủ thiết bị`
  - `Người xem`

## Tính năng chính

- Đăng nhập bằng số điện thoại và mật khẩu.
- Đăng ký tài khoản mới ngay trong app.
- Tự khôi phục phiên đăng nhập từ secure storage.
- Tải danh sách thiết bị đã liên kết qua `GET /api/v1/me/devices`.
- Liên kết thiết bị bằng `device_id` + `pairing_code`.
- Xem dữ liệu realtime của thiết bị đang chọn.
- Xem lịch sử theo ngày với biểu đồ cho từng chỉ số.
- Gửi yêu cầu đo ECG theo thiết bị.
- Xem danh sách cảnh báo theo thiết bị hiện tại.
- Chủ thiết bị có thể:
  - quản lý người xem
  - xác nhận cảnh báo
  - gửi yêu cầu đo ECG
- Người xem chỉ có quyền xem dữ liệu và cảnh báo ở chế độ read-only.

## Nền tảng và công nghệ sử dụng

- Flutter
- Dart
- Provider để quản lý state
- Dio để gọi REST API
- `flutter_secure_storage` để lưu token
- `shared_preferences` để lưu cache người dùng hiện tại
- `fl_chart` để hiển thị biểu đồ
- `flutter_dotenv` để đọc cấu hình môi trường

## Kiến trúc tổng quan

App được tổ chức theo các lớp chính:

- `lib/src/features`: các màn hình giao diện như đăng nhập, thiết bị, trang chủ, lịch sử, cảnh báo
- `lib/src/state`: các provider quản lý session, device, realtime, history, alerts, ECG
- `lib/src/data/api`: các service gọi backend
- `lib/src/domain/models`: model dữ liệu
- `lib/src/widgets`: các widget dùng lại
- `lib/src/core`: hằng số, validator, helper layout, helper format

Luồng dữ liệu chính:

1. App khởi động và nạp `.env`
2. `SessionProvider` thử restore session cũ
3. Nếu đã đăng nhập:
   - gọi `GET /api/v1/auth/me`
   - gọi `GET /api/v1/me/devices`
4. Người dùng chọn hoặc claim thiết bị
5. Các provider realtime / history / alerts / ECG bind theo `device_id`

## Cấu trúc màn hình

- `DevicePage`
  - màn hình đầu tiên của app
  - dùng để đăng nhập, đăng ký, xem danh sách thiết bị đã liên kết, chọn thiết bị, mở claim device
- `HomePage`
  - hiển thị dữ liệu realtime của thiết bị hiện tại
  - cho phép mở lịch sử, cảnh báo, gửi yêu cầu ECG
- `HistoryPage`
  - hiển thị lịch sử theo ngày và theo chỉ số
- `AlertsPage`
  - hiển thị cảnh báo theo thiết bị hiện tại
  - chủ thiết bị mới thấy nút xác nhận cảnh báo
- `ClaimDevicePage`
  - nhập `device_id` và `pairing_code` để liên kết thiết bị
- `DeviceViewersPage`
  - dành cho chủ thiết bị quản lý người xem
- `RegisterPage`
  - tạo tài khoản mới bằng số điện thoại

## Contract backend hiện tại

App production dùng JWT người dùng, không phụ thuộc `USER_ID` hay `DEVICE_ID` trong `.env`.

Luồng chính:

1. `POST /api/v1/auth/login`
2. `GET /api/v1/auth/me`
3. `GET /api/v1/me/devices`
4. Chọn `currentDeviceId`
5. Tải dữ liệu chính theo `device_id`

Header xác thực mặc định:

```http
Authorization: Bearer <access_token>
```

`X-API-Key` chỉ là fallback dev-only và không được hardcode vào build release của người dùng cuối.

## Endpoint app đang sử dụng

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

Device data:

- `GET /api/v1/devices/{device_id}/latest`
- `GET /api/v1/devices/{device_id}/history?limit=...`
- `GET /api/v1/devices/{device_id}/summary?period=24h`
- `GET /api/v1/devices/{device_id}/alerts`
- `GET /api/v1/devices/{device_id}/ecg?limit=...`
- `POST /api/v1/devices/{device_id}/ecg/request`

Alerts:

- `POST /api/v1/alerts/{alert_id}/acknowledge`

## Yêu cầu môi trường

- Flutter SDK phù hợp với Dart `^3.10.1`
- Thiết bị chạy Android, Windows, hoặc môi trường Flutter hỗ trợ khác
- Backend đang hoạt động và có thể truy cập qua HTTPS

## Cấu hình môi trường

Tạo file `.env` ở thư mục gốc:

```env
API_BASE_URL=https://api.eldercare.io.vn
LOGIN_PHONE_NUMBER=0987654321
LOGIN_PASSWORD=your-password
REQUEST_TIMEOUT_MS=15000
POLL_INTERVAL_MS=2000
```

Giải thích:

- `API_BASE_URL`: địa chỉ backend
- `LOGIN_PHONE_NUMBER`: chỉ để tiện test/dev, không phải dữ liệu bắt buộc của production
- `LOGIN_PASSWORD`: chỉ để tiện test/dev
- `REQUEST_TIMEOUT_MS`: timeout mỗi request
- `POLL_INTERVAL_MS`: chu kỳ polling cho một số luồng dữ liệu

Lưu ý:

- App tự chuẩn hóa số điện thoại trước khi login/register
- Ví dụ:
  - `0987654321` -> `+84987654321`
  - `84987654321` -> `+84987654321`
  - `+84987654321` giữ nguyên
- Production phải hoạt động bình thường dù `.env` không chứa số điện thoại hay thông tin thiết bị cố định

## Cài đặt và chạy app

1. Cài package:

```bash
flutter pub get
```

2. Chạy app:

```bash
flutter run
```

3. Chạy riêng theo nền tảng khi cần:

```bash
flutter run -d windows
flutter run -d chrome
flutter run -d android
```

## Hướng dẫn sử dụng

### 1. Đăng nhập

- Mở app ở màn `Đăng nhập`
- Nhập số điện thoại
- Nhập mật khẩu
- Nhấn `Đăng nhập`

Nếu backend hợp lệ, app sẽ:

- lấy access token và refresh token
- gọi `GET /api/v1/auth/me`
- tải danh sách thiết bị qua `GET /api/v1/me/devices`

### 2. Đăng ký tài khoản mới

- Tại màn đăng nhập, chọn `Chưa có tài khoản? Đăng ký`
- Nhập:
  - họ và tên
  - số điện thoại
  - ngày sinh
  - mật khẩu
  - nhập lại mật khẩu
- Gửi form để tạo tài khoản
- Sau khi tạo thành công, app quay lại màn đăng nhập và điền sẵn số điện thoại vừa đăng ký

### 3. Chọn thiết bị để theo dõi

Sau khi đăng nhập:

- vào danh sách `Thiết bị đã liên kết`
- chọn một thiết bị
- nhấn `Theo dõi thiết bị này`

App sẽ chuyển vào `HomePage` và đồng bộ dữ liệu theo thiết bị đã chọn.

### 4. Liên kết thiết bị

Nếu tài khoản chưa có thiết bị:

- tại `DevicePage`, nhấn `Liên kết thiết bị`
- nhập `device_id`
- nhập `pairing_code`
- nhấn xác nhận

Sau khi claim thành công, app sẽ:

1. gọi lại `GET /api/v1/me/devices`
2. cập nhật `currentDeviceId`
3. reload:
   - realtime
   - history
   - alerts
   - ECG scope

### 5. Theo dõi dữ liệu realtime

Tại `HomePage`, app hiển thị:

- nhịp tim
- SpO2
- nhiệt độ
- nhịp thở
- trạng thái thiết bị
- quyền hiện tại trên thiết bị

Ngoài ra người dùng có thể:

- mở `Lịch sử`
- mở `Cảnh báo`
- mở `Quản lý người xem` nếu là chủ thiết bị
- gửi `Yêu cầu đo ECG` nếu là chủ thiết bị

### 6. Xem lịch sử

Tại `HistoryPage`:

- chọn ngày
- chọn chỉ số cần xem
- xem biểu đồ theo giờ trong ngày

Nếu chưa có dữ liệu, trang sẽ hiển thị empty state tương ứng.

### 7. Xem cảnh báo

Tại `AlertsPage`:

- lọc theo mức độ
- lọc theo trạng thái đã xử lý / chưa xử lý
- mở về thiết bị liên quan

Quyền:

- `Chủ thiết bị`: có thể xác nhận cảnh báo
- `Người xem`: chỉ xem được cảnh báo, không có nút xác nhận

### 8. Quản lý người xem

Tại `DeviceViewersPage`:

- chỉ chủ thiết bị mới vào được
- có thể thêm người xem
- có thể xóa người xem

### 9. ECG theo yêu cầu

Tại `HomePage`:

- chủ thiết bị nhấn `Yêu cầu đo ECG`
- app gửi lệnh tới backend theo `device_id`
- app chờ và cập nhật kết quả ECG mới

Người xem sẽ chỉ thấy thông báo read-only, không thể gửi yêu cầu.

## Phân quyền trong app

App hiện dùng mô hình quyền theo thiết bị:

- `Chủ thiết bị`
  - xem dữ liệu
  - gửi yêu cầu ECG
  - quản lý người xem
  - xác nhận cảnh báo
- `Người xem`
  - xem dữ liệu
  - xem lịch sử
  - xem cảnh báo
  - không được gửi ECG
  - không được xác nhận cảnh báo
  - không được quản lý người xem

## Tài khoản test và dữ liệu thử nghiệm

### Lưu ý quan trọng

- Production tại `https://api.eldercare.io.vn` không đảm bảo có sẵn tài khoản test seed.
- README này không nên cam kết rằng các tài khoản ví dụ chắc chắn tồn tại trên production.
- Cách an toàn nhất để test app là tự tạo tài khoản qua màn `Đăng ký`.

### Bộ tài khoản test khuyến nghị cho môi trường dev hoặc staging

Nếu bạn đang dùng backend dev/staging riêng hoặc tự seed dữ liệu, có thể dùng bộ tài khoản sau:

- Chủ thiết bị:
  - số điện thoại: `0987654321`
  - mật khẩu: `OwnerPass123`
- Người xem:
  - số điện thoại: `0987654322`
  - mật khẩu: `ViewerPass123`
- Tài khoản chia sẻ thêm:
  - số điện thoại: `0987654323`
  - mật khẩu: `SharedPass123`

Khuyến nghị:

- nếu backend chưa seed sẵn các tài khoản trên, hãy tạo chúng qua màn `Đăng ký`
- sau đó dùng một tài khoản owner để claim thiết bị
- rồi dùng chức năng `Quản lý người xem` để thêm viewer

### Thiết bị test khuyến nghị cho môi trường dev

Bạn có thể chuẩn bị dữ liệu test như sau:

- `device_id`: `dev-001`
- `pairing_code`: `PAIR-1234`

Lưu ý:

- đây là dữ liệu test khuyến nghị cho môi trường phát triển
- production cần device thật và pairing code thật do backend hoặc thiết bị cấp

## Kiểm thử thủ công đề xuất

### Auth

- đăng nhập bằng tài khoản hợp lệ
- nhập sai mật khẩu và kiểm tra thông báo lỗi
- đóng app, mở lại và kiểm tra restore session
- logout và kiểm tra quay lại màn hình đăng nhập

### Devices

- sau login, app gọi `/api/v1/me/devices`
- nếu có nhiều thiết bị, đổi thiết bị đang theo dõi
- nếu chưa có thiết bị, app hiển thị empty state rõ ràng

### Claim

- nhập `device_id`
- nhập `pairing_code`
- claim thành công
- xác nhận danh sách thiết bị được refresh ngay

### Home

- kiểm tra dữ liệu realtime theo đúng thiết bị đang chọn
- owner thấy nút quản lý người xem và ECG
- viewer chỉ thấy read-only

### History

- đổi ngày
- đổi chỉ số
- xác nhận biểu đồ cập nhật đúng

### Alerts

- kiểm tra lọc mức độ
- kiểm tra lọc trạng thái
- owner thấy nút xác nhận cảnh báo
- viewer không thấy nút xác nhận

## Xử lý lỗi mong muốn ở UI

- `401`: thử refresh token, nếu không được thì quay về login
- `403`: báo không có quyền với thiết bị này
- `404`: không tìm thấy thiết bị hoặc chưa có dữ liệu
- `422`: dữ liệu gửi lên không hợp lệ, ví dụ pairing code sai
- `429`: thông báo thử lại sau và giảm polling
- `500`: thông báo lỗi máy chủ

## Các file quan trọng

- `lib/main.dart`: điểm vào của ứng dụng
- `lib/src/app/app.dart`: cấu hình `MultiProvider`, theme và routes
- `lib/src/app/routes.dart`: khai báo route
- `lib/src/data/api/api_client.dart`: client REST và xử lý token
- `lib/src/data/api/auth_api_service.dart`: login, register, me, refresh, logout
- `lib/src/data/api/device_api_service.dart`: me/devices, claim device, quản lý viewer
- `lib/src/data/api/health_api_service.dart`: latest, history, summary, ECG theo `device_id`
- `lib/src/data/api/alerts_api_service.dart`: alerts theo `device_id`
- `lib/src/state/session_provider.dart`: quản lý phiên đăng nhập
- `lib/src/state/device_provider.dart`: quản lý danh sách thiết bị và current device
- `lib/src/state/realtime_provider.dart`: dữ liệu realtime
- `lib/src/state/history_provider.dart`: dữ liệu lịch sử
- `lib/src/state/alerts_provider.dart`: dữ liệu cảnh báo
- `lib/src/state/ecg_provider.dart`: dữ liệu ECG

## Lưu ý vận hành

- Không hardcode `ADMIN_API_KEY` vào build release.
- Không phụ thuộc production vào `USER_ID` hay `DEVICE_ID` trong `.env`.
- Sau khi claim thiết bị, luôn refresh lại danh sách thiết bị và scope dữ liệu.
- Nếu không đăng nhập được, nên kiểm tra:
  - `API_BASE_URL`
  - tài khoản có tồn tại trên backend hay không
  - backend trả `401`, `422` hay lỗi kết nối

## Trạng thái hiện tại của project

Project đang đi theo hướng:

- app responsive cho điện thoại và desktop
- quyền theo thiết bị
- login bằng số điện thoại
- dữ liệu theo `device_id`
- claim thiết bị bằng `pairing_code`

README này nên được cập nhật tiếp nếu backend thay đổi contract hoặc nếu team bổ sung seed data chính thức cho dev/staging.
