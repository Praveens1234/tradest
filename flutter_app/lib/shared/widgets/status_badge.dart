import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status.toLowerCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: config.dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _displayLabel(status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: config.textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _displayLabel(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  _BadgeConfig _getConfig(String status) {
    switch (status) {
      case 'running':
        return _BadgeConfig(
          backgroundColor: const Color(0xFF1D4ED8).withAlpha(51),
          dotColor: const Color(0xFF3B82F6),
          textColor: const Color(0xFF93C5FD),
        );
      case 'done':
      case 'completed':
      case 'success':
        return _BadgeConfig(
          backgroundColor: const Color(0xFF166534).withAlpha(51),
          dotColor: const Color(0xFF22C55E),
          textColor: const Color(0xFF86EFAC),
        );
      case 'failed':
      case 'error':
        return _BadgeConfig(
          backgroundColor: const Color(0xFF991B1B).withAlpha(51),
          dotColor: const Color(0xFFEF4444),
          textColor: const Color(0xFFFCA5A5),
        );
      case 'cancelled':
      case 'canceled':
        return _BadgeConfig(
          backgroundColor: const Color(0xFF92400E).withAlpha(51),
          dotColor: const Color(0xFFF59E0B),
          textColor: const Color(0xFFFCD34D),
        );
      case 'pending':
      default:
        return _BadgeConfig(
          backgroundColor: const Color(0xFF374151),
          dotColor: const Color(0xFF9CA3AF),
          textColor: const Color(0xFFD1D5DB),
        );
    }
  }
}

class _BadgeConfig {
  final Color backgroundColor;
  final Color dotColor;
  final Color textColor;

  const _BadgeConfig({
    required this.backgroundColor,
    required this.dotColor,
    required this.textColor,
  });
}
