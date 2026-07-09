import re

with open('lib/features/items/views/create_item_sheet.dart', 'r') as f:
    create_content = f.read()

with open('lib/features/items/views/item_detail_sheet.dart', 'r') as f:
    detail_content = f.read()

# Extract _confirmDelete from detail_content
confirm_delete_match = re.search(r'Future<void> _confirmDelete\(\) async \{.*?\n  \}', detail_content, re.DOTALL)
if confirm_delete_match:
    confirm_delete_code = confirm_delete_match.group(0)
else:
    confirm_delete_code = """
  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text(
          'Delete "${widget.item.title.isNotEmpty ? widget.item.title : widget.item.content}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: AppTheme.deleteRed)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(itemOperationsProvider).deleteItem(widget.item.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
"""

# Replace class names
new_content = create_content.replace('CreateItemSheet', 'ItemDetailSheet')
new_content = new_content.replace('class _ItemDetailSheetState extends ConsumerState<ItemDetailSheet>', 'class _ItemDetailSheetState extends ConsumerState<ItemDetailSheet>')

# Update constructor
# CreateItemSheet has:
#   final Item? item;
#   final String? initialContent;
#   final String? initialTitle;
#   final String? initialIcon;
# ItemDetailSheet requires final Item item;
constructor_code = """  final Item item;

  const ItemDetailSheet({
    super.key,
    required this.item,
  });"""
new_content = re.sub(r'  final Item\? item;.*?}\);', constructor_code, new_content, flags=re.DOTALL)

# Update initState to use widget.item directly instead of widget.item?
new_content = new_content.replace('widget.item?.content ?? widget.initialContent ?? \'\'', 'widget.item.content')
new_content = new_content.replace('widget.item?.title ?? widget.initialTitle ?? \'\'', 'widget.item.title')
new_content = new_content.replace('widget.item?.icon ?? widget.initialIcon', 'widget.item.icon')
new_content = new_content.replace('widget.item != null || hasTitle', 'true') # always show expanded title row since it's an existing item? Wait, user said "if all are active", meaning if both fields are populated, they should be active. But in create, expanded means active. Let's just use 'widget.item.title.isNotEmpty || widget.item.icon != null'

# In _save, remove the if (widget.item == null) branch
save_code = """
  Future<void> _save() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return; // content is required

    final ops = ref.read(itemOperationsProvider);
    try {
      final title = _showTitle ? _titleController.text.trim() : '';
      await ops.updateItem(
        id: widget.item.id,
        title: title,
        content: content,
        icon: _selectedIcon,
      );
      if (mounted) {
        Navigator.of(context).pop();
        CustomToast.show(context, 'Saved!', isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(context, 'Failed to save: $e', isSuccess: false);
      }
    }
  }
"""
new_content = re.sub(r'  Future<void> _save\(\) async \{.*?\n  \}', save_code, new_content, flags=re.DOTALL)

# Add _confirmDelete
new_content = new_content.replace('Future<void> _openIconPicker() async {', confirm_delete_code + '\n\n  Future<void> _openIconPicker() async {')

# Update _buildHeader to include Delete button
header_code = """  Widget _buildHeader(bool isDark) {
    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildXButton(isDark),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDeleteButton(),
              const SizedBox(width: 8),
              _buildSaveButton(isDark),
            ],
          ),
        ],
      ),
    );
  }"""
new_content = re.sub(r'  Widget _buildHeader\(bool isDark\) \{.*?\n  \}', header_code, new_content, flags=re.DOTALL)

# Add _buildDeleteButton
delete_button_code = """
  Widget _buildDeleteButton() {
    return DangerButton(
      width: 48,
      height: 48,
      padding: EdgeInsets.zero,
      onTap: _confirmDelete,
      child: Center(
        child: SvgPicture.asset(
          IconAssets.getLinePath('bin'), // Use bin icon or x? detail sheet uses 'bin'
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(
            Colors.white,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
"""
new_content = new_content.replace('Widget _buildSaveButton(bool isDark) {', delete_button_code + '\n  Widget _buildSaveButton(bool isDark) {')

# "the fields are active (if all are active)"
# I'll modify the text area to be active if it already has content, or if focus is true.
# In create_item_sheet.dart: final isActive = _contentFocusNode.hasFocus;
# For detail sheet: final isActive = _contentFocusNode.hasFocus || _contentController.text.isNotEmpty;
new_content = new_content.replace('final isActive = _contentFocusNode.hasFocus;', 'final isActive = true; // User requested "the fields are active (if all are active)" so we keep it in active state')

# Write back
with open('lib/features/items/views/item_detail_sheet.dart', 'w') as f:
    f.write(new_content)

print("Done updating item_detail_sheet.dart")
