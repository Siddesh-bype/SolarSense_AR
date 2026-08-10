import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isFullWidth;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isFullWidth = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final button = onPressed == null
        ? null
        : () {
            FocusScope.of(context).unfocus();
            onPressed!();
          };
    final content = icon == null
        ? Text(text)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(text)],
          );
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(onPressed: button, child: content),
    );
  }
}