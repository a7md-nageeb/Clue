import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
                        child: SvgPicture.asset(
                          IconAssets.getPath(_selectedIcon ?? 'note'),
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
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Watch all active items to extract unique list of used icons
    final allItems = ref.watch(activeItemsStreamProvider).value ?? [];
    final List<String> recentIcons = allItems
        .map((item) => item.icon)
        .whereType<String>()
        .toSet()
        .toList();

    // Filter icons by query
    Map<String, List<String>> filteredCategories = {};
    List<String> flatFilteredList = [];

    if (_searchQuery.isEmpty) {
      filteredCategories = IconAssets.categorizedIcons;
    } else {
      final query = _searchQuery.toLowerCase();
      IconAssets.categorizedIcons.forEach((category, icons) {
        final matches = icons
            .where((icon) => icon.toLowerCase().contains(query))
            .toList();
        if (matches.isNotEmpty) {
          filteredCategories[category] = matches;
          flatFilteredList.addAll(matches);
        }
      });
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
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
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: 16 + bottomInset,
          ),
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
              Row(
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
              const SizedBox(height: 12),
              // Search Field
              Container(
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
                                            IconAssets.getSolidPath('x-circle'),
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
              const SizedBox(height: 16),
              // Scrollable Categories or Search results
              Expanded(
                child: _searchQuery.isNotEmpty
                    ? (flatFilteredList.isEmpty
                          ? const Center(
                              child: Text('No icons match your search'),
                            )
                          : GridView.builder(
                              itemCount: flatFilteredList.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 6,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemBuilder: (context, index) {
                                final iconName = flatFilteredList[index];
                                return GestureDetector(
                                  onTap: () =>
                                      Navigator.of(context).pop(iconName),
                                  child: _buildIconTile(iconName, isDark),
                                );
                              },
                            ))
                    : ListView.builder(
                        itemCount:
                            filteredCategories.length +
                            (recentIcons.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (recentIcons.isNotEmpty && index == 0) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'RECENTLY USED',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.primaryOcean,
                                    ),
                                  ),
                                ),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: recentIcons.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 6,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                  itemBuilder: (context, iIndex) {
                                    final iconName = recentIcons[iIndex];
                                    return GestureDetector(
                                      onTap: () =>
                                          Navigator.of(context).pop(iconName),
                                      child: _buildIconTile(iconName, isDark),
                                    );
                                  },
                                ),
                              ],
                            );
                          }

                          final categoryIndex = recentIcons.isNotEmpty
                              ? index - 1
                              : index;
                          final categoryName = filteredCategories.keys
                              .elementAt(categoryIndex);
                          final icons = filteredCategories[categoryName]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  categoryName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primaryOcean,
                                  ),
                                ),
                              ),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: icons.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 6,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                    ),
                                itemBuilder: (context, iIndex) {
                                  final iconName = icons[iIndex];
                                  return GestureDetector(
                                    onTap: () =>
                                        Navigator.of(context).pop(iconName),
                                    child: _buildIconTile(iconName, isDark),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconTile(String iconName, bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(16)),
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
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0x1F141414),
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
            child: SvgPicture.asset(
              IconAssets.getPath(iconName),
              colorFilter: ColorFilter.mode(
                isDark ? Colors.white70 : AppTheme.primaryOcean,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
