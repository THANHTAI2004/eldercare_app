import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:eldercare_app/src/domain/models/vital_point.dart';

class HealthCard extends StatelessWidget {
  const HealthCard({super.key, this.point});

  final VitalPoint? point;

  Color _alpha(Color color, double alpha) => color.withValues(alpha: alpha);

  Widget _prettyItem({
    required BuildContext context,
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isEmpty = value.trim().isEmpty || value.trim() == '--';

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_alpha(accent, 0.14), _alpha(accent, 0.06)],
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _alpha(accent, 0.22),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isEmpty ? '--' : value,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          unit,
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = point;
    final time = current?.time;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hr = current?.hr?.toString() ?? '--';
    final spo2 = current?.spo2?.toString() ?? '--';
    final temp = current?.temp == null ? '--' : current!.temp!.toStringAsFixed(1);
    final rr = current?.rr?.toString() ?? '--';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.health_and_safety_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Thông số sức khỏe',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _prettyItem(
                  context: context,
                  label: 'HR',
                  value: hr,
                  unit: 'bpm',
                  icon: Icons.favorite_rounded,
                  accent: const Color(0xFFFF4D6D),
                ),
                const SizedBox(width: 12),
                _prettyItem(
                  context: context,
                  label: 'SpO2',
                  value: spo2,
                  unit: '%',
                  icon: Icons.bloodtype_rounded,
                  accent: const Color(0xFF3B82F6),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _prettyItem(
                  context: context,
                  label: 'Nhiệt độ',
                  value: temp,
                  unit: '°C',
                  icon: Icons.thermostat_rounded,
                  accent: const Color(0xFFFFA726),
                ),
                const SizedBox(width: 12),
                _prettyItem(
                  context: context,
                  label: 'RR',
                  value: rr,
                  unit: 'rpm',
                  icon: Icons.air_rounded,
                  accent: const Color(0xFF8B5CF6),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                time == null
                    ? 'Chưa có dữ liệu'
                    : 'Cập nhật: ${DateFormat('HH:mm:ss dd/MM').format(time.toLocal())}',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
