import 'package:flutter/material.dart';

class AdaptiveMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;

  const AdaptiveMenuItem({
    super.key,
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = PopupMenuTheme.of(context).color ?? theme.cardColor;
    final foreground = background.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;

    return ListTile(
      leading: Icon(icon, color: foreground),
      title: Text(title, style: TextStyle(color: foreground)),
    );
  }
}
