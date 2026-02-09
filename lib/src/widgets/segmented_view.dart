import 'package:flutter/material.dart';

class SegmentedView extends StatelessWidget {
  const SegmentedView({
    super.key,
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(labels.length, (i) {
        final selected = i == index;
        return Padding(
          padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
          child: ChoiceChip(
            label: Text(labels[i]),
            selected: selected,
            onSelected: (_) => onChanged(i),
          ),
        );
      }),
    );
  }
}
