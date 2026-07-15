import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class FsCard extends StatelessWidget {
  const FsCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.accentColor,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final Color? accentColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppColors.cardShadow],
      ),
      child: accentColor != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 3, color: accentColor),
                    Expanded(child: Padding(padding: padding ?? const EdgeInsets.all(AppSpacing.cardPad), child: child)),
                  ],
                ),
              ),
            )
          : Padding(padding: padding ?? const EdgeInsets.all(AppSpacing.cardPad), child: child),
    );

    if (onTap == null) return inner;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(AppSpacing.radiusLg), child: inner),
    );
  }
}
