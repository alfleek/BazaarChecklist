import 'package:flutter/material.dart';

/// Shared horizontal label + slider + value for win counts and similar controls.
class LabeledSliderRow extends StatelessWidget {
  const LabeledSliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    super.key,
    this.labelWidth = 72,
    this.valueWidth = 28,
  });

  final String label;
  final int value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final double labelWidth;
  final double valueWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            label: '$value',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: valueWidth,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
