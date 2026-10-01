import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

class NoteTextSizeSheet extends StatefulWidget {
  const NoteTextSizeSheet({
    super.key,
    required this.initialIndex,
    required this.onChanged,
  });

  final int initialIndex;
  final ValueChanged<int> onChanged;

  @override
  State<NoteTextSizeSheet> createState() => _NoteTextSizeSheetState();
}

class _NoteTextSizeSheetState extends State<NoteTextSizeSheet> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final sheet = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 28 + bottomInset),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppTheme.charcoal50.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.75),
            blurRadius: 8,
            offset: const Offset(0, 4),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.96),
            blurRadius: 2,
            offset: const Offset(1, 1),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.96),
            blurRadius: 2,
            offset: const Offset(-1, -1),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppTheme.charcoal200,
                borderRadius: BorderRadius.circular(200),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Text Size',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppTheme.charcoal400,
            ),
          ),
          const SizedBox(height: 12),
          NoteTextSizeControl(
            isDark: isDark,
            index: _index,
            onChanged: (value) {
              setState(() => _index = value);
              widget.onChanged(value);
            },
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Color(0x0A000000), blurRadius: 2, spreadRadius: 1),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? sheet
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: sheet,
                ),
        ),
      ),
    );
  }
}

class NoteTextSizeControl extends StatelessWidget {
  const NoteTextSizeControl({
    super.key,
    required this.isDark,
    required this.index,
    required this.onChanged,
    this.showBackground = true,
  });

  final bool isDark;
  final int index;
  final ValueChanged<int> onChanged;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        _SizeLetter(size: 14, isDark: isDark),
        const SizedBox(width: 12),
        Expanded(
          child: _DiscreteSlider(
            index: index,
            isDark: isDark,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 12),
        _SizeLetter(size: 22, isDark: isDark),
      ],
    );

    if (!showBackground) return content;

    final surface = Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.charcoal900.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.75),
            blurRadius: 8,
            offset: const Offset(0, 4),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.96),
            blurRadius: 2,
            offset: const Offset(1, 1),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.96),
            blurRadius: 2,
            offset: const Offset(-1, -1),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: content,
    );

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 2, spreadRadius: 1),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? surface
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: surface,
              ),
      ),
    );
  }
}

class _SizeLetter extends StatelessWidget {
  const _SizeLetter({required this.size, required this.isDark});

  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        'A',
        style: GoogleFonts.nunito(
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: 1,
          color: isDark
              ? Colors.white.withValues(alpha: 0.45)
              : AppTheme.charcoal400,
        ),
      ),
    );
  }
}

class _DiscreteSlider extends StatelessWidget {
  const _DiscreteSlider({
    required this.index,
    required this.isDark,
    required this.onChanged,
  });

  static const _thumbWidth = 32.0;
  static const _thumbHeight = 20.0;
  static const _trackHeight = 4.0;
  static const _height = 52.0;
  static const _tickGap = 6.0;
  static const _steps = 5;

  final int index;
  final bool isDark;
  final ValueChanged<int> onChanged;

  void _updateFromLocalX(double localX, double width) {
    final usable = (width - _thumbWidth).clamp(1.0, width);
    final t = ((localX - _thumbWidth / 2) / usable).clamp(0.0, 1.0);
    final next = (t * (_steps - 1)).round();
    if (next != index) {
      HapticFeedback.selectionClick();
      onChanged(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = isDark ? Colors.white : AppTheme.ocean900;
    final inactive = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : AppTheme.charcoal200;
    const labels = ['Smallest', 'Smaller', 'Default', 'Larger', 'Largest'];

    return Semantics(
      slider: true,
      value: labels[index],
      increasedValue: index < _steps - 1 ? labels[index + 1] : null,
      decreasedValue: index > 0 ? labels[index - 1] : null,
      onIncrease: index < _steps - 1 ? () => onChanged(index + 1) : null,
      onDecrease: index > 0 ? () => onChanged(index - 1) : null,
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final usable = width - _thumbWidth;
            final thumbCenter =
                _thumbWidth / 2 + (index / (_steps - 1)) * usable;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _updateFromLocalX(details.localPosition.dx, width),
              onHorizontalDragUpdate: (details) =>
                  _updateFromLocalX(details.localPosition.dx, width),
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top:
                        (_height - _thumbHeight - _tickGap) / 2 +
                        (_thumbHeight - _trackHeight) / 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(200),
                      child: SizedBox(
                        height: _trackHeight,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            ColoredBox(
                              color: inactive,
                              child: const SizedBox.expand(),
                            ),
                            FractionallySizedBox(
                              widthFactor: index / (_steps - 1),
                              child: ColoredBox(color: active),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (var i = 0; i < _steps; i++)
                    Positioned(
                      left: _thumbWidth / 2 + (i / (_steps - 1)) * usable - 2,
                      bottom: 2,
                      child: Container(
                        width: i == 2 ? 6 : 4,
                        height: i == 2 ? 6 : 4,
                        decoration: BoxDecoration(
                          color: i == 2
                              ? AppTheme.ocean300
                              : (isDark
                                    ? Colors.white.withValues(alpha: 0.28)
                                    : AppTheme.charcoal300),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    left: thumbCenter - _thumbWidth / 2,
                    top: (_height - _thumbHeight - _tickGap) / 2,
                    child: Container(
                      width: _thumbWidth,
                      height: _thumbHeight,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.charcoal50 : Colors.white,
                        borderRadius: BorderRadius.circular(200),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 2,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: Color(0x1A141414),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
