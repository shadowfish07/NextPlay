import 'package:flutter/material.dart';
import '../../../domain/models/game/game_status.dart';
import '../view_models/library_view_model.dart';

/// 游戏库筛选组件
class GameLibraryFilters extends StatefulWidget {
  final String searchQuery;
  final Set<GameStatus> statusFilters;
  final Set<String> genreFilters;
  final LibrarySortOption sortOption;
  final bool sortAscending;
  final List<String> availableGenres;
  final Function(String) onSearchChanged;
  final Function(Set<GameStatus>) onStatusFiltersChanged;
  final Function(Set<String>) onGenreFiltersChanged;
  final Function(LibrarySortOption) onSortChanged;
  final VoidCallback onClearFilters;
  final bool hasFilters;

  const GameLibraryFilters({
    super.key,
    required this.searchQuery,
    required this.statusFilters,
    required this.genreFilters,
    required this.sortOption,
    required this.sortAscending,
    required this.availableGenres,
    required this.onSearchChanged,
    required this.onStatusFiltersChanged,
    required this.onGenreFiltersChanged,
    required this.onSortChanged,
    required this.onClearFilters,
    required this.hasFilters,
  });

  @override
  State<GameLibraryFilters> createState() => _GameLibraryFiltersState();
}

class _GameLibraryFiltersState extends State<GameLibraryFilters>
    with TickerProviderStateMixin {
  late TextEditingController _searchController;
  bool _isExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索栏
        _buildSearchBar(context),
        
        const SizedBox(height: 12),
        
        // 快速筛选chips
        _buildQuickFilters(context),
        
        // 展开的详细筛选
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Column(
            children: [
              const SizedBox(height: 16),
              _buildDetailedFilters(context),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索游戏、开发商或类型...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: widget.searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearchChanged('');
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            onChanged: widget.onSearchChanged,
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 筛选展开按钮
        IconButton(
          onPressed: _toggleExpanded,
          icon: AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 300),
            child: const Icon(Icons.tune),
          ),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceVariant,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        
        // 清除筛选按钮
        if (widget.hasFilters)
          IconButton(
            onPressed: widget.onClearFilters,
            icon: const Icon(Icons.clear_all),
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.errorContainer,
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
          ),
      ],
    );
  }

  /// 构建快速筛选chips
  Widget _buildQuickFilters(BuildContext context) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // 排序chip
          _buildSortChip(context),
          
          const SizedBox(width: 8),
          
          // 状态筛选chips
          ...GameStatusExtension.values.map((status) {
            final isSelected = widget.statusFilters.contains(status);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Text(status.displayName),
                onSelected: (selected) {
                  final newFilters = Set<GameStatus>.from(widget.statusFilters);
                  if (selected) {
                    newFilters.add(status);
                  } else {
                    newFilters.remove(status);
                  }
                  widget.onStatusFiltersChanged(newFilters);
                },
                avatar: _getStatusIcon(status),
                selectedColor: theme.colorScheme.primaryContainer,
                checkmarkColor: theme.colorScheme.onPrimaryContainer,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 构建排序chip
  Widget _buildSortChip(BuildContext context) {
    final theme = Theme.of(context);
    
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.sortOption.displayName),
          const SizedBox(width: 4),
          Icon(
            widget.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
          ),
        ],
      ),
      onPressed: () => _showSortOptions(context),
      backgroundColor: theme.colorScheme.secondaryContainer,
      labelStyle: TextStyle(
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
  }

  /// 构建详细筛选选项
  Widget _buildDetailedFilters(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '高级筛选',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 游戏类型筛选
            _buildGenreFilter(context),
            
            const SizedBox(height: 16),
            
            // 排序选项
            _buildSortOptions(context),
          ],
        ),
      ),
    );
  }

  /// 构建游戏类型筛选
  Widget _buildGenreFilter(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '游戏类型',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 8),
        
        if (widget.availableGenres.isEmpty)
          Text(
            '暂无可筛选的类型',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.availableGenres.map((genre) {
              final isSelected = widget.genreFilters.contains(genre);
              return FilterChip(
                selected: isSelected,
                label: Text(genre),
                onSelected: (selected) {
                  final newFilters = Set<String>.from(widget.genreFilters);
                  if (selected) {
                    newFilters.add(genre);
                  } else {
                    newFilters.remove(genre);
                  }
                  widget.onGenreFiltersChanged(newFilters);
                },
                selectedColor: theme.colorScheme.tertiaryContainer,
                checkmarkColor: theme.colorScheme.onTertiaryContainer,
              );
            }).toList(),
          ),
      ],
    );
  }

  /// 构建排序选项
  Widget _buildSortOptions(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '排序方式',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: LibrarySortOption.values.map((option) {
            final isSelected = widget.sortOption == option;
            return ChoiceChip(
              selected: isSelected,
              label: Text(option.displayName),
              onSelected: (selected) {
                if (selected) {
                  widget.onSortChanged(option);
                }
              },
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected 
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 显示排序选项对话框
  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择排序方式',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 16),
            
            ...LibrarySortOption.values.map((option) {
              final isSelected = widget.sortOption == option;
              return ListTile(
                title: Text(option.displayName),
                leading: isSelected ? const Icon(Icons.check) : null,
                trailing: isSelected
                    ? Icon(
                        widget.sortAscending 
                            ? Icons.arrow_upward 
                            : Icons.arrow_downward,
                      )
                    : null,
                selected: isSelected,
                onTap: () {
                  Navigator.of(context).pop();
                  widget.onSortChanged(option);
                },
              );
            }),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// 获取状态对应的图标
  Widget _getStatusIcon(GameStatus status) {
    return status.when(
      notStarted: () => const Icon(Icons.play_arrow, size: 16),
      playing: () => const Icon(Icons.pause, size: 16),
      completed: () => const Icon(Icons.check_circle, size: 16),
      abandoned: () => const Icon(Icons.cancel, size: 16),
      multiplayer: () => const Icon(Icons.people, size: 16),
      paused: () => const Icon(Icons.pause_circle_outline, size: 16),
    );
  }

  /// 切换展开状态
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    
    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }
}

/// 游戏库统计信息组件
class LibraryStatsCard extends StatelessWidget {
  final LibraryStats stats;

  const LibraryStatsCard({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '游戏库统计',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    '总计',
                    stats.totalGames.toString(),
                    Icons.videogame_asset,
                    theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    '未开始',
                    stats.notStarted.toString(),
                    Icons.play_arrow,
                    theme.colorScheme.secondary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    '游玩中',
                    stats.playing.toString(),
                    Icons.pause,
                    theme.colorScheme.tertiary,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    '已完成',
                    stats.completed.toString(),
                    Icons.check_circle,
                    theme.colorScheme.inversePrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}