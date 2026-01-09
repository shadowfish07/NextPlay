import type { IGDBGame, GameData } from "./types";
import {
  AgeRatingOrganization,
  AgeRatingCategory,
  GameStatus,
  LanguageSupportType,
} from "./enums";
import { getGenreName, getThemeName } from "./i18n";

function normalizeImageUrl(url: string): string {
  if (url.startsWith("//")) {
    return `https:${url}`;
  }
  return url;
}

export function transformIGDBGame(
  igdbGame: IGDBGame,
  steamId: number,
  language: string = "en"
): GameData {
  return {
    steamId,
    name: igdbGame.name,
    summary: igdbGame.summary || "",
    url: igdbGame.url || "",
    cover: igdbGame.cover
      ? {
          url: normalizeImageUrl(igdbGame.cover.url.replace("t_thumb", "t_cover_big")),
          width: igdbGame.cover.width,
          height: igdbGame.cover.height,
        }
      : undefined,
    first_release_date: igdbGame.first_release_date,
    aggregated_rating: igdbGame.aggregated_rating,
    total_rating: igdbGame.total_rating,
    game_status: igdbGame.game_status !== undefined
      ? GameStatus[igdbGame.game_status] || `Unknown (${igdbGame.game_status})`
      : undefined,
    age_ratings: igdbGame.age_ratings
      ? igdbGame.age_ratings.map((ar) => ({
          organization: AgeRatingOrganization[ar.organization] || `Unknown (${ar.organization})`,
          rating: AgeRatingCategory[`${ar.organization}_${ar.rating_category}`] || `Unknown (${ar.rating_category})`,
          synopsis: ar.synopsis,
        }))
      : [],
    platforms: igdbGame.platforms
      ? igdbGame.platforms.map((p) => ({ name: p.name }))
      : [],
    game_modes: igdbGame.game_modes
      ? igdbGame.game_modes.map((gm) => ({ name: gm.name }))
      : [],
    language_supports: igdbGame.language_supports
      ? igdbGame.language_supports.map((ls) => ({
          language: ls.language.name,
          support_type: LanguageSupportType[ls.language_support_type] || `Unknown (${ls.language_support_type})`,
        }))
      : [],
    genres: igdbGame.genres
      ? igdbGame.genres.map((g) => ({ name: getGenreName(g.id, language) }))
      : [],
    themes: igdbGame.themes
      ? igdbGame.themes.map((t) => ({ name: getThemeName(t.id, language) }))
      : [],
    similar_games: igdbGame.similar_games
      ? igdbGame.similar_games.slice(0, 5).map((sg) => ({
          name: sg.name,
          cover: sg.cover ? { url: normalizeImageUrl(sg.cover.url.replace("t_thumb", "t_cover_big")) } : undefined,
        }))
      : [],
  };
}
