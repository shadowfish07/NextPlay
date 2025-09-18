# NextPlay 项目结构

## 主要目录结构
```
lib/
├── main.dart                          # 应用入口
├── main_viewmodel.dart                # 应用级 ViewModel
│
├── config/
│   ├── dependencies.dart              # 依赖注入装配
│   └── env.dart                       # 运行环境配置
│
├── ui/                                # UI层
│   ├── core/
│   │   ├── theme.dart                 # M3 主题配置
│   │   ├── main_layout.dart           # 通用布局
│   │   └── ui/                        # 通用组件
│   │
│   ├── discover/                      # 发现页（推荐功能）
│   │   ├── view_models/
│   │   └── widgets/
│   │
│   ├── library/                       # 游戏库页（状态管理）
│   │   ├── view_models/
│   │   └── widgets/
│   │
│   ├── game_details/                  # 游戏详情页
│   │   ├── view_models/
│   │   └── widgets/
│   │
│   ├── game_status/                   # 游戏状态管理
│   │   ├── view_models/
│   │   └── widgets/
│   │
│   ├── settings/                      # 设置页
│   │   ├── view_models/
│   │   └── widgets/
│   │
│   └── onboarding/                    # 引导页
│       ├── view_models/
│       └── widgets/
│
├── domain/                            # 领域层
│   ├── models/                        # 领域模型（freezed）
│   │   ├── game/
│   │   ├── discover/
│   │   ├── game_status/
│   │   ├── user/
│   │   └── onboarding/
│   └── use_cases/                     # 业务用例（可选）
│
├── data/                              # 数据层
│   ├── repository/                    # 仓库（统一数据访问）
│   │   ├── game/
│   │   ├── user/
│   │   └── onboarding/
│   └── service/                       # 服务（数据源）
│
├── routing/                           # 路由配置
│   ├── router.dart
│   └── routes.dart
│
└── utils/                             # 工具类
    ├── logger.dart
    ├── exceptions.dart
    └── extensions.dart
```

## 核心游戏卡片组件
- `GameRecommendationCard`: 主推荐大卡片（发现页）
- `SmallGameCard`: 小推荐卡片（横向滚动列表）
- `GameLibraryCard`: 游戏库列表卡片
- `GalleryGameCard`: 游戏库网格卡片
- `NewGameRecommendationCard`: 新游戏推荐卡片