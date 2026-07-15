import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FsLogo extends StatelessWidget {
  const FsLogo({super.key, this.size = 40, this.showText = true, this.light = false});

  final double size;
  final bool showText;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final textColor = light ? AppColors.textOnDark : AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: AppColors.amber500.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.bolt_rounded, color: AppColors.navy900, size: size * 0.55),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FuelSense',
                style: TextStyle(
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              Text(
                'SRI LANKA',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w600,
                  color: light ? AppColors.textOnDark.withValues(alpha: 0.6) : AppColors.textMuted,
                  letterSpacing: 2,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class FsLoadingScreen extends StatelessWidget {
  const FsLoadingScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FsLogo(size: 48, showText: true),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
