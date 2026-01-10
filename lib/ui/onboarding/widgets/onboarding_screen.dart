import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/models/onboarding/onboarding_step.dart';
import '../view_models/onboarding_view_model.dart';
import '../../../routing/routes.dart';
import '../../core/ui/webview_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<OnboardingViewModel>(
      builder: (context, viewModel, child) {
        final state = viewModel.state;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(state.currentStep.title),
            leading: state.currentStep.previous != null 
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => viewModel.previousStepCommand.execute(),
                  )
                : null,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: state.currentStep.stepNumber / state.currentStep.totalSteps,
                ),
                const SizedBox(height: 16),
                Text(
                  'Step ${state.currentStep.stepNumber} of ${state.currentStep.totalSteps}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: _buildStepContent(context, viewModel),
                ),
                const SizedBox(height: 16),
                _buildNavigationButtons(context, viewModel),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepContent(BuildContext context, OnboardingViewModel viewModel) {
    final state = viewModel.state;

    switch (state.currentStep) {
      case OnboardingStep.welcome:
        return _buildWelcomeStep(context, viewModel);
      case OnboardingStep.steamConnection:
        return _buildSteamConnectionStep(context, viewModel);
      case OnboardingStep.apiKeyGuide:
        return _buildApiKeyGuideStep(context, viewModel);
      case OnboardingStep.steamIdInput:
        return _buildSteamIdInputStep(context, viewModel);
      case OnboardingStep.dataSync:
        return _buildDataSyncStep(context, viewModel);
    }
  }

  Widget _buildWelcomeStep(BuildContext context, OnboardingViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/images/app_icon.png',
            width: 100,
            height: 100,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '欢迎使用 NextPlay',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          '让我们帮您找到下一款值得游玩的游戏',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSteamConnectionStep(BuildContext context, OnboardingViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.link,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          '连接 Steam 账户',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          '我们需要连接您的 Steam 账户来获取游戏库信息。\n\n您的数据将完全存储在本地设备上，我们不会收集或上传任何个人信息。',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildApiKeyGuideStep(BuildContext context, OnboardingViewModel viewModel) {
    final apiKeyController = TextEditingController(text: viewModel.state.apiKey);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            '获取 Steam API Key',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '步骤：',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('1. 点击下方按钮打开 Steam API Key 页面'),
                  const Text('2. 使用您的 Steam 账户登录'),
                  const Text('3. 填写域名（可以随意填写）'),
                  const Text('4. 复制生成的 API Key'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const WebViewPage(
                    url: 'https://steamcommunity.com/dev/apikey',
                    title: 'Steam API Key',
                  ),
                ),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new),
                SizedBox(width: 8),
                Text('打开 Steam API Key 页面'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: apiKeyController,
            decoration: const InputDecoration(
              labelText: 'Steam API Key',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              viewModel.saveApiKeyCommand.execute(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSteamIdInputStep(BuildContext context, OnboardingViewModel viewModel) {
    final steamIdController = TextEditingController(text: viewModel.state.steamId);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            '输入 Steam ID',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '如何获取 Steam ID：',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('1. 点击下方按钮打开 Steam 账户页面'),
                  const Text('2. 登录您的 Steam 账户'),
                  const Text('3. 复制页面左上角显示的 Steam ID'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const WebViewPage(
                    url: 'https://store.steampowered.com/account/',
                    title: 'Steam 账户',
                  ),
                ),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new),
                SizedBox(width: 8),
                Text('打开 Steam 账户页面'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: steamIdController,
            decoration: const InputDecoration(
              labelText: 'Steam ID',
              border: OutlineInputBorder(),
              helperText: '请输入17位数字的 Steam ID',
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              viewModel.saveSteamIdCommand.execute(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDataSyncStep(BuildContext context, OnboardingViewModel viewModel) {
    final state = viewModel.state;
    final hasError = state.errorMessage.isNotEmpty;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          hasError ? Icons.error_outline : Icons.sync,
          size: 80,
          color: hasError ? colorScheme.error : colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          '同步游戏库',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // 同步消息
        Text(
          state.syncMessage.isNotEmpty
              ? state.syncMessage
              : '正在同步您的游戏库数据，请稍候...',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // 进度条
        LinearProgressIndicator(
          value: state.syncProgress,
          backgroundColor: colorScheme.surfaceContainerHighest,
        ),
        const SizedBox(height: 12),
        // 进度详情
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(state.syncProgress * 100).toInt()}%',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (state.totalGames != null)
              Text(
                '${state.totalGames} 个游戏',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        // 错误信息
        if (hasError) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colorScheme.onErrorContainer,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.errorMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        // 操作按钮
        if (!state.isLoading && state.gameLibrary.isNotEmpty)
          FilledButton(
            onPressed: () async {
              await viewModel.completeOnboarding();
              if (context.mounted) {
                context.go(Routes.main);
              }
            },
            child: const Text('完成'),
          ),
        // 重试按钮
        if (!state.isLoading && hasError && state.gameLibrary.isEmpty)
          FilledButton.tonal(
            onPressed: () => viewModel.syncGameLibraryCommand.execute(),
            child: const Text('重试'),
          ),
      ],
    );
  }

  Widget _buildNavigationButtons(BuildContext context, OnboardingViewModel viewModel) {
    final state = viewModel.state;

    if (state.currentStep == OnboardingStep.dataSync) {
      // Auto-start sync when entering this step
      if (!state.isLoading && state.syncProgress == 0.0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          viewModel.syncGameLibraryCommand.execute();
        });
      }
      return const SizedBox.shrink(); // No manual navigation during sync
    }

    return Row(
      children: [
        if (viewModel.canGoPrevious)
          Expanded(
            child: OutlinedButton(
              onPressed: () => viewModel.previousStepCommand.execute(),
              child: const Text('上一步'),
            ),
          ),
        if (viewModel.canGoPrevious && viewModel.canGoNext)
          const SizedBox(width: 16),
        if (viewModel.canGoNext)
          Expanded(
            child: FilledButton(
              onPressed: () => viewModel.nextStepCommand.execute(),
              child: Text(
                state.currentStep == OnboardingStep.steamConnection
                    ? '开始设置'
                    : '下一步'
              ),
            ),
          ),
      ],
    );
  }
}