---
name: nextplay-android-e2e
description: Run and diagnose NextPlay's deterministic Android verification loop. Use for Android, Flutter UI, navigation, startup, secure-storage migration, dependency composition, integration-test, APK installation, emulator, or GitHub Actions Android E2E changes and failures; also use whenever a request asks Codex to build, launch, click through, or prove a NextPlay change in the real Android runtime.
---

# NextPlay Android E2E

Use the repository-owned commands as the source of truth. Prefer Flutter test APIs, ADB, UI Automator output, screenshots, and scoped logs. Treat Computer Use as a fallback only when no stable programmatic path exists.

## Establish scope

1. Work from the repository root and read `AGENTS.md`.
2. Inspect `git status --short` before changing anything. Preserve unrelated user changes.
3. Read `docs/agentic-development.md` when test architecture, credentials, selectors, or human handoff boundaries matter.
4. In a linked worktree, run `tool/worktree.sh setup` before other commands. It installs locked dependencies, generates required sources, and seeds the ignored `.env` without overwriting an existing copy.
5. Never print or commit `.env`, credentials, `.artifacts/`, signing material, local databases, screenshots, UI dumps, or logs.

## Select the required gates

- Run `tool/verify_fast.sh` after every code change. It owns dependency resolution, code generation, formatting checks, analysis, host tests, and the coverage gate.
- Also run `tool/e2e_android.sh` for UI, navigation, startup, Android integration, dependency-composition, persistence, secure-storage, or automation-selector changes.
- Run `tool/live_smoke.sh` separately only when the change affects a live IGDB or Steam contract. Deterministic E2E uses injected fakes and does not prove live-service health.
- Validate workflow-only edits with a YAML parser and `git diff --check`, then exercise the workflow through an authorized push when CI confirmation is in scope.

Do not substitute source inspection, `flutter analyze`, a screenshot alone, or raw `flutter run` for the required gates.

## Run local Android verification

Execute:

```bash
tool/verify_fast.sh
tool/e2e_android.sh
```

In a linked worktree, prefer the lifecycle wrapper so setup cannot be skipped:

```bash
tool/worktree.sh e2e
```

The wrapper and direct runner acquire the same lease under the Git common directory, so invoking `tool/e2e_android.sh` directly cannot bypass serialization.

When selecting an already-running dedicated emulator, use:

```bash
NEXTPLAY_ANDROID_DEVICE=emulator-5554 tool/e2e_android.sh
```

Do not select an arbitrary physical or daily-use device. An explicit serial must report the configured `NEXTPLAY_AVD`; otherwise the runner fails closed. Without an explicit device, the runner reuses or starts only `NEXTPLAY_AVD` and clears only `me.zqydev.nextplay.debug`.

All NextPlay worktrees share the one configured AVD. If another worktree owns it, wait for the shared lease or set a bounded `NEXTPLAY_ANDROID_LEASE_TIMEOUT_SECONDS`; never start a second arbitrary AVD to evade contention. Inspect ownership with `tool/worktree.sh status`. Use `tool/worktree.sh down` only for verified stale runtime state owned by the current worktree.

Expect the Android runner to:

1. Run `integration_test/app_flow_test.dart` with deterministic injected dependencies.
2. Exercise secure-storage migration plus credential-free onboarding and core navigation.
3. Build an ABI-scoped debug APK, install it, clear app state, and launch the production entry point.
4. Assert the onboarding UI with ADB/UI Automator and reject fatal Android runtime logs.
5. Write evidence under `.artifacts/e2e/<timestamp>/` and stop only an emulator that it started.
6. For every runtime, UI, navigation, or interaction change, identify the changed key states before running E2E and capture a named screenshot for each important state after the app reaches it. Keep these screenshots under `.artifacts/e2e/<timestamp>/` for user confirmation; the runner's generic final screenshot alone is not sufficient. Use ADB `screencap` or an equivalent repository-owned capture path, and label screenshots taken with injected fakes or other simulated boundaries.

Treat success from the integration test and success from the standalone build/install/launch assertion as separate requirements.

## Diagnose failures from evidence

Start with the first failing command and the artifact directory printed by the runner. Do not blindly rerun before inspecting it.

Inspect available evidence:

```bash
rg -n -C 6 'FATAL EXCEPTION|AndroidRuntime.*FATAL|Exception|Error|failed|Failure' .artifacts/e2e/<timestamp>
rg -n 'text=|content-desc=|resource-id=' .artifacts/e2e/<timestamp>/*.xml
```

Use image inspection for `screenshot.png`. Read these files according to the symptom:

- `ui.xml` and `launcher-ui.xml`: visible app state, stable text, and system overlays.
- `logcat.txt`: app-scoped crash and platform-plugin evidence.
- `launch.txt`: Activity Manager launch result.
- `emulator.log`: boot, graphics, and emulator failures when the runner started the AVD.
- Named key-state screenshots: visual evidence for the changed screen or interaction, which must be reviewed and reported to the user.

Distinguish application failures from harness or emulator failures:

- If the app is visible behind a `Pixel Launcher isn't responding` or `System UI isn't responding` dialog, treat it as a known system overlay. The runner should dismiss its `android:id/aerr_close` control and then re-check NextPlay; do not weaken the NextPlay UI assertion.
- If generated Freezed or JSON files are missing only in CI, remember that GitHub jobs have isolated checkouts. Generate code inside every job that compiles the app.
- If a runner command such as `rg` is absent, install and version-check it in that CI job.
- If a state test depends on a fixed delay, await the command or operation's completion future instead of increasing the sleep.
- If deterministic tests pass but live calls fail, switch to the explicit live-smoke path and diagnose the local/public service separately.

Make the narrowest source, test, runner, or workflow fix supported by the evidence. Re-run every gate affected by that fix.

## Close the GitHub Actions loop

After an authorized push, find and monitor the exact run for the pushed SHA:

```bash
gh run list --workflow Build --branch main --limit 10 \
  --json databaseId,headSha,status,conclusion,url
gh run watch <run-id> --interval 20 --exit-status
```

On failure, retrieve the failed log and Android evidence before editing:

```bash
gh run view <run-id> --log-failed
gh run download <run-id> -n android-e2e-evidence -D <temporary-directory>
```

Use a temporary directory outside the repository for downloaded CI evidence. Remember that `Build Debug APK` is intentionally skipped for pushes and runs only for pull requests; do not misreport that skip as a failure.

Continue until the exact pushed SHA reports successful `Test and Analyze` and `Android E2E`, or report a genuine external blocker. Do not call a CI repair complete while the replacement run is pending.

## Completion contract

Before handing off:

1. Confirm the required local gates passed after the final edit.
2. Confirm real Android build/install/launch behavior for runtime-relevant changes.
3. Confirm the exact remote run is green when a push was part of the task.
4. Check `git status --short` and distinguish this work from pre-existing user changes.
5. Confirm the shared Android lease and owned runtime state were released; an emulator that predated the run should still be running.
6. Report the exercised behavior, CI run link, commit when applicable, and any untested or simulated boundary.
7. For runtime/UI changes, report the named key-state screenshot paths and explicitly state which changed locations they confirm.

Never claim full Android closure from code review or host tests alone.
