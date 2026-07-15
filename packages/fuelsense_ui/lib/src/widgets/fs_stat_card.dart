import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'fs_card.dart';

/// CEP DashboardKpi pattern.
class FsStatCard extends StatelessWidget {
  const FsStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = 'ocean',
    this.iconColor,
    this.subtitle,
    this.trendText,
    this.trendUp,
  });

  final String label;
  final String value;
  final IconData icon;
  final String tone;
  final Color? iconColor;
  final String? subtitle;
  final String? trendText;
  final bool? trendUp;

  @override
  Widget build(BuildContext context) {
    final toneBg = iconColor != null ? iconColor!.withValues(alpha: 0.1) : AppColors.kpiToneBg(tone);
    final toneFg = iconColor ?? AppColors.kpiToneFg(tone);

    return FsCard(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: toneBg, borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            child: Icon(icon, size: 17, color: toneFg),
          ),
          const SizedBox(height: 12),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.ibmPlexMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.1,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (subtitle != null || trendText != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (trendText != null) ...[
                  Icon(
                    trendUp == true ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 12,
                    color: trendUp == true ? AppColors.successFg : AppColors.dangerFg,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    trendText!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: trendUp == true ? AppColors.successFg : AppColors.dangerFg,
                    ),
                  ),
                  if (subtitle != null) const SizedBox(width: 6),
                ],
                if (subtitle != null)
                  Expanded(
                    child: Text(subtitle!, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class FsPanel extends StatelessWidget {
  const FsPanel({super.key, required this.child, this.header});

  final Widget child;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppColors.cardShadow],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.borderFaint))),
              child: header,
            ),
          child,
        ],
      ),
    );
  }
}

/// CEP ChartPanel / TPanelHead — compact panel title row.
class FsPanelHeader extends StatelessWidget {
  const FsPanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
