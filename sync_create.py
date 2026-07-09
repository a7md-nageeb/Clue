import re

with open('lib/features/items/views/create_item_sheet.dart', 'r') as f:
    content = f.read()

old_collapsed_row = """  Widget _buildCollapsedRow(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildChip(
            isDark: isDark,
            iconPath: _selectedIcon != null
                ? IconAssets.getPath(_selectedIcon!) // show chosen icon
                : IconAssets.getLinePath('star'), // placeholder star
            iconColor: AppTheme.primaryOcean,
            label: 'Add Icon',
            onTap: _openIconPicker,
            showIcon: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildChip(
            isDark: isDark,
            iconPath: null,
            iconColor: isDark ? Colors.white54 : AppTheme.charcoal900,
            label: 'Add Title',
            onTap: _expandTitle,
            showIcon: false,
          ),
        ),
      ],
    );
  }"""

new_collapsed_row = """  Widget _buildCollapsedRow(bool isDark) {
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
            label: hasIcon ? '' : 'Add Icon',
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
            iconColor: hasTitle ? AppTheme.ocean900 : (isDark ? Colors.white54 : AppTheme.charcoal900),
            label: hasTitle ? _titleController.text : 'Add Title',
            onTap: _expandTitle,
            showIcon: false,
            isFilled: hasTitle,
          ),
        ),
      ],
    );
  }"""

content = content.replace(old_collapsed_row, new_collapsed_row)

old_build_chip = """  Widget _buildChip({
    required bool isDark,
    String? iconPath,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    bool showIcon = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
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
                  color: isDark ? AppTheme.darkCard : const Color(0xCCF5F5F7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.96),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.75),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      blurStyle: BlurStyle.inner,
                    ),
                  ],
                ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (showIcon && iconPath != null) ...[
                    SvgPicture.asset(
                      iconPath,
                      width: 24,
                      height: 24,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryOcean,
                    ),
                  ),
                ],
              ),"""

new_build_chip = """  Widget _buildChip({
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
                      : (isFilled ? const Color(0xCCFFFFFF) : const Color(0xCCF5F5F7)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.08)
                        : (isFilled ? const Color(0x1F141414) : Colors.white.withValues(alpha: 0.96)),
                    width: 1,
                  ),
                  boxShadow: isFilled ? [] : [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.75),
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
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
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
              ),"""

content = content.replace(old_build_chip, new_build_chip)

with open('lib/features/items/views/create_item_sheet.dart', 'w') as f:
    f.write(content)

print("Updated create_item_sheet.dart for filled state")
