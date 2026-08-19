import 'package:flutter/material.dart';
import 'package:kasir_dapur/core/constants/app_constants.dart';

class KdPinPad extends StatelessWidget {
  const KdPinPad({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.length = AppConstants.pinLength,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final int length;

  void _append(String digit) {
    if (!enabled || value.length >= length) {
      return;
    }
    onChanged('$value$digit');
  }

  void _backspace() {
    if (!enabled || value.isEmpty) {
      return;
    }
    onChanged(value.substring(0, value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List<Widget>.generate(length, (int index) {
            final bool filled = index < value.length;
            return Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? scheme.primary : scheme.surfaceContainerHighest,
                border: Border.all(color: scheme.outlineVariant),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        for (final List<String> row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'del'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((String key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 72, height: 72);
                }
                if (key == 'del') {
                  return _KeyButton(
                    onPressed: enabled ? _backspace : null,
                    child: const Icon(Icons.backspace_outlined),
                  );
                }
                return _KeyButton(
                  onPressed: enabled ? () => _append(key) : null,
                  child: Text(
                    key,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.child, this.onPressed});

  final Widget child;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: IconButton.filledTonal(onPressed: onPressed, icon: child),
    );
  }
}
