# NextPlay 项目概览

## 项目描述
NextPlay 是一款基于 Steam 游戏库的智能游戏推荐应用，通过连接用户的 Steam 账户，帮助用户从庞大的游戏库中智能推荐下一款值得游玩的游戏，解决玩家的"选择困难症"。

## 技术栈
- **开发框架**: Flutter (Dart 3.9.0+)
- **架构模式**: MVVM + Repository Pattern
- **状态管理**: ChangeNotifier + ListenableBuilder
- **命令模式**: flutter_command (^7.2.2)
- **结果处理**: result_dart (^1.1.0)
- **依赖注入**: provider (^6.1.1)
- **路由管理**: go_router (^13.0.0)
- **数据模型**: freezed (^2.4.7) + json_annotation (^4.8.1)
- **数据存储**: sqflite (^2.3.0) + shared_preferences (^2.2.2)
- **网络请求**: dio (^5.4.0)
- **设计规范**: Material Design 3

## 项目特点
- 纯客户端应用，无后端依赖
- 本地数据存储，保护用户隐私
- Steam API 集成获取用户游戏库数据
- 智能推荐算法，基于游戏状态、类型平衡、用户偏好

## 平台支持
- 目标平台：Android (主要)
- 支持多平台：iOS, macOS, Linux, Windows, Web