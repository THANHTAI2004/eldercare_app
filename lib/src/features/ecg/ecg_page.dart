import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eldercare_app/src/domain/models/device.dart';
import 'package:eldercare_app/src/domain/models/ecg_reading.dart';
import 'package:eldercare_app/src/state/device_provider.dart';
import 'package:eldercare_app/src/state/ecg_provider.dart';
import 'package:eldercare_app/src/ui/app_spacing.dart';
import 'package:eldercare_app/src/ui/components/app_button.dart';
import 'package:eldercare_app/src/ui/components/app_card.dart';
import 'package:eldercare_app/src/ui/components/app_scaffold.dart';
import 'package:eldercare_app/src/ui/components/device_selector.dart';
import 'package:eldercare_app/src/ui/components/ecg_waveform_card.dart';
import 'package:eldercare_app/src/ui/components/empty_state.dart';
import 'package:eldercare_app/src/ui/components/loading_state.dart';
import 'package:eldercare_app/src/ui/components/section_header.dart';
import 'package:eldercare_app/src/ui/components/status_badge.dart';

class ECGPage extends StatefulWidget {
  const ECGPage({super.key});

  @override
  State<ECGPage> createState() => _ECGPageState();
}

class _ECGPageState extends State<ECGPage> {
  String? _lastScopeKey;

  void _syncScope() {
    final ecg = context.read<EcgProvider>();
    final device = context.read<DeviceProvider>().current;
    final nextScopeKey = '${ecg.deviceId}::${device?.resolvedDeviceId ?? ''}';
    if (_lastScopeKey == nextScopeKey) return;
    _lastScopeKey = nextScopeKey;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final today = _todayLocal();
      ecg.bindScope(deviceId: device?.resolvedDeviceId ?? '');
      await ecg.refreshLatest();
      await ecg.loadHistoryForDay(today);
    });
  }

  Future<void> _selectDevice(String? deviceId) async {
    final selectedId = deviceId?.trim() ?? '';
    if (selectedId.isEmpty) return;
    final deviceProvider = context.read<DeviceProvider>();
    final ecg = context.read<EcgProvider>();
    await deviceProvider.setCurrent(selectedId);
    final current = deviceProvider.current;
    if (!mounted || current == null) return;
    ecg.bindScope(deviceId: current.resolvedDeviceId);
    await ecg.refreshLatest();
    await ecg.loadHistoryForDay(_todayLocal());
  }

  Future<void> _refresh() async {
    final ecg = context.read<EcgProvider>();
    await ecg.refreshLatest();
    await ecg.loadHistoryForDay(_todayLocal());
  }

  Future<void> _requestEcg() async {
    final ecg = context.read<EcgProvider>();
    final ok = await ecg.requestMeasurement();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Đã gửi yêu cầu đo ECG tới thiết bị.'
              : (ecg.error ?? 'Không thể gửi yêu cầu đo ECG.'),
        ),
      ),
    );

    if (ok) {
      await ecg.refreshLatest(silent: true);
      await ecg.loadHistoryForDay(_todayLocal());
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final ecg = context.watch<EcgProvider>();
    final currentDevice = deviceProvider.current;
    final recentReadings = ecg.historyReadings.reversed.take(6).toList();
    final canRequestEcg = currentDevice?.isOwnerLink == true;

    _syncScope();

    return AppScaffold(
      title: 'Điện tâm đồ (ECG)',
      leading: Navigator.of(context).canPop()
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          : null,
      actions: [
        IconButton(
          onPressed: ecg.isLoading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (currentDevice != null)
              DeviceSelector(
                devices: deviceProvider.devices,
                currentDeviceId: currentDevice.id,
                onChanged: _selectDevice,
                isBusy: ecg.isLoadingHistory || ecg.isLoading,
              )
            else
              const EmptyState(
                icon: Icons.monitor_heart_outlined,
                title: 'Chưa có thiết bị theo dõi',
                message: 'Hãy chọn thiết bị để xem bản ghi ECG.',
              ),
            const SizedBox(height: AppSpacing.section),
            if (ecg.isLoading && ecg.latest == null)
              const LoadingState(message: 'Đang tải dữ liệu ECG...')
            else if (ecg.latest == null)
              const EmptyState(
                icon: Icons.monitor_heart_outlined,
                title: 'Chưa có bản ghi ECG',
                message:
                    'Thiết bị hiện tại chưa gửi bản ghi ECG có thể hiển thị trong ứng dụng.',
              )
            else ...[
              _LatestSummaryCard(reading: ecg.latest!),
              const SizedBox(height: AppSpacing.section),
              ECGWaveformCard(reading: ecg.latest!),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader(
                title: 'Lịch sử ECG hôm nay',
              ),
              const SizedBox(height: AppSpacing.lg),
              if (recentReadings.isEmpty)
                const EmptyState(
                  icon: Icons.history_toggle_off_rounded,
                  title: 'Chưa có lịch sử ECG',
                  message: 'Không có bản ghi ECG gần đây cho thiết bị này.',
                )
              else
                ...recentReadings.map(
                  (reading) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _ReadingListTile(reading: reading),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.section),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yêu cầu đo ECG',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _requestReason(currentDevice),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Yêu cầu đo ECG',
                      onPressed: canRequestEcg && !ecg.isRequesting
                          ? _requestEcg
                          : null,
                      isLoading: ecg.isRequesting,
                      icon: const Icon(Icons.send_outlined),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _requestReason(Device? device) {
    if (device == null) {
      return 'Chưa có thiết bị đang theo dõi để gửi yêu cầu đo ECG.';
    }
    if (!device.isOwnerLink) {
      return 'Bạn đang ở quyền người xem. Chỉ chủ thiết bị mới có thể gửi yêu cầu đo ECG.';
    }
    return 'Project hiện chưa có endpoint yêu cầu đo ECG, nên nút này được giữ ở trạng thái chờ triển khai backend.';
  }
}

class _LatestSummaryCard extends StatelessWidget {
  const _LatestSummaryCard({required this.reading});

  final EcgReading reading;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lần đo gần nhất',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatusBadge(
                label: reading.quality?.trim().isEmpty ?? true
                    ? 'Chất lượng chưa rõ'
                    : 'Chất lượng: ${reading.quality}',
                tone: (reading.quality ?? '').toLowerCase() == 'good'
                    ? StatusTone.success
                    : StatusTone.info,
              ),
              StatusBadge(
                label: reading.leadOff == true ? 'Lead off' : 'Lead off: Không',
                tone: reading.leadOff == true
                    ? StatusTone.warning
                    : StatusTone.success,
              ),
              StatusBadge(
                label: 'ECG HR: ${reading.ecgHr ?? '--'} bpm',
                tone: StatusTone.neutral,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadingListTile extends StatelessWidget {
  const _ReadingListTile({required this.reading});

  final EcgReading reading;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.monitor_heart_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${reading.ecgHr ?? '--'} bpm • ${reading.samplingRate ?? '--'} Hz',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  reading.recordedAt.toLocal().toString(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusBadge(
            label: reading.leadOff == true ? 'Lead off' : 'Tín hiệu ổn',
            tone: reading.leadOff == true
                ? StatusTone.warning
                : StatusTone.success,
          ),
        ],
      ),
    );
  }
}

DateTime _todayLocal() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
