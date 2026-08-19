# NextPlay

Agent/Codex development, verification, Android E2E, and live-service instructions are documented in [docs/agentic-development.md](docs/agentic-development.md).

基于 Steam 游戏库的智能游戏推荐应用，帮助玩家从庞大的游戏库中找到下一款值得游玩的游戏。本仓库同时包含 Flutter 客户端和 Bun 元数据服务。

## 功能特性

- **智能推荐** - 基于游戏状态、类型平衡、用户偏好的个性化推荐
- **状态管理** - 追踪游戏进度：未开始、游玩中、已通关、搁置等
- **游戏库同步** - 连接 Steam 账户，自动同步游戏库数据
- **纯本地化** - 所有数据存储在本地，保护用户隐私

## 截图

<!-- TODO: 添加应用截图 -->

## 技术栈

- **框架**: Flutter
- **架构**: MVVM + Repository Pattern
- **状态管理**: ChangeNotifier + flutter_command
- **依赖注入**: Provider
- **路由**: go_router
- **数据模型**: freezed
- **本地存储**: sqflite + shared_preferences
- **设计规范**: Material Design 3

## 开始使用

### 环境要求

- Flutter SDK >= 3.9.0
- Dart SDK >= 3.9.0
- Bun 1.x（服务端与完整验证）

### 安装

1. 克隆仓库

```bash
git clone https://github.com/your-username/NextPlay.git
cd NextPlay
```

2. 初始化当前 checkout

```bash
tool/worktree.sh setup
```

3. 运行完整快速验证

```bash
tool/verify_fast.sh
```

4. 运行 Android 集成、安装与启动验证

```bash
tool/e2e_android.sh
```

服务端常用命令统一从仓库根目录运行：

```bash
tool/service.sh verify
tool/service.sh dev
tool/service.sh deploy
tool/service.sh status
```

本地启动或部署前，将 `services/igdb/.env.example` 复制为忽略的
`services/igdb/.env` 并填写 Twitch/IGDB 凭据。

## 项目结构

```
NextPlay/
├── lib/                      # Flutter 客户端源码
├── android/                  # Android 工程
├── integration_test/         # Android 集成流程
├── services/
│   └── igdb/                 # IGDB + Steam 官方本地化 Bun 服务
├── tool/                     # 单仓开发、验证、部署入口
└── .github/workflows/        # 客户端与服务端 CI
```

Flutter 暂时保留在仓库根目录，以保持 Gradle、Flutter、发布和 Orca
worktree 路径兼容；新增服务统一放在 `services/` 下。

## API 依赖

- **Steam Web API** - 获取用户游戏库（需用户提供 API Key）
- **元数据服务** - 仓库内 [`services/igdb`](services/igdb/README.md)
  提供 IGDB 基础资料，并通过服务端持久队列统一限速获取 Steam 发行商维护的
  官方标题与简介。App 只轮询服务端缓存并保存本地展示副本，不直接请求 Steam
  Store，也不会使用 AI 生成游戏标题或描述。

## 许可证

<!-- TODO: 添加许可证信息 -->

## 致谢

- [Steam Web API](https://developer.valvesoftware.com/wiki/Steam_Web_API)
- [IGDB API](https://api-docs.igdb.com/)
