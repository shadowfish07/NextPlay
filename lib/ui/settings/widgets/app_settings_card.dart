import 'package:flutter/material.dart';

class AppSettingsCard extends StatelessWidget {
  final bool isDarkTheme;
  final String language;
  final bool isLoading;
  final Function(bool) onThemeChanged;
  final Function(String) onLanguageChanged;
  final VoidCallback onClearCache;
  final VoidCallback onClearAllData;

  const AppSettingsCard({
    super.key,
    required this.isDarkTheme,
    required this.language,
    required this.isLoading,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onClearCache,
    required this.onClearAllData,
  });

  static const List<String> supportedLanguages = [
    'zh_CN', // 简体中文
    'en_US', // English
  ];

  static const Map<String, String> languageLabels = {
    'zh_CN': '简体中文',
    'en_US': 'English',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_applications,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '应用设置',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Theme Setting
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isDarkTheme ? Icons.dark_mode : Icons.light_mode,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('深色主题'),
              subtitle: Text(isDarkTheme ? '深色模式已启用' : '浅色模式已启用'),
              trailing: Switch(
                value: isDarkTheme,
                onChanged: isLoading ? null : onThemeChanged,
              ),
            ),
            
            const Divider(),
            
            // Language Setting
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.language,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('语言设置'),
              subtitle: Text(languageLabels[language] ?? '简体中文'),
              trailing: PopupMenuButton<String>(
                enabled: !isLoading,
                onSelected: onLanguageChanged,
                itemBuilder: (context) => supportedLanguages.map((lang) => 
                  PopupMenuItem<String>(
                    value: lang,
                    child: Row(
                      children: [
                        if (language == lang)
                          Icon(
                            Icons.check,
                            color: theme.colorScheme.primary,
                            size: 20,
                          )
                        else
                          const SizedBox(width: 20),
                        const SizedBox(width: 8),
                        Text(languageLabels[lang]!),
                      ],
                    ),
                  ),
                ).toList(),
                child: Icon(
                  Icons.arrow_drop_down,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            
            const Divider(),
            
            // Data Management Section
            Text(
              '数据管理',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.cached,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('清除缓存'),
              subtitle: const Text('清除游戏图片和临时数据'),
              trailing: isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
              onTap: isLoading ? null : onClearCache,
            ),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_sweep,
                color: theme.colorScheme.error,
              ),
              title: Text(
                '清除所有数据',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text('删除所有应用数据，重置到初始状态'),
              trailing: isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.error,
                  ),
              onTap: isLoading ? null : () => _showClearAllDataConfirmation(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearAllDataConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清除所有数据'),
        content: const Text(
          '此操作将删除所有应用数据，包括：\n\n'
          '• Steam 连接信息\n'
          '• 游戏状态和标记\n'
          '• 推荐偏好设置\n'
          '• 所有缓存数据\n\n'
          '此操作不可撤销，确定要继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClearAllData();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }
}