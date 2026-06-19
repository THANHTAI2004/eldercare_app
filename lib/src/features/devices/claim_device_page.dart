import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/features/devices/device_qr_scanner_page.dart';
import 'package:eldercare_app/src/state/alerts_provider.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/state/history_provider.dart';
import 'package:eldercare_app/src/state/realtime_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_button.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_scaffold.dart';
import 'package:eldercare_app/src/ui/components/app_text_field.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';
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
  String? _successMessage;
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

  Future<void> _scanQr() async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => const DeviceQrScannerPage()),
    );
    if (!mounted || result == null || result.trim().isEmpty) return;

    final parsed = _parseQrPayload(result);
    setState(() {
      if ((parsed.deviceId ?? '').isNotEmpty) {
        _deviceIdCtrl.text = parsed.deviceId!;
      }
      if ((parsed.pairingCode ?? '').isNotEmpty) {
        _pairingCodeCtrl.text = parsed.pairingCode!;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final normalizedDeviceId = _deviceIdCtrl.text.trim();
    final normalizedPairingCode = _pairingCodeCtrl.text.trim();

    try {
      await _resolvedApi.claimDevice(
        deviceId: normalizedDeviceId,
        pairingCode: normalizedPairingCode,
      );
      final selectedDeviceId = await _refreshDeviceState(normalizedDeviceId);
      if (!mounted) return;
      setState(() {
        _successMessage = 'Thiết bị đã được liên kết thành công.';
      });
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      Navigator.pop(context, selectedDeviceId);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error);
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
    final realtime = Provider.of<RealtimeProvider?>(context, listen: false);
    final history = Provider.of<HistoryProvider?>(context, listen: false);
    final ecg = Provider.of<EcgProvider?>(context, listen: false);
    final alerts = Provider.of<AlertsProvider?>(context, listen: false);

    await deviceProvider.syncFromServer(
      authenticatedUserId: session.authenticatedUserId,
    );
    if (!mounted) return claimedDeviceId;

    final claimedDevice = deviceProvider.findById(claimedDeviceId);
    if (claimedDevice == null) {
      return claimedDeviceId;
    }

    await deviceProvider.setCurrent(claimedDevice.id);
    if (!mounted) return claimedDevice.resolvedDeviceId;

    final resolvedDeviceId = claimedDevice.resolvedDeviceId;
    ecg?.bindScope(deviceId: resolvedDeviceId);
    alerts?.bindDevice(resolvedDeviceId);

    final reloads = <Future<void>>[];
    if (realtime != null) {
      reloads.add(realtime.changeDevice(resolvedDeviceId));
    }
    if (history != null) {
      reloads.add(
        history.bindScope(
          deviceId: resolvedDeviceId,
          dayLocal: _todayLocal(),
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

  String _friendlyError(Object error) {
    if (error is ApiRequestException) {
      switch (error.statusCode) {
        case 401:
          return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.';
        case 403:
          return 'Tài khoản hiện tại không có quyền liên kết thiết bị này.';
        case 404:
          return 'Không tìm thấy thiết bị với mã đã nhập.';
        case 409:
          return 'Thiết bị này đã được liên kết trước đó.';
        case 422:
          return 'Pairing Code không đúng hoặc dữ liệu gửi lên chưa hợp lệ.';
        case 429:
          return 'Đang bị giới hạn yêu cầu, vui lòng thử lại sau.';
        case 500:
          return 'Máy chủ đang gặp lỗi, vui lòng thử lại sau.';
      }
      return error.message;
    }
    return 'Liên kết thiết bị thất bại. Vui lòng thử lại.';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Liên kết thiết bị',
      leading: IconButton(
        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      child: ListView(
        children: [
          AppCard(
            child: Column(
              children: [
                const AppBrandLockup(
                  logoSize: 64,
                  title: 'Kết nối thiết bị của bạn',
                ),
                const SizedBox(height: AppSpacing.xxl),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: _deviceIdCtrl,
                        label: 'Device ID',
                        hint: 'VD: ED01A2B3C4D5',
                        prefix: const Icon(Icons.watch_outlined),
                        enabled: !_isSubmitting,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Nhập Device ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _pairingCodeCtrl,
                        label: 'Pairing Code',
                        hint: 'VD: 123456',
                        prefix: const Icon(Icons.password_outlined),
                        enabled: !_isSubmitting,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Nhập Pairing Code';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Pairing Code thường gồm 6 ký tự hiển thị trên thiết bị hoặc hướng dẫn sử dụng.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _MessageBanner(
                          message: _errorMessage!,
                          tone: StatusTone.danger,
                        ),
                      ],
                      if (_successMessage != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _MessageBanner(
                          message: _successMessage!,
                          tone: StatusTone.success,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        width: double.infinity,
                        child: SecondaryButton(
                          label: 'Quét QR',
                          onPressed: _isSubmitting ? null : _scanQr,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: _isSubmitting
                              ? 'Đang liên kết thiết bị...'
                              : 'Liên kết thiết bị',
                          onPressed: _submit,
                          isLoading: _isSubmitting,
                          icon: const Icon(Icons.add_link_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.tone});

  final String message;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final isSuccess = tone == StatusTone.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSuccess
            ? const Color(0xFFDCFCE7)
            : Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isSuccess
              ? const Color(0xFF166534)
              : Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

class _QrPayload {
  const _QrPayload({this.deviceId, this.pairingCode});

  final String? deviceId;
  final String? pairingCode;
}

_QrPayload _parseQrPayload(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      return _QrPayload(
        deviceId: map['device_id']?.toString() ?? map['deviceId']?.toString(),
        pairingCode: map['pairing_code']?.toString() ??
            map['pairingCode']?.toString(),
      );
    }
  } catch (_) {}
  return _QrPayload(deviceId: raw.trim());
}

DateTime _todayLocal() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
