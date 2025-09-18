# 项目工程规范

基于 Flutter 官方推荐的架构模式与最佳实践

## 目录

1. 项目概述
2. 核心架构原则
3. 分层架构设计
4. MVVM 架构模式
5. UI 层实现规范
6. 数据层实现规范
7. 依赖注入规范
8. 项目结构组织
9. 核心库使用规范
10. 编码最佳实践
11. 错误与异常处理规范
12. 测试策略
13. 开发工作流

---

## 1. 项目概述

@PRD.md

架构技术栈：

- 架构模式：MVVM + Repository Pattern
- 状态管理：ChangeNotifier + ListenableBuilder
- 命令模式：flutter_command
- 结果处理：result_dart
- 依赖注入：provider
- 路由管理：go_router
- 数据模型：freezed
- 主题：Material Design 3，仅通过主题定义样式（禁止硬编码颜色、字号等）

工程约束：

- 变更代码后，必须执行 flutter analyze。禁止执行 flutter run。
- 所有样式必须来源于主题，不得硬编码颜色、字号、边距等。

---

## 2. 核心架构原则

1. 关注点分离

- UI 逻辑与业务逻辑分离
- 数据获取与展示分离
- 按功能模块组织代码
- 单一职责类

2. 单一数据源（SSOT）

- 每种数据类型由单一 Repository 负责
- 统一数据管理，避免重复与不一致

3. 单向数据流

- [数据层] → [逻辑层] → [UI 层]，用户操作通过 Command 反向触发数据更新

4. 声明式 UI

- 界面完全由状态驱动：\[UI = f(State)\]

5. 分层依赖原则

- ViewModel → Repository → Service
- 禁止 ViewModel 直接依赖 Service

6. 全局共享数据管理

- 通过共享的 Repository 实例统一管理

7. ViewModel 解耦

- ViewModel 之间禁止直接依赖，通信通过 Repository/Stream

8. Repository 通知机制

- Repository 使用 StreamController 暴露数据变更，禁止继承 ChangeNotifier

---

## 3. 分层架构设计

三层架构（与参考项目一致）：

- UI 层（Views & ViewModels）：展示与交互；通过 flutter_command 执行操作
- 逻辑层（Use Cases，可选）：封装复杂业务逻辑、协调多仓库
- 数据层（Repositories & Services）：数据管理、来源整合、结果处理、缓存策略

职责矩阵：
| 层次 | 组件 | 职责 |
|---|---|---|
| UI 层 | View, ViewModel | 页面展示、用户交互、状态管理 |
| 逻辑层 | Use Cases | 封装复杂业务、跨 Repository 协调 |
| 数据层 | Repository, Service | 统一数据访问、来源抽象与实现、错误与缓存 |

---

## 4. MVVM 架构模式

关系规则：

- 每个功能页面对应一个 View 与一个 ViewModel
- ViewModel 持有 Repository 的引用（或多个）
- Repository 可被多个 ViewModel 共享
- Service 专注单一数据源（如邮件、CSV、本地存储、URL Scheme 集成通道）

---

## 5. UI 层实现规范

View 规范：

- 构造函数仅接收 key 与 viewModel（或以 Provider 注入）
- 处理 Command 的执行态、完成态与错误态
- 不包含业务逻辑
- 所有用户交互经由 Command 执行

ViewModel 规范：

- 继承 ChangeNotifier
- 私有 final Repository 成员
- 使用 flutter_command 暴露用户动作（异步/同步）
- UI 状态 private setter + public getter
- 在构造中初始化 Commands
- 使用全局 appLogger 记录关键操作、错误与状态变更

Command 监听器规范：

- 在 initState 中订阅 results 与 errors 流
- 在 dispose 中取消订阅
- 使用 mounted 检查 Widget 生命周期

主题与样式：

- 遵循 Material Design 3
- 仅通过主题定义颜色、字号、密度、形状与间距；禁止硬编码
- 提供暗色 / 亮色方案和动态色适配（可选）

无障碍与国际化：

- 遵循 a11y 最佳实践（语义标签、可达性焦点顺序）
- 预留多语言能力（arb 文件与本地化代理）

---

## 6. 数据层实现规范

Repository 规范：

- 统一返回 Result<T>
- 负责缓存、错误与重试、模型转换（API/来源数据 → 领域模型）
- 多来源整合（邮件/CSV/本地等）在仓库层组合
- 通过 StreamController 广播数据变更
- 禁止继承 ChangeNotifier

Service 规范：

- 无状态类
- 单一数据源职责（如 MailIngestService、CsvIngestService、LocalStoreService、UrlSchemeService）
- 返回 Result<T>
- 统一错误处理与边界封装
- 私有底层依赖（如 Dio、SharedPreferences、平台通道）

来源扩展约束（可拓展性）：

- 为新来源定义独立 Service，遵循单一职责
- Repository 以组合/策略模式接入新增来源
- 对外 API 与领域模型稳定，新增来源不影响上层调用
- 使用接口/抽象类对来源进行契约约束，便于插件化扩展

---

## 7. 依赖注入规范

- 使用 Provider 完成依赖注入（应用级、模块级、页面级）
- 构造函数注入 Repository 至 ViewModel
- 在 config/dependencies.dart 统一注册与装配
- 提供测试替身注入入口（Mocks/Fakes）

---

## 8. 项目结构组织

建议目录：

```
lib/
├── main.dart                          # 应用入口
├── main_viewmodel.dart                # 应用级 ViewModel（主题/会话等）
│
├── config/
│   ├── dependencies.dart              # 依赖注入装配
│   └── env.dart                       # 运行环境配置（可选）
│
├── ui/
│   ├── core/
│   │   ├── theme.dart                 # M3 主题配置（禁止硬编码）
│   │   ├── main_layout.dart           # 通用布局
│   │   └── ui/                        # 通用组件（加载、错误、空态等）
│   │
│   ├── bills_list/                    # 账单列表视图
│   │   ├── view_models/
│   │   └── widgets/
│   │
│   ├── bills_calendar/                # 账单日历视图
│   │   ├── view_models/
│   │   └── widgets/
│   │
│   └── settings/                      # 设置与导入配置
│       ├── view_models/
│       └── widgets/
│
├── domain/
│   ├── models/                        # 领域模型（freezed）
│   │   ├── bill/
│   │   └── source/                    # 来源/渠道定义与枚举
│   └── use_cases/                     # 复杂业务用例（可选）
│
├── data/
│   ├── repository/
│   │   ├── bill/                      # BillRepository（SSOT）
│   │   └── settings/                  # 配置相关仓库
│   └── service/
│       ├── mail_ingest_service.dart   # 邮件导入
│       ├── csv_ingest_service.dart    # CSV 导入
│       ├── local_store_service.dart   # 本地存储（数据库/Prefs）
│       ├── url_scheme_service.dart    # URL Scheme 集成（导入到一木记账）
│       └── platform/                  # 平台通道封装（如 iOS/Android）
│
├── routing/
│   ├── router.dart                    # go_router 配置
│   └── routes.dart                    # 路由常量
│
└── utils/
    ├── logger.dart                    # appLogger
    ├── exceptions.dart                # 统一异常
    └── option_data.dart               # 工具
```

测试与资源：

```
test/
├── unit/
│   ├── data/
│   ├── domain/
│   └── ui/
├── widget/
├── integration/
└── helpers/

test_resources/
├── mocks/
└── fixtures/
```

命名规范（与参考保持一致）：
| 类型 | 命名 | 示例 |
|---|---|---|
| ViewModel | {Feature}ViewModel | BillsListViewModel |
| Screen | {Feature}Screen | BillsCalendarScreen |
| Repository | {Domain}Repository | BillRepository |
| Service | {Purpose}Service | MailIngestService |
| Model | {Entity}/{Entity}ApiModel | Bill/BillCsvModel |
| UseCase | {Action}UseCase | MergeBillSourcesUseCase |
| Exception | {Context}Exception | IngestFailedException |

---

## 9. 核心库使用规范

- flutter_command：所有交互动作以 Command 暴露，使用 results/errors 订阅
- result_dart：所有失败可能的操作统一返回 Result<T>；在 VM 中使用 isSuccess/getOrNull/exceptionOrNull 处理
- provider：多层级依赖注入，支持测试替身
- freezed：所有模型不可变，集中定义 copyWith/equality 与序列化
- go_router：集中路由与导航栈管理

---

## 10. 编码最佳实践

强制要求：

- 分层清晰：View 不直接访问 Repository，所有数据经 ViewModel
- MVVM：每个页面 1:1 的 View 与 ViewModel
- Command 模式：用户交互通过 Command.execute()
- Result 模式：错误路径明确、可测试
- 依赖注入：Provider 装配，构造注入依赖
- 不可变模型：使用 freezed
- 主题化：无硬编码样式，统一从 Theme 中取值
- 每次代码修改后执行 flutter analyze；切勿执行 flutter run

推荐实践：

- Use Case：封装跨仓库的复杂流程
- 缓存策略：仓库实现内存/本地缓存
- 离线支持：本地存储容错与回放
- 统一日志：appLogger 在 VM/Repository 关键路径打点

---

## 10.1. 单一数据源（SSOT）实施指南

### 核心原则

**禁止数据重复缓存**：
- ViewModel 不得缓存来自 Repository 的业务数据
- UI 组件不得维护自己的状态数据
- 所有数据变更必须通过 Repository 进行

### ViewModel 实施规范

**✅ 正确做法**：
```dart
class LibraryViewModel extends ChangeNotifier {
  final GameRepository _gameRepository;
  
  // 仅保留UI专用状态
  bool _isLoading = false;
  String _searchQuery = '';
  
  // 动态从Repository获取数据
  List<Game> get games => _getFilteredGames();
  Map<int, GameStatus> get gameStatuses => _gameRepository.gameStatuses;
  
  List<Game> _getFilteredGames() {
    // 实时从Repository获取并筛选
    return _gameRepository.gameLibrary.where(...);
  }
}
```

**❌ 错误做法**：
```dart
class LibraryViewModel extends ChangeNotifier {
  // 违规：缓存了Repository中的数据
  List<Game> _games = [];
  Map<int, GameStatus> _gameStatuses = {};
  
  // 违规：返回缓存的数据而非实时获取
  List<Game> get games => _games;
}
```

### UI组件实施规范

**✅ 正确做法**：
```dart
class GameListWidget extends StatelessWidget {
  Widget build(BuildContext context) {
    return Consumer<LibraryViewModel>(
      builder: (context, viewModel, child) {
        // 直接从ViewModel获取数据
        final games = viewModel.games;
        return ListView.builder(...);
      },
    );
  }
}
```

**❌ 错误做法**：
```dart
class GameListWidget extends StatefulWidget {
  State<GameListWidget> createState() => _GameListWidgetState();
}

class _GameListWidgetState extends State<GameListWidget> {
  // 违规：在Widget中缓存数据
  List<Game> _localGames = [];
  
  void initState() {
    // 违规：从ViewModel复制数据到本地
    _localGames = context.read<LibraryViewModel>().games;
  }
}
```

### Repository责任边界

**Repository 负责**：
- 数据的唯一存储和缓存
- 数据变更的统一管理
- 通过 Stream 广播数据变更
- 数据持久化和同步

**ViewModel 负责**：
- UI状态管理（加载、错误、筛选条件等）
- 将用户操作转换为 Repository 调用
- 数据的展示逻辑（筛选、排序、格式化）

**UI组件 负责**：
- 纯展示和用户交互
- 不维护任何业务状态
- 通过 ViewModel 获取所有数据

### 违规检查清单

**ViewModel检查项**：
- [ ] 是否缓存了Repository中存在的数据？
- [ ] getter是否直接返回缓存字段而非从Repository获取？
- [ ] 是否监听Repository的Stream并更新本地缓存？
- [ ] 状态更新方法是否同时更新本地缓存和Repository？

**UI组件检查项**：
- [ ] StatefulWidget是否存储了业务数据？
- [ ] 是否从ViewModel复制数据到本地变量？
- [ ] 是否直接调用Repository而跳过ViewModel？
- [ ] 是否使用Consumer/Provider正确获取最新数据？

**Repository检查项**：
- [ ] 是否通过Stream暴露数据变更？
- [ ] 数据是否只在Repository中存在单一副本？
- [ ] 是否正确处理数据的增删改查？

### 常见违规模式及修复

**模式1：ViewModel缓存Repository数据**
```dart
// 违规
class MyViewModel {
  List<Game> _games = [];
  
  void loadGames() {
    _games = _repository.gameLibrary; // 创建了数据副本
  }
}

// 修复
class MyViewModel {
  List<Game> get games => _repository.gameLibrary; // 直接获取
}
```

**模式2：UI组件状态缓存**
```dart
// 违规
class _MyWidgetState {
  List<Game> _localGames = [];
  
  void initState() {
    _localGames = widget.viewModel.games;
  }
}

// 修复
class MyWidget {
  Widget build(context) {
    return Consumer<MyViewModel>(
      builder: (context, viewModel, child) {
        return ListView(children: viewModel.games.map(...));
      },
    );
  }
}
```

**模式3：重复的数据同步逻辑**
```dart
// 违规
class MyViewModel {
  void updateGame(Game game) {
    _repository.updateGame(game);
    _localGames = _repository.gameLibrary; // 重复同步
  }
}

// 修复
class MyViewModel {
  void updateGame(Game game) {
    _repository.updateGame(game); // Repository通过Stream通知变更
    // ViewModel通过getter自动获取最新数据
  }
}
```

---

## 11. 错误与异常处理规范

统一错误页面组件：

- 位置：lib/ui/core/ui/error_page.dart
- 所有错误态统一走 ErrorPage 工厂方法（如 ErrorPage.fromException(e)）
- 异常分层：Service 抛领域内可解释异常，Repository 转换与聚合后返回 Result 失败分支
- 主题一致：错误组件遵循主题与密度体系
- 用户反馈：清晰提示与可选重试入口

异常分型建议：

- IngestFailedException（来源导入失败）
- ParseException（CSV/邮件解析失败）
- NetworkException（网络错误）
- StorageException（本地存储错误）
- UrlSchemeException（外部导入/跳转错误）
- UnsupportedSourceException（不受支持的来源/格式）

---

## 12. 测试策略

覆盖要求：

- Repository 层与 ViewModel 层 100% 覆盖率目标
- 关键 Widget 的 UI 测试
- Command 执行流与错误路径测试
- Result 处理逻辑测试
- 路由与深链（URL Scheme）集成测试（可在集成测试中验证）

测试资源：

- 使用 fixtures 提供 CSV/邮件样本
- 使用 mocks/stubs 替代外部依赖（Service/平台通道）

---

## 13. 开发工作流

- 版本与提交：采用 semantic-release，提交信息遵循 Conventional Commits
- feat/fix/refactor/docs/style/test/perf/ci/build/chore/revert
- TDD：先写失败测试，再实现功能
- 代码质量：每次提交前执行 flutter analyze
- 代码生成：涉及 Mockito/Freezed 等代码生成问题时，先运行 flutter pub run build_runner build

---

附加约束与说明

- URL Scheme 集成仅定义在 Service 与 Repository 层对外的抽象契约；UI 通过 ViewModel 的 Command 触发
- 多来源导入需通过统一的领域模型输出，来源差异在 Service 内部处理
- 如需新增来源/视图，严格遵循现有分层与依赖规则，确保对上层无破坏性变更

本规范为项目基础骨架与约束，后续可在不改变架构与技术栈前提下增补模块级细则与代码模板。
