import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/item_providers.dart';
import '../../../core/database/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/custom_toast.dart';
import '../../../core/widgets/logo_widget.dart';
import '../../../core/widgets/app_buttons.dart';
import '../../../core/constants/icon_assets.dart';
import 'create_item_sheet.dart';
import 'item_detail_sheet.dart';
import '../widgets/item_more_menu.dart';
import '../../../core/sync/sync_service.dart';
import '../../settings/views/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _fabKey = GlobalKey();
  String? _selectedCategory;
  bool _isTagsScrolled = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(searchQueryProvider.notifier).state = _searchController.text;
    });
    _searchFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showSharedLinkSheet(String link) {
    ref.read(pendingSharedLinkProvider.notifier).state = null;

    String defaultTitle = 'Shared Link';
    try {
      final uri = Uri.parse(link.trim());
      if (uri.hasScheme && uri.host.isNotEmpty) {
        defaultTitle = uri.host;
      }
    } catch (_) {}

    HapticFeedback.heavyImpact();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateItemSheet(
          initialContent: link,
          initialTitle: defaultTitle,
          initialIcon: 'note',
        ),
      ),
    );
  }

  // Opens the item detail / edit sheet for an existing item.
  // Uses the same slide-up + blur transition as _showEditSheet.
  void _showDetailSheet(BuildContext context, Item item) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ItemDetailSheet(item: item)));
  }

  // Expanding create animation: scale panel from FAB centre outward.
  void _showExpandingCreate(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateItemSheet()));
  }

  Future<void> _copyContent(BuildContext context, Item item) async {
    await Clipboard.setData(ClipboardData(text: item.content));
    await HapticFeedback.mediumImpact();
    if (context.mounted) {
      CustomToast.show(
        context,
        'Copied: ${item.content.length > 25 ? "${item.content.substring(0, 25)}..." : item.content}',
        isSuccess: true,
      );
    }
  }

  // Figma: icon fill = rgba(102,157,242) = primaryOcean
  Widget _buildItemIcon(String? iconName, {Color? color, double size = 26}) {
    final assetPath = IconAssets.getPath(iconName ?? 'note');
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(
        color ?? AppTheme.primaryOcean,
        BlendMode.srcIn,
      ),
    );
  }

  Future<void> _refreshItems() async {
    await Future.wait([
      ref.read(syncServiceProvider).sync(),
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingSharedLinkProvider, (previous, next) {
      if (next != null) {
        _showSharedLinkSheet(next);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pendingLink = ref.read(pendingSharedLinkProvider);
      if (pendingLink != null) {
        _showSharedLinkSheet(pendingLink);
      }
    });

    final filteredItemsAsync = ref.watch(filteredItemsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isSearchActive = _searchFocusNode.hasFocus;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        children: [
          // ─── 1. Scrollable content ────────────────────────────────────────
          Positioned.fill(
            child: filteredItemsAsync.when(
              data: (items) {
                final allItems =
                    ref.watch(activeItemsStreamProvider).value ?? [];

                final Map<String, int> iconCounts = {};
                for (var item in allItems) {
                  final icon = item.icon ?? 'note';
                  iconCounts[icon] = (iconCounts[icon] ?? 0) + 1;
                }

                if (_selectedCategory != null &&
                    !iconCounts.containsKey(_selectedCategory!)) {
                  _selectedCategory = null;
                }

                final itemsToShow = _selectedCategory == null
                    ? items
                    : items
                          .where(
                            (item) =>
                                (item.icon ?? 'note') == _selectedCategory,
                          )
                          .toList();

                final bool isApple =
                    defaultTargetPlatform == TargetPlatform.iOS ||
                    defaultTargetPlatform == TargetPlatform.macOS;

                Widget scrollView = CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    if (isApple)
                      CupertinoSliverRefreshControl(
                        refreshTriggerPullDistance: topPadding + 124.0,
                        refreshIndicatorExtent: topPadding + 96.0,
                        builder:
                            (
                              context,
                              refreshState,
                              pulledExtent,
                              refreshTriggerPullDistance,
                              refreshIndicatorExtent,
                            ) {
                              final progress =
                                  (pulledExtent / refreshTriggerPullDistance)
                                      .clamp(0.0, 1.0)
                                      .toDouble();
                              final isRefreshing =
                                  refreshState == RefreshIndicatorMode.armed ||
                                  refreshState == RefreshIndicatorMode.refresh;

                              return SizedBox(
                                height: refreshIndicatorExtent,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      bottom: defaultTargetPlatform ==
                                              TargetPlatform.macOS
                                          ? 24
                                          : 16,
                                    ),
                                    child: Opacity(
                                      opacity: isRefreshing ? 1.0 : progress,
                                      child: CupertinoActivityIndicator(
                                        radius: 10 + (2 * progress),
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.ocean500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                        onRefresh: _refreshItems,
                      ),
                    // ─── Top Nav (Dynamic Sticky Header) ───
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TopNavDelegate(
                        topPadding: topPadding,
                        isDark: isDark,
                        hasTags: allItems.isNotEmpty,
                        selectedCategory: _selectedCategory,
                        totalItemsCount: allItems.length,
                        logoRow: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const ForgottenThingsLogo(
                              assetPath: 'assets/clue_logo.svg',
                              height: 48,
                            ),
                            SecondaryButton(
                              width: 48,
                              height: 48,
                              padding: EdgeInsets.zero,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                              child: SvgPicture.asset(
                                IconAssets.getLinePath('gear'),
                                width: 24,
                                height: 24,
                                colorFilter: ColorFilter.mode(
                                  isDark ? Colors.white : AppTheme.charcoal900,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ],
                        ),
                        tagsRow: allItems.isEmpty
                            ? const SizedBox.shrink()
                            : SizedBox(
                                height: 32, // Figma: chip height = 32
                                child: Row(
                                  children: [
                                    // Sticky "All" Tag Chip
                                    Padding(
                                      padding: const EdgeInsets.only(left: 20),
                                      child: _buildTagChip(
                                        context,
                                        isActive: _selectedCategory == null,
                                        isDark: isDark,
                                        onTap: () => setState(
                                          () => _selectedCategory = null,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'All',
                                              style: GoogleFonts.nunito(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: _selectedCategory == null
                                                    ? Colors.white
                                                    : (isDark
                                                          ? Colors.white70
                                                          : AppTheme
                                                                .charcoal900),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${allItems.length}',
                                              style: GoogleFonts.nunito(
                                                fontWeight: FontWeight.w400,
                                                fontSize: 16,
                                                color: _selectedCategory == null
                                                    ? AppTheme.ocean100
                                                    : (isDark
                                                          ? Colors.white38
                                                          : AppTheme
                                                                .charcoal600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Sticky Vertical Separator (1A1A1A @ 12%)
                                    Container(
                                      width: 1,
                                      height: 22,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : const Color(
                                              0x1F1A1A1A,
                                            ), // 1A1A1A at 12% opacity
                                    ),

                                    // Horizontally Scrollable Category Tags
                                    Expanded(
                                      child: ShaderMask(
                                        shaderCallback: (Rect bounds) {
                                          return LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: _isTagsScrolled
                                                ? const <Color>[
                                                    Colors.transparent,
                                                    Colors.white,
                                                  ]
                                                : const <Color>[
                                                    Colors.white,
                                                    Colors.white,
                                                  ],
                                            stops: [
                                              0.0,
                                              24.0 / bounds.width,
                                            ], // 24px fade on the left
                                          ).createShader(bounds);
                                        },
                                        blendMode: BlendMode.dstIn,
                                        child: NotificationListener<ScrollNotification>(
                                          onNotification: (notification) {
                                            final isScrolled =
                                                notification.metrics.pixels > 0;
                                            if (_isTagsScrolled != isScrolled) {
                                              Future.microtask(() {
                                                if (mounted) {
                                                  setState(
                                                    () => _isTagsScrolled =
                                                        isScrolled,
                                                  );
                                                }
                                              });
                                            }
                                            return false;
                                          },
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.only(
                                              right: 20,
                                            ),
                                            child: Row(
                                              children: iconCounts.keys.toList().asMap().entries.map((
                                                entry,
                                              ) {
                                                final index = entry.key;
                                                final iconName = entry.value;
                                                final count =
                                                    iconCounts[iconName]!;
                                                final isTagActive =
                                                    _selectedCategory ==
                                                    iconName;

                                                return Padding(
                                                  padding: EdgeInsets.only(
                                                    left: index == 0 ? 0 : 8,
                                                  ),
                                                  child: _buildTagChip(
                                                    context,
                                                    isActive: isTagActive,
                                                    isDark: isDark,
                                                    onTap: () => setState(() {
                                                      _selectedCategory =
                                                          isTagActive
                                                          ? null
                                                          : iconName;
                                                    }),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        _buildItemIcon(
                                                          iconName,
                                                          size: 20,
                                                          color: isTagActive
                                                              ? Colors.white
                                                              : (isDark
                                                                    ? Colors
                                                                          .white70
                                                                    : AppTheme
                                                                          .charcoal900),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          '$count',
                                                          style: GoogleFonts.nunito(
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            fontSize: 16,
                                                            color: isTagActive
                                                                ? AppTheme
                                                                      .ocean100
                                                                : (isDark
                                                                      ? Colors
                                                                            .white38
                                                                      : AppTheme
                                                                            .charcoal600),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),

                    // Items list — Figma: itemSpacing=12
                    itemsToShow.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: _buildEmptyState(
                              context,
                              verticalOffset:
                                  -((topPadding + 104) +
                                      (bottomPadding + 120)) /
                                  2,
                            ),
                          )
                        : SliverPadding(
                            padding: EdgeInsets.only(
                              left: 20,
                              right: 20,
                              bottom: bottomPadding + 120,
                            ),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildItemCard(
                                  context,
                                  itemsToShow[index],
                                  isDark,
                                ),
                                childCount: itemsToShow.length,
                              ),
                            ),
                          ),
                  ],
                );

                if (!isApple) {
                  return RefreshIndicator(
                    color: AppTheme.primaryOcean,
                    displacement: topPadding + 48,
                    onRefresh: _refreshItems,
                    child: scrollView,
                  );
                }

                return scrollView;
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),

          // ─── 3. Floating Bottom Action Bar ───────────────────────────────
          // Figma: Frame 114  375×132, BACKGROUND_BLUR=20,
          //        paddingL/R=20, paddingT=24, paddingB=44, itemSpacing=16
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Stack(
              children: [
                // 1. Progressive Blur Background (Optimized for performance)
                Positioned.fill(
                  child: Stack(
                    children: [
                      // Progressive blur using ShaderMask
                      if (!isAndroid)
                        ClipRect(
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                isDark ? Colors.black : Colors.white,
                              ],
                              stops: const [0.0, 0.5],
                            ).createShader(bounds),
                            blendMode: BlendMode.dstIn,
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                color: isDark
                                    ? Colors.black.withValues(alpha: 0.0)
                                    : Colors.white.withValues(alpha: 0.0),
                              ),
                            ),
                          ),
                        ),
                      // Optional: add a subtle gradient to simulate the surface fade-in
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isAndroid
                                ? [
                                    isDark
                                        ? AppTheme.darkSurface.withValues(
                                            alpha: 0.18,
                                          )
                                        : Colors.white.withValues(alpha: 0.18),
                                    isDark
                                        ? AppTheme.darkSurface.withValues(
                                            alpha: 0.82,
                                          )
                                        : const Color(
                                            0xFFF5F5F7,
                                          ).withValues(alpha: 0.86),
                                    isDark
                                        ? AppTheme.darkSurface.withValues(
                                            alpha: 0.96,
                                          )
                                        : Colors.white.withValues(alpha: 0.96),
                                    isDark
                                        ? AppTheme.darkSurface
                                        : Colors.white,
                                  ]
                                : [
                                    isDark
                                        ? Colors.black.withValues(alpha: 0.0)
                                        : Colors.white.withValues(alpha: 0.0),
                                    isDark
                                        ? Colors.black.withValues(alpha: 0.9)
                                        : Colors.white.withValues(alpha: 0.95),
                                  ],
                            stops: isAndroid
                                ? const [0.0, 0.28, 0.72, 1.0]
                                : const [0.0, 0.7],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 2. Content
                Container(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 24,
                    // Figma paddingBottom=44 accounts for ~20px safe area.
                    // On real devices safe area is larger, so: bottomPadding + 20
                    bottom: bottomPadding + 20,
                  ),
                  child: Row(
                    children: [
                      // ── Search bar ───────────────────────────────────────
                      // Figma: 255×64, cornerRadius=200,
                      //   FILL  rgba(245,245,247,0.8)
                      //   DROP_SHADOW  rgba(0,0,0,0.04) offset=(0,0) blur=2 spread=1
                      //   DROP_SHADOW  rgba(0,0,0,0.04) offset=(0,4) blur=12 spread=2
                      //   INNER_SHADOW rgba(255,255,255,0.96/0.75)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _searchFocusNode.requestFocus(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            height: 64,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(200),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 2,
                                  spreadRadius: 1,
                                  offset: Offset.zero,
                                ),
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: RepaintBoundary(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(200),
                                child: isAndroid
                                    ? _buildSearchSurface(
                                        isDark: isDark,
                                        isSearchActive: isSearchActive,
                                      )
                                    : BackdropFilter(
                                        filter: ImageFilter.blur(
                                          sigmaX: 8,
                                          sigmaY: 8,
                                        ),
                                        child: _buildSearchSurface(
                                          isDark: isDark,
                                          isSearchActive: isSearchActive,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16), // Figma: itemSpacing=16
                      // ── FAB ──────────────────────────────────────────────
                      PrimaryButton(
                        key: _fabKey,
                        width: 64,
                        height: 64,
                        padding: EdgeInsets.zero,
                        onTap: () => _showExpandingCreate(context),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required double verticalOffset,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Transform.translate(
        offset: Offset(0, verticalOffset),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                'assets/empty_note_blue.svg',
                width: 64,
                height: 72,
              ),
              const SizedBox(height: 16),
              Text(
                'Nothing is here',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.ocean900,
                  letterSpacing: -0.045,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add your first note',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? Colors.white60
                      : AppTheme.ocean900.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSurface({
    required bool isDark,
    required bool isSearchActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkCard
            : (isSearchActive
                  ? Colors.white.withValues(alpha: 0.94)
                  : Colors.white.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(200),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.96),
          width: 1,
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
              focusNode: _searchFocusNode,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppTheme.charcoal900,
              ),
              decoration: InputDecoration(
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search things',
                hintStyle: GoogleFonts.nunito(
                  color: isDark ? Colors.white38 : AppTheme.charcoal500,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                suffixIcon: isSearchActive
                    ? GestureDetector(
                        onTap: () => _searchFocusNode.unfocus(),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 12.0,
                            right: 4.0,
                            top: 4.0,
                            bottom: 4.0,
                          ),
                          child: SvgPicture.asset(
                            IconAssets.getSolidPath('x-circle'),
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              isDark ? Colors.white38 : AppTheme.charcoal400,
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
    );
  }

  Widget _buildTagChip(
    BuildContext context, {
    required bool isActive,
    required bool isDark,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Figma: paddingL/R=12, paddingT/B=4, cornerRadius=200
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          // Figma active:   FILL rgba(102,157,242) = primaryOcean
          // Figma inactive: FILL rgba(245,245,247) = charcoal50
          color: isActive
              ? AppTheme.primaryOcean
              : (isDark ? AppTheme.darkCard : AppTheme.charcoal50),
          borderRadius: BorderRadius.circular(200),
          border: Border.all(
            // Figma active:   STROKE rgba(26,26,26,0.20)
            // Figma inactive: STROKE rgba(26,26,26,0.12)
            color: isActive
                ? const Color(0x331A1A1A) // rgba(26,26,26,0.20)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0x1F1A1A1A)), // rgba(26,26,26,0.12)
            width: 1.0,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, Item item, bool isDark) {
    final hasTitle = item.title.trim().isNotEmpty;
    final textToShow = hasTitle ? item.title.trim() : item.content.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12), // Figma: itemSpacing=12
      child: Dismissible(
        key: Key(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: AppTheme.deleteRed.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.delete_sweep_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        confirmDismiss: (_) async {
          return showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Item'),
              content: Text('Are you sure you want to delete "${item.title}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.deleteRed,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) {
          ref.read(itemOperationsProvider).deleteItem(item.id);
          CustomToast.show(context, 'Item deleted', isSuccess: true);
        },
        child: Container(
          // Outer container holds the drop shadow (outside ClipRRect)
          // Figma: DROP_SHADOW rgba(0,0,0,0.04) offset=(0,0) blur=2 spread=1
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
            child: defaultTargetPlatform == TargetPlatform.android
                ? _buildItemCardSurface(
                    context,
                    item,
                    isDark,
                    hasTitle,
                    textToShow,
                  )
                : BackdropFilter(
                    // Figma: BACKGROUND_BLUR radius=16
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: _buildItemCardSurface(
                      context,
                      item,
                      isDark,
                      hasTitle,
                      textToShow,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCardSurface(
    BuildContext context,
    Item item,
    bool isDark,
    bool hasTitle,
    String textToShow,
  ) {
    return GestureDetector(
      onLongPress: itemMoreMenuUsesLongPress
          ? () {
              final box = context.findRenderObject()! as RenderBox;
              openItemMoreMenuFromItemRow(
                context: context,
                ref: ref,
                item: item,
                isDark: isDark,
                globalAnchor: box.localToGlobal(box.size.center(Offset.zero)),
              );
            }
          : null,
      onSecondaryTapDown: itemMoreMenuUsesRightClick
          ? (details) {
              openItemMoreMenuFromItemRow(
                context: context,
                ref: ref,
                item: item,
                isDark: isDark,
                globalAnchor: details.globalPosition,
              );
            }
          : null,
      child: InkWell(
      // Tap card body → open detail/edit sheet
      onTap: () => _showDetailSheet(context, item),
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // Figma: FILL rgba(255,255,255,0.4)
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : const Color(0x66FFFFFF),
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          // Figma: STROKE rgba(20,20,20,0.12) w=1
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0x1F141414),
            width: 1.0,
          ),
          boxShadow: [
            // INNER_SHADOW rgba(255,255,255,0.75) offset=(0,4) blur=8
            BoxShadow(
              color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.75),
              blurRadius: 8,
              offset: const Offset(0, 4),
              blurStyle: BlurStyle.inner,
            ),
            // INNER_SHADOW rgba(255,255,255,0.96) offset=(1,1) blur=2
            BoxShadow(
              color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.96),
              blurRadius: 2,
              offset: const Offset(1, 1),
              blurStyle: BlurStyle.inner,
            ),
            // INNER_SHADOW rgba(255,255,255,0.96) offset=(-1,-1) blur=2
            BoxShadow(
              color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.96),
              blurRadius: 2,
              offset: const Offset(-1, -1),
              blurStyle: BlurStyle.inner,
            ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                // Figma: icon 20×20, fill=rgba(102,157,242) = primaryOcean
                _buildItemIcon(
                  item.icon,
                  size: 20,
                  color: isDark ? Colors.white70 : AppTheme.primaryOcean,
                ),
                const SizedBox(width: 12), // Figma: itemSpacing=12
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 36),
                    child: Text(
                      textToShow,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        // Figma: bold title (700), regular content (400)
                        fontWeight: hasTitle
                            ? FontWeight.w700
                            : FontWeight.w400,
                        // Figma: fill rgba(15,35,67) = ocean900
                        color: isDark ? Colors.white : AppTheme.ocean900,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: SvgPicture.asset(
                      IconAssets.getLinePath('copy'),
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(
                        isDark ? Colors.white38 : AppTheme.charcoal500,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: -10,
              right: -10,
              bottom: -10,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _copyContent(context, item),
                child: const SizedBox(width: 44),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _TopNavDelegate extends SliverPersistentHeaderDelegate {
  final double topPadding;
  final bool isDark;
  final Widget logoRow;
  final Widget tagsRow;
  final bool hasTags;
  final String? selectedCategory;
  final int totalItemsCount;

  _TopNavDelegate({
    required this.topPadding,
    required this.isDark,
    required this.logoRow,
    required this.tagsRow,
    required this.hasTags,
    required this.selectedCategory,
    required this.totalItemsCount,
  });

  @override
  double get maxExtent => topPadding + 104 + (hasTags ? 52 : 0);

  @override
  double get minExtent => hasTags ? (topPadding + 68) : 0.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final double maxShrink = maxExtent - minExtent;
    final double progress = maxShrink > 0
        ? (shrinkOffset / maxShrink).clamp(0.0, 1.0)
        : 0.0;

    final logoOpacity = (1.0 - progress * 2).clamp(0.0, 1.0);
    final logoTop = topPadding + 16 - shrinkOffset;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final glassProgress = isAndroid ? 1.0 : progress;
    final dividerProgress = progress < 0.08 ? 0.0 : progress;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background blur that fades in as you scroll
        if (hasTags)
          Positioned.fill(
            child: Stack(
              children: [
                // Uniform blur for the entire top bar
                if (!isAndroid)
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 10 * progress,
                        sigmaY: 10 * progress,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                // Smooth gradient overlay matching Figma with bottom border
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isAndroid
                          ? [
                              isDark ? AppTheme.darkSurface : Colors.white,
                              isDark
                                  ? AppTheme.darkSurface
                                  : const Color(0xFFF5F5F7),
                              isDark
                                  ? AppTheme.darkSurface
                                  : const Color(0xFFF5F5F7),
                            ]
                          : [
                              isDark
                                  ? Colors.black.withValues(
                                      alpha: 0.8 * progress,
                                    )
                                  : Colors.white.withValues(
                                      alpha: 0.8 * progress,
                                    ),
                              isDark
                                  ? Colors.black.withValues(alpha: 0.0)
                                  : const Color(
                                      0x00F5F5F7,
                                    ).withValues(alpha: 0.0),
                            ],
                      stops: isAndroid
                          ? const [0.0, 0.62, 1.0]
                          : const [0.0, 1.0],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(
                                0xFFC2C2C6,
                              ).withValues(alpha: 0.2 * dividerProgress)
                            : const Color(
                                0xFFC2C2C6,
                              ).withValues(alpha: dividerProgress),
                        width: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Logo and Settings
        Positioned(
          top: logoTop,
          left: 20,
          right: 20,
          child: Opacity(opacity: logoOpacity, child: logoRow),
        ),

        // Tags
        if (hasTags) Positioned(bottom: 20, left: 0, right: 0, child: tagsRow),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _TopNavDelegate oldDelegate) {
    return oldDelegate.topPadding != topPadding ||
        oldDelegate.isDark != isDark ||
        oldDelegate.hasTags != hasTags ||
        oldDelegate.selectedCategory != selectedCategory ||
        oldDelegate.totalItemsCount != totalItemsCount;
  }
}
