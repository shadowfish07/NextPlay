enum OnboardingStep {
  welcome,
  steamConnection,
  apiKeyGuide,
  steamIdInput,
  dataSync,
  gameTagging,
}

extension OnboardingStepExtension on OnboardingStep {
  String get title {
    switch (this) {
      case OnboardingStep.welcome:
        return '欢迎使用 NextPlay';
      case OnboardingStep.steamConnection:
        return '连接 Steam 账户';
      case OnboardingStep.apiKeyGuide:
        return '获取 API Key';
      case OnboardingStep.steamIdInput:
        return '输入 Steam ID';
      case OnboardingStep.dataSync:
        return '同步游戏库';
      case OnboardingStep.gameTagging:
        return '快速标记';
    }
  }

  String get description {
    switch (this) {
      case OnboardingStep.welcome:
        return '让我们帮您找到下一款值得游玩的游戏';
      case OnboardingStep.steamConnection:
        return '我们需要连接您的 Steam 账户来获取游戏库信息';
      case OnboardingStep.apiKeyGuide:
        return '请按照指引获取您的 Steam Web API Key';
      case OnboardingStep.steamIdInput:
        return '输入您的 Steam ID（steamID64）';
      case OnboardingStep.dataSync:
        return '正在同步您的游戏库数据，请稍候...';
      case OnboardingStep.gameTagging:
        return '让我们为您的游戏添加状态标记';
    }
  }

  int get stepNumber {
    return index + 1;
  }

  int get totalSteps {
    return OnboardingStep.values.length;
  }

  OnboardingStep? get next {
    final nextIndex = index + 1;
    if (nextIndex < OnboardingStep.values.length) {
      return OnboardingStep.values[nextIndex];
    }
    return null;
  }

  OnboardingStep? get previous {
    final prevIndex = index - 1;
    if (prevIndex >= 0) {
      return OnboardingStep.values[prevIndex];
    }
    return null;
  }
}