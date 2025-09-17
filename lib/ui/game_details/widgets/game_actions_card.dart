import 'package:flutter/material.dart';

/// 用户操作卡片（状态管理、笔记）
class GameActionsCard extends StatefulWidget {
  final String userNotes;
  final bool isEditingNotes;
  final VoidCallback onToggleNotesEditing;
  final Function(String) onSaveNotes;
  final VoidCallback onCancelNotesEditing;

  const GameActionsCard({
    super.key,
    required this.userNotes,
    required this.isEditingNotes,
    required this.onToggleNotesEditing,
    required this.onSaveNotes,
    required this.onCancelNotesEditing,
  });

  @override
  State<GameActionsCard> createState() => _GameActionsCardState();
}

class _GameActionsCardState extends State<GameActionsCard> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.userNotes);
  }

  @override
  void didUpdateWidget(GameActionsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userNotes != oldWidget.userNotes) {
      _notesController.text = widget.userNotes;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit_note,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '我的笔记',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 笔记区域
            _buildNotesSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    final theme = Theme.of(context);
    
    if (widget.isEditingNotes) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '记录你对这款游戏的想法、攻略要点或游戏体验...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: theme.textTheme.bodyMedium,
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              FilledButton.icon(
                onPressed: () => widget.onSaveNotes(_notesController.text),
                icon: const Icon(Icons.save, size: 16),
                label: const Text('保存'),
              ),
              
              const SizedBox(width: 8),
              
              TextButton.icon(
                onPressed: () {
                  _notesController.text = widget.userNotes;
                  widget.onCancelNotesEditing();
                },
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('取消'),
              ),
            ],
          ),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.userNotes.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.edit_note_outlined,
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  '还没有游戏笔记',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '点击下方按钮添加你的游戏感想',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          OutlinedButton.icon(
            onPressed: widget.onToggleNotesEditing,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('添加笔记'),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.userNotes,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          
          const SizedBox(height: 12),
          
          OutlinedButton.icon(
            onPressed: widget.onToggleNotesEditing,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('编辑笔记'),
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}