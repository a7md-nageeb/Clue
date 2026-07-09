import re

with open('lib/features/items/views/item_detail_sheet.dart', 'r') as f:
    content = f.read()

content = content.replace("IconAssets.getFilledPath(_selectedIcon!)", "IconAssets.getPath(_selectedIcon!)")

with open('lib/features/items/views/item_detail_sheet.dart', 'w') as f:
    f.write(content)
