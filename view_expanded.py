with open('lib/features/items/views/item_detail_sheet.dart', 'r') as f:
    for i, line in enumerate(f.read().splitlines()[600:650]):
        print(f"{i+600}: {line}")
