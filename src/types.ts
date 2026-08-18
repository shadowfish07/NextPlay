// API Request/Response Types
export interface GamesRequest {
  steamIds: number[];
  forceRefresh?: boolean;
  language?: string; // e.g., "en", "zh-CN", "ja"
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
  screenshots?: IGDBScreenshot[];
  artworks?: IGDBArtwork[];
  videos?: IGDBVideo[];
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
  game_localizations?: IGDBGameLocalization[];
  alternative_names?: IGDBAlternativeName[];
  involved_companies?: IGDBInvolvedCompany[];
}

export interface IGDBGameLocalization {
  id: number;
  name: string;
  region: number;
}

export interface IGDBAlternativeName {
  id: number;
  name: string;
  comment?: string;
}

export interface IGDBCover {
  id: number;
  url: string;
  width: number;
  height: number;
}

export interface IGDBScreenshot {
  id: number;
  image_id: string;
  url: string;
  width: number;
  height: number;
}

export interface IGDBArtwork {
  id: number;
  image_id: string;
  url: string;
  width: number;
  height: number;
  artwork_type?: number;
}

export interface IGDBVideo {
  id: number;
  name?: string;
  video_id: string; // YouTube video ID
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

export interface IGDBCompany {
  id: number;
  name: string;
}

export interface IGDBInvolvedCompany {
  id: number;
  company: IGDBCompany;
  developer: boolean;
  publisher: boolean;
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
  localizedName?: string;
  summary: string;
  url: string;
  cover?: {
    url: string;
    width: number;
    height: number;
  };
  screenshots: Array<{
    image_id: string;
    url: string;
    width: number;
    height: number;
  }>;
  artworks: Array<{
    image_id: string;
    url: string;
    width: number;
    height: number;
    artwork_type?: number;
  }>;
  videos: Array<{
    name?: string;
    video_id: string;
    youtube_url: string;
  }>;
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
  developers: Array<{
    name: string;
  }>;
  publishers: Array<{
    name: string;
  }>;
}

// Cache Types
export interface CachedGame {
  steam_id: number;
  igdb_id: number;
  language: string;
  data: string; // JSON string
  cached_at: number;
  expires_at: number;
}

// OAuth Types
export interface TwitchTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}
