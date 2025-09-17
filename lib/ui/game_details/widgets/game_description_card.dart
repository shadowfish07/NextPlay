import 'package:flutter/material.dart';

/// 游戏描述卡片
class GameDescriptionCard extends StatefulWidget {
  final String description;

  const GameDescriptionCard({
    super.key,
    required this.description,
  });

  @override
  State<GameDescriptionCard> createState() => _GameDescriptionCardState();
}

class _GameDescriptionCardState extends State<GameDescriptionCard> {
  bool _isExpanded = false;
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shouldShowExpandButton = widget.description.length > 200;
    final displayText = shouldShowExpandButton && !_isExpanded 
        ? '${widget.description.substring(0, 200)}...'
        : widget.description;
    
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
                  Icons.description,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '游戏介绍',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Text(
              displayText,
              style: theme.textTheme.bodyMedium,
            ),
            
            if (shouldShowExpandButton) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                ),
                label: Text(_isExpanded ? '收起' : '展开'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}