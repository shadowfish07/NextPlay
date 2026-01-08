import 'package:flutter/material.dart';
import '../../../domain/models/game/game_status.dart';
import '../view_models/library_view_model.dart';
import '../../core/ui/game_status_display.dart';

/// 游戏库筛选组件
class GameLibraryFilters extends StatefulWidget {
  final String searchQuery;
  final Set<GameStatus> statusFilters;
  final Set<String> genreFilters;
  final LibrarySortOption sortOption;
  final bool sortAscending;
  final List<String> availableGenres;
  final LibraryStats libraryStats;
  final Function(String) onSearchChanged;
  final Function(Set<GameStatus>) onStatusFiltersChanged;
  final Function(Set<String>) onGenreFiltersChanged;
  final Function(LibrarySortOption) onSortChanged;
  final Function(bool) onSortDirectionChanged;
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
    required this.libraryStats,
    required this.onSearchChanged,
    required this.onStatusFiltersChanged,
    required this.onGenreFiltersChanged,
    required this.onSortChanged,
    required this.onSortDirectionChanged,
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
  void didUpdateWidget(GameLibraryFilters oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),

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
              fillColor: theme.colorScheme.surfaceContainerHighest,
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
          icon: const Icon(Icons.tune),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
            final count = _getStatusCount(status);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Text('${status.displayName} ($count)'),
                onSelected: (selected) {
                  final newFilters = Set<GameStatus>.from(widget.statusFilters);
                  if (selected) {
                    newFilters.add(status);
                  } else {
                    newFilters.remove(status);
                  }
                  widget.onStatusFiltersChanged(newFilters);
                },
                avatar: isSelected ? null : Icon(
                  GameStatusDisplay.getStatusIcon(status),
                  size: 16,
                ),
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
      onPressed: () {
        // 直接切换排序方向
        widget.onSortDirectionChanged(!widget.sortAscending);
      },
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
        // 标题和排序方向切换按钮
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '排序方式',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            // 排序方向切换按钮
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.arrow_upward, size: 16),
                  label: Text('升序'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.arrow_downward, size: 16),
                  label: Text('降序'),
                ),
              ],
              selected: {widget.sortAscending},
              onSelectionChanged: (Set<bool> selected) {
                widget.onSortDirectionChanged(selected.first);
              },
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // 排序字段选择
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

  /// 获取指定状态的游戏数量
  int _getStatusCount(GameStatus status) {
    return status.when(
      notStarted: () => widget.libraryStats.notStarted,
      playing: () => widget.libraryStats.playing,
      completed: () => widget.libraryStats.completed,
      abandoned: () => widget.libraryStats.abandoned,
      paused: () => 0, // 暂停状态暂时返回0，待统计数据添加此字段
      multiplayer: () => widget.libraryStats.multiplayer,
    );
  }
}

