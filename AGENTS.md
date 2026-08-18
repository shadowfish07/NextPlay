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

## NextPlay engineering loop

- Run all commands from the repository root.
- Do not use raw `flutter run`. Use `tool/e2e_android.sh` for Android integration, installation, launcher checks, screenshots, UI hierarchy, and scoped logs.
- Before handing off a code change, run `tool/verify_fast.sh`. The command owns dependency resolution, code generation, formatting checks, `flutter analyze`, tests, and the coverage gate.
- Use `tool/live_smoke.sh` only for explicit live-service verification. IGDB checks are credential-free; Steam checks are opt-in through `NEXTPLAY_STEAM_API_KEY` and `NEXTPLAY_STEAM_ID` and must never print either value.
- Keep production composition in `AppDependencies.production()`. Tests and integration harnesses must inject fakes through `AppDependencies.create()`; test fixtures must never be selected from production `main()`.
- Use `AppKeys` for automation-facing controls and states. Existing key strings are compatibility contracts: add new keys freely, but rename or remove an existing key only with matching test and documentation updates.
- A change is complete only when fast verification passes. UI or navigation changes additionally require the Android E2E runner. External-contract changes additionally require the relevant live smoke check.
- Preserve `.artifacts/` as ignored, local evidence. Do not commit screenshots, UI dumps, logs, API keys, Steam IDs, signing material, or local databases.
