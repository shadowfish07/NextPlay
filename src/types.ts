// API Request/Response Types
export interface GamesRequest {
  steamIds: number[];
  forceRefresh?: boolean;
}

export interface GamesResponse {
  games: GameData[];
  notFound: number[];
  errors: ErrorData[];
}

export interface ErrorData {
  steamId: number;
  reason: string;
}

// IGDB API Types
export interface IGDBGame {
  id: number;
  name: string;
  summary?: string;
  url?: string;
  cover?: IGDBCover;
  first_release_date?: number;
  aggregated_rating?: number;
  total_rating?: number;
  game_status?: number;
  age_ratings?: IGDBAgeRating[];
  platforms?: IGDBPlatform[];
  game_modes?: IGDBGameMode[];
  language_supports?: IGDBLanguageSupport[];
  similar_games?: IGDBSimilarGame[];
  tags?: unknown[];
}

export interface IGDBCover {
  id: number;
  url: string;
  width: number;
  height: number;
}

export interface IGDBAgeRating {
  category: number;
  rating: number;
}

export interface IGDBPlatform {
  id: number;
  name: string;
}

export interface IGDBGameMode {
  id: number;
  name: string;
}

export interface IGDBLanguageSupport {
  language: {
    id: number;
    name: string;
  };
  language_support_type: number;
}

export interface IGDBSimilarGame {
  id: number;
  name: string;
  cover?: {
    url: string;
  };
}

export interface IGDBExternalGame {
  id: number;
  uid: string;
  game: number;
  category: number;
}

// Client Response Type
export interface GameData {
  steamId: number;
  name: string;
  summary: string;
  url: string;
  cover?: {
    url: string;
    width: number;
    height: number;
  };
  first_release_date?: number;
  aggregated_rating?: number;
  total_rating?: number;
  game_status?: number;
  age_ratings: Array<{
    category: number;
    rating: number;
  }>;
  platforms: Array<{
    name: string;
  }>;
  game_modes: Array<{
    name: string;
  }>;
  language_supports: Array<{
    language: { name: string };
    language_support_type: number;
  }>;
  similar_games: Array<{
    name: string;
    cover?: { url: string };
  }>;
  tags: unknown[];
}

// Cache Types
export interface CachedGame {
  steam_id: number;
  igdb_id: number;
  data: string; // JSON string
  cached_at: number;
}

// OAuth Types
export interface TwitchTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}
