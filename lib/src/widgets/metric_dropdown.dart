import 'package:flutter/material.dart';
import 'package:eldercare_app/src/core/constants.dart';
import 'package:eldercare_app/src/domain/models/metric.dart';

class MetricDropdown extends StatelessWidget {
  const MetricDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Metric value;
  final ValueChanged<Metric> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Metric>(
      isExpanded: true,
      initialValue: value,
      items: AppConstants.allMetrics
          .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
          .toList(),
      onChanged: (m) {
        if (m != null) onChanged(m);
      },
    );
  }
}
