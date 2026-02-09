import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:eldercare_app/src/config/env.dart';
import 'package:eldercare_app/src/core/constants.dart';
import 'package:eldercare_app/src/core/utils.dart';
import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/vitals_api.dart';
import 'package:eldercare_app/src/data/mqtt/mqtt_service.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';
import 'package:eldercare_app/src/domain/models/vital_point.dart';

class RealtimeProvider extends ChangeNotifier {
  final _api = VitalsApi(ApiClient(baseUrl: Env.apiBaseUrl));
  final _mqtt = MqttService(
    host: Env.mqttHost,
    username: Env.mqttUsername,
    password: Env.mqttPassword,
    tcpPort: Env.mqttTcpPort,
    wsPort: Env.mqttWsPort,
    wsPath: Env.mqttWsPath,
  );

  /// userId hiện tại – lấy từ DeviceProvider
  String userId = Env.defaultUserId;
  bool get hasUser => userId.isNotEmpty;

  bool _initialized = false;
  bool isLoadingLatest = false;
  bool isLoadingHistory = false;

  String? error;

  VitalPoint? latest;
  Metric selectedMetric = Metric.hr;

  final List<VitalPoint> _livePoints = [];
  List<VitalPoint> get livePoints => List.unmodifiable(_livePoints);

  final List<VitalPoint> _historyPoints = [];
  List<VitalPoint> get historyPoints => List.unmodifiable(_historyPoints);

  StreamSubscription<MqttRxMessage>? _mqttSub;

  // =========================
  // ONLINE / OFFLINE STATUS
  // =========================

  DateTime? _lastSeenUtc;

  /// ngưỡng để coi là đang hoạt động (tuỳ bạn chỉnh)
  final Duration onlineThreshold = const Duration(seconds: 12);

  DateTime? get lastSeen => _lastSeenUtc?.toLocal();

  bool get isOnline {
    final t = _lastSeenUtc;
    if (t == null) return false;
    return DateTime.now().toUtc().difference(t) <= onlineThreshold;
  }

  String get lastSeenText {
    final t = _lastSeenUtc;
    if (t == null) return 'Chưa có dữ liệu';
    final diff = DateTime.now().toUtc().difference(t);

    if (diff.inSeconds < 5) return 'Vừa xong';
    if (diff.inSeconds < 60) return '${diff.inSeconds}s trước';
    if (diff.inMinutes < 60) return '${diff.inMinutes}p trước';
    return '${diff.inHours}h trước';
  }

  void _markSeen([DateTime? time]) {
    final t = (time ?? DateTime.now()).toUtc();
    _lastSeenUtc = t;
  }

  void _resetSeen() {
    _lastSeenUtc = null;
  }

  /// Khởi tạo lần đầu, có thể gọi lại nhiều lần
  Future<void> init({String? userId}) async {
    if (_initialized) {
      // lần sau nếu truyền userId khác thì đổi user
      if (userId != null && userId.isNotEmpty && userId != this.userId) {
        changeUser(userId); // không await -> không block UI
      }
      return;
    }
    _initialized = true;

    if (userId != null && userId.isNotEmpty) {
      this.userId = userId;
    }

    if (!hasUser) {
      latest = null;
      _livePoints.clear();
      _historyPoints.clear();
      error = null;
      _resetSeen();
      notifyListeners();
      return;
    }

    // chạy nền, không await để UI lên ngay
    refreshLatest();
    connectMqtt();
    loadHistory(from: '-30d', to: 'now()', window: '10m');
  }

  /// Đổi userId khi chọn thiết bị khác trong DevicePage
  Future<void> changeUser(String newUserId) async {
    newUserId = newUserId.trim();

    // Xoá hết thiết bị -> clear user
    if (newUserId.isEmpty) {
      userId = '';
      latest = null;
      _livePoints.clear();
      _historyPoints.clear();
      error = null;

      _resetSeen();

      _mqttSub?.cancel();
      _mqttSub = null;
      await _mqtt.disconnect();

      notifyListeners();
      return;
    }

    // Ngắt MQTT & reset state cũ
    _mqttSub?.cancel();
    _mqttSub = null;
    await _mqtt.disconnect();

    userId = newUserId;
    latest = null;
    _livePoints.clear();
    _historyPoints.clear();
    error = null;

    _resetSeen();

    notifyListeners(); // UI cập nhật ngay theo thiết bị mới

    // Kick các call nặng, KHÔNG await -> không block UI
    refreshLatest();
    connectMqtt();
    loadHistory(from: '-30d', to: 'now()', window: '10m');
  }

  Future<void> refreshLatest() async {
    if (!hasUser) {
      latest = null;
      _resetSeen();
      notifyListeners();
      return;
    }

    try {
      isLoadingLatest = true;
      error = null;
      notifyListeners();

      final p = await _api.latest(userId: userId);
      latest = p;

      // ✅ đánh dấu thiết bị vừa có dữ liệu (từ API)
      if (p.time != null) {
        _markSeen(p.time);
      } else {
        _markSeen();
      }
    } catch (e) {
      error ??= 'Latest error: $e';
    } finally {
      isLoadingLatest = false;
      notifyListeners();
    }
  }

  /// Load history theo range tương đối
  Future<void> loadHistory({
    String from = '-30d',
    String to = 'now()',
    String window = '10m',
  }) async {
    if (!hasUser) {
      _historyPoints.clear();
      notifyListeners();
      return;
    }

    try {
      isLoadingHistory = true;
      error = null;
      notifyListeners();

      final points = await _api.history(
        userId: userId,
        from: from,
        to: to,
        window: window,
      );
      points.sort((a, b) => a.time.compareTo(b.time));

      _historyPoints
        ..clear()
        ..addAll(points);
    } catch (e) {
      error ??= 'History error: $e';
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Load đúng 1 ngày LOCAL cho HistoryPage
  Future<void> loadHistoryForLocalDay({
    required DateTime dayLocal,
    String window = '10m',
  }) async {
    final startLocal = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
    final endLocal = startLocal.add(const Duration(days: 1));

    final startUtc = startLocal.toUtc();
    final endUtc = endLocal.toUtc();

    final from = 'time(v: "${startUtc.toIso8601String()}")';
    final to = 'time(v: "${endUtc.toIso8601String()}")';

    await loadHistory(from: from, to: to, window: window);
  }

  /// Kết nối MQTT cho user hiện tại
  Future<void> connectMqtt() async {
    if (!hasUser) return;

    try {
      error = null;
      await _mqtt.connect(
        clientId: 'eld_${userId}_${kIsWeb ? "web" : "io"}',
      );

      final topic = 'eldercare/$userId/telemetry';
      _mqtt.subscribe(topic);

      _mqttSub?.cancel();
      _mqttSub = _mqtt.messages.listen((m) {
        if (m.topic != topic) return;

        final json = safeJsonMap(m.payload);
        final p = VitalPoint.fromJson(json);

        latest = p;

        // ✅ đánh dấu thiết bị vừa có dữ liệu (từ MQTT)
        _markSeen(p.time);

        _livePoints.add(p);
        if (_livePoints.length > AppConstants.liveMaxPoints) {
          _livePoints.removeRange(
            0,
            _livePoints.length - AppConstants.liveMaxPoints,
          );
        }

        notifyListeners();
      });
    } catch (e) {
      error ??= 'MQTT error: $e';
      notifyListeners();
    }
  }

  void setMetric(Metric metric) {
    selectedMetric = metric;
    notifyListeners();
  }

  List<VitalPoint> liveSeriesFor(Metric metric) {
    return _livePoints.where((p) => p.valueOf(metric) != null).toList();
  }

  /// Lọc history theo ngày LOCAL (cho HistoryPage)
  List<VitalPoint> historyForLocalDay(DateTime dayLocal) {
    return _historyPoints.where((p) {
      final t = p.time.toLocal();
      return t.year == dayLocal.year &&
          t.month == dayLocal.month &&
          t.day == dayLocal.day;
    }).toList();
  }

  /// (Giữ lại nếu còn dùng UTC-day ở chỗ khác)
  List<VitalPoint> historyForUtcDay(DateTime dayUtc) {
    final d = DateTime.utc(dayUtc.year, dayUtc.month, dayUtc.day);
    final next = d.add(const Duration(days: 1));
    return _historyPoints
        .where((p) => !p.time.isBefore(d) && p.time.isBefore(next))
        .toList();
  }

  /// Kiểm tra userId có dữ liệu trên server hay không.
  /// Dựa vào API history: nếu không có điểm nào trong 30 ngày qua -> coi như không tồn tại.
  Future<bool> checkUserExists(String userId) async {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) return false;

    try {
      final points = await _api.history(
        userId: trimmed,
        from: '-30d',
        to: 'now()',
        window: '1h',
      );
      return points.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('checkUserExists error: $e');
      }
      return false;
    }
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    _mqtt.dispose();
    super.dispose();
  }
}
