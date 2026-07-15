import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'fs_logo.dart';

class FsLoginBrandPanel extends StatelessWidget {
  const FsLoginBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.loginHeroGradient),
      child: Stack(
        children: [
          CustomPaint(painter: _GridPainter(), size: Size.infinite),
          Positioned(
            right: -70,
            top: -60,
            child: Opacity(
              opacity: 0.08,
              child: FsLogo(size: 420, showText: false, light: true),
            ),
          ),
          Positioned(
            left: 52,
            right: 52,
            bottom: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Real-time fuel visibility across Sri Lanka — stock, forecasts, and crisis-aware dispensing.',
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white, height: 1.4, letterSpacing: -0.2),
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _TrustPill(icon: Icons.shield_outlined, label: 'ML-powered forecasts'),
                    _TrustPill(icon: Icons.radar_rounded, label: 'Live stock WebSocket'),
                  ],
                ),
                const SizedBox(height: 36),
                const Row(
                  children: [
                    _Stat(value: '500+', label: 'stations tracked'),
                    SizedBox(width: 32),
                    _Stat(value: '72h', label: 'demand forecast'),
                    SizedBox(width: 32),
                    _Stat(value: '24/7', label: 'crisis mode ready'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustPill extends StatelessWidget {
  const _TrustPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const step = 46.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FsLoginLayout extends StatelessWidget {
  const FsLoginLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
    this.eyebrow,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 981;

    if (!wide) {
      return Scaffold(
        backgroundColor: AppColors.surfaceCard,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _FormColumn(title: title, subtitle: subtitle, eyebrow: eyebrow, form: form, footer: footer),
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FsLogo(size: 36, showText: true),
                    const Spacer(),
                    _FormColumn(title: title, subtitle: subtitle, eyebrow: eyebrow, form: form, footer: footer),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
          const Expanded(child: FsLoginBrandPanel()),
        ],
      ),
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({
    required this.title,
    required this.subtitle,
    required this.form,
    this.footer,
    this.eyebrow,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget? footer;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!.toUpperCase(),
              style: GoogleFonts.ibmPlexMono(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.4, height: 1.15),
          ),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted, fontSize: 14.5)),
          const SizedBox(height: 28),
          form,
          if (footer != null) ...[const SizedBox(height: 20), footer!],
        ],
      ),
    );
  }
}
