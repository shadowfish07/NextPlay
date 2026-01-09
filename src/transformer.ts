import type { IGDBGame, GameData } from "./types";
import {
  AgeRatingOrganization,
  AgeRatingCategory,
  GameStatus,
  LanguageSupportType,
} from "./enums";
import { getGenreName, getThemeName, getRegionsForLanguage, getLanguageKeywords } from "./i18n";

function normalizeImageUrl(url: string): string {
  if (url.startsWith("//")) {
    return `https:${url}`;
  }
  return url;
}

/**
 * Get localized game name based on language preference
 * Priority: game_localizations > alternative_names > original name
 */
function getLocalizedName(igdbGame: IGDBGame, language: string): string {
  // If language is English, return original name
  if (language === "en" || language.startsWith("en-")) {
    return igdbGame.name;
  }

  // Try game_localizations first (most reliable)
  if (igdbGame.game_localizations && igdbGame.game_localizations.length > 0) {
    const regions = getRegionsForLanguage(language);
    for (const regionId of regions) {
      const localization = igdbGame.game_localizations.find(
        (loc) => loc.region === regionId
      );
      if (localization?.name) {
        return localization.name;
      }
    }
  }

  // Try alternative_names with language keywords
  if (igdbGame.alternative_names && igdbGame.alternative_names.length > 0) {
    const keywords = getLanguageKeywords(language);
    if (keywords.length > 0) {
      for (const altName of igdbGame.alternative_names) {
        if (altName.comment) {
          const commentLower = altName.comment.toLowerCase();
          for (const keyword of keywords) {
            if (commentLower.includes(keyword.toLowerCase())) {
              return altName.name;
            }
          }
        }
      }
    }
  }

  // Fallback to original name
  return igdbGame.name;
}

export function transformIGDBGame(
  igdbGame: IGDBGame,
  steamId: number,
  language: string = "en"
): GameData {
  const localizedName = getLocalizedName(igdbGame, language);
  return {
    steamId,
    name: igdbGame.name,
    localizedName: localizedName !== igdbGame.name ? localizedName : undefined,
    summary: igdbGame.summary || "",
    url: igdbGame.url || "",
    cover: igdbGame.cover
      ? {
          url: normalizeImageUrl(igdbGame.cover.url.replace("t_thumb", "t_cover_big")),
          width: igdbGame.cover.width,
          height: igdbGame.cover.height,
        }
      : undefined,
    screenshots: igdbGame.screenshots
      ? igdbGame.screenshots.map((s) => ({
          url: normalizeImageUrl(s.url.replace("t_thumb", "t_screenshot_big")),
          width: s.width,
          height: s.height,
        }))
      : [],
    artworks: igdbGame.artworks
      ? igdbGame.artworks.map((a) => ({
          url: normalizeImageUrl(a.url.replace("t_thumb", "t_1080p")),
          width: a.width,
          height: a.height,
        }))
      : [],
    videos: igdbGame.videos
      ? igdbGame.videos.map((v) => ({
          name: v.name,
          video_id: v.video_id,
          youtube_url: `https://www.youtube.com/watch?v=${v.video_id}`,
        }))
      : [],
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
    developers: igdbGame.involved_companies
      ? igdbGame.involved_companies
          .filter((ic) => ic.developer && ic.company)
          .map((ic) => ({ name: ic.company.name }))
      : [],
    publishers: igdbGame.involved_companies
      ? igdbGame.involved_companies
          .filter((ic) => ic.publisher && ic.company)
          .map((ic) => ({ name: ic.company.name }))
      : [],
  };
}
