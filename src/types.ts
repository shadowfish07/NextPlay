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
  genres?: IGDBGenre[];
  themes?: IGDBTheme[];
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
  id: number;
  organization: number;
  rating_category: number;
  synopsis?: string;
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

export interface IGDBGenre {
  id: number;
  name: string;
}

export interface IGDBTheme {
  id: number;
  name: string;
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
  game_status?: string;
  age_ratings: Array<{
    organization: string;
    rating: string;
    synopsis?: string;
  }>;
  platforms: Array<{
    name: string;
  }>;
  game_modes: Array<{
    name: string;
  }>;
  language_supports: Array<{
    language: string;
    support_type: string;
  }>;
  genres: Array<{
    name: string;
  }>;
  themes: Array<{
    name: string;
  }>;
  similar_games: Array<{
    name: string;
    cover?: { url: string };
  }>;
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
