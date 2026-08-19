# Worktree development

NextPlay supports primary and linked Git worktrees while sharing one dedicated Android Virtual Device. Source builds and host tests can run in parallel. Android E2E runs are serialized because every run installs and clears the same debug package on the same AVD.

## State contract

The primary checkout is the first checkout reported by `git worktree list --porcelain`. Setup does not infer ownership from a directory or branch name.

| State | Worktree behavior | Reverse synchronization |
| --- | --- | --- |
| Tracked source and `pubspec.lock` | Provided by Git | Through Git only |
| `.env` and all `NEXTPLAY_*` credentials | Copied from primary once with mode `0600`; explicit refresh only | Never |
| `.dart_tool/`, `build/`, coverage, generated Dart | Created independently in each checkout | Never |
| `.artifacts/` and logs | Created independently in each checkout | Never |
| SQLite, SharedPreferences, secure storage, WebView state | Stored inside the leased AVD | Never |
| Keystores and signing files | Not copied by worktree setup | Never |
| Worktree metadata | `.nextplay-worktree/`, mode `0700`, ignored | Never |

There is no `data:push` command. Application data is device-local, and deterministic E2E clears the debug package deliberately.

## Commands

Run every command from the checkout it should operate on.

```bash
# Idempotent dependency and local-state setup.
tool/worktree.sh setup

# Show role, stable identity, env provenance, configured AVD, and lease owner.
tool/worktree.sh status

# Run the existing Android runner under the shared lease.
tool/worktree.sh e2e

# Replace a linked worktree's .env from primary after creating a local backup.
tool/worktree.sh env:pull

# Recover only stale Android state owned by this worktree.
tool/worktree.sh down
```

Setup runs `flutter pub get --enforce-lockfile` followed by the repository's build-runner generation. Repeating setup preserves an existing `.env` and any worktree-local investigation state while bringing ignored generated Dart files up to date. If primary has no `.env`, setup keeps an existing linked copy or skips the copy without deleting anything.

`env:pull` is primary to linked only. Backups are written under `.nextplay-worktree/env-backup-<timestamp>.<suffix>/.env`, remain ignored, and contain credentials. The command refuses to replace `.env` while this worktree owns an active Android E2E run.

## Shared Android lease

The lease lives at `<git-common-dir>/nextplay-android-e2e.lock`. The default wait is 900 seconds and can be changed in `.env`:

```bash
NEXTPLAY_ANDROID_LEASE_TIMEOUT_SECONDS=900
```

Both `tool/worktree.sh e2e` and direct `tool/e2e_android.sh` invocations use the same lease. A selected `NEXTPLAY_ANDROID_DEVICE` must report the configured `NEXTPLAY_AVD`; arbitrary physical devices and unrelated emulators fail closed.

The runner records its owned runtime under `.nextplay-worktree/e2e-runtime/`. Normal exit collects evidence, stops only an emulator that the run started, removes local runtime state, and releases the lease. An already-running configured AVD remains running.

If a foreground run is active, `tool/worktree.sh down` refuses to terminate it; interrupt the owning terminal so its normal cleanup runs. If the process died without cleanup, `down` verifies the worktree token, AVD name, serial or emulator command, then stops only the orphan it can prove belongs to this checkout. Running `down` twice is a harmless no-op.

## Worktree-manager hooks

Orca reads the committed repository-root `orca.yaml`, which wires the lifecycle commands below. Other worktree managers should use the same repository commands rather than manager-specific copy rules:

```text
Setup hook:   tool/worktree.sh setup
Archive hook: tool/worktree.sh down
```

The hook run policy and agent startup policy remain local Orca repository settings rather than `orca.yaml` fields. Keep setup at `run-by-default` and agent startup at `wait-for-setup` so an agent cannot race dependency resolution or code generation.

Archive hooks are best-effort. The foreground E2E process remains the primary lifecycle owner, and stale cleanup is always available from the checkout before it is removed.

## Validation gates

After changing the worktree tooling:

1. Create two disposable linked worktrees and run setup twice in each.
2. Confirm `.env` is mode `0600`, is independent, and the primary checksum is unchanged.
3. Start Android E2E in one worktree and confirm the other waits or times out without touching the AVD.
4. Confirm normal completion releases the lease and `down` is idempotent.
5. Run `tool/verify_fast.sh` and one complete `tool/e2e_android.sh` build/install/launch assertion.
