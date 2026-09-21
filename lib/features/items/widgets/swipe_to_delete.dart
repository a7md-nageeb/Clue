import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/icon_assets.dart';
import '../../../core/theme/app_theme.dart';

class SwipeToDelete extends StatefulWidget {
  const SwipeToDelete({
    super.key,
    required this.child,
    required this.onDelete,
    required this.isOpen,
    required this.onOpenChanged,
  });

  final Widget child;
  final VoidCallback onDelete;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;

  static const gap = 8.0;
  static const actionWidth = 72.0;
  static const extent = gap + actionWidth;

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete>
    with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 0.72,
    stiffness: 210,
    damping: 16,
  );

  late final AnimationController _progress;
  bool _hapticFired = false;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1.35,
      value: widget.isOpen ? 1 : 0,
    )..addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant SwipeToDelete oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen == oldWidget.isOpen) return;
    _snapTo(widget.isOpen ? 1 : 0);
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _snapTo(double target, {double velocity = 0}) {
    _progress.animateWith(
      SpringSimulation(_spring, _progress.value, target, velocity),
    );
  }

  void _onDragStart(DragStartDetails details) {
    _hapticFired = _progress.value >= 0.92;
    _progress.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final next = (_progress.value - details.delta.dx / SwipeToDelete.extent)
        .clamp(0.0, 1.22);
    _progress.value = next;
    if (!_hapticFired && next >= 0.92) {
      _hapticFired = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = -details.velocity.pixelsPerSecond.dx / SwipeToDelete.extent;
    final shouldOpen = _progress.value > 0.38 || velocity > 1.6;
    if (shouldOpen && !_hapticFired) {
      HapticFeedback.mediumImpact();
    }
    widget.onOpenChanged(shouldOpen);
    _snapTo(shouldOpen ? 1 : 0, velocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: _SwipeDeleteButton(
            onTap: () {
              HapticFeedback.mediumImpact();
              widget.onOpenChanged(false);
              widget.onDelete();
            },
          ),
        ),
        Transform.translate(
          offset: Offset(-SwipeToDelete.extent * _progress.value, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _SwipeDeleteButton extends StatelessWidget {
  const _SwipeDeleteButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(16));
    final surface = ColoredBox(
      color: AppTheme.coral,
      child: CustomPaint(
        painter: _DeleteButtonEffectPainter(),
        child: Center(
          child: SvgPicture.asset(
            IconAssets.getPath('bin'),
            width: 24,
            height: 24,
            fit: BoxFit.contain,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: SwipeToDelete.actionWidth,
        decoration: const BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 2,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? surface
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: surface,
                ),
        ),
      ),
    );
  }
}

class _DeleteButtonEffectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    canvas.save();
    canvas.clipRRect(rrect);

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [Color(0x14000000), Color(0x00000000)],
          stops: [0.0, 0.45],
        ).createShader(rect),
    );

    final edge = Paint()
      ..color = const Color(0x99FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);
    canvas.drawRRect(rrect.shift(const Offset(-1, -1)), edge);
    canvas.drawRRect(rrect.shift(const Offset(1, 1)), edge);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
