import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/icon_assets.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';

Future<bool> showDeleteItemSheet({
  required BuildContext context,
  required Item item,
}) async {
  final result = await Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      fullscreenDialog: true,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return DeleteItemSheet(
          item: item,
          animation: animation,
        );
      },
    ),
  );
  return result == true;
}

class DeleteItemSheet extends StatelessWidget {
  const DeleteItemSheet({
    super.key,
    required this.item,
    required this.animation,
  });

  final Item item;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final slide = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final hasTitle = item.title.trim().isNotEmpty;
    final previewText = hasTitle ? item.title.trim() : item.content.trim();

    return Semantics(
      namesRoute: true,
      label: 'Delete Item',
      child: Stack(
        children: [
          FadeTransition(
            opacity: animation,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              behavior: HitTestBehavior.opaque,
              child: const _Scrim(),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(slide),
              child: Material(
                color: Colors.transparent,
                child: _SheetSurface(
                  isDark: isDark,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    math.max(48, 16 + bottomInset),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TrashBadge(isDark: isDark),
                      const SizedBox(height: 12),
                      Text(
                        'Delete Item',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          height: 26 / 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.25,
                          color: isDark ? Colors.white : AppTheme.ocean900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Are you sure you want to delete this item?',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          height: 26 / 18,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.25,
                          color: isDark ? Colors.white : AppTheme.ocean900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _ItemPreviewCard(
                        isDark: isDark,
                        iconName: item.icon,
                        text: previewText,
                        isTitle: hasTitle,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              height: 48,
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              onTap: () => Navigator.of(context).pop(false),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  height: 24 / 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.ocean900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DangerButton(
                              height: 48,
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              onTap: () => Navigator.of(context).pop(true),
                              child: Text(
                                'Delete',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  height: 24 / 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.charcoal50,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    final overlay = ColoredBox(
      color: const Color(0x1F1A1A1A),
      child: const SizedBox.expand(),
    );

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      return overlay;
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
      child: overlay,
    );
  }
}

class _SheetSurface extends StatelessWidget {
  const _SheetSurface({
    required this.isDark,
    required this.padding,
    required this.child,
  });

  final bool isDark;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      width: double.infinity,
      padding: padding,
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
      child: child,
    );

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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

class _TrashBadge extends StatelessWidget {
  const _TrashBadge({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.coral.withValues(alpha: 0.16)
            : AppTheme.coral50,
        borderRadius: BorderRadius.circular(200),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.6),
            blurRadius: 2,
            offset: const Offset(-1, -1),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.6),
            blurRadius: 2,
            offset: const Offset(1, 1),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: SvgPicture.asset(
        IconAssets.getLinePath('bin'),
        width: 24,
        height: 24,
        colorFilter: const ColorFilter.mode(AppTheme.coral, BlendMode.srcIn),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(200)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(200),
        child: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? badge
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: badge,
              ),
      ),
    );
  }
}

class _ItemPreviewCard extends StatelessWidget {
  const _ItemPreviewCard({
    required this.isDark,
    required this.iconName,
    required this.text,
    required this.isTitle,
  });

  final bool isDark;
  final String? iconName;
  final String text;
  final bool isTitle;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0x66FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x1F141414),
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
      child: Row(
        children: [
          SvgPicture.asset(
            IconAssets.getPath(iconName ?? 'note'),
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              isDark ? Colors.white70 : AppTheme.primaryOcean,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text.isEmpty ? 'Untitled' : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 16,
                height: 24 / 16,
                fontWeight: isTitle ? FontWeight.w700 : FontWeight.w400,
                color: isDark ? Colors.white : AppTheme.ocean900,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
