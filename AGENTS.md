## NextPlay engineering loop

- Run all commands from the repository root.
- Initialize a primary or linked checkout with `tool/worktree.sh setup`. Linked worktrees copy the primary checkout's complete `.env` only when their local file is absent; refresh it explicitly with `tool/worktree.sh env:pull`, and never write credentials back automatically.
- Do not use raw `flutter run`. Use `tool/e2e_android.sh` for Android integration, installation, launcher checks, screenshots, UI hierarchy, and scoped logs.
- Android E2E is serialized across all Git worktrees through one shared AVD lease. Inspect ownership with `tool/worktree.sh status`; use `tool/worktree.sh down` only to recover stale runtime state owned by the current worktree.
- Before handing off a code change, run `tool/verify_fast.sh`. The command owns dependency resolution, code generation, formatting checks, `flutter analyze`, tests, and the coverage gate.
- The Flutter app stays at the repository root; the Bun metadata service lives in `services/igdb`. Run it only through `tool/service.sh` from the repository root. `tool/verify_fast.sh` verifies both projects.
- Keep service credentials only in ignored `services/igdb/.env` or the process environment. Never copy credentials into committed root configuration or print them. Use `tool/service.sh deploy` so PM2 runs the binary from the monorepo path.
- Local automation configuration is loaded from the ignored repository-root `.env`; keep the committed `.env.example` current. Only `NEXTPLAY_*` assignments are accepted, and an explicitly exported environment variable overrides the file.
- Use `tool/live_smoke.sh` only for explicit live-service verification. IGDB checks are credential-free; Steam checks are opt-in through `NEXTPLAY_STEAM_API_KEY` and `NEXTPLAY_STEAM_ID` from `.env` or the process environment and must never print either value.
- Keep production composition in `AppDependencies.production()`. Tests and integration harnesses must inject fakes through `AppDependencies.create()`; test fixtures must never be selected from production `main()`.
- Persist Steam API keys only through `ApiKeyStorage`. The SharedPreferences `api_key` key is a read-only legacy migration source: never add a new production write to it, and remove it only after the secure copy has been read back successfully.
- Use `AppKeys` for automation-facing controls and states. Existing key strings are compatibility contracts: add new keys freely, but rename or remove an existing key only with matching test and documentation updates.
- After every code change, proactively run a real local build and tests appropriate to the change before handing it off. Static inspection, source diffs, or analysis alone are not sufficient. When runtime behavior changes, verify it in the actual target runtime, compare relevant before-and-after behavior, and clearly disclose any simulated or unexercised part of the flow.
- A change is complete only when fast verification passes. UI or navigation changes additionally require the Android E2E runner. External-contract changes additionally require the relevant live smoke check.
- Preserve `.artifacts/` and `.env` as ignored local state. Do not commit screenshots, UI dumps, logs, API keys, Steam IDs, signing material, or local databases.

<!-- ai-rules:routing:start -->
## Shared rule routing

共享规则根目录为 `.ai/rules/`。不要扫描或全量读取该目录。

开始任务前，根据当前任务涉及的文件和目标读取下表中匹配的入口。若同时匹配多行，
读取所有对应入口；随后只按各入口 `index.md` 的指引继续按需读取。

| 范围或触发条件 | 首先读取 |
|---|---|
| 修改仓库自有代码、测试、构建配置、验收脚本或发布流程 | `.ai/rules/verification/index.md` |
| `pubspec.yaml`、`lib/**`、`test/**`、`integration_test/**` 或 Flutter 构建 | `.ai/rules/flutter/index.md` |
| `android/**`、Gradle、APK、模拟器、真机或 `tool/e2e_android.sh` | `.ai/rules/android/index.md` |
| 用户可见 UI、交互或导航 | `.ai/rules/ui-acceptance/index.md` |
| Git、PR、提交、分支、交付或 worktree 操作 | `.ai/rules/git/index.md` |

如果 `.ai/rules` 不存在或路由目标不可读，先说明共享规则未加载，再继续遵守本文件中
提交到项目的约定。项目规则以及更靠近工作文件的 `AGENTS.md` 优先于共享规则；其他
冲突不要自行猜测，应向用户报告。
<!-- ai-rules:routing:end -->
