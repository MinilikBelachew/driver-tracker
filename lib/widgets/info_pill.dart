

import 'package:flutter/material.dart';



// Modern info pill
class InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(width: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

