import { spawn } from "node:child_process";
import { mkdtempSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ArchiveRemote } from "./archive";

export type RcloneRunner = (
  args: string[],
) => Promise<{ code: number; bytes: Uint8Array }>;

function runner(binary: string): RcloneRunner {
  return (args) => new Promise((resolve, reject) => {
    const child = spawn(binary, [...args, "--contimeout", "20s", "--timeout", "60s", "--retries", "2"], {
      stdio: ["ignore", "pipe", "ignore"],
      timeout: 300_000,
      killSignal: "SIGKILL",
    });
    const chunks: Buffer[] = [];
    child.stdout.on("data", (data: Buffer) => chunks.push(data));
    child.on("error", () => reject(new Error("Could not execute rclone; check binary and service permissions")));
    child.on("close", (code) => resolve({ code: code ?? -1, bytes: Buffer.concat(chunks) }));
  });
}

/** Uses rclone's existing authorization without reading or copying its tokens. */
export class RcloneRemote implements ArchiveRemote {
  private readonly run: RcloneRunner;
  constructor(readonly directory: string, binary = "rclone", execute?: RcloneRunner) {
    // Require a named remote and a dedicated directory; never target the drive root.
    if (!/^[a-zA-Z0-9_-]+:[a-zA-Z0-9_-]+(?:\/[a-zA-Z0-9_-]+)*$/.test(directory))
      throw new Error("Rclone archive destination must be remote:dedicated/directory");
    this.run = execute ?? runner(binary);
  }
  private path(name: string) {
    if (!/^nextplay-[a-zA-Z0-9_-]+\.(jsonl\.gz|json\.gz|json)$/.test(name))
      throw new Error("Invalid rclone archive object name");
    return `${this.directory}/${name}`;
  }
  private async checked(args: string[]) {
    const result = await this.run(args);
    if (result.code !== 0) throw new Error(`Rclone ${args[0]} failed (exit ${result.code}); local data retained`);
    return result.bytes;
  }
  async find(name: string): Promise<string | null> {
    const result = await this.run(["lsjson", this.path(name), "--stat"]);
    if (result.code === 3 || result.code === 4) return null;
    if (result.code !== 0) throw new Error(`Rclone lookup failed (exit ${result.code})`);
    const entry = JSON.parse(Buffer.from(result.bytes).toString());
    if (!entry || entry.IsDir !== false || entry.Name !== name)
      throw new Error("Invalid rclone object metadata");
    return name;
  }
  async put(name: string, bytes: Uint8Array): Promise<string> {
    const target = this.path(name);
    if (await this.find(name)) return name; // Caller verifies the existing immutable object.
    const temporary = mkdtempSync(join(tmpdir(), "nextplay-upload-"));
    try {
      const file = join(temporary, name);
      writeFileSync(file, bytes, { mode: 0o600 });
      await this.checked(["copyto", file, target, "--immutable"]);
      return name;
    } finally {
      rmSync(temporary, { recursive: true, force: true });
    }
  }
  async get(name: string): Promise<Uint8Array> {
    return this.checked(["cat", this.path(name)]);
  }
  async remove(name: string) {
    if (await this.find(name)) await this.checked(["deletefile", this.path(name)]);
  }
}
