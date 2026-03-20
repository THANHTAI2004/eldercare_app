import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/data/api/api_client.dart';
import 'package:eldercare_app/src/data/api/device_api_service.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/session_provider.dart';

class ClaimDevicePage extends StatefulWidget {
  const ClaimDevicePage({super.key, DeviceApiService? api}) : _api = api;

  final DeviceApiService? _api;

  @override
  State<ClaimDevicePage> createState() => _ClaimDevicePageState();
}

class _ClaimDevicePageState extends State<ClaimDevicePage> {
  final _formKey = GlobalKey<FormState>();
  final _deviceIdCtrl = TextEditingController();

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
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _resolvedApi.claimDevice(deviceId: _deviceIdCtrl.text.trim());
      if (!mounted) return;
      final session = context.read<SessionProvider>();
      await context.read<DeviceProvider>().syncFromServer(
        authenticatedUserId: session.authenticatedUserId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      final message = _friendlyError(e);
      if (!mounted) return;
      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiRequestException) {
      if (e.statusCode == 404) {
        return 'Không tìm thấy thiết bị với mã đã nhập.';
      }
      if (e.statusCode == 409) {
        return 'Thiết bị này đã có người quản lý.';
      }
      if (e.statusCode == 403) {
        return 'Tài khoản hiện tại không thể liên kết thiết bị này.';
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
                        Text(
                          'Thêm thiết bị bằng mã thiết bị',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhập mã thiết bị để liên kết thiết bị vào tài khoản của bạn. Sau khi liên kết thành công, danh sách thiết bị sẽ được cập nhật lại.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _deviceIdCtrl,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            labelText: 'Mã thiết bị',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nhập mã thiết bị';
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
                        FilledButton.icon(
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
