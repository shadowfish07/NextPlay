import { test, expect } from "bun:test";
import { resolve } from "node:path";

test("service wrapper preserves diagnostic exit codes without printing configuration", async () => {
  const root = resolve(import.meta.dir, "../../../..");
  const child = Bun.spawn(
    ["bash", "tool/service.sh", "history", "unknown-command"],
    {
      cwd: root,
      stdout: "pipe",
      stderr: "pipe",
      env: {
        ...process.env,
        NEXTPLAY_HISTORY_ACCOUNTS: "DO_NOT_PRINT_PRIVATE_CONFIGURATION",
      },
    },
  );
  const [code, out, err] = await Promise.all([
    child.exited,
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
  ]);
  expect(code).toBe(2);
  expect(err).toContain("Usage:");
  expect(out + err).not.toContain("DO_NOT_PRINT_PRIVATE_CONFIGURATION");
});
