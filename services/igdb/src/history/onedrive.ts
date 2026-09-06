import { digest } from "./store";
import {
  existsSync,
  unlinkSync,
  readFileSync,
  writeFileSync,
  renameSync,
  mkdirSync,
} from "node:fs";
import { dirname } from "node:path";
import type { ArchiveRemote } from "./archive";
import type { Fetcher } from "./collector";

interface Tokens {
  access_token: string;
  refresh_token: string;
  expires_at: number;
}
export class OneDriveRemote implements ArchiveRemote {
  private tokens?: Tokens;
  constructor(
    readonly clientId: string,
    readonly tokenPath: string,
    readonly folderId: string,
    readonly fetcher: Fetcher = fetch,
    readonly tenant = "consumers",
  ) {
    if (!/^[a-zA-Z0-9.-]+$/.test(tenant))
      throw new Error("Invalid Microsoft tenant");
  }
  private endpoint() {
    return `https://login.microsoftonline.com/${this.tenant}/oauth2/v2.0`;
  }
  private save(body: any) {
    if (
      typeof body.access_token !== "string" ||
      !Number.isFinite(body.expires_in) ||
      !(body.refresh_token || this.tokens?.refresh_token)
    )
      throw new Error("Invalid Microsoft token response");
    this.tokens = {
      access_token: body.access_token,
      refresh_token: body.refresh_token ?? this.tokens!.refresh_token,
      expires_at: Date.now() + body.expires_in * 1000,
    };
    mkdirSync(dirname(this.tokenPath), { recursive: true, mode: 0o700 });
    writeFileSync(`${this.tokenPath}.tmp`, JSON.stringify(this.tokens), {
      mode: 0o600,
    });
    renameSync(`${this.tokenPath}.tmp`, this.tokenPath);
  }
  async beginLogin(): Promise<{
    message: string;
    device_code: string;
    interval: number;
    expires_in: number;
  }> {
    const response = await this.fetcher(`${this.endpoint()}/devicecode`, {
      method: "POST",
      body: new URLSearchParams({
        client_id: this.clientId,
        scope: "offline_access Files.ReadWrite",
      }),
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok)
      throw new Error("Microsoft device authorization could not start");
    const body: any = await response.json();
    if (
      typeof body.message !== "string" ||
      typeof body.device_code !== "string" ||
      !Number.isFinite(body.interval) ||
      !Number.isFinite(body.expires_in)
    )
      throw new Error("Invalid device authorization response");
    return {
      message: body.message,
      device_code: body.device_code,
      interval: body.interval,
      expires_in: body.expires_in,
    };
  }
  async completeLogin(
    code: string,
  ): Promise<"pending" | "slow_down" | "complete"> {
    const response = await this.fetcher(`${this.endpoint()}/token`, {
      method: "POST",
      body: new URLSearchParams({
        client_id: this.clientId,
        grant_type: "urn:ietf:params:oauth:grant-type:device_code",
        device_code: code,
      }),
      signal: AbortSignal.timeout(30_000),
    });
    const body: any = await response.json();
    if (body.error === "authorization_pending") return "pending";
    if (body.error === "slow_down") return "slow_down";
    if (!response.ok)
      throw new Error("Microsoft device authorization failed or expired");
    this.save(body);
    return "complete";
  }
  private async token() {
    this.tokens ??= JSON.parse(readFileSync(this.tokenPath, "utf8"));
    if (this.tokens!.expires_at < Date.now() + 60_000) {
      const response = await this.fetcher(`${this.endpoint()}/token`, {
        method: "POST",
        body: new URLSearchParams({
          client_id: this.clientId,
          grant_type: "refresh_token",
          refresh_token: this.tokens!.refresh_token,
          scope: "offline_access Files.ReadWrite",
        }),
        signal: AbortSignal.timeout(30_000),
      });
      if (!response.ok)
        throw new Error("OneDrive authorization requires renewal");
      this.save(await response.json());
    }
    return this.tokens!.access_token;
  }
  private async graph(path: string, init: RequestInit = {}) {
    const response = await this.fetcher(
      `https://graph.microsoft.com/v1.0${path.replace(/:$/, "")}`,
      {
        ...init,
        headers: {
          ...init.headers,
          Authorization: `Bearer ${await this.token()}`,
        },
        signal: AbortSignal.timeout(60_000),
      },
    );
    if (!response.ok) throw new Error(`OneDrive HTTP ${response.status}`);
    return response;
  }
  async put(name: string, bytes: Uint8Array): Promise<string> {
    const path = `/me/drive/items/${encodeURIComponent(this.folderId)}:/${encodeURIComponent(name)}:`;
    // Immutable deterministic filenames: a prior uncertain completion is verified by the caller.
    const lookup = await this.fetcher(
      `https://graph.microsoft.com/v1.0${path.replace(/:$/, "")}`,
      {
        headers: { Authorization: `Bearer ${await this.token()}` },
        signal: AbortSignal.timeout(30_000),
      },
    );
    if (lookup.ok) return ((await lookup.json()) as any).id;
    if (lookup.status !== 404)
      throw new Error(`OneDrive lookup HTTP ${lookup.status}`);
    const sessionPath = `${this.tokenPath}.${digest(`${this.clientId}:${this.folderId}:${name}`)}.upload.json`;
    let session: any;
    let offset = 0;
    if (existsSync(sessionPath)) {
      const saved = JSON.parse(readFileSync(sessionPath, "utf8"));
      if (saved.hash !== digest(bytes))
        throw new Error("Upload name reused with different content");
      const status = await this.fetcher(saved.uploadUrl, {
        signal: AbortSignal.timeout(30_000),
      });
      if (status.ok) {
        session = { ...saved, ...((await status.json()) as object) };
        offset = Number(session.nextExpectedRanges?.[0]?.split("-")[0] ?? 0);
      } else if (status.status === 404 || status.status === 410)
        unlinkSync(sessionPath);
      else throw new Error(`OneDrive upload status HTTP ${status.status}`);
    }
    if (!session) {
      session = await (
        await this.graph(`${path}/createUploadSession`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            item: { "@microsoft.graph.conflictBehavior": "fail", name },
          }),
        })
      ).json();
      writeFileSync(
        `${sessionPath}.tmp`,
        JSON.stringify({ ...session, hash: digest(bytes) }),
        { mode: 0o600 },
      );
      renameSync(`${sessionPath}.tmp`, sessionPath);
    }
    if (
      !Number.isSafeInteger(offset) ||
      offset < 0 ||
      offset >= bytes.length ||
      offset % (320 * 1024) !== 0
    )
      throw new Error("Invalid upload resume offset");
    const upload = new URL(session.uploadUrl);
    if (upload.protocol !== "https:") throw new Error("Invalid upload URL");
    const chunk = 10 * 320 * 1024;
    for (; offset < bytes.length; offset += chunk) {
      const end = Math.min(offset + chunk, bytes.length);
      const response = await this.fetcher(upload, {
        method: "PUT",
        body: bytes.slice(offset, end),
        headers: {
          "Content-Length": String(end - offset),
          "Content-Range": `bytes ${offset}-${end - 1}/${bytes.length}`,
        },
        signal: AbortSignal.timeout(60_000),
      });
      if (!response.ok)
        throw new Error(`OneDrive upload HTTP ${response.status}`);
      if (end === bytes.length) {
        const item: any = await response.json();
        if (typeof item.id !== "string")
          throw new Error("OneDrive upload not committed");
        if (existsSync(sessionPath)) unlinkSync(sessionPath);
        return item.id;
      }
    }
    throw new Error("Empty archive");
  }
  async find(name: string): Promise<string | null> {
    const path = `/me/drive/items/${encodeURIComponent(this.folderId)}:/${encodeURIComponent(name)}:`;
    const response = await this.fetcher(
      `https://graph.microsoft.com/v1.0${path.replace(/:$/, "")}`,
      {
        headers: { Authorization: `Bearer ${await this.token()}` },
        signal: AbortSignal.timeout(30_000),
      },
    );
    if (response.status === 404) return null;
    if (!response.ok)
      throw new Error(`OneDrive lookup HTTP ${response.status}`);
    return ((await response.json()) as any).id;
  }
  async remove(id: string): Promise<void> {
    const response = await this.fetcher(
      `https://graph.microsoft.com/v1.0/me/drive/items/${encodeURIComponent(id)}`,
      {
        method: "DELETE",
        headers: { Authorization: `Bearer ${await this.token()}` },
        signal: AbortSignal.timeout(60000),
      },
    );
    if (!response.ok && response.status !== 404)
      throw new Error(`OneDrive delete HTTP ${response.status}`);
  }
  async get(id: string): Promise<Uint8Array> {
    const response = await this.graph(
      `/me/drive/items/${encodeURIComponent(id)}/content`,
    );
    return new Uint8Array(await response.arrayBuffer());
  }
}
