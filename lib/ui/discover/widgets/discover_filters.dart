import 'package:flutter/material.dart';
import '../../../domain/models/discover/filter_criteria.dart';

/// 发现页筛选器组件
class DiscoverFilters extends StatelessWidget {
  final FilterCriteria criteria;
  final ValueChanged<FilterCriteria> onFiltersChanged;
  final VoidCallback? onClear;
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  const DiscoverFilters({
    super.key,
    required this.criteria,
    required this.onFiltersChanged,
    this.onClear,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 筛选器标题栏
            _buildFilterHeader(context),
            
            const SizedBox(height: 12),
            
            // 快速筛选chips
            _buildQuickFilters(context),
            
            if (isExpanded) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              // 详细筛选选项
              _buildDetailedFilters(context),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建筛选器标题栏
  Widget _buildFilterHeader(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveFilters = _hasActiveFilters();
    
    return Row(
      children: [
        Icon(
          Icons.filter_list,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          '筛选条件',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_getActiveFilterCount()}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (hasActiveFilters && onClear != null)
          TextButton(
            onPressed: onClear,
            child: const Text('清除'),
          ),
        if (onToggleExpanded != null)
          IconButton(
            onPressed: onToggleExpanded,
            icon: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
            ),
          ),
      ],
    );
  }

  /// 构建快速筛选chips
  Widget _buildQuickFilters(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 时间预算筛选
        _buildTimeFilterChips(context),
        
        // 心情筛选
        _buildMoodFilterChips(context),
        
        // 快速选项
        _buildQuickOptionChips(context),
      ].expand((chips) => chips).toList(),
    );
  }

  /// 构建时间筛选chips
  List<Widget> _buildTimeFilterChips(BuildContext context) {
    return TimeFilter.values.where((filter) => filter != TimeFilter.any).map((filter) {
      final isSelected = criteria.timeFilter == filter;
      
      return FilterChip(
        label: Text(filter.displayName),
        selected: isSelected,
        onSelected: (selected) {
          _updateTimeFilter(selected ? filter : TimeFilter.any);
        },
        avatar: Icon(
          _getTimeFilterIcon(filter),
          size: 16,
        ),
      );
    }).toList();
  }

  /// 构建心情筛选chips
  List<Widget> _buildMoodFilterChips(BuildContext context) {
    return MoodFilter.values.where((mood) => mood != MoodFilter.any).map((mood) {
      final isSelected = criteria.moodFilter == mood;
      
      return FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mood.emoji),
            const SizedBox(width: 4),
            Text(mood.displayName),
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          _updateMoodFilter(selected ? mood : MoodFilter.any);
        },
      );
    }).toList();
  }

  /// 构建快速选项chips
  List<Widget> _buildQuickOptionChips(BuildContext context) {
    return [
      FilterChip(
        label: const Text('仅未开始'),
        selected: criteria.onlyUnplayed,
        onSelected: (selected) {
          _updateQuickOption(onlyUnplayed: selected);
        },
        avatar: const Icon(
          Icons.fiber_new,
          size: 16,
        ),
      ),
      FilterChip(
        label: const Text('包含已通关'),
        selected: criteria.includeCompleted,
        onSelected: (selected) {
          _updateQuickOption(includeCompleted: selected);
        },
        avatar: const Icon(
          Icons.check_circle,
          size: 16,
        ),
      ),
    ];
  }

  /// 构建详细筛选选项
  Widget _buildDetailedFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 单次游戏时间
        _buildSectionTitle(context, '单次游戏时间'),
        const SizedBox(height: 8),
        _buildSessionTimeSelector(context),
        
        const SizedBox(height: 16),
        
        // 游戏类型筛选
        _buildSectionTitle(context, '游戏类型'),
        const SizedBox(height: 8),
        _buildGenreSelector(context),
      ],
    );
  }

  /// 构建章节标题
  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    
    return Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  /// 构建单次游戏时间选择器
  Widget _buildSessionTimeSelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SessionTime.values.map((sessionTime) {
        final isSelected = criteria.sessionTime == sessionTime;
        
        return ChoiceChip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(sessionTime.displayName),
              Text(
                sessionTime.description,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              _updateSessionTime(sessionTime);
            }
          },
        );
      }).toList(),
    );
  }

  /// 构建游戏类型选择器
  Widget _buildGenreSelector(BuildContext context) {
    final commonGenres = [
      'Action', 'Adventure', 'RPG', 'Strategy', 'Simulation',
      'Puzzle', 'Shooter', 'Platformer', 'Racing', 'Sports',
      'Indie', 'Casual', 'Horror', 'Fighting'
    ];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: commonGenres.map((genre) {
        final isSelected = criteria.selectedGenres.contains(genre);
        
        return FilterChip(
          label: Text(genre),
          selected: isSelected,
          onSelected: (selected) {
            _updateGenreSelection(genre, selected);
          },
        );
      }).toList(),
    );
  }

  /// 获取时间筛选图标
  IconData _getTimeFilterIcon(TimeFilter filter) {
    switch (filter) {
      case TimeFilter.short:
        return Icons.flash_on;
      case TimeFilter.medium:
        return Icons.schedule;
      case TimeFilter.long:
        return Icons.movie;
      case TimeFilter.any:
        return Icons.all_inclusive;
    }
  }

  /// 更新时间筛选
  void _updateTimeFilter(TimeFilter timeFilter) {
    final newCriteria = criteria.copyWith(timeFilter: timeFilter);
    onFiltersChanged(newCriteria);
  }

  /// 更新心情筛选
  void _updateMoodFilter(MoodFilter moodFilter) {
    final newCriteria = criteria.copyWith(moodFilter: moodFilter);
    onFiltersChanged(newCriteria);
  }

  /// 更新单次游戏时间
  void _updateSessionTime(SessionTime sessionTime) {
    final newCriteria = criteria.copyWith(sessionTime: sessionTime);
    onFiltersChanged(newCriteria);
  }

  /// 更新快速选项
  void _updateQuickOption({
    bool? onlyUnplayed,
    bool? includeCompleted,
  }) {
    final newCriteria = criteria.copyWith(
      onlyUnplayed: onlyUnplayed ?? criteria.onlyUnplayed,
      includeCompleted: includeCompleted ?? criteria.includeCompleted,
    );
    onFiltersChanged(newCriteria);
  }

  /// 更新类型选择
  void _updateGenreSelection(String genre, bool selected) {
    final selectedGenres = Set<String>.from(criteria.selectedGenres);
    
    if (selected) {
      selectedGenres.add(genre);
    } else {
      selectedGenres.remove(genre);
    }
    
    final newCriteria = criteria.copyWith(selectedGenres: selectedGenres);
    onFiltersChanged(newCriteria);
  }

  /// 检查是否有活跃的筛选条件
  bool _hasActiveFilters() {
    return criteria.timeFilter != TimeFilter.any ||
           criteria.moodFilter != MoodFilter.any ||
           criteria.sessionTime != SessionTime.medium ||
           criteria.selectedGenres.isNotEmpty ||
           criteria.onlyUnplayed ||
           criteria.includeCompleted;
  }

  /// 获取活跃筛选条件数量
  int _getActiveFilterCount() {
    int count = 0;
    
    if (criteria.timeFilter != TimeFilter.any) count++;
    if (criteria.moodFilter != MoodFilter.any) count++;
    if (criteria.sessionTime != SessionTime.medium) count++;
    if (criteria.selectedGenres.isNotEmpty) count++;
    if (criteria.onlyUnplayed) count++;
    if (criteria.includeCompleted) count++;
    
    return count;
  }
}

/// 简化版筛选器 - 用于顶部快速筛选
class QuickDiscoverFilters extends StatelessWidget {
  final FilterCriteria criteria;
  final ValueChanged<FilterCriteria> onFiltersChanged;
  final VoidCallback? onShowMore;

  const QuickDiscoverFilters({
    super.key,
    required this.criteria,
    required this.onFiltersChanged,
    this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 时间筛选
          ...TimeFilter.values.where((f) => f != TimeFilter.any).map((filter) {
            final isSelected = criteria.timeFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter.displayName),
                selected: isSelected,
                onSelected: (selected) {
                  final newCriteria = criteria.copyWith(
                    timeFilter: selected ? filter : TimeFilter.any,
                  );
                  onFiltersChanged(newCriteria);
                },
              ),
            );
          }),
          
          // 心情筛选
          ...MoodFilter.values.where((m) => m != MoodFilter.any).map((mood) {
            final isSelected = criteria.moodFilter == mood;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${mood.emoji} ${mood.displayName}'),
                selected: isSelected,
                onSelected: (selected) {
                  final newCriteria = criteria.copyWith(
                    moodFilter: selected ? mood : MoodFilter.any,
                  );
                  onFiltersChanged(newCriteria);
                },
              ),
            );
          }),
          
          // 更多筛选按钮
          if (onShowMore != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ActionChip(
                label: const Text('更多筛选'),
                avatar: const Icon(Icons.tune, size: 16),
                onPressed: onShowMore,
              ),
            ),
        ],
      ),
    );
  }
}

/// 筛选器状态指示器
class FilterStatusIndicator extends StatelessWidget {
  final FilterCriteria criteria;
  final VoidCallback? onTap;

  const FilterStatusIndicator({
    super.key,
    required this.criteria,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeFilters = _getActiveFilterTexts();
    
    if (activeFilters.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.filter_alt,
              size: 16,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '已应用筛选: ${activeFilters.join(', ')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getActiveFilterTexts() {
    final filters = <String>[];
    
    if (criteria.timeFilter != TimeFilter.any) {
      filters.add(criteria.timeFilter.displayName);
    }
    
    if (criteria.moodFilter != MoodFilter.any) {
      filters.add(criteria.moodFilter.displayName);
    }
    
    if (criteria.selectedGenres.isNotEmpty) {
      filters.add('${criteria.selectedGenres.length}个类型');
    }
    
    if (criteria.onlyUnplayed) {
      filters.add('仅未开始');
    }
    
    if (criteria.includeCompleted) {
      filters.add('包含已通关');
    }
    
    return filters;
  }
}