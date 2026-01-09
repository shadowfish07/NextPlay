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
