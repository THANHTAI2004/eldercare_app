# Test API Connection và Lịch Sử

## 🧪 Script test API

### 1. Kiểm tra server đang chạy
```bash
# Test health endpoint
curl http://172.26.135.230:8000/health

# Kết quả mong đợi:
# {"status": "healthy"} hoặc tương tự
```

### 2. Kiểm tra API vitals
```bash
# Lấy dữ liệu 24h gần nhất
curl "http://172.26.135.230:8000/api/v1/users/patient001/vitals?limit=100"

# Kết quả mong đợi:
# {
#   "user_id": "patient001",
#   "count": <số lượng>,
#   "items": [
#     {
#       "device_id": "chest001",
#       "user_id": "patient001",
#       "timestamp": 1707835296.0,
#       "spo2": 98.0,
#       "temperature": 36.5,
#       "heart_rate": 72,
#       "respiratory_rate": 16
#     }
#   ]
# }
```

### 3. Gửi dữ liệu test qua MQTT
```bash
# Cài mosquitto clients (nếu chưa có)
# Windows: choco install mosquitto
# Linux: sudo apt-get install mosquitto-clients

# Gửi dữ liệu mẫu
mosquitto_pub -h 172.26.135.230 -t 'health/patient001' -m '{
  "device_id": "chest001",
  "device_type": "chest",
  "user_id": "patient001",
  "timestamp": 1707835296.0,
  "spo2": 98.0,
  "temperature": 36.5,
  "heart_rate": 72,
  "respiratory_rate": 16,
  "battery_level": 85
}'
```

## 📱 Test trong Flutter App

### Dashboard (Realtime)
1. Mở app, vào tab "Trang chủ"
2. Kiểm tra connection indicator (góc trên bên phải)
   - API: ✅ Xanh = Connected
   - MQTT: ✅ Xanh = Connected
3. Gửi data qua MQTT (dùng lệnh trên)
4. Xem data xuất hiện realtime trên dashboard

### History (Lịch sử từ MongoDB)
1. Vào tab "Lịch sử"
2. Kiểm tra status bar (góc trên bên phải):
   - 🟢 Online = Kết nối thành công
   - 🔴 Offline = Không kết nối được
3. Nếu có dữ liệu:
   - Chọn khoảng thời gian (1h, 6h, 24h, 7d, 30d)
   - Chọn loại thông số (SpO2, Nhịp tim, Nhịp thở, Nhiệt độ)
   - Xem biểu đồ và thống kê
4. Nếu không có dữ liệu:
   - Thấy thông báo "Không có dữ liệu trong khoảng thời gian này"
   - Thử chọn khoảng thời gian khác

### Troubleshooting
Nếu thấy lỗi kết nối:
- Kiểm tra server URL trong error message
- Nhấn nút "Thử lại" để retry
- Kiểm tra server đang chạy
- Ping server: `ping 172.26.135.230`

## 🔍 Debug Mode

App sẽ in log trong console:

```dart
// MQTT logs
🔌 Connecting to MQTT broker at 172.26.135.230:1883
✅ MQTT Connected
📡 Subscribing to: health/patient001
✅ Subscribed to: health/patient001
📊 New health reading: HR=72, SpO2=98

// API logs  
Error loading history: <error message>
```

## ✅ Checklist Test

- [ ] Server health check thành công
- [ ] API /vitals trả về dữ liệu
- [ ] MQTT connection thành công
- [ ] Dashboard hiển thị data realtime
- [ ] History screen kết nối thành công
- [ ] History screen hiển thị charts
- [ ] Thống kê tính toán đúng
- [ ] Error handling hoạt động (tắt server để test)
- [ ] Retry button hoạt động

## 📊 Kết quả mong đợi

**Khi có dữ liệu:**
- Biểu đồ line chart mượt mà
- Thống kê: Trung bình, Thấp nhất, Cao nhất
- Tổng số lần đo hiển thị đúng

**Khi không có dữ liệu:**
- Thông báo rõ ràng
- Gợi ý chọn khoảng thời gian khác

**Khi lỗi kết nối:**
- Hiển thị error message chi tiết
- Nút "Thử lại" để retry
- Hiển thị server URL để debug
