import { test, expect } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { OneDriveRemote } from "./onedrive";

test("OneDrive uses immutable upload session and never sends bearer token to upload host", async () => {
  const dir = mkdtempSync(join(tmpdir(), "nextplay-onedrive-"));
  try {
    const tokenPath = join(dir, "token.json");
    writeFileSync(
      tokenPath,
      JSON.stringify({
        access_token: "private",
        refresh_token: "refresh",
        expires_at: Date.now() + 1000000,
      }),
    );
    const seen: string[] = [];
    const remote = new OneDriveRemote(
      "client",
      tokenPath,
      "folder",
      async (url, init) => {
        const address = String(url);
        seen.push(address);
        if (address.includes("createUploadSession"))
          return Response.json({ uploadUrl: "https://upload.example/session" });
        if (address.includes("upload.example")) {
          expect(new Headers(init?.headers).has("Authorization")).toBe(false);
          expect(new Headers(init?.headers).get("Content-Range")).toBe(
            "bytes 0-2/3",
          );
          return Response.json({ id: "remote-id" });
        }
        if (address.endsWith("/content"))
          return new Response(new Uint8Array([1, 2, 3]));
        return new Response(null, { status: 404 });
      },
    );
    expect(await remote.put("archive.gz", new Uint8Array([1, 2, 3]))).toBe(
      "remote-id",
    );
    expect(await remote.get("remote-id")).toEqual(new Uint8Array([1, 2, 3]));
    expect(seen).toHaveLength(4);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test("OneDrive resumes a persisted upload session after process replacement", async () => {
  const dir = mkdtempSync(join(tmpdir(), "nextplay-onedrive-resume-"));
  try {
    const tokenPath = join(dir, "token.json");
    writeFileSync(
      tokenPath,
      JSON.stringify({
        access_token: "private",
        refresh_token: "refresh",
        expires_at: Date.now() + 1000000,
      }),
    );
    const chunk = 320 * 1024 * 10,
      bytes = new Uint8Array(chunk + 3);
    let interrupted = false;
    let sessions = 0;
    const ranges: string[] = [];
    const fetcher = async (url: string | URL, init?: RequestInit) => {
      const address = String(url);
      if (address.includes("createUploadSession")) {
        sessions++;
        return Response.json({ uploadUrl: "https://upload.example/session" });
      }
      if (address.includes("upload.example")) {
        if (!init?.method)
          return Response.json({ nextExpectedRanges: [`${chunk}-`] });
        const range = new Headers(init.headers).get("Content-Range")!;
        ranges.push(range);
        if (range.startsWith(`bytes ${chunk}-`) && !interrupted) {
          interrupted = true;
          throw new Error("connection interrupted");
        }
        return range.startsWith("bytes 0-")
          ? Response.json(
              { nextExpectedRanges: [`${chunk}-`] },
              { status: 202 },
            )
          : Response.json({ id: "done" });
      }
      return new Response(null, { status: 404 });
    };
    await expect(
      new OneDriveRemote("c", tokenPath, "f", fetcher).put("a.gz", bytes),
    ).rejects.toThrow();
    expect(
      await new OneDriveRemote("c", tokenPath, "f", fetcher).put("a.gz", bytes),
    ).toBe("done");
    expect(sessions).toBe(1);
    expect(ranges.filter((r) => r.startsWith("bytes 0-"))).toHaveLength(1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
