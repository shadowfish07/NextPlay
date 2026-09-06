import { withArchiveLease } from "./lease";
import { deleteAccount } from "./lifecycle";
import { applyRemoteDeletions, recoverHistory } from "./backup";
import { join, resolve } from "node:path";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { HistoryRuntime, loadAccounts } from "./runtime";
import { OneDriveRemote } from "./onedrive";
import { HistoryArchiver, type ArchiveRow } from "./archive";

const root = process.env.NEXTPLAY_HISTORY_DIR ?? "data/history";
const command = process.argv[2];
async function main() {
  if (command === "login") {
    const clientId = process.env.NEXTPLAY_ONEDRIVE_CLIENT_ID;
    if (!clientId)
      throw new Error(
        "Set NEXTPLAY_ONEDRIVE_CLIENT_ID for a public-client Microsoft app first",
      );
    const remote = new OneDriveRemote(
      clientId,
      join(root, "onedrive-token.json"),
      process.env.NEXTPLAY_ONEDRIVE_FOLDER_ID ?? "root",
      fetch,
      process.env.NEXTPLAY_ONEDRIVE_TENANT ?? "consumers",
    );
    const device = await remote.beginLogin();
    console.log(device.message); // User-facing short-lived device code, never OAuth tokens.
    const expires = Date.now() + device.expires_in * 1000;
    let delay = Math.max(device.interval, 5) * 1000;
    while (Date.now() < expires) {
      await Bun.sleep(delay);
      const state = await remote.completeLogin(device.device_code);
      if (state === "complete") {
        console.log("OneDrive authorization saved securely.");
        return;
      }
      if (state === "slow_down") delay += 5000;
    }
    throw new Error("OneDrive authorization expired");
  }
  if (
    ![
      "status",
      "collect",
      "archive",
      "restore",
      "recover",
      "backup",
      "export",
      "delete-account",
      "pause",
      "resume",
    ].includes(command)
  ) {
    console.error(
      "Usage: tool/service.sh history login|status|collect|archive|restore <archive-id>|backup <new-directory>|export <new-directory>|pause <account>|resume <account>",
    );
    process.exitCode = 2;
    return;
  }
  const runtime = new HistoryRuntime(loadAccounts(process.env), root);
  try {
    switch (command) {
      case "status":
        console.log(
          JSON.stringify(
            runtime.accounts.map((a) => ({
              account: a.id,
              ...runtime.store.status(a.id),
            })),
            null,
            2,
          ),
        );
        break;
      case "collect":
        await runtime.collector.tick();
        console.log(
          "History collection attempt finished; inspect status for source verdict.",
        );
        break;
      case "archive":
        if (!runtime.archiver) throw new Error("OneDrive is not configured");
        await runtime.archive();
        console.log("Archive pass verified.");
        break;
      case "recover": {
        if (!runtime.archiver) throw new Error("OneDrive is not configured");
        const [item, hash, destination] = process.argv.slice(3);
        if (!item || !hash || !destination)
          throw new Error(
            "Usage: history recover <remote-id> <sha256> <new-directory>",
          );
        await recoverHistory(
          runtime.archiver.remote,
          item,
          hash,
          resolve(destination),
        );
        await applyRemoteDeletions(
          runtime.archiver.remote,
          resolve(destination),
        );
        console.log(
          "History backup restored with tracking paused; inspect before resuming.",
        );
        break;
      }
      case "restore": {
        if (!runtime.archiver) throw new Error("OneDrive is not configured");
        const row = runtime.store.db
          .query("SELECT * FROM archives WHERE id=?")
          .get(process.argv[3] ?? "") as ArchiveRow | null;
        if (!row) throw new Error("Unknown archive ID");
        const count = await runtime.archiver.restore(row);
        console.log(`Restored ${count} payloads with checksum verification.`);
        break;
      }
      case "delete-account": {
        const account = process.argv[3];
        if (
          !runtime.accounts.some((a) => a.id === account) ||
          !runtime.archiver
        )
          throw new Error("Configured account and OneDrive required");
        await withArchiveLease(runtime.store, () =>
          deleteAccount(runtime.store, runtime.archiver!.remote, account!),
        );
        console.log(
          "Account archive deleted; old backups are subject to retention and deletion marker enforcement.",
        );
        break;
      }
      case "pause":
      case "resume": {
        const account = process.argv[3];
        if (!runtime.accounts.some((a) => a.id === account))
          throw new Error("Unknown configured account");
        if (
          command === "resume" &&
          runtime.store.db
            .query("SELECT account FROM tombstones WHERE account=?")
            .get(account!)
        )
          throw new Error(
            "Deleted account IDs cannot resume; configure a new tracking ID",
          );
        runtime.store.db
          .query("UPDATE accounts SET enabled=? WHERE id=?")
          .run(command === "resume" ? 1 : 0, account!);
        console.log(`Tracking ${command} applied.`);
        break;
      }
      case "backup":
      case "export": {
        const target = process.argv[3];
        if (!target || existsSync(target))
          throw new Error("Provide a new output directory");
        const out = resolve(target);
        mkdirSync(out, { recursive: true, mode: 0o700 });
        // Serialize gives a consistent SQLite image including committed WAL contents.
        writeFileSync(join(out, "history.db"), runtime.store.db.serialize(), {
          mode: 0o600,
        });
        const rows = runtime.store.db
          .query("SELECT * FROM archives")
          .all() as ArchiveRow[];
        writeFileSync(
          join(out, "archives.json"),
          JSON.stringify({ version: 1, archives: rows }),
          { mode: 0o600 },
        );
        const payloads = runtime.store.db
          .query("SELECT id,path,archive FROM payloads")
          .all() as { id: string; path: string; archive: string | null }[];
        const local = join(out, "raw");
        mkdirSync(local, { mode: 0o700 });
        for (const p of payloads) {
          if (existsSync(p.path))
            await Bun.write(join(local, `${p.id}.json.gz`), Bun.file(p.path));
          else if (
            !rows.some(
              (a) =>
                a.id === p.archive &&
                ["verified", "local_evicted"].includes(a.state),
            )
          )
            throw new Error("Backup incomplete: missing unverified payload");
        }
        writeFileSync(
          join(out, "complete.json"),
          JSON.stringify({
            version: 1,
            created: Date.now(),
            payloads: payloads.length,
            cloudRequired: payloads.some((p) => !existsSync(p.path)),
          }),
          { mode: 0o600 },
        );
        console.log(`History ${command} complete: ${out}`);
        break;
      }
    }
  } finally {
    await runtime.close();
  }
}
main().catch((error) => {
  console.error(
    error instanceof Error ? error.message : "History command failed",
  );
  process.exitCode = 1;
});
