import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrimaryButtonSurface extends StatelessWidget {
  const PrimaryButtonSurface({
    super.key,
    this.color,
    this.borderRadius = 200,
    this.blurBackground = true,
  });

  final Color? color;
  final double borderRadius;
  final bool blurBackground;

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? AppTheme.ocean300;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: buttonColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: CustomPaint(
        painter: _PrimaryButtonEffectPainter(),
        child: const SizedBox.expand(),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 2,
            spreadRadius: 1,
            offset: Offset.zero,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: !blurBackground ||
                defaultTargetPlatform == TargetPlatform.android
            ? surface
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: surface,
              ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final double? width;
  final double? height;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const PrimaryButton({
    super.key,
    required this.onTap,
    required this.child,
    this.width,
    this.height,
    this.color,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? AppTheme.ocean300;
    final buttonBody = SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(200),
        ),
        child: CustomPaint(
          painter: _PrimaryButtonEffectPainter(),
          child: Padding(
            padding: padding,
            child: Center(child: child),
          ),
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(200),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 2,
              spreadRadius: 1,
              offset: Offset.zero,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(200),
          child: defaultTargetPlatform == TargetPlatform.android
              ? buttonBody
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: buttonBody,
                ),
        ),
      ),
    );
  }
}

class _PrimaryButtonEffectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.shortestSide / 2);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [Color(0x14000000), Color(0x00000000)],
          stops: [0.0, 0.5],
        ).createShader(rect),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0x20FFFFFF), Color(0x00FFFFFF)],
          stops: [0.0, 0.42],
        ).createShader(rect),
    );

    final highlightPaint = Paint()
      ..color = const Color(0x66FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);

    canvas.drawRRect(rrect.shift(const Offset(-1, -1)), highlightPaint);
    canvas.drawRRect(rrect.shift(const Offset(1, 1)), highlightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DangerButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;

  const DangerButton({
    super.key,
    required this.onTap,
    required this.child,
    this.width,
    this.height = 48,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      onTap: onTap,
      width: width,
      height: height,
      color: AppTheme.coral, // Danger red color
      padding: padding,
      child: child,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  const SecondaryButton({
    super.key,
    required this.onTap,
    required this.child,
    this.width,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonBody = Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(200),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.96),
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              isDark ? AppTheme.darkCard : const Color(0xCCF5F5F7),
              Colors.white,
              isDark ? 0.08 : 0.6,
            )!,
            isDark ? AppTheme.darkCard : const Color(0xCCF5F5F7),
          ],
          stops: const [0.0, 0.3],
        ),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(200),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 2,
              spreadRadius: 1,
              offset: Offset.zero,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(200),
          child: defaultTargetPlatform == TargetPlatform.android
              ? buttonBody
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: buttonBody,
                ),
        ),
      ),
    );
  }
}
