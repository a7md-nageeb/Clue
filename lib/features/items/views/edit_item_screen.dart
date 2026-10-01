import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/item_providers.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/widgets/custom_toast.dart';
import '../../../core/constants/icon_assets.dart';

class EditItemScreen extends ConsumerStatefulWidget {
  final Item? item;
  final String? initialTitle;
  final String? initialContent;
  final String? initialIcon;

  const EditItemScreen({
    super.key,
    this.item,
    this.initialTitle,
    this.initialContent,
    this.initialIcon,
  });

  @override
  ConsumerState<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends ConsumerState<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String? _selectedIcon;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.item?.title ?? widget.initialTitle ?? '',
    );
    _contentController = TextEditingController(
      text: widget.item?.content ?? widget.initialContent ?? '',
    );
    _selectedIcon = widget.item?.icon ?? widget.initialIcon ?? 'note';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final ops = ref.read(itemOperationsProvider);

    try {
      if (widget.item == null) {
        await ops.createItem(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          icon: _selectedIcon,
        );
        if (mounted) {
          CustomToast.show(
            context,
            'Saved item successfully!',
            isSuccess: true,
          );
        }
      } else {
        await ops.updateItem(
          id: widget.item!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          icon: _selectedIcon,
        );
        if (mounted) {
          CustomToast.show(
            context,
            'Updated item successfully!',
            isSuccess: true,
          );
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Failed to save item: $e', isSuccess: false);
      }
    }
  }

  void _openIconPicker() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const IconPickerSheet(),
    );
    if (selected != null) {
      setState(() {
        _selectedIcon = selected;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: 24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pull Bar indicator
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                widget.item == null ? 'Add Forgotten Thing' : 'Edit Thing',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.charcoal900,
                ),
              ),
              const SizedBox(height: 20),

              // Title Field
              TextFormField(
                controller: _titleController,
                autofocus:
                    widget.item ==
                    null, // Autofocus for fast saving under 3 seconds!
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g. WiFi Password, Room Number)',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Content Field
              TextFormField(
                controller: _contentController,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(
                  labelText: 'Content (e.g. B2-119, guest_5G, 1208)',
                  prefixIcon: Icon(Icons.vpn_key_rounded),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Content is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Icon Selector
              const Text(
                'Choose Icon',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _openIconPicker,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.08)
                          : Colors.black.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOcean.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: SvgPicture(
                          IconAssets.loader(
                            IconAssets.getPath(_selectedIcon ?? 'note'),
                          ),
                          colorFilter: const ColorFilter.mode(
                            AppTheme.primaryOcean,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedIcon != null
                                  ? _selectedIcon!
                                        .replaceAll('-', ' ')
                                        .toUpperCase()
                                  : 'NOTE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.charcoal900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap to select a custom icon',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      height: 54,
                      onTap: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.charcoal900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryButton(
                      height: 54,
                      onTap: _save,
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
    );
  }
}

class IconPickerSheet extends ConsumerStatefulWidget {
  const IconPickerSheet({super.key});

  @override
  ConsumerState<IconPickerSheet> createState() => IconPickerSheetState();
}

class IconPickerSheetState extends ConsumerState<IconPickerSheet> {
  static const _recentTab = 'Recently Used';
  static const _hPadding = EdgeInsets.symmetric(horizontal: 20);

  final _searchController = TextEditingController();
  final _pageController = PageController();
  final _tabKeys = <String, GlobalKey>{};
  String _searchQuery = '';
  String? _selectedTab;
  bool _hasSelected = false;

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final allItems = ref.watch(activeItemsStreamProvider).value ?? [];
    final List<String> recentIcons = allItems
        .map((item) => item.icon)
        .whereType<String>()
        .where(IconAssets.allIcons.contains)
        .toSet()
        .toList();

    final tabs = [
      if (recentIcons.isNotEmpty) _recentTab,
      ...IconAssets.categorizedIcons.keys,
    ];
    final activeTab = tabs.contains(_selectedTab) ? _selectedTab! : tabs.first;

    final query = _searchQuery.toLowerCase();
    final searchResults = query.isEmpty
        ? const <String>[]
        : IconAssets.allIcons
              .where((icon) => icon.toLowerCase().contains(query))
              .toList();

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.8,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 2,
            spreadRadius: 1,
            offset: Offset.zero,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        child: Container(
          padding: EdgeInsets.only(top: 16, bottom: 16 + bottomInset),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkSurface.withValues(alpha: 0.92)
                : AppTheme.charcoal50.withValues(alpha: 0.96),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.96),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.75),
                blurRadius: 8,
                offset: const Offset(0, 4),
                blurStyle: BlurStyle.inner,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.96),
                blurRadius: 2,
                offset: const Offset(1, 1),
                blurStyle: BlurStyle.inner,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.96),
                blurRadius: 2,
                offset: const Offset(-1, -1),
                blurStyle: BlurStyle.inner,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : AppTheme.ocean900.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Header Row
              Padding(
                padding: _hPadding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose Icon',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppTheme.charcoal900,
                      ),
                    ),
                    SecondaryButton(
                      width: 48,
                      height: 48,
                      padding: EdgeInsets.zero,
                      onTap: () => Navigator.of(context).pop(),
                      child: SvgPicture.asset(
                        IconAssets.getLinePath('x'),
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          isDark ? Colors.white : AppTheme.ocean900,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Search Field
              Padding(
                padding: _hPadding,
                child: Container(
                  height: 56,
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
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(200),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.96),
                          ),
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
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              IconAssets.getLinePath('search'),
                              width: 24,
                              height: 24,
                              colorFilter: ColorFilter.mode(
                                isDark ? Colors.white38 : AppTheme.charcoal500,
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val.trim();
                                  });
                                },
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.ocean900,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search 700+ icons...',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white38
                                        : AppTheme.charcoal500,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  suffixIconConstraints: const BoxConstraints(
                                    minWidth: 0,
                                    minHeight: 0,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            _searchController.clear();
                                            setState(() {
                                              _searchQuery = '';
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              left: 12,
                                              right: 2,
                                            ),
                                            child: SvgPicture.asset(
                                              IconAssets.getSolidPath(
                                                'x-circle',
                                              ),
                                              width: 20,
                                              height: 20,
                                              colorFilter: ColorFilter.mode(
                                                isDark
                                                    ? Colors.white38
                                                    : AppTheme.charcoal400,
                                                BlendMode.srcIn,
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_searchQuery.isEmpty) ...[
                _buildTabBar(tabs, activeTab, isDark),
                const SizedBox(height: 16),
              ],
              Expanded(
                // The PageView stays mounted during search so its page
                // stays in sync with the selected tab.
                child: IndexedStack(
                  index: _searchQuery.isEmpty ? 0 : 1,
                  sizing: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: tabs.length,
                      onPageChanged: (index) => _onTabChanged(tabs[index]),
                      itemBuilder: (context, index) {
                        final tab = tabs[index];
                        return _buildIconGrid(
                          tab == _recentTab
                              ? recentIcons
                              : IconAssets.categorizedIcons[tab]!,
                          isDark,
                        );
                      },
                    ),
                    if (_searchQuery.isEmpty)
                      const SizedBox.shrink()
                    else if (searchResults.isEmpty)
                      const Center(child: Text('No icons match your search'))
                    else
                      _buildIconGrid(searchResults, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _select(String iconName) {
    if (_hasSelected) return;
    _hasSelected = true;
    Navigator.of(context).pop(iconName);
  }

  void _onTabChanged(String tab) {
    if (tab == _selectedTab) return;
    setState(() => _selectedTab = tab);
    final chipContext = _tabKeys[tab]?.currentContext;
    if (chipContext != null) {
      Scrollable.ensureVisible(
        chipContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildTabBar(List<String> tabs, String activeTab, bool isDark) {
    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: _hPadding,
        child: Row(
          children: [
            for (final (index, tab) in tabs.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              _buildTabChip(tab, index, tab == activeTab, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String tab, int index, bool isActive, bool isDark) {
    return GestureDetector(
      key: _tabKeys.putIfAbsent(tab, GlobalKey.new),
      onTap: () {
        _onTabChanged(tab);
        _pageController.jumpToPage(index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryOcean
              : (isDark ? AppTheme.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(200),
          border: Border.all(
            color: isActive
                ? const Color(0x331A1A1A)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0x1F1A1A1A)),
          ),
        ),
        child: Text(
          tab,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white70 : AppTheme.charcoal900),
          ),
        ),
      ),
    );
  }

  Widget _buildIconGrid(List<String> icons, bool isDark) {
    return GridView.builder(
      padding: _hPadding.copyWith(bottom: MediaQuery.paddingOf(context).bottom),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: icons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final iconName = icons[index];
        return GestureDetector(
          onTap: () => _select(iconName),
          child: _buildIconTile(iconName, isDark),
        );
      },
    );
  }

  // Keep tiles flat: blurs or shadows here cause scroll jank with dozens of
  // tiles on screen, and Android can run out of GPU memory.
  Widget _buildIconTile(String iconName, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0x14141414),
        ),
      ),
      child: SvgPicture(
        IconAssets.loader(IconAssets.getPath(iconName)),
        colorFilter: ColorFilter.mode(
          isDark ? Colors.white70 : AppTheme.primaryOcean,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}
