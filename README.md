# NextPlay

基于 Steam 游戏库的智能游戏推荐应用，帮助玩家从庞大的游戏库中找到下一款值得游玩的游戏。

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

### 安装

1. 克隆仓库

```bash
git clone https://github.com/your-username/NextPlay.git
cd NextPlay
```

2. 安装依赖

```bash
flutter pub get
```

3. 生成代码（freezed 模型等）

```bash
flutter pub run build_runner build
```

4. 运行应用

```bash
flutter run
```

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── config/                   # 依赖注入配置
├── data/                     # 数据层 (Repository & Service)
├── domain/                   # 领域模型
├── routing/                  # 路由配置
├── ui/
│   ├── core/                 # 通用 UI 组件
│   ├── discover/             # 发现页 - 游戏推荐
│   ├── library/              # 游戏库管理
│   ├── game_details/         # 游戏详情
│   ├── game_status/          # 游戏状态管理
│   ├── settings/             # 设置页
│   └── onboarding/           # 首次启动引导
└── utils/                    # 工具类
```

## API 依赖

- **Steam Web API** - 获取用户游戏库（需用户提供 API Key）
- **IGDB API** - 本项目依赖[这个封装的 IGDB API](https://github.com/shadowfish07/igdb_service)提供游戏元数据服务

## 许可证

<!-- TODO: 添加许可证信息 -->

## 致谢

- [Steam Web API](https://developer.valvesoftware.com/wiki/Steam_Web_API)
- [IGDB API](https://api-docs.igdb.com/)
