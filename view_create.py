with open('lib/features/items/views/create_item_sheet.dart', 'r') as f:
    for i, line in enumerate(f.read().splitlines()[450:500]):
        print(f"{i+450}: {line}")
