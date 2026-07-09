with open('lib/features/items/views/item_detail_sheet.dart', 'r') as f:
    content = f.read()

content = content.replace("    final isActive = true; // User requested \"the fields are active (if all are active)\" so we keep it in active state\n", "")

with open('lib/features/items/views/item_detail_sheet.dart', 'w') as f:
    f.write(content)
