import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../domain/models/onboarding/onboarding_step.dart';
import '../view_models/onboarding_view_model.dart';
import '../../../routing/routes.dart';
import '../../../data/repository/game_repository.dart';
import '../../game_status/view_models/batch_status_view_model.dart';
import '../../game_status/widgets/batch_status_screen.dart';

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
      case OnboardingStep.gameTagging:
        return _buildGameTaggingStep(context, viewModel);
    }
  }

  Widget _buildWelcomeStep(BuildContext context, OnboardingViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.videogame_asset,
          size: 100,
          color: Theme.of(context).colorScheme.primary,
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
    
    return Column(
      children: [
        Text(
          '获取 Steam API Key',
          style: Theme.of(context).textTheme.headlineSmall,
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
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text('1. 访问 steamcommunity.com/dev/apikey'),
                const Text('2. 使用您的 Steam 账户登录'),
                const Text('3. 填写域名（可以随意填写）'),
                const Text('4. 复制生成的 API Key'),
              ],
            ),
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
    );
  }

  Widget _buildSteamIdInputStep(BuildContext context, OnboardingViewModel viewModel) {
    final steamIdController = TextEditingController(text: viewModel.state.steamId);
    
    return Column(
      children: [
        Text(
          '输入 Steam ID',
          style: Theme.of(context).textTheme.headlineSmall,
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
                  '如何获取 steamID64：',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text('1. 访问 steamid.io'),
                const Text('2. 输入您的 Steam 个人资料链接或用户名'),
                const Text('3. 复制 steamID64 (17位数字)'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: steamIdController,
          decoration: const InputDecoration(
            labelText: 'steamID64',
            border: OutlineInputBorder(),
            helperText: '请输入17位数字的 steamID64',
          ),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            viewModel.saveSteamIdCommand.execute(value);
          },
        ),
      ],
    );
  }

  Widget _buildDataSyncStep(BuildContext context, OnboardingViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.sync,
          size: 80,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          '同步游戏库',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          '正在同步您的游戏库数据，请稍候...',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        LinearProgressIndicator(
          value: viewModel.state.syncProgress,
        ),
        const SizedBox(height: 16),
        Text(
          '${(viewModel.state.syncProgress * 100).toInt()}%',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (!viewModel.state.isLoading && viewModel.state.gameLibrary.isNotEmpty)
          FilledButton(
            onPressed: () => viewModel.nextStepCommand.execute(),
            child: const Text('继续'),
          ),
      ],
    );
  }

  Widget _buildGameTaggingStep(BuildContext context, OnboardingViewModel viewModel) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.auto_awesome,
          size: 100,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          '游戏状态智能标记',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          '让我们为您的游戏库设置合适的状态标记\n这将帮助推荐系统为您提供更精准的建议',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  // 跳过批量标记，直接完成引导
                  viewModel.completeOnboardingCommand.execute();
                  context.go(Routes.main);
                },
                child: const Text('跳过此步骤'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () {
                  // 进入批量状态管理
                  _startBatchStatusManagement(context, viewModel);
                },
                child: const Text('开始智能标记'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 启动批量状态管理
  void _startBatchStatusManagement(BuildContext context, OnboardingViewModel viewModel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (context) => BatchStatusViewModel(
            gameRepository: context.read<GameRepository>(),
          ),
          child: BatchStatusScreen(
            isFromOnboarding: true,
            onCompleted: () {
              // 批量状态管理完成后，完成引导流程
              Navigator.of(context).pop(); // 关闭批量状态管理页面
              viewModel.completeOnboardingCommand.execute();
              context.go(Routes.main);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(BuildContext context, OnboardingViewModel viewModel) {
    final state = viewModel.state;
    
    if (state.currentStep == OnboardingStep.gameTagging) {
      return const SizedBox.shrink(); // No navigation buttons on final step
    }
    
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