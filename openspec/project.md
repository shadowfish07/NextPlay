# Project Context

## Purpose

NextPlay 是一款基于 Steam 游戏库的智能游戏推荐应用。通过连接用户的 Steam 账户，帮助用户从庞大的游戏库中智能推荐下一款值得游玩的游戏，解决玩家的"选择困难症"。

核心价值：

- **智能推荐**：基于游戏状态、类型平衡、用户偏好的个性化推荐
- **状态管理**：简化游戏库管理，清晰追踪游玩进度
- **纯本地化**：无需后端服务，数据完全存储在本地，保护用户隐私

## Tech Stack

- **框架**: Flutter (Android 平台)
- **设计规范**: Material Design 3 (M3)
- **架构模式**: MVVM + Repository Pattern
- **状态管理**: ChangeNotifier + ListenableBuilder
- **命令模式**: flutter_command
- **结果处理**: result_dart
- **依赖注入**: provider
- **路由管理**: go_router
- **数据模型**: freezed
- **本地数据库**: SQLite (sqflite)
- **配置存储**: SharedPreferences

## Project Conventions

### Code Style

**命名规范**：
| 类型 | 命名格式 | 示例 |
|------|----------|------|
| ViewModel | {Feature}ViewModel | BillsListViewModel |
| Screen | {Feature}Screen | BillsCalendarScreen |
| Repository | {Domain}Repository | GameRepository |
| Service | {Purpose}Service | SteamApiService |
| Model | {Entity} | Game, GameStatus |
| Exception | {Context}Exception | NetworkException |

**文件组织**：

- 按功能模块组织代码
- View 与 ViewModel 1:1 对应
- 所有样式必须来源于主题，禁止硬编码颜色、字号、边距等

### Architecture Patterns

**三层架构**：

- **UI 层** (Views & ViewModels)：展示与交互，通过 flutter_command 执行操作
- **逻辑层** (Use Cases，可选)：封装复杂业务逻辑、协调多仓库
- **数据层** (Repositories & Services)：数据管理、来源整合、结果处理、缓存策略

**核心原则**：

1. **单一数据源 (SSOT)**：每种数据类型由单一 Repository 负责
2. **单向数据流**：[数据层] → [逻辑层] → [UI 层]
3. **声明式 UI**：界面完全由状态驱动 [UI = f(State)]
4. **分层依赖**：ViewModel → Repository → Service，禁止 ViewModel 直接依赖 Service
5. **Repository 通知机制**：使用 StreamController 暴露数据变更，禁止继承 ChangeNotifier

**SSOT 实施要点**：

- ViewModel 不得缓存来自 Repository 的业务数据
- UI 组件不得维护自己的状态数据
- 所有数据变更必须通过 Repository 进行

### Testing Strategy

- Repository 层与 ViewModel 层 100% 覆盖率目标
- 关键 Widget 的 UI 测试
- Command 执行流与错误路径测试
- Result 处理逻辑测试
- 使用 fixtures 提供测试样本
- 使用 mocks/stubs 替代外部依赖

### Git Workflow

- **提交规范**: Conventional Commits (feat/fix/refactor/docs/style/test/perf/ci/build/chore/revert)
- **PR 关联**: 提交 PR 时需使用 GitHub issue 关联语法关联上 issue
- **代码质量**: 每次提交前执行 `flutter analyze`

## Domain Context

**游戏状态分类**：

线性/剧情游戏：

- 未开始、游玩中、已通关、n 周目标记

可重玩/网络游戏：

- 未开始、游玩中、暂时搁置、彻底不玩、多人游戏

**推荐算法考量**：

- 优先推荐"未开始"和"游玩中"状态的游戏
- 游戏类型平衡：避免连续推荐同类型游戏
- 支持时间预算筛选（短/中/长游戏）
- 支持心情匹配（轻松/挑战/思考/社交）

## Important Constraints

- **纯客户端应用**：无后端依赖，所有数据存储在本地
- **禁止执行 flutter run**：变更代码后必须执行 `flutter analyze`
- **主题化强制**：所有样式必须来源于 M3 主题，禁止硬编码

## Application Features

### 发现页（游戏概览）

发现页展示玩家的游戏活动数据和推荐，页面结构从上到下：

1. **活动统计卡片**
   - 今日游玩游戏数量（基于 `lastPlayed` 在今天）
   - 本周游玩游戏数量（基于 `lastPlayed` 在本周）
   - 本月游玩游戏数量（基于 `lastPlayed` 在本月）
   - 近两周总时长（汇总 `playtimeLastTwoWeeks`）

2. **最近在玩**（横向滚动列表）
   - 按 `lastPlayed` 降序排列
   - 最多展示 10 个游戏
   - 无数据时隐藏该区域

3. **本月热玩**（横向滚动列表）
   - 本月玩过且按 `playtimeLastTwoWeeks` 降序排列
   - 最多展示 5 个游戏
   - 无数据时隐藏该区域

4. **发现新游戏**（推荐区域）
   - 1 个主推荐大卡片 + 3 个备选小卡片
   - 推荐条件：`playtimeForever = 0` 的未玩游戏
   - 随机展示

**数据来源限制**：Steam API 仅提供 `playtimeLastTwoWeeks`（近两周时长）和 `lastPlayed`（最后游玩时间），无法获取精确的每日/每周/每月时长数据。

### 游戏库页

- 游戏列表展示与管理
- 搜索、筛选、排序功能
- 批量状态更新
- 长按进入多选模式

### 设置页

- Steam 连接状态管理
- 游戏库同步
- 应用信息和帮助

## External Dependencies

### Steam Web API

- 用户提供 API Key
- 获取用户游戏库列表、游戏时长、最后游玩时间、成就完成情况

### IGDB Steam Game Service

- 封装的 TypeScript + Bun 服务器（本地部署）
- 端点：POST /api/games
- 请求参数：steamIds (Steam app IDs 数组, 最多 100 个), forceRefresh (可选)
- 响应数据：游戏详细信息（名称、简介、封面、评分、类型、主题、游戏模式、相似游戏等）
- 内置 SQLite 缓存和速率限制处理（批量处理 + 250ms 延迟）
- 底层通过 Twitch OAuth 访问 IGDB API
- 服务地址：https://igdb.zqydev.me
