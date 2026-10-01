import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../../features/settings/providers/settings_provider.dart';

class CustomToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    Duration duration = const Duration(seconds: 2),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlayState = Overlay.of(context);
    var unblurEnabled = true;
    var fromBottom = true;
    var subtleMotion = true;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      unblurEnabled = container.read(toastUnblurEnabledProvider);
      fromBottom = container.read(toastFromBottomProvider);
      subtleMotion = container.read(toastSubtleMotionProvider);
    } catch (_) {}

    if (_current != null && _current!.mounted) {
      _current!.remove();
    }
    _current = null;

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        isSuccess: isSuccess,
        unblurEnabled: unblurEnabled,
        fromBottom: fromBottom,
        subtleMotion: subtleMotion,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismissed: () {
          if (_current == overlayEntry) {
            _current = null;
          }
          if (overlayEntry.mounted) {
            overlayEntry.remove();
          }
        },
        duration: duration,
      ),
    );

    _current = overlayEntry;
    overlayState.insert(overlayEntry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final bool unblurEnabled;
  final bool fromBottom;
  final bool subtleMotion;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;
  final Duration duration;

  const _ToastWidget({
    required this.message,
    required this.isSuccess,
    required this.unblurEnabled,
    required this.fromBottom,
    required this.subtleMotion,
    this.actionLabel,
    this.onAction,
    required this.onDismissed,
    required this.duration,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  static const _enterDuration = Duration(milliseconds: 560);
  static const _exitDuration = Duration(milliseconds: 280);
  static const _travel = 240.0;
  static const _maxBlur = 18.0;
  static const _enterCurve = Cubic(0.16, 1.05, 0.3, 1);

  static const _subtleEnterDuration = Duration(milliseconds: 350);
  static const _subtleExitDuration = Duration(milliseconds: 250);
  static const _subtleTravel = 16.0;
  static const _subtleMaxBlur = 2.0;
  static const _subtleStartScale = 0.97;
  static const _subtleCurve = Cubic(0.22, 1, 0.36, 1);

  static const _searchBarHeight = 64.0;
  static const _searchBarBottomGap = 20.0;
  static const _toastAboveBarGap = 12.0;
  static const _bottomClearance =
      _searchBarBottomGap + _searchBarHeight + _toastAboveBarGap;

  late final AnimationController _controller;
  late final Animation<double> _slide;
  late final Animation<double> _blur;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  Timer? _holdTimer;
  bool _started = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (widget.subtleMotion) {
      _initSubtleMotion();
    } else {
      _initClassicMotion();
    }
  }

  void _initSubtleMotion() {
    _controller = AnimationController(
      vsync: this,
      duration: _subtleEnterDuration,
      reverseDuration: _subtleExitDuration,
    );

    // Flipped on reverse so the exit also starts fast and eases out.
    final motion = CurvedAnimation(
      parent: _controller,
      curve: _subtleCurve,
      reverseCurve: _subtleCurve.flipped,
    );

    _slide = Tween<double>(
      begin: widget.fromBottom ? _subtleTravel : -_subtleTravel,
      end: 0,
    ).animate(motion);
    _blur = Tween<double>(
      begin: widget.unblurEnabled ? _subtleMaxBlur : 0,
      end: 0,
    ).animate(motion);
    _opacity = Tween<double>(begin: 0, end: 1).animate(motion);
    _scale = Tween<double>(begin: _subtleStartScale, end: 1).animate(motion);
  }

  void _initClassicMotion() {
    _scale = const AlwaysStoppedAnimation(1);
    _controller = AnimationController(
      vsync: this,
      duration: _enterDuration,
      reverseDuration: _exitDuration,
    );

    final motion = CurvedAnimation(
      parent: _controller,
      curve: _enterCurve,
      reverseCurve: Curves.easeInCubic,
    );

    _slide = Tween<double>(
      begin: widget.fromBottom ? _travel : -_travel,
      end: 0,
    ).animate(motion);
    _blur = Tween<double>(begin: widget.unblurEnabled ? _maxBlur : 0, end: 0)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.82, curve: _enterCurve),
            reverseCurve: const Interval(0.2, 1, curve: Curves.easeIn),
          ),
        );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.22, curve: Curves.easeOut),
        reverseCurve: const Interval(0.0, 0.55, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _scheduleDismiss();
      return;
    }

    _controller.forward();
    _scheduleDismiss();
  }

  void _scheduleDismiss() {
    _holdTimer?.cancel();
    _holdTimer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _holdTimer?.cancel();

    if (_controller.value == 0) {
      widget.onDismissed();
      return;
    }

    try {
      await _controller.reverse();
    } catch (_) {
      // The overlay may have been replaced while the exit ran.
    }
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    final padding = MediaQuery.paddingOf(context);
    final ime = MediaQuery.viewInsetsOf(context).bottom;
    final bottomOffset = ime > 0 ? ime + 12 : padding.bottom + _bottomClearance;

    return Positioned(
      top: widget.fromBottom ? null : padding.top + 16,
      bottom: widget.fromBottom ? bottomOffset : null,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: widget.actionLabel == null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final sigma = widget.unblurEnabled ? _blur.value : 0.0;
            Widget toast = child!;
            if (sigma > 0.05) {
              toast = ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: sigma,
                  sigmaY: sigma,
                  tileMode: TileMode.decal,
                ),
                child: toast,
              );
            }
            return Opacity(
              opacity: _opacity.value,
              child: Transform.translate(
                offset: Offset(0, _slide.value),
                child: Transform.scale(scale: _scale.value, child: toast),
              ),
            );
          },
          child: Align(
            heightFactor: 1,
            alignment: widget.fromBottom
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            child: RepaintBoundary(
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(200),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: CustomPaint(
                      foregroundPainter: const _ToastEffectPainter(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: isDark ? 0.52 : 0.4,
                          ),
                          borderRadius: BorderRadius.circular(200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 2,
                              spreadRadius: 1,
                              offset: Offset.zero,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.isSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              color: widget.isSuccess
                                  ? AppTheme.accentGreen
                                  : AppTheme.deleteRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                widget.message,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                  color: widget.isSuccess
                                      ? AppTheme.ocean900
                                      : AppTheme.deleteRed,
                                ),
                              ),
                            ),
                            if (widget.actionLabel != null) ...[
                              const SizedBox(width: 12),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  widget.onAction?.call();
                                  _dismiss();
                                },
                                child: Text(
                                  widget.actionLabel!,
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    height: 1.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryOcean,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastEffectPainter extends CustomPainter {
  const _ToastEffectPainter();

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
          colors: [Color(0xBFFFFFFF), Color(0x00FFFFFF)],
        ).createShader(rect),
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: [Color(0x14000000), Color(0x00000000)],
        ).createShader(rect),
    );

    final highlightPaint = Paint()
      ..color = const Color(0xF5FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    canvas.drawRRect(rrect.shift(const Offset(1, 1)), highlightPaint);
    canvas.drawRRect(rrect.shift(const Offset(-1, -1)), highlightPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
