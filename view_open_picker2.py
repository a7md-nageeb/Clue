with open('lib/features/items/views/create_item_sheet.dart', 'r') as f:
    for i, line in enumerate(f.read().splitlines()[100:200]):
        print(f"{i+100}: {line}")
