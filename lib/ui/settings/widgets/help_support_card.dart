import 'package:flutter/material.dart';

class HelpSupportCard extends StatelessWidget {
  final String appVersion;
  final VoidCallback? onShowUserGuide;
  final VoidCallback? onShowFAQ;
  final VoidCallback? onShowPrivacyPolicy;

  const HelpSupportCard({
    super.key,
    required this.appVersion,
    this.onShowUserGuide,
    this.onShowFAQ,
    this.onShowPrivacyPolicy,
  });

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
                  Icons.help_outline,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  '帮助与支持',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // User Guide
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.menu_book,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('使用指南'),
              subtitle: const Text('了解如何使用 NextPlay'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onShowUserGuide ?? () => _showUserGuide(context),
            ),
            
            // FAQ
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.quiz,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('常见问题'),
              subtitle: const Text('Steam 连接、使用技巧等'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onShowFAQ ?? () => _showFAQ(context),
            ),
            
            // Privacy Policy
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.privacy_tip,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('隐私政策'),
              subtitle: const Text('了解数据使用和隐私保护'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onShowPrivacyPolicy ?? () => _showPrivacyPolicy(context),
            ),
            
            const Divider(),
            
            // About Section
            Text(
              '关于应用',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.info_outline,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: const Text('版本信息'),
              subtitle: Text('NextPlay v$appVersion'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showAboutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const UserGuideSheet(),
    );
  }

  void _showFAQ(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const FAQSheet(),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const PrivacyPolicySheet(),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'NextPlay',
      applicationVersion: appVersion,
      applicationIcon: const Icon(Icons.casino, size: 48),
      children: [
        const Text('一款基于 Steam 游戏库的智能游戏推荐应用'),
        const SizedBox(height: 16),
        const Text('帮助玩家从庞大的游戏库中找到下一款值得游玩的游戏'),
      ],
    );
  }
}

class UserGuideSheet extends StatelessWidget {
  const UserGuideSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '使用指南',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: const [
                  _GuideSection(
                    title: '1. 连接 Steam 账户',
                    content: '首次使用需要连接您的 Steam 账户。请准备好 Steam API Key 和 Steam ID。',
                  ),
                  _GuideSection(
                    title: '2. 同步游戏库',
                    content: '连接成功后，应用会自动同步您的游戏库。首次同步可能需要一些时间。',
                  ),
                  _GuideSection(
                    title: '3. 标记游戏状态',
                    content: '在游戏库页面为游戏标记状态：未开始、游玩中、已通关等。这有助于获得更准确的推荐。',
                  ),
                  _GuideSection(
                    title: '4. 获取推荐',
                    content: '在发现页面查看推荐游戏。可以使用筛选功能根据时长、类型等条件筛选。',
                  ),
                  _GuideSection(
                    title: '5. 个性化设置',
                    content: '在设置页面调整推荐偏好，设置时间预算、心情偏好等，获得更个性化的推荐。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FAQSheet extends StatelessWidget {
  const FAQSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '常见问题',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: const [
                  _FAQItem(
                    question: '如何获取 Steam API Key？',
                    answer: '访问 https://steamcommunity.com/dev/apikey，使用 Steam 账户登录，填写域名（可填 localhost），同意条款即可获得。',
                  ),
                  _FAQItem(
                    question: '如何获取 Steam ID？',
                    answer: '查看个人资料页面 URL 中的数字 ID，或使用 steamid.io 等网站转换您的用户名。',
                  ),
                  _FAQItem(
                    question: '为什么连接 Steam 失败？',
                    answer: '请检查 API Key 和 Steam ID 是否正确，确保网络连接正常，个人资料设置为公开。',
                  ),
                  _FAQItem(
                    question: '推荐不准确怎么办？',
                    answer: '请确保正确标记了游戏状态，在设置中调整推荐偏好，使用越多推荐越准确。',
                  ),
                  _FAQItem(
                    question: '数据存储在哪里？',
                    answer: '所有数据完全存储在您的设备本地，不会上传到任何服务器，保护您的隐私。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PrivacyPolicySheet extends StatelessWidget {
  const PrivacyPolicySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '隐私政策',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: const [
                  _GuideSection(
                    title: '数据收集',
                    content: 'NextPlay 只收集您明确提供的 Steam API Key 和 Steam ID，用于连接您的 Steam 账户。',
                  ),
                  _GuideSection(
                    title: '数据使用',
                    content: '收集的数据仅用于获取您的游戏库信息，生成个性化推荐，不用于任何其他目的。',
                  ),
                  _GuideSection(
                    title: '数据存储',
                    content: '所有数据完全存储在您的设备本地，不会上传到任何远程服务器或第三方服务。',
                  ),
                  _GuideSection(
                    title: '数据安全',
                    content: '您可以随时在设置中清除所有应用数据。卸载应用时，所有数据将被自动删除。',
                  ),
                  _GuideSection(
                    title: '第三方服务',
                    content: '应用仅连接 Steam Web API 获取公开的游戏库信息，不访问私人信息或好友数据。',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  final String title;
  final String content;

  const _GuideSection({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q: $question',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'A: $answer',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}