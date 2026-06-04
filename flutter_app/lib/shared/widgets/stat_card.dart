import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;
  final IconData? icon;
  final Color? iconColor;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (icon != null)
                Icon(
                  icon,
                  size: 16,
                  color: iconColor ?? cs.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? cs.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
