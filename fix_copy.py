import re

with open('lib/features/items/views/item_detail_sheet.dart', 'r') as f:
    content = f.read()

# Add missing import if needed
if "import 'package:flutter/services.dart';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/services.dart';")

# Add _copyText and _buildCopyButton
copy_code = """
  void _copyText() {
    final text = _contentController.text;
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      CustomToast.show(context, 'Copied to clipboard!', isSuccess: true);
    }
  }

  Widget _buildCopyButton(bool isDark) {
    return GestureDetector(
      onTap: _copyText,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
              spreadRadius: 1,
              offset: Offset.zero,
            ),
          ],
        ),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(200),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : const Color(0xCCF5F5F7),
                  borderRadius: BorderRadius.circular(200),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
"""

content = content.replace("  Widget _buildSaveButton(bool isDark) {", copy_code + "\n  Widget _buildSaveButton(bool isDark) {")

# Insert _buildCopyButton below _buildTextArea
panel_children = """
              children: [
                _buildHeader(isDark),
                const SizedBox(height: 24),
                _buildBottomRow(isDark),
                const SizedBox(height: 16),
                _buildTextArea(isDark),
                const SizedBox(height: 16),
                _buildCopyButton(isDark),
              ],
"""
content = re.sub(r'              children: \[\n                _buildHeader\(isDark\),\n                const SizedBox\(height: 24\),\n                _buildBottomRow\(isDark\),\n                const SizedBox\(height: 16\),\n                _buildTextArea\(isDark\),\n              \],', panel_children, content)

with open('lib/features/items/views/item_detail_sheet.dart', 'w') as f:
    f.write(content)

print("Copy button restored and styled")
