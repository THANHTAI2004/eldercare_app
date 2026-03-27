import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/domain/models/device_thresholds.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/device_thresholds_provider.dart';

class DeviceThresholdsPage extends StatefulWidget {
  const DeviceThresholdsPage({super.key});

  @override
  State<DeviceThresholdsPage> createState() => _DeviceThresholdsPageState();
}

class _DeviceThresholdsPageState extends State<DeviceThresholdsPage> {
  final _formKey = GlobalKey<FormState>();

  final _spo2LowCtrl = TextEditingController();
  final _spo2CriticalCtrl = TextEditingController();
  final _tempLowCtrl = TextEditingController();
  final _tempHighCtrl = TextEditingController();
  final _tempCriticalCtrl = TextEditingController();
  final _hrLowCtrl = TextEditingController();
  final _hrLowCriticalCtrl = TextEditingController();
  final _hrHighCtrl = TextEditingController();
  final _hrCriticalCtrl = TextEditingController();
  final _rrLowCtrl = TextEditingController();
  final _rrHighCtrl = TextEditingController();

  String? _lastScopeKey;
  String? _lastHydratedFingerprint;

  @override
  void dispose() {
    _spo2LowCtrl.dispose();
    _spo2CriticalCtrl.dispose();
    _tempLowCtrl.dispose();
    _tempHighCtrl.dispose();
    _tempCriticalCtrl.dispose();
    _hrLowCtrl.dispose();
    _hrLowCriticalCtrl.dispose();
    _hrHighCtrl.dispose();
    _hrCriticalCtrl.dispose();
    _rrLowCtrl.dispose();
    _rrHighCtrl.dispose();
    super.dispose();
  }

  void _syncScope({
    required Device? device,
    required DeviceThresholdsProvider provider,
  }) {
    final nextDeviceId = device?.resolvedDeviceId ?? '';
    final nextScopeKey = '${provider.isAuthenticated}::$nextDeviceId';
    if (_lastScopeKey == nextScopeKey) return;
    _lastScopeKey = nextScopeKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      provider.bindDevice(nextDeviceId);
      await provider.loadThresholds();
    });
  }

  void _hydrateForm(DeviceThresholds? thresholds, String? deviceId) {
    final nextFingerprint =
        '${deviceId ?? ''}::${thresholds?.toFingerprint() ?? ''}';
    if (_lastHydratedFingerprint == nextFingerprint) return;
    _lastHydratedFingerprint = nextFingerprint;

    _spo2LowCtrl.text = _formatValue(thresholds?.spo2Low);
    _spo2CriticalCtrl.text = _formatValue(thresholds?.spo2Critical);
    _tempLowCtrl.text = _formatValue(thresholds?.tempLow);
    _tempHighCtrl.text = _formatValue(thresholds?.tempHigh);
    _tempCriticalCtrl.text = _formatValue(thresholds?.tempCritical);
    _hrLowCtrl.text = _formatValue(thresholds?.hrLow);
    _hrLowCriticalCtrl.text = _formatValue(thresholds?.hrLowCritical);
    _hrHighCtrl.text = _formatValue(thresholds?.hrHigh);
    _hrCriticalCtrl.text = _formatValue(thresholds?.hrCritical);
    _rrLowCtrl.text = _formatValue(thresholds?.rrLow);
    _rrHighCtrl.text = _formatValue(thresholds?.rrHigh);
  }

  Future<void> _save(DeviceThresholdsProvider provider) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final next = DeviceThresholds(
      spo2Low: _parseRequiredNumber(_spo2LowCtrl.text),
      spo2Critical: _parseRequiredNumber(_spo2CriticalCtrl.text),
      tempLow: _parseRequiredNumber(_tempLowCtrl.text),
      tempHigh: _parseRequiredNumber(_tempHighCtrl.text),
      tempCritical: _parseRequiredNumber(_tempCriticalCtrl.text),
      hrLow: _parseRequiredNumber(_hrLowCtrl.text),
      hrLowCritical: _parseRequiredNumber(_hrLowCriticalCtrl.text),
      hrHigh: _parseRequiredNumber(_hrHighCtrl.text),
      hrCritical: _parseRequiredNumber(_hrCriticalCtrl.text),
      rrLow: _parseRequiredNumber(_rrLowCtrl.text),
      rrHigh: _parseRequiredNumber(_rrHighCtrl.text),
    );

    final ok = await provider.saveThresholds(next);
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Đã lưu ngưỡng cảnh báo cho thiết bị.'
              : (provider.error ?? 'Không thể lưu ngưỡng cảnh báo'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final thresholdsProvider = context.watch<DeviceThresholdsProvider>();
    final device = deviceProvider.current;

    _syncScope(device: device, provider: thresholdsProvider);
    _hydrateForm(thresholdsProvider.thresholds, device?.resolvedDeviceId);

    final canEdit = device?.isOwnerLink == true;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt ngưỡng cảnh báo')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device?.name ?? 'Chưa chọn thiết bị',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          device == null
                              ? 'Hãy chọn thiết bị trước khi chỉnh ngưỡng cảnh báo.'
                              : 'Mã thiết bị: ${device.resolvedDeviceId}',
                        ),
                        if (device != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            canEdit
                                ? 'Bạn đang là chủ thiết bị và có thể chỉnh sửa ngưỡng.'
                                : 'Thiết bị này đang ở chế độ chỉ xem. Chỉ chủ thiết bị mới được chỉnh ngưỡng.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (thresholdsProvider.error != null &&
                    thresholdsProvider.error!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InlineBanner(
                    message: thresholdsProvider.error!,
                    isError: true,
                  ),
                ],
                if (thresholdsProvider.infoMessage != null &&
                    thresholdsProvider.infoMessage!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _InlineBanner(
                    message: thresholdsProvider.infoMessage!,
                    isError: false,
                  ),
                ],
                if (!canEdit || device == null) ...[
                  const SizedBox(height: 12),
                  _InlineBanner(
                    message: device == null
                        ? 'Chưa có thiết bị hiện tại để cấu hình ngưỡng cảnh báo.'
                        : 'Chỉ chủ thiết bị mới có thể mở màn hình này.',
                    isError: false,
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  if (thresholdsProvider.isLoading &&
                      thresholdsProvider.thresholds == null)
                    const Center(child: CircularProgressIndicator())
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (thresholdsProvider.isLoading) ...[
                                const LinearProgressIndicator(),
                                const SizedBox(height: 16),
                              ],
                              Text(
                                'Nhập ngưỡng cảnh báo',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 16),
                              _ThresholdSection(
                                title: 'SpO2',
                                children: [
                                  _ThresholdField(
                                    controller: _spo2LowCtrl,
                                    label: 'SpO2 thấp',
                                    suffixText: '%',
                                    allowDecimal: false,
                                  ),
                                  _ThresholdField(
                                    controller: _spo2CriticalCtrl,
                                    label: 'SpO2 nguy kịch',
                                    suffixText: '%',
                                    allowDecimal: false,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _ThresholdSection(
                                title: 'Nhiệt độ',
                                children: [
                                  _ThresholdField(
                                    controller: _tempLowCtrl,
                                    label: 'Nhiệt độ thấp',
                                    suffixText: '°C',
                                    allowDecimal: true,
                                  ),
                                  _ThresholdField(
                                    controller: _tempHighCtrl,
                                    label: 'Nhiệt độ cao',
                                    suffixText: '°C',
                                    allowDecimal: true,
                                  ),
                                  _ThresholdField(
                                    controller: _tempCriticalCtrl,
                                    label: 'Nhiệt độ nguy kịch',
                                    suffixText: '°C',
                                    allowDecimal: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _ThresholdSection(
                                title: 'Nhịp tim',
                                children: [
                                  _ThresholdField(
                                    controller: _hrLowCtrl,
                                    label: 'Nhịp tim thấp',
                                    suffixText: 'bpm',
                                    allowDecimal: false,
                                  ),
                                  _ThresholdField(
                                    controller: _hrLowCriticalCtrl,
                                    label: 'Nhịp tim thấp nguy kịch',
                                    suffixText: 'bpm',
                                    allowDecimal: false,
                                  ),
                                  _ThresholdField(
                                    controller: _hrHighCtrl,
                                    label: 'Nhịp tim cao',
                                    suffixText: 'bpm',
                                    allowDecimal: false,
                                  ),
                                  _ThresholdField(
                                    controller: _hrCriticalCtrl,
                                    label: 'Nhịp tim nguy kịch',
                                    suffixText: 'bpm',
                                    allowDecimal: false,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _ThresholdSection(
                                title: 'Nhịp thở',
                                children: [
                                  _ThresholdField(
                                    controller: _rrLowCtrl,
                                    label: 'Nhịp thở thấp',
                                    suffixText: '/phút',
                                    allowDecimal: false,
                                  ),
                                  _ThresholdField(
                                    controller: _rrHighCtrl,
                                    label: 'Nhịp thở cao',
                                    suffixText: '/phút',
                                    allowDecimal: false,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: thresholdsProvider.isSaving
                                    ? null
                                    : () => _save(thresholdsProvider),
                                icon: thresholdsProvider.isSaving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  thresholdsProvider.isSaving
                                      ? 'Đang lưu...'
                                      : 'Lưu ngưỡng',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatValue(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  static double _parseRequiredNumber(String text) {
    return double.parse(text.trim().replaceAll(',', '.'));
  }
}

class _ThresholdSection extends StatelessWidget {
  const _ThresholdSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ...children.map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
        ),
      ],
    );
  }
}

class _ThresholdField extends StatelessWidget {
  const _ThresholdField({
    required this.controller,
    required this.label,
    required this.suffixText,
    required this.allowDecimal,
  });

  final TextEditingController controller;
  final String label;
  final String suffixText;
  final bool allowDecimal;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffixText),
      validator: (value) {
        final raw = value?.trim() ?? '';
        if (raw.isEmpty) return 'Nhập giá trị cho $label';

        final normalized = raw.replaceAll(',', '.');
        final parsed = double.tryParse(normalized);
        if (parsed == null) return 'Giá trị của $label phải là số';
        if (!allowDecimal && parsed != parsed.roundToDouble()) {
          return '$label phải là số nguyên';
        }
        return null;
      },
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = isError ? scheme.errorContainer : scheme.primaryContainer;
    final textColor = isError
        ? scheme.onErrorContainer
        : scheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: textColor),
      ),
    );
  }
}
