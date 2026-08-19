<!-- OPENSPEC:START -->

# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:

- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:

- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

每次改变接口行为时，必须自检是否需要更新 README.md 的接口描述

在 NextPlay 单仓中从仓库根目录运行 `tool/service.sh <command>`，不要依赖旧的独立仓库路径。服务端凭据只允许保存在忽略的 `services/igdb/.env` 或进程环境中。
