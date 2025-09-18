# NextPlay 开发规范与约束

## 核心架构原则
1. **关注点分离**: UI 逻辑与业务逻辑分离
2. **单一数据源(SSOT)**: 每种数据类型由单一 Repository 负责
3. **单向数据流**: [数据层] → [逻辑层] → [UI 层]
4. **声明式 UI**: 界面完全由状态驱动 [UI = f(State)]
5. **分层依赖**: ViewModel → Repository → Service

## MVVM 架构规范
- 每个功能页面对应一个 View 与一个 ViewModel
- ViewModel 继承 ChangeNotifier
- 使用 flutter_command 暴露用户动作
- Repository 禁止继承 ChangeNotifier，使用 StreamController 广播数据变更
- 所有失败可能的操作统一返回 Result<T>

## UI 层规范
- 构造函数仅接收 key 与 viewModel（或通过 Provider 注入）
- 处理 Command 的执行态、完成态与错误态
- 不包含业务逻辑，所有用户交互经由 Command 执行
- 遵循 Material Design 3，禁止硬编码颜色、字号、边距等
- 仅通过主题定义样式

## 数据层规范
- Repository 统一返回 Result<T>
- Service 无状态类，单一数据源职责
- 统一错误处理与边界封装
- 通过 StreamController 广播数据变更

## 命名规范
| 类型 | 命名 | 示例 |
|---|---|---|
| ViewModel | {Feature}ViewModel | DiscoverViewModel |
| Screen | {Feature}Screen | DiscoverScreen |
| Repository | {Domain}Repository | GameRepository |
| Service | {Purpose}Service | SteamApiService |
| Model | {Entity} | Game, GameStatus |

## 工程约束
- 变更代码后，必须执行 flutter analyze
- 禁止执行 flutter run
- 所有样式必须来源于主题，不得硬编码
- 使用全局 appLogger 记录关键操作、错误与状态变更