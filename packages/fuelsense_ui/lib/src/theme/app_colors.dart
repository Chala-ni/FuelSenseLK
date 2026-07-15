import 'package:flutter/material.dart';

/// CEP Capacity Tracker design tokens — semantic layer.
abstract final class AppColors {
  // Brand ocean blue
  static const ocean500 = Color(0xFF034AA4);
  static const ocean600 = Color(0xFF023C86);
  static const ocean700 = Color(0xFF02326F);
  static const ocean800 = Color(0xFF06294F);
  static const ocean50 = Color(0xFFEAF1FA);

  static const primary = ocean500;
  static const primaryHover = ocean600;
  static const primarySoft = Color(0xFFEAF1FB);
  static const onPrimarySoft = ocean700;

  static const teal500 = Color(0xFF06B6D4);
  static const teal300 = Color(0xFF67E8F9);

  // Surfaces (CEP semantic)
  static const surfaceLight = Color(0xFFF4F6FA); // bg-app
  static const surfaceCard = Color(0xFFFFFFFF); // bg-surface
  static const surfaceMuted = Color(0xFFF8FAFC); // bg-surface-2
  static const surfaceSunken = Color(0xFFEEF1F6);
  static const surfaceHover = Color(0xFFF1F4F9);
  static const surfaceSelected = Color(0xFFEAF1FB);
  static const sidebarBg = surfaceCard;

  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const borderFaint = Color(0xFFF1F5F9);

  // Text fg-1..4
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF64748B);
  static const textFaint = Color(0xFF94A3B8);
  static const textOnDark = Color(0xFFF8FAFC);

  // Semantic states
  static const success = Color(0xFF22A565);
  static const successSoft = Color(0xFFE8F6EF);
  static const successFg = Color(0xFF166534);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFEF4DE);
  static const warningFg = Color(0xFF92400E);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFCE8E8);
  static const dangerFg = Color(0xFF991B1B);
  static const info = ocean500;
  static const infoSoft = Color(0xFFE8F2FD);
  static const infoFg = Color(0xFF1E3FA0);

  // Legacy aliases (mobile / fuel accents)
  static const navy800 = Color(0xFF111827);
  static const navy900 = Color(0xFF0B1220);
  static const amber500 = Color(0xFFF59E0B);
  static const amber400 = Color(0xFFFBBF24);
  static const amber600 = Color(0xFFD97706);
  static const teal400 = Color(0xFF2DD4BF);

  static const petrol92 = Color(0xFF3B82F6);
  static const petrol95 = Color(0xFF8B5CF6);
  static const diesel = teal500;
  static const superDiesel = Color(0xFF6366F1);

  static Color fuelColor(String code) => switch (code) {
        'petrol_92' => petrol92,
        'petrol_95' => petrol95,
        'auto_diesel' => diesel,
        'super_diesel' => superDiesel,
        _ => textSecondary,
      };

  static Color stockColor(double? pct) {
    if (pct == null) return textFaint;
    if (pct <= 0) return danger;
    if (pct < 20) return danger;
    if (pct < 50) return warning;
    return success;
  }

  static Color riskColor(String tier) => switch (tier.toLowerCase()) {
        'red' || 'critical' || 'high' => danger,
        'amber' || 'medium' || 'moderate' => warning,
        'green' || 'low' => success,
        'inactive' => textFaint,
        _ => textMuted,
      };

  static Color kpiToneBg(String tone) => switch (tone) {
        'success' => successSoft,
        'warning' => warningSoft,
        'danger' => dangerSoft,
        'teal' => Color(0xFFECFEFF),
        'ocean' || _ => primarySoft,
      };

  static Color kpiToneFg(String tone) => switch (tone) {
        'success' => successFg,
        'warning' => warningFg,
        'danger' => dangerFg,
        'teal' => Color(0xFF0E7490),
        'ocean' || _ => primary,
      };

  static const cardShadow = BoxShadow(
    color: Color(0x0F152F59),
    blurRadius: 3,
    offset: Offset(0, 1),
  );

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A3170), Color(0xFF06214C), Color(0xFF04152E)],
  );

  static const loginHeroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF0A3170), Color(0xFF06214C), Color(0xFF04152E)],
  );

  static const accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [amber500, amber600],
  );
}
