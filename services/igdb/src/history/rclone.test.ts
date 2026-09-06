import { expect, test } from "bun:test";
import { existsSync, readFileSync } from "node:fs";
import { RcloneRemote, type RcloneRunner } from "./rclone";

const name = "nextplay-example.jsonl.gz";
const ok = (value: unknown) => ({ code: 0, bytes: Buffer.from(JSON.stringify(value)) });
test("rclone confines every operation to a dedicated directory", async () => {
  for (const path of ["onedrive:", "onedrive:../private", "/tmp/NextPlay", "onedrive:NextPlay/../../x"])
    expect(() => new RcloneRemote(path)).toThrow();
  let calls = 0;
  const remote = new RcloneRemote("onedrive:NextPlay/history", "rclone", async () => { calls++; return ok({}); });
  for (const value of ["../nextplay-example.json", "x/nextplay-example.json", "--config", "private.json"])
    await expect(remote.get(value)).rejects.toThrow();
  expect(calls).toBe(0);
});
test("rclone distinguishes absent files from authorization failures", async () => {
  for (const code of [3, 4]) {
    const remote = new RcloneRemote("onedrive:NextPlay/history", "rclone", async () => ({ code, bytes: new Uint8Array() }));
    expect(await remote.find(name)).toBeNull();
  }
  const remote = new RcloneRemote("onedrive:NextPlay/history", "rclone", async () => ({ code: 1, bytes: Buffer.from("secret error") }));
  await expect(remote.put(name, Buffer.from("data"))).rejects.toThrow("exit 1");
});
test("rclone retries use immutable objects and clean temporary payloads on failure", async () => {
  let temporary = "";
  const execute: RcloneRunner = async (args) => {
    if (args[0] === "lsjson") return { code: 4, bytes: new Uint8Array() };
    expect(args[0]).toBe("copyto");
    expect(args[2]).toBe(`onedrive:NextPlay/history/${name}`);
    expect(args[3]).toBe("--immutable");
    temporary = args[1]!;
    expect(readFileSync(temporary).toString()).toBe("private payload");
    return { code: 1, bytes: new Uint8Array() };
  };
  const remote = new RcloneRemote("onedrive:NextPlay/history", "rclone", execute);
  await expect(remote.put(name, Buffer.from("private payload"))).rejects.toThrow();
  expect(existsSync(temporary)).toBe(false);
  const existing = new RcloneRemote("onedrive:NextPlay/history", "rclone", async (args) => {
    expect(args[0]).toBe("lsjson");
    return ok({ Name: name, IsDir: false });
  });
  expect(await existing.put(name, Buffer.from("payload"))).toBe(name);
});
