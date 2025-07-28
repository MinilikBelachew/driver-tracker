


import 'package:flutter/material.dart';

import 'dart:ui'; // for ImageFilter


// Glassmorphism card
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withOpacity(0.40)
                : Colors.white.withOpacity(0.38),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.09)
                  : Colors.black.withOpacity(0.08),
              width: 1.1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}