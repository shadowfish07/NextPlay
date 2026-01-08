import { CacheManager } from "./cache";
import type { GameData } from "./types";

const cache = new CacheManager("./data/test-cache.db");

// Test data
const testGame: GameData = {
  steamId: 730,
  name: "Counter-Strike: Global Offensive",
  summary: "Test summary",
  url: "https://www.igdb.com/games/counter-strike-global-offensive",
  cover: {
    url: "https://images.igdb.com/igdb/image/upload/t_cover_big/test.jpg",
    width: 264,
    height: 352,
  },
  age_ratings: [],
  platforms: [],
  game_modes: [],
  language_supports: [],
  similar_games: [],
  tags: [],
};

// Test set
cache.set(730, 113, testGame);

// Test get
const retrieved = cache.get(730);
console.log("Retrieved:", retrieved);

// Test miss
const missing = cache.get(999999);
console.log("Missing:", missing);

cache.close();
