import type { IGDBGame, GameData } from "./types";

export function transformIGDBGame(
  igdbGame: IGDBGame,
  steamId: number
): GameData {
  return {
    steamId,
    name: igdbGame.name,
    summary: igdbGame.summary || "",
    url: igdbGame.url || "",
    cover: igdbGame.cover
      ? {
          url: igdbGame.cover.url.replace("t_thumb", "t_cover_big"),
          width: igdbGame.cover.width,
          height: igdbGame.cover.height,
        }
      : undefined,
    first_release_date: igdbGame.first_release_date,
    aggregated_rating: igdbGame.aggregated_rating,
    total_rating: igdbGame.total_rating,
    game_status: igdbGame.game_status,
    age_ratings: igdbGame.age_ratings
      ? igdbGame.age_ratings.map((ar) => ({
          category: ar.category,
          rating: ar.rating,
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
          language: { name: ls.language.name },
          language_support_type: ls.language_support_type,
        }))
      : [],
    similar_games: igdbGame.similar_games
      ? igdbGame.similar_games.slice(0, 5).map((sg) => ({
          name: sg.name,
          cover: sg.cover ? { url: sg.cover.url.replace("t_thumb", "t_cover_big") } : undefined,
        }))
      : [],
    tags: igdbGame.tags || [],
  };
}
