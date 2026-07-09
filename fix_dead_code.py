import re

with open('lib/features/items/views/item_detail_sheet.dart', 'r') as f:
    content = f.read()

# Fix unused hasTitle
content = content.replace('    final hasTitle = (_titleController.text).isNotEmpty;\n    _showTitle = true;', '    _showTitle = true;')

# Fix dead code in text area
# Replace color
content = content.replace('(isActive ? const Color(0xCCFFFFFF) : const Color(0xCCF5F5F7))', 'const Color(0xCCFFFFFF)')
# Replace border color
content = content.replace('(isActive ? const Color(0x1F141414) : const Color(0xE6FFFFFF))', 'const Color(0x1F141414)')
# Replace boxShadow
# ] : null, -> ],
content = content.replace('] : null,', '],')
# Now the array is active always. Wait, we should make sure we don't accidentally replace a different ] : null,
# In _buildTextArea:
# boxShadow: isActive ? [ ... ] : null,
content = content.replace('boxShadow: isActive ? [', 'boxShadow: [')

with open('lib/features/items/views/item_detail_sheet.dart', 'w') as f:
    f.write(content)

print("Dead code fixed")
