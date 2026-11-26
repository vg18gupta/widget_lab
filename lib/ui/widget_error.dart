import 'package:flutter/material.dart';
import 'package:widget_lab/theme/palette.dart';

/// Shown in place of any widget that failed. Replaces Flutter's default error box, so a
/// failure looks deliberate and stays inside the widget that caused it.
class WidgetErrorTile extends StatelessWidget {
  const WidgetErrorTile({super.key, required this.message, this.onRetry});

  /// A short description of the failure, first line only.
  final String message;
  /// Rebuilds the widget. Null where a retry makes no sense (for example, outside a card).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final firstLine = message.split('\n').first;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Palette.error, size: 18),
              const SizedBox(height: 4),
              const Text('Widget error',
                style: TextStyle(color: Palette.error, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(firstLine,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.textMuted, fontSize: 10)),
              if (onRetry != null)
                TextButton(onPressed: onRetry, child: const Text('Retry', style: TextStyle(fontSize: 11))),
            ],
          ),
        ),
      ),
    );
  }
}
