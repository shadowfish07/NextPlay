/**
 * i18n Translation Loader
 * Loads and provides access to genre/theme translations
 */

import genresData from "./genres.json" with { type: "json" };
import themesData from "./themes.json" with { type: "json" };

type TranslationMap = { [lang: string]: { [id: string]: string } };

const genres = genresData as TranslationMap;
const themes = themesData as TranslationMap;

const DEFAULT_LANG = "en";

/**
 * IGDB Region IDs mapping
 * Based on IGDB API regions endpoint
 */
export const IGDB_REGIONS = {
  EUROPE: 1,
  NORTH_AMERICA: 2,
  AUSTRALIA: 3,
  NEW_ZEALAND: 4,
  JAPAN: 5,
  CHINA: 6,
  ASIA: 7,
  WORLDWIDE: 8,
  KOREA: 9,
  BRAZIL: 10,
} as const;

/**
 * Language code to IGDB region ID mapping
 * Maps common language codes to their corresponding IGDB regions
 */
const LANGUAGE_TO_REGIONS: { [lang: string]: number[] } = {
  "zh-CN": [IGDB_REGIONS.CHINA, IGDB_REGIONS.ASIA],
  "zh-TW": [IGDB_REGIONS.ASIA, IGDB_REGIONS.CHINA],
  "zh": [IGDB_REGIONS.CHINA, IGDB_REGIONS.ASIA],
  "ja": [IGDB_REGIONS.JAPAN, IGDB_REGIONS.ASIA],
  "ko": [IGDB_REGIONS.KOREA, IGDB_REGIONS.ASIA],
  "pt-BR": [IGDB_REGIONS.BRAZIL],
  "en": [IGDB_REGIONS.NORTH_AMERICA, IGDB_REGIONS.EUROPE, IGDB_REGIONS.WORLDWIDE],
  "en-US": [IGDB_REGIONS.NORTH_AMERICA, IGDB_REGIONS.WORLDWIDE],
  "en-GB": [IGDB_REGIONS.EUROPE, IGDB_REGIONS.WORLDWIDE],
};

/**
 * Alternative name comment keywords for language matching
 */
const LANGUAGE_KEYWORDS: { [lang: string]: string[] } = {
  "zh-CN": ["chinese", "simplified chinese", "中文", "简体"],
  "zh-TW": ["traditional chinese", "繁體", "繁体"],
  "zh": ["chinese", "中文"],
  "ja": ["japanese", "日本語", "日本"],
  "ko": ["korean", "한국어", "한국"],
};

/**
 * Get IGDB region IDs for a language code
 */
export function getRegionsForLanguage(lang: string): number[] {
  return LANGUAGE_TO_REGIONS[lang] || LANGUAGE_TO_REGIONS["en"];
}

/**
 * Get keywords for matching alternative names by language
 */
export function getLanguageKeywords(lang: string): string[] {
  return LANGUAGE_KEYWORDS[lang] || [];
}

/**
 * Get translated genre name by ID
 */
export function getGenreName(id: number, lang: string = DEFAULT_LANG): string {
  const langMap = genres[lang] || genres[DEFAULT_LANG];
  return langMap?.[id.toString()] || genres[DEFAULT_LANG]?.[id.toString()] || "Unknown";
}

/**
 * Get translated theme name by ID
 */
export function getThemeName(id: number, lang: string = DEFAULT_LANG): string {
  const langMap = themes[lang] || themes[DEFAULT_LANG];
  return langMap?.[id.toString()] || themes[DEFAULT_LANG]?.[id.toString()] || "Unknown";
}

/**
 * Check if a language is supported
 */
export function isLanguageSupported(lang: string): boolean {
  return lang in genres && lang in themes;
}

/**
 * Get list of supported languages
 */
export function getSupportedLanguages(): string[] {
  return Object.keys(genres);
}
