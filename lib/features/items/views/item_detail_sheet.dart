import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/item_providers.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/custom_toast.dart';
import '../../../core/constants/icon_assets.dart';
import 'edit_item_screen.dart'; // reuse IconPickerSheet
import '../widgets/item_more_menu.dart';

// ---------------------------------------------------------------------------
// ItemDetailSheet  (also used for editing when item != null)
//
// Rendered via PageRouteBuilder(opaque: false) — home screen shows through.
// The expanding-from-FAB animation lives in home_screen.dart's transitionsBuilder.
//
// Figma node 3948-1719
//
// Bottom row behaviour:
//   • Collapsed (default for new items): [Add Icon chip] [Add Title chip]
//   • Expanded (tapping "Add Title" or when editing an existing item):
//       [48×48 icon button] [expanded title TextField]
//
// Title is always optional — omitting it saves with an empty title and the
// home screen falls back to showing the content text.
// ---------------------------------------------------------------------------
class ItemDetailSheet extends ConsumerStatefulWidget {
  /// Pass an existing [Item] to edit it; leave null to create a new one.
  final Item item;

  const ItemDetailSheet({super.key, required this.item});

  @override
  ConsumerState<ItemDetailSheet> createState() => _ItemDetailSheetState();
}

class _ItemDetailSheetState extends ConsumerState<ItemDetailSheet> {
  late final TextEditingController _contentController;
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _contentFocusNode;
  String? _selectedIcon;
  final GlobalKey _moreButtonKey = GlobalKey();
  bool _isMoreMenuOpen = false;
  late bool _isPinned;
  late bool _showInMenuBar;

  /// Whether the title row is expanded (icon button + TextField visible).
  /// Starts true when editing an existing item or when initialTitle is given.
  late bool _showTitle;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.item.content);
    _titleController = TextEditingController(text: widget.item.title);
    _titleFocusNode = FocusNode()
      ..addListener(() {
        setState(() {});
      });
    _contentFocusNode = FocusNode()
      ..addListener(() {
        setState(() {});
      });
    _titleController.addListener(() {
      setState(() {});
    });
    _contentController.addListener(() {
      setState(() {});
    });
    _selectedIcon = widget.item.icon;
    _isPinned = widget.item.isPinned;
    _showInMenuBar = widget.item.showInMenuBar;

    // Show title row expanded when editing or when a pre-filled title exists
    _showTitle = true;
  }

  bool get _isEditing =>
      _titleFocusNode.hasFocus ||
      _contentFocusNode.hasFocus ||
      _titleController.text != widget.item.title ||
      _contentController.text != widget.item.content ||
      _selectedIcon != widget.item.icon;

  @override
  void dispose() {
    _contentController.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return; // content is required

    final ops = ref.read(itemOperationsProvider);
    try {
      final title = _showTitle ? _titleController.text.trim() : '';
      await ops.updateItem(
        id: widget.item.id,
        title: title,
        content: content,
        icon: _selectedIcon,
      );
      if (mounted) {
        Navigator.of(context).pop();
        CustomToast.show(context, 'Saved!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Failed to save: $e', isSuccess: false);
      }
    }
  }

  Future<void> _openIconPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IconPickerSheet(),
    );
    if (selected != null && mounted) {
      setState(() => _selectedIcon = selected);
    }
  }

  void _expandTitle() {
    setState(() => _showTitle = true);
    // Focus the title field after the next frame so it's in the tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocusNode.requestFocus();
    });
  }

  // ── Root build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 24),
              _buildBottomRow(isDark),
              const SizedBox(height: 16),
              Expanded(child: _buildTextArea(isDark)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header: [X close]  ←spacer→  [✓ Save] ────────────────────────────────
  Widget _buildHeader(bool isDark) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildBackButton(isDark),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isEditing) _buildSaveButton(isDark),
              if (_isEditing) const SizedBox(width: 8),
              _buildMoreButton(isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return SecondaryButton(
      width: 48,
      height: 48,
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).pop(),
      child: SvgPicture.asset(
        IconAssets.getLinePath('arrow-left-alt2'),
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(
          isDark ? Colors.white : const Color(0xFF141414),
          BlendMode.srcIn,
        ),
      ),
    );
  }

  Widget _buildMoreButton(bool isDark) {
    if (_isMoreMenuOpen) {
      return GestureDetector(
        key: _moreButtonKey,
        onTap: () => _showMoreMenu(context, isDark),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(200),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.charcoal50.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(200),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x80FFFFFF),
                    blurRadius: 2,
                    offset: Offset(-1, -1),
                    blurStyle: BlurStyle.inner,
                  ),
                  BoxShadow(
                    color: Color(0x80FFFFFF),
                    blurRadius: 2,
                    offset: Offset(1, 1),
                    blurStyle: BlurStyle.inner,
                  ),
                  BoxShadow(
                    color: Color(0x0A1F1F1F),
                    blurRadius: 12,
                    offset: Offset(0, -4),
                    blurStyle: BlurStyle.inner,
                  ),
                  BoxShadow(
                    color: Color(0x291F1F1F),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                    blurStyle: BlurStyle.inner,
                  ),
                ],
              ),
              child: SvgPicture.asset(
                IconAssets.getLinePath('more-horizontal'),
                width: 24,
                height: 24,
                colorFilter: const ColorFilter.mode(
                  AppTheme.ocean900,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SecondaryButton(
      key: _moreButtonKey,
      width: 48,
      height: 48,
      padding: EdgeInsets.zero,
      onTap: () => _showMoreMenu(context, isDark),
      child: Center(
        child: SvgPicture.asset(
          IconAssets.getLinePath('more-horizontal'),
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            isDark ? Colors.white : const Color(0xFF141414),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  void _showMoreMenu(BuildContext context, bool isDark) {
    final RenderBox button =
        _moreButtonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = button.localToGlobal(Offset.zero);

    showItemMoreMenu(
      context: context,
      ref: ref,
      item: widget.item.copyWith(
        isPinned: _isPinned,
        showInMenuBar: _showInMenuBar,
      ),
      isDark: isDark,
      globalAnchor: offset,
      placement: ItemMoreMenuPlacement.belowTopRight,
      titleOverride: _titleController.text,
      contentOverride: _contentController.text,
      onDeleted: () => Navigator.of(context).pop(),
      onPinnedChanged: (value) => setState(() => _isPinned = value),
      onMenuBarVisibilityChanged: (value) =>
          setState(() => _showInMenuBar = value),
      onMenuOpened: () => setState(() => _isMoreMenuOpen = true),
      onMenuClosed: () {
        if (mounted) setState(() => _isMoreMenuOpen = false);
      },
    );
  }

  void _copyText() {
    final text = _contentController.text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      CustomToast.show(context, 'Copied to clipboard!', isSuccess: true);
    }
  }

  Widget _buildCopyButton(bool isDark) {
    if (!_isEditing) {
      return PrimaryButton(
        width: double.infinity,
        height: null,
        padding: const EdgeInsets.symmetric(vertical: 16),
        onTap: _copyText,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              IconAssets.getLinePath('copy'),
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppTheme.ocean50,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Copy Text',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.ocean50,
              ),
            ),
          ],
        ),
      );
    }

    return SecondaryButton(
      height: null,
      padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 16),
      onTap: _copyText,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            IconAssets.getLinePath('copy'),
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              isDark ? Colors.white : AppTheme.ocean900,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Copy Text',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 20 / 14,
              color: isDark ? Colors.white : AppTheme.ocean900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return PrimaryButton(
      width: 96,
      height: 48,
      padding: EdgeInsets.zero,
      onTap: _save,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            IconAssets.getLinePath('checkmark'),
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              AppTheme.ocean50,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Save',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF5F5F7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.96),
          width: 1,
        ),
        boxShadow: _contentFocusNode.hasFocus
            ? [
                const BoxShadow(
                  color: Color(0x0A000000),
                  offset: Offset(0, 4),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Color(0x0A000000),
                  offset: Offset.zero,
                  blurRadius: 2,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _contentController,
              focusNode: _contentFocusNode,
              autofocus: false,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white : AppTheme.ocean900,
              ),
              decoration: InputDecoration(
                hintText: 'Enter Text',
                hintStyle: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white38 : const Color(0x590F2343),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCopyButton(isDark),
        ],
      ),
    );
  }

  // ── Bottom row ────────────────────────────────────────────────────────────
  Widget _buildBottomRow(bool isDark) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      child: _showTitle
          ? KeyedSubtree(
              key: const ValueKey('expanded'),
              child: _buildExpandedRow(isDark),
            )
          : KeyedSubtree(
              key: const ValueKey('collapsed'),
              child: _buildCollapsedRow(isDark),
            ),
    );
  }

  // ── Collapsed: two 145.5-wide chips ──────────────────────────────────────
  Widget _buildCollapsedRow(bool isDark) {
    final bool hasIcon = _selectedIcon != null;
    final bool hasTitle = _titleController.text.isNotEmpty;
    return Row(
      children: [
        Expanded(
          child: _buildChip(
            isDark: isDark,
            iconPath: hasIcon
                ? IconAssets.getPath(_selectedIcon!)
                : IconAssets.getLinePath('star'),
            iconColor: hasIcon ? AppTheme.ocean900 : AppTheme.primaryOcean,
            label: hasIcon
                ? (_selectedIcon![0].toUpperCase() +
                      _selectedIcon!.substring(1))
                : 'Add Icon',
            onTap: _openIconPicker,
            showIcon: true,
            isFilled: hasIcon,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildChip(
            isDark: isDark,
            iconPath: null,
            iconColor: hasTitle ? AppTheme.ocean900 : AppTheme.primaryOcean,
            label: hasTitle ? _titleController.text : 'Add Title',
            onTap: _expandTitle,
            showIcon: false,
            isFilled: hasTitle,
          ),
        ),
      ],
    );
  }

  // Shared chip widget for the collapsed bottom row
  Widget _buildChip({
    required bool isDark,
    String? iconPath,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    bool showIcon = true,
    bool isFilled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isFilled
              ? const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset(0, 4),
                    blurRadius: 4,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Color(0x0A000000),
                    offset: Offset.zero,
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 2,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkCard
                      : (isFilled
                            ? const Color(0xCCFFFFFF)
                            : const Color(0xCCF5F5F7)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : (isFilled
                              ? const Color(0x1F141414)
                              : Colors.white.withValues(alpha: 0.96)),
                    width: 1,
                  ),
                  boxShadow: isFilled
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.white.withValues(
                              alpha: isDark ? 0.08 : 0.75,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                            blurStyle: BlurStyle.inner,
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (showIcon && iconPath != null)
                      SvgPicture.asset(
                        iconPath,
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          iconColor,
                          BlendMode.srcIn,
                        ),
                      ),
                    if (showIcon && iconPath != null && label.isNotEmpty)
                      const SizedBox(width: 8),
                    if (label.isNotEmpty)
                      Text(
                        label,
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Expanded: 48-wide icon button + full-width title field ────────────────
  Widget _buildExpandedRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildIconButton(isDark),
        const SizedBox(width: 12),
        Expanded(child: _buildTitleField(isDark)),
      ],
    );
  }

  // 48×48 glass square — tap to open icon picker
  Widget _buildIconButton(bool isDark) {
    final iconName = _selectedIcon ?? 'star';
    return GestureDetector(
      onTap: _openIconPicker,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          boxShadow: [
            BoxShadow(color: Color(0x0A000000), blurRadius: 2, spreadRadius: 1),
          ],
        ),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xCCFFFFFF),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.96),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: SvgPicture.asset(
                    _selectedIcon != null
                        ? IconAssets.getPath(iconName)
                        : IconAssets.getLinePath('star'),
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      AppTheme.primaryOcean,
                      BlendMode.srcIn,
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

  // Glass title input field (fills remaining width)
  Widget _buildTitleField(bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        boxShadow: _titleFocusNode.hasFocus
            ? const [
                BoxShadow(
                  color: Color(0x0A000000),
                  blurRadius: 2,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xCCFFFFFF),
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.96),
                  width: 1,
                ),
              ),
              child: Center(
                child: TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.ocean900,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter Title',
                    hintStyle: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white38 : const Color(0x590F2343),
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
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
