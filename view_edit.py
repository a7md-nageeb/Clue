with open('lib/features/items/views/edit_item_screen.dart', 'r') as f:
    for i, line in enumerate(f.read().splitlines()[200:230]):
        print(f"{i+200}: {line}")
