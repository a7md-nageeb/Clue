import re

with open('lib/features/items/views/item_detail_sheet.dart', 'r') as f:
    content = f.read()

# 1. Remove the copy button from the panel children
old_children = """              children: [
                _buildHeader(isDark),
                const SizedBox(height: 24),
                _buildBottomRow(isDark),
                const SizedBox(height: 16),
                _buildTextArea(isDark),
                const SizedBox(height: 16),
                _buildCopyButton(isDark),
              ],"""

new_children = """              children: [
                _buildHeader(isDark),
                const SizedBox(height: 24),
                _buildBottomRow(isDark),
                const SizedBox(height: 16),
                _buildTextArea(isDark),
              ],"""

content = content.replace(old_children, new_children)

# 2. Update _buildTextArea to include the copy button
old_text_area = """        child: TextField(
          controller: _contentController,
          focusNode: _contentFocusNode,
          autofocus: true,
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
            contentPadding: const EdgeInsets.all(12),
          ),
        ),"""

new_text_area = """        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                autofocus: true,
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
        ),"""

content = content.replace(old_text_area, new_text_area)

with open('lib/features/items/views/item_detail_sheet.dart', 'w') as f:
    f.write(content)

print("Moved copy button into text field area")
