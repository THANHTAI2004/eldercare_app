import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/domain/models/device_registration_result.dart';
import 'package:eldercare_app/src/state/session_provider.dart';
import 'package:eldercare_app/src/widgets/app_logo.dart';

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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

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

  String _friendlyError(Object error) {
    if (error is ApiRequestException) {
      if (error.statusCode == 401) {
        return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.';
      }
      if (error.statusCode == 403) {
        return 'Tài khoản hiện tại không có quyền quản trị để đăng ký thiết bị.';
      }
      if (error.statusCode == 409) {
        return 'Thiết bị hoặc mã ghép nối đang bị trùng. Hãy kiểm tra lại và thử lại.';
      }
      if (error.statusCode == 422) {
        return 'Dữ liệu đăng ký thiết bị chưa hợp lệ. Hãy kiểm tra lại các trường bắt buộc.';
      }
      if (error.statusCode == 500) {
        return 'Máy chủ đang gặp lỗi khi đăng ký thiết bị. Vui lòng thử lại sau.';
      }
      return error.message;
    }
    return 'Không thể đăng ký thiết bị lúc này. Vui lòng thử lại.';
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final isAdmin = session.authenticatedRole == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Đăng ký thiết bị')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: !isAdmin
                      ? const _AdminAccessDenied()
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Center(
                                child: AppBrandLockup(
                                  logoSize: 72,
                                  subtitle:
                                      'Tạo mới thiết bị hoặc cấp lại mã ghép nối để chuyển cho chủ thiết bị.',
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Đăng ký thiết bị cho quản trị viên',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Trang này gọi trực tiếp endpoint quản trị để tạo hoặc cập nhật thiết bị, sau đó trả lại mã ghép nối cho bạn.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _deviceIdCtrl,
                                enabled: !_isSubmitting,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Mã thiết bị',
                                  hintText: 'Ví dụ: dev-esp-001',
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
                                controller: _deviceNameCtrl,
                                enabled: !_isSubmitting,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Tên thiết bị',
                                  hintText: 'Ví dụ: Máy đo phòng ngủ',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _deviceTypeCtrl,
                                enabled: !_isSubmitting,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Loại thiết bị',
                                  hintText: 'Ví dụ: esp32',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _firmwareVersionCtrl,
                                enabled: !_isSubmitting,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Phiên bản firmware',
                                  hintText: 'Ví dụ: 1.0.0',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _pairingCodeCtrl,
                                enabled: !_isSubmitting,
                                textInputAction: TextInputAction.done,
                                decoration: const InputDecoration(
                                  labelText: 'Mã ghép nối tùy chọn',
                                  hintText:
                                      'Bỏ trống để máy chủ tự sinh mã mới',
                                ),
                                onFieldSubmitted: (_) => _submit(),
                              ),
                              if (_errorMessage != null &&
                                  _errorMessage!.trim().isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _ResultBanner(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.errorContainer,
                                  textColor: Theme.of(
                                    context,
                                  ).colorScheme.onErrorContainer,
                                  child: Text(_errorMessage!),
                                ),
                              ],
                              if (_result != null) ...[
                                const SizedBox(height: 16),
                                _ResultBanner(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  textColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Đăng ký thiết bị thành công',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      SelectableText(
                                        'Mã thiết bị: ${_result!.deviceId}',
                                      ),
                                      const SizedBox(height: 4),
                                      SelectableText(
                                        'Mã ghép nối: ${_result!.pairingCode}',
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Hãy gửi đúng hai mã này cho chủ thiết bị để họ liên kết trên ứng dụng.',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: _isSubmitting ? null : _submit,
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.admin_panel_settings),
                                label: Text(
                                  _isSubmitting
                                      ? 'Đang đăng ký thiết bị'
                                      : 'Đăng ký thiết bị',
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

class _AdminAccessDenied extends StatelessWidget {
  const _AdminAccessDenied();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trang này chỉ dành cho quản trị viên',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Bạn đang đăng nhập bằng tài khoản không có quyền quản trị. Hãy dùng tài khoản admin để đăng ký hoặc cấp lại mã ghép nối cho thiết bị.',
        ),
      ],
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.backgroundColor,
    required this.textColor,
    required this.child,
  });

  final Color backgroundColor;
  final Color textColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTextStyle(
        style: Theme.of(
          context,
        ).textTheme.bodyMedium!.copyWith(color: textColor),
        child: IconTheme(
          data: IconThemeData(color: textColor),
          child: child,
        ),
      ),
    );
  }
}
