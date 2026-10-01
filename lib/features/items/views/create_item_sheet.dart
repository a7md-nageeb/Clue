import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/item_providers.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/custom_toast.dart';
import '../../../core/constants/icon_assets.dart';
import '../../settings/providers/settings_provider.dart';
import 'edit_item_screen.dart'; // reuse IconPickerSheet

// ---------------------------------------------------------------------------
// CreateItemSheet  (also used for editing when item != null)
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
class CreateItemSheet extends ConsumerStatefulWidget {
  /// Pass an existing [Item] to edit it; leave null to create a new one.
  final Item? item;

  /// Pre-fill content/title/icon when creating (item must be null).
  final String? initialContent;
  final String? initialTitle;
  final String? initialIcon;

  const CreateItemSheet({
    super.key,
    this.item,
    this.initialContent,
    this.initialTitle,
    this.initialIcon,
  });

  @override
  ConsumerState<CreateItemSheet> createState() => _CreateItemSheetState();
}

class _CreateItemSheetState extends ConsumerState<CreateItemSheet> {
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

  bool get _useLiveBlur => defaultTargetPlatform != TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.item?.content ?? widget.initialContent ?? '',
    );
    _titleController = TextEditingController(
      text: widget.item?.title ?? widget.initialTitle ?? '',
    );
    _titleFocusNode = FocusNode();
    _contentFocusNode = FocusNode()
      ..addListener(() {
        setState(() {});
      });
    _selectedIcon = widget.item?.icon ?? widget.initialIcon;
    _isPinned = widget.item?.isPinned ?? false;
    _showInMenuBar = widget.item?.showInMenuBar ?? true;

    // Show title row expanded when editing or when a pre-filled title exists
    final hasTitle = (_titleController.text).isNotEmpty;
    _showTitle = widget.item != null || hasTitle;
  }

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
      if (widget.item == null) {
        await ops.createItem(
          title: title,
          content: content,
          icon: _selectedIcon,
        );
      } else {
        await ops.updateItem(
          id: widget.item!.id,
          title: title,
          content: content,
          icon: _selectedIcon,
        );
      }
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
    FocusManager.instance.primaryFocus?.unfocus();
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

  Future<void> _togglePin() async {
    final item = widget.item;
    if (item == null) return;

    final nextValue = !_isPinned;
    setState(() => _isPinned = nextValue);

    try {
      await ref.read(itemOperationsProvider).togglePin(item.id);

      if (!mounted) return;
      CustomToast.show(
        context,
        nextValue ? 'Moved to top!' : 'Removed from top.',
        isSuccess: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isPinned = !nextValue);
        CustomToast.show(context, 'Failed to update pin: $e', isSuccess: false);
      }
    }
  }

  Future<void> _toggleMenuBarVisibility() async {
    final item = widget.item;
    if (item == null) return;

    final nextValue = !_showInMenuBar;
    setState(() => _showInMenuBar = nextValue);

    try {
      await ref
          .read(itemOperationsProvider)
          .setShowInMenuBar(item.id, nextValue);

      if (!mounted) return;
      CustomToast.show(
        context,
        nextValue ? 'Shown in menu bar' : 'Hidden from menu bar',
        isSuccess: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _showInMenuBar = !nextValue);
        CustomToast.show(
          context,
          'Failed to update menu bar visibility: $e',
          isSuccess: false,
        );
      }
    }
  }

  void _expandTitle() {
    setState(() => _showTitle = true);
    // Focus the title field after the next frame so it's in the tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocusNode.requestFocus();
    });
  }

  Widget _buildMoreButton(bool isDark) {
    if (widget.item == null) {
      return const SizedBox.shrink();
    }
    if (_isMoreMenuOpen) {
      return GestureDetector(
        key: _moreButtonKey,
        onTap: () => _showMoreMenu(context, isDark),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(200),
          child: _useLiveBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: _buildMoreButtonSurface(),
                )
              : _buildMoreButtonSurface(),
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

  Widget _buildMoreButtonSurface() {
    return Container(
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
        colorFilter: const ColorFilter.mode(AppTheme.ocean900, BlendMode.srcIn),
      ),
    );
  }

  Widget _maybeBlur(Widget child) {
    if (!_useLiveBlur) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: child,
    );
  }

  void _showMoreMenu(BuildContext context, bool isDark) {
    final RenderBox button =
        _moreButtonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = button.localToGlobal(Offset.zero);

    setState(() => _isMoreMenuOpen = true);

    Navigator.of(context)
        .push(
          PageRouteBuilder<void>(
            opaque: false,
            fullscreenDialog: true,
            barrierDismissible: true,
            barrierColor: Colors.transparent,
            pageBuilder: (context, _, __) {
              return Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: Colors.transparent),
                  ),
                  Positioned(
                    top: offset.dy + 52,
                    right: 20,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 176,
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
                          child: _maybeBlur(
                            Container(
                              decoration: BoxDecoration(
                                color: AppTheme.charcoal50.withValues(
                                  alpha: 0.8,
                                ),
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
                                children: [
                                  _buildMoreMenuItem(
                                    iconPath: IconAssets.getLinePath('send'),
                                    label: 'Share',
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      final title = _titleController.text
                                          .trim();
                                      final content = _contentController.text
                                          .trim();
                                      final shareText = [
                                        if (title.isNotEmpty) title,
                                        if (content.isNotEmpty) content,
                                      ].join('\n\n');

                                      if (shareText.isNotEmpty) {
                                        Share.share(shareText);
                                      } else {
                                        CustomToast.show(
                                          context,
                                          'Nothing to share!',
                                          isSuccess: false,
                                        );
                                      }
                                    },
                                  ),
                                  _buildMoreMenuItem(
                                    iconPath: IconAssets.getLinePath(
                                      _isPinned
                                          ? 'arrow-fromLine-down'
                                          : 'arrow-toLine-up',
                                    ),
                                    label: _isPinned
                                        ? 'Remove from Top'
                                        : 'Move to Top',
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _togglePin();
                                    },
                                  ),
                                  if (defaultTargetPlatform ==
                                      TargetPlatform.macOS)
                                    _buildMoreMenuItem(
                                      iconPath: IconAssets.getLinePath(
                                        _showInMenuBar ? 'eye-off' : 'eye',
                                      ),
                                      label: _showInMenuBar
                                          ? "Don't show in menu bar"
                                          : 'Show in menu bar',
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _toggleMenuBarVisibility();
                                      },
                                    ),
                                  _buildMoreMenuItem(
                                    iconPath: IconAssets.getLinePath('bin'),
                                    label: 'Delete',
                                    textColor: const Color(0xFF992929),
                                    iconColor: AppTheme.coral,
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      // Add confirm delete logic here if needed
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        )
        .whenComplete(() {
          if (mounted) setState(() => _isMoreMenuOpen = false);
        });
  }

  Widget _buildMoreMenuItem({
    required String iconPath,
    required String label,
    required VoidCallback onTap,
    Color textColor = AppTheme.ocean900,
    Color iconColor = AppTheme.ocean900,
  }) {
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
              SvgPicture(
                IconAssets.loader(iconPath),
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

  // ── Root build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fontSize = NoteTextSizes.scaledFrom(
      18,
      ref.watch(noteTextSizeIndexProvider),
    );

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
              Expanded(child: _buildTextArea(isDark, fontSize)),
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
              _buildSaveButton(isDark),
              if (widget.item != null) const SizedBox(width: 8),
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

  Widget _buildTextArea(bool isDark, double fontSize) {
    final isActive = _contentFocusNode.hasFocus;
    final style = GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
      height: NoteTextSizes.lineHeightRatio,
      letterSpacing: NoteTextSizes.letterSpacing,
      color: isDark ? Colors.white : AppTheme.ocean900,
    );
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
        boxShadow: isActive
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
      child: TextField(
        controller: _contentController,
        focusNode: _contentFocusNode,
        autofocus: defaultTargetPlatform != TargetPlatform.android,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: style,
        decoration: InputDecoration(
          hintText: 'Enter Text',
          hintStyle: style.copyWith(
            color: isDark ? Colors.white38 : const Color(0x590F2343),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: const EdgeInsets.all(12),
        ),
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
            child: _maybeBlur(
              Container(
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
                      SvgPicture(
                        IconAssets.loader(iconPath),
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
            child: _maybeBlur(
              Container(
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
                  child: SvgPicture(
                    IconAssets.loader(
                      _selectedIcon != null
                          ? IconAssets.getPath(iconName)
                          : IconAssets.getLinePath('star'),
                    ),
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
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 2, spreadRadius: 1),
        ],
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: _maybeBlur(
            Container(
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
