import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/domain/models/device_registration_result.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_button.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_scaffold.dart';
import 'package:eldercare_app/src/ui/components/app_text_field.dart';
import 'package:eldercare_app/src/ui/components/empty_state.dart';

class AdminDeviceRegistrationPage extends StatefulWidget {
  const AdminDeviceRegistrationPage({super.key, DeviceApiService? api})
    : _api = api;

  final DeviceApiService? _api;

  @override
  State<AdminDeviceRegistrationPage> createState() =>
      _AdminDeviceRegistrationPageState();
}

class _AdminDeviceRegistrationPageState
    extends State<AdminDeviceRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdCtrl = TextEditingController();
  final _deviceNameCtrl = TextEditingController();
  final _deviceTypeCtrl = TextEditingController(text: 'esp32');
  final _firmwareVersionCtrl = TextEditingController();
  final _pairingCodeCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  DeviceRegistrationResult? _result;
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
    _deviceNameCtrl.dispose();
    _deviceTypeCtrl.dispose();
    _firmwareVersionCtrl.dispose();
    _pairingCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final result = await _resolvedApi.registerDevice(
        deviceId: _deviceIdCtrl.text.trim(),
        deviceName: _deviceNameCtrl.text,
        deviceType: _deviceTypeCtrl.text,
        firmwareVersion: _firmwareVersionCtrl.text,
        pairingCode: _pairingCodeCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
      });
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

  Future<void> _copyPairingCode() async {
    final pairingCode = _result?.pairingCode ?? '';
    if (pairingCode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: pairingCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã sao chép pairing code.')),
    );
  }

  String _friendlyError(Object error) {
    if (error is ApiRequestException) {
      switch (error.statusCode) {
        case 401:
          return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.';
        case 403:
          return 'Tài khoản hiện tại không có quyền quản trị để đăng ký thiết bị.';
        case 409:
          return 'Thiết bị hoặc pairing code đang bị trùng. Hãy kiểm tra lại.';
        case 422:
          return 'Dữ liệu đăng ký thiết bị chưa hợp lệ.';
        case 500:
          return 'Máy chủ đang gặp lỗi khi đăng ký thiết bị.';
      }
      return error.message;
    }
    return 'Không thể đăng ký thiết bị lúc này. Vui lòng thử lại.';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final isAdmin = session.authenticatedRole == 'admin';

    return AppScaffold(
      title: 'Đăng ký thiết bị mới',
      subtitle: 'Công cụ dành cho quản trị viên để tạo hoặc cấp lại thiết bị.',
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      child: ListView(
        children: [
          if (!isAdmin)
            const EmptyState(
              icon: Icons.admin_panel_settings_outlined,
              title: 'Trang này chỉ dành cho quản trị viên',
              message:
                  'Hãy đăng nhập bằng tài khoản admin để đăng ký hoặc cấp lại thiết bị.',
            )
          else ...[
            AppCard(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Thông tin thiết bị', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: _deviceIdCtrl,
                      label: 'Device ID',
                      hint: 'VD: dev-esp-001',
                      prefix: const Icon(Icons.watch_outlined),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Nhập Device ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _deviceNameCtrl,
                      label: 'Tên thiết bị',
                      hint: 'VD: Elder Band 01',
                      prefix: const Icon(Icons.badge_outlined),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _deviceTypeCtrl,
                      label: 'Loại thiết bị',
                      hint: 'VD: esp32',
                      prefix: const Icon(Icons.memory_outlined),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _firmwareVersionCtrl,
                      label: 'Firmware version',
                      hint: 'VD: 1.0.0',
                      prefix: const Icon(Icons.system_update_alt_outlined),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: _pairingCodeCtrl,
                      label: 'Pairing code',
                      hint: 'Bỏ trống để server tự sinh',
                      prefix: const Icon(Icons.password_outlined),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: _isSubmitting
                            ? 'Đang đăng ký thiết bị...'
                            : 'Đăng ký thiết bị',
                        onPressed: _submit,
                        isLoading: _isSubmitting,
                        icon: const Icon(Icons.add_circle_outline_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_result != null) ...[
              const SizedBox(height: AppSpacing.section),
              AppCard(
                backgroundColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Đăng ký thiết bị thành công',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Device ID: ${_result!.deviceId}'),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Pairing code: ${_result!.pairingCode}'),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Trạng thái: ${_result!.status}'),
                    const SizedBox(height: AppSpacing.xl),
                    SecondaryButton(
                      label: 'Sao chép pairing code',
                      onPressed: _copyPairingCode,
                      icon: const Icon(Icons.copy_outlined),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
