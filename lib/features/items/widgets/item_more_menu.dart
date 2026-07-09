import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/icon_assets.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_toast.dart';
import '../providers/item_providers.dart';

enum ItemMoreMenuPlacement {
  /// Anchors below a top-right control (e.g. the ⋮ button).
  belowTopRight,

  /// Anchors near a pointer / long-press location.
  atPointer,
}

Future<void> showItemMoreMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Item item,
  required bool isDark,
  required Offset globalAnchor,
  ItemMoreMenuPlacement placement = ItemMoreMenuPlacement.atPointer,
  String? titleOverride,
  String? contentOverride,
  VoidCallback? onDeleted,
  void Function(bool isPinned)? onPinnedChanged,
  void Function(bool showInMenuBar)? onMenuBarVisibilityChanged,
  VoidCallback? onMenuOpened,
  VoidCallback? onMenuClosed,
}) {
  onMenuOpened?.call();

  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      fullscreenDialog: true,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      pageBuilder: (context, _, __) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        const menuWidth = 224.0;

        final top = placement == ItemMoreMenuPlacement.belowTopRight
            ? globalAnchor.dy + 52
            : globalAnchor.dy + 8;

        Widget menu = Material(
          color: Colors.transparent,
          child: Container(
            width: menuWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 4,
                  spreadRadius: 2,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 2,
                  spreadRadius: 1,
                  offset: Offset.zero,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.charcoal50.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xF5FFFFFF),
                        blurRadius: 2,
                        offset: Offset(-1, -1),
                        blurStyle: BlurStyle.inner,
                      ),
                      BoxShadow(
                        color: Color(0xF5FFFFFF),
                        blurRadius: 2,
                        offset: Offset(1, 1),
                        blurStyle: BlurStyle.inner,
                      ),
                      BoxShadow(
                        color: Color(0xBFFFFFFF),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                        blurStyle: BlurStyle.inner,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _buildMenuItems(
                      context: context,
                      ref: ref,
                      item: item,
                      titleOverride: titleOverride,
                      contentOverride: contentOverride,
                      onDeleted: onDeleted,
                      onPinnedChanged: onPinnedChanged,
                      onMenuBarVisibilityChanged: onMenuBarVisibilityChanged,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        if (placement == ItemMoreMenuPlacement.belowTopRight) {
          menu = Positioned(top: top, right: 20, child: menu);
        } else {
          final left = (globalAnchor.dx - menuWidth / 2).clamp(
            16.0,
            screenWidth - menuWidth - 16,
          );
          menu = Positioned(top: top, left: left, child: menu);
        }

        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
            menu,
          ],
        );
      },
    ),
  ).whenComplete(onMenuClosed ?? () {});
}

List<Widget> _buildMenuItems({
  required BuildContext context,
  required WidgetRef ref,
  required Item item,
  String? titleOverride,
  String? contentOverride,
  VoidCallback? onDeleted,
  void Function(bool isPinned)? onPinnedChanged,
  void Function(bool showInMenuBar)? onMenuBarVisibilityChanged,
}) {
  final title = titleOverride ?? item.title;
  final content = contentOverride ?? item.content;

  return [
    _ItemMoreMenuItem(
      iconPath: IconAssets.getLinePath('send'),
      label: 'Share',
      onTap: () {
        Navigator.of(context).pop();
        final shareText = [
          if (title.trim().isNotEmpty) title.trim(),
          if (content.trim().isNotEmpty) content.trim(),
        ].join('\n\n');

        if (shareText.isNotEmpty) {
          Share.share(shareText);
        } else {
          CustomToast.show(context, 'Nothing to share!', isSuccess: false);
        }
      },
    ),
    _ItemMoreMenuItem(
      iconPath: IconAssets.getLinePath(
        item.isPinned ? 'arrow-fromLine-down' : 'arrow-toLine-up',
      ),
      label: item.isPinned ? 'Remove from Top' : 'Move to Top',
      onTap: () async {
        final hostContext = Navigator.of(context).context;
        Navigator.of(context).pop();
        final nextValue = !item.isPinned;
        onPinnedChanged?.call(nextValue);

        try {
          await ref.read(itemOperationsProvider).togglePin(item.id);
          if (!hostContext.mounted) return;
          CustomToast.show(
            hostContext,
            nextValue ? 'Moved to top!' : 'Removed from top.',
            isSuccess: true,
          );
        } catch (e) {
          onPinnedChanged?.call(item.isPinned);
          if (hostContext.mounted) {
            CustomToast.show(
              hostContext,
              'Failed to update pin: $e',
              isSuccess: false,
            );
          }
        }
      },
    ),
    if (defaultTargetPlatform == TargetPlatform.macOS)
      _ItemMoreMenuItem(
        iconPath: IconAssets.getLinePath(
          item.showInMenuBar ? 'eye-off' : 'eye',
        ),
        label: item.showInMenuBar
            ? "Don't show in menu bar"
            : 'Show in menu bar',
        onTap: () async {
          final hostContext = Navigator.of(context).context;
          Navigator.of(context).pop();
          final nextValue = !item.showInMenuBar;
          onMenuBarVisibilityChanged?.call(nextValue);

          try {
            await ref
                .read(itemOperationsProvider)
                .setShowInMenuBar(item.id, nextValue);
            if (!hostContext.mounted) return;
            CustomToast.show(
              hostContext,
              nextValue ? 'Shown in menu bar' : 'Hidden from menu bar',
              isSuccess: true,
            );
          } catch (e) {
            onMenuBarVisibilityChanged?.call(item.showInMenuBar);
            if (hostContext.mounted) {
              CustomToast.show(
                hostContext,
                'Failed to update menu bar visibility: $e',
                isSuccess: false,
              );
            }
          }
        },
      ),
    _ItemMoreMenuItem(
      iconPath: IconAssets.getLinePath('bin'),
      label: 'Delete',
      textColor: const Color(0xFF992929),
      iconColor: AppTheme.coral,
      onTap: () async {
        final hostContext = Navigator.of(context).context;
        Navigator.of(context).pop();
        final confirmed = await showDialog<bool>(
          context: hostContext,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Item'),
            content: Text(
              'Delete "${item.title.isNotEmpty ? item.title : item.content}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.deleteRed),
                ),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        try {
          await ref.read(itemOperationsProvider).deleteItem(item.id);
          if (hostContext.mounted) {
            CustomToast.show(hostContext, 'Item deleted', isSuccess: true);
          }
          onDeleted?.call();
        } catch (e) {
          if (hostContext.mounted) {
            CustomToast.show(
              hostContext,
              'Failed to delete item: $e',
              isSuccess: false,
            );
          }
        }
      },
    ),
  ];
}

class _ItemMoreMenuItem extends StatelessWidget {
  const _ItemMoreMenuItem({
    required this.iconPath,
    required this.label,
    required this.onTap,
    this.textColor = AppTheme.ocean900,
    this.iconColor = AppTheme.ocean900,
  });

  final String iconPath;
  final String label;
  final VoidCallback onTap;
  final Color textColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x0A0F2343))),
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                iconPath,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    height: 24 / 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool get itemMoreMenuUsesLongPress =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.android;

bool get itemMoreMenuUsesRightClick =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

Future<void> openItemMoreMenuFromItemRow({
  required BuildContext context,
  required WidgetRef ref,
  required Item item,
  required bool isDark,
  required Offset globalAnchor,
  VoidCallback? onDeleted,
}) async {
  await HapticFeedback.mediumImpact();
  if (!context.mounted) return;

  await showItemMoreMenu(
    context: context,
    ref: ref,
    item: item,
    isDark: isDark,
    globalAnchor: globalAnchor,
    placement: ItemMoreMenuPlacement.atPointer,
    onDeleted: onDeleted,
  );
}
