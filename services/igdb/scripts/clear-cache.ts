#!/usr/bin/env bun
/**
 * 强制清空缓存脚本
 * 用法: bun scripts/clear-cache.ts
 */

import { Database } from "bun:sqlite";
import { existsSync, unlinkSync } from "node:fs";

const CACHE_DB_PATH = "./data/cache.db";

function clearCache() {
  console.log("[Clear Cache] 开始清空缓存...");

  if (!existsSync(CACHE_DB_PATH)) {
    console.log("[Clear Cache] 缓存文件不存在，无需清空");
    return;
  }

  try {
    const db = new Database(CACHE_DB_PATH);
    const countBefore = db.query<{ count: number }, []>(
      "SELECT COUNT(*) as count FROM games"
    ).get();

    db.run("DELETE FROM games");
    db.run("VACUUM");

    console.log(`[Clear Cache] 已清空 ${countBefore?.count ?? 0} 条缓存记录`);
    db.close();
    console.log("[Clear Cache] 缓存清空完成!");
  } catch (error) {
    console.error("[Clear Cache] 清空失败:", error);
    console.log("[Clear Cache] 尝试直接删除缓存文件...");
    try {
      unlinkSync(CACHE_DB_PATH);
      console.log("[Clear Cache] 缓存文件已删除");
    } catch (unlinkError) {
      console.error("[Clear Cache] 删除文件失败:", unlinkError);
      process.exit(1);
    }
  }
}

clearCache();
