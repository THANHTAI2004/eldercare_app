import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/state/alerts_provider.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/widgets/app_logo.dart';

class ClaimDevicePage extends StatefulWidget {
  const ClaimDevicePage({super.key, DeviceApiService? api}) : _api = api;

  final DeviceApiService? _api;

  @override
  State<ClaimDevicePage> createState() => _ClaimDevicePageState();
}

class _ClaimDevicePageState extends State<ClaimDevicePage> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdCtrl = TextEditingController();
  final _pairingCodeCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  DeviceApiService? _api;

  DeviceApiService get _resolvedApi => _api!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api ??= widget._api ?? DeviceApiService(client: context.read<ApiClient>());
  }

  @override
  void dispose() {
    _deviceIdCtrl.dispose();
    _pairingCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final normalizedDeviceId = _deviceIdCtrl.text.trim();
    final normalizedPairingCode = _pairingCodeCtrl.text.trim();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _resolvedApi.claimDevice(
        deviceId: normalizedDeviceId,
        pairingCode: normalizedPairingCode,
      );
      final selectedDeviceId = await _refreshDeviceState(normalizedDeviceId);
      if (!mounted) return;
      Navigator.pop(context, selectedDeviceId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<String> _refreshDeviceState(String claimedDeviceId) async {
    final session = context.read<SessionProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    await deviceProvider.syncFromServer(
      authenticatedUserId: session.authenticatedUserId,
    );

    final claimedDevice = deviceProvider.findById(claimedDeviceId);
    if (claimedDevice == null) {
      return claimedDeviceId;
    }

    await deviceProvider.setCurrent(claimedDevice.id);

    final resolvedDeviceId = claimedDevice.resolvedDeviceId;
    final realtime = Provider.of<RealtimeProvider?>(context, listen: false);
    final history = Provider.of<HistoryProvider?>(context, listen: false);
    final ecg = Provider.of<EcgProvider?>(context, listen: false);
    final alerts = Provider.of<AlertsProvider?>(context, listen: false);

    ecg?.bindScope(deviceId: resolvedDeviceId);
    alerts?.bindDevice(resolvedDeviceId);

    final now = DateTime.now();
    final todayLocal = DateTime(now.year, now.month, now.day);
    final reloads = <Future<void>>[];

    if (realtime != null) {
      reloads.add(realtime.changeDevice(resolvedDeviceId));
    }
    if (history != null) {
      reloads.add(
        history.bindScope(
          deviceId: resolvedDeviceId,
          dayLocal: todayLocal,
          load: true,
        ),
      );
    }
    if (alerts != null) {
      reloads.add(alerts.loadAlerts());
    }

    if (reloads.isNotEmpty) {
      await Future.wait(reloads);
    }

    return resolvedDeviceId;
  }

  String _friendlyError(Object e) {
    if (e is ApiRequestException) {
      if (e.statusCode == 401) {
        return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.';
      }
      if (e.statusCode == 403) {
        return 'Tài khoản hiện tại không có quyền liên kết thiết bị này.';
      }
      if (e.statusCode == 404) {
        return 'Không tìm thấy thiết bị với mã đã nhập.';
      }
      if (e.statusCode == 409) {
        return 'Thiết bị này đã được liên kết trước đó.';
      }
      if (e.statusCode == 422) {
        return 'Mã ghép nối không đúng hoặc dữ liệu gửi lên chưa hợp lệ.';
      }
      if (e.statusCode == 429) {
        return 'Đang bị giới hạn yêu cầu, vui lòng thử lại sau.';
      }
      if (e.statusCode == 500) {
        return 'Máy chủ đang gặp lỗi, vui lòng thử lại sau.';
      }
      return e.message;
    }
    return 'Liên kết thiết bị thất bại. Vui lòng thử lại.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liên kết thiết bị')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: AppBrandLockup(
                            logoSize: 72,
                            subtitle:
                                'Xác thực thiết bị bằng mã ghép nối để hoàn tất quyền truy cập an toàn.',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Liên kết thiết bị bằng mã ghép nối',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhập mã thiết bị và mã ghép nối để nhận quyền trên thiết bị, sau đó ứng dụng sẽ tải lại danh sách thiết bị của bạn.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _deviceIdCtrl,
                          enabled: !_isSubmitting,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Mã thiết bị',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nhập mã thiết bị';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pairingCodeCtrl,
                          enabled: !_isSubmitting,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Mã ghép nối',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nhập mã ghép nối';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        if (_errorMessage != null &&
                            _errorMessage!.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _InlineError(message: _errorMessage!),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.add_link),
                            label: Text(
                              _isSubmitting
                                  ? 'Đang liên kết thiết bị...'
                                  : 'Liên kết thiết bị',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
      ),
    );
  }
}
