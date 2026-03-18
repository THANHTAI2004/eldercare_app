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

  DeviceApiService get _api => widget._api ?? DeviceApiService();

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
      await _api.claimDevice(deviceId: _deviceIdCtrl.text.trim());
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
        return 'Khong tim thay thiet bi voi ma da nhap.';
      }
      if (e.statusCode == 409) {
        return 'Thiet bi nay da co nguoi quan ly.';
      }
      if (e.statusCode == 403) {
        return 'Tai khoan hien tai khong the claim thiet bi nay.';
      }
      return e.message;
    }
    return 'Them thiet bi that bai. Vui long thu lai.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim thiet bi')),
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
                          'Claim thiet bi bang device_id',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nhap device_id de claim thiet bi. Neu thanh cong, app se dong bo lai danh sach /api/v1/me/devices.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _deviceIdCtrl,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            labelText: 'Device ID',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nhap device_id';
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
                                ? 'Dang claim thiet bi...'
                                : 'Claim thiet bi',
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
