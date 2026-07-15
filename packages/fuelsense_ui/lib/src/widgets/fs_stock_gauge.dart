import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/fuel_utils.dart';
import 'fs_card.dart';

class FsStockGauge extends StatelessWidget {
  const FsStockGauge({
    super.key,
    required this.fuelType,
    required this.percentage,
    this.litres,
    this.compact = true,
  });

  final String fuelType;
  final double percentage;
  final String? litres;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.stockColor(percentage);
    final fuelAccent = AppColors.fuelColor(fuelType);

    return FsCard(
      accentColor: fuelAccent,
      padding: EdgeInsets.all(compact ? 12 : AppSpacing.cardPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: fuelAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(fuelIcon(fuelType), color: fuelAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fuelLabel(fuelType), style: theme.textTheme.titleMedium),
                    if (litres != null) Text('$litres L in tank', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0, 1),
              minHeight: compact ? 6 : 8,
              backgroundColor: AppColors.surfaceMuted,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
