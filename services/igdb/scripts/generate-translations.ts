/**
 * IGDB Genres/Themes Translation Generator
 *
 * Usage:
 *   bun run scripts/generate-translations.ts --lang zh-CN,ja,ko
 *
 * Environment Variables:
 *   AI_API_KEY      - API Key for AI service
 *   AI_BASE_URL     - API endpoint (required)
 *   AI_MODEL        - Model name (default: gpt-4o-mini)
 */

import { generateText } from "ai";
import { createOpenAICompatible } from "@ai-sdk/openai-compatible";
import { IGDBClient } from "../src/igdb-client";

// Types
interface IGDBItem {
  id: number;
  name: string;
  slug: string;
}

interface TranslationMap {
  [lang: string]: { [id: string]: string };
}

// Parse command line arguments
function parseArgs(): { languages: string[] } {
  const args = process.argv.slice(2);
  const langIndex = args.indexOf("--lang");

  if (langIndex === -1 || !args[langIndex + 1]) {
    console.error("Usage: bun run scripts/generate-translations.ts --lang zh-CN,ja,ko");
    process.exit(1);
  }

  const languages = args[langIndex + 1].split(",").map((l) => l.trim());
  return { languages };
}

// Get AI model based on environment
function getModel() {
  const apiKey = process.env.AI_API_KEY;
  const baseURL = process.env.AI_BASE_URL;
  const modelName = process.env.AI_MODEL || "gpt-4o-mini";

  if (!apiKey) {
    console.error("Error: AI_API_KEY is required");
    process.exit(1);
  }

  if (!baseURL) {
    console.error("Error: AI_BASE_URL is required");
    process.exit(1);
  }

  const provider = createOpenAICompatible({
    name: "custom",
    baseURL,
    apiKey,
  });

  console.log(`Using model: ${modelName} (${baseURL})`);
  return provider(modelName);
}

// Fetch all genres from IGDB
async function fetchGenres(client: IGDBClient): Promise<IGDBItem[]> {
  console.log("Fetching genres from IGDB...");
  const query = "fields id, name, slug; limit 500;";
  const results = await client.request("genres", query);
  console.log(`Fetched ${results.length} genres`);
  return results;
}

// Fetch all themes from IGDB
async function fetchThemes(client: IGDBClient): Promise<IGDBItem[]> {
  console.log("Fetching themes from IGDB...");
  const query = "fields id, name, slug; limit 500;";
  const results = await client.request("themes", query);
  console.log(`Fetched ${results.length} themes`);
  return results;
}

// Translate items to target language using AI
async function translateItems(
  items: IGDBItem[],
  targetLang: string,
  category: string
): Promise<{ [id: string]: string }> {
  const model = getModel();
  const names = items.map((item) => item.name);

  const prompt = `Translate the following video game ${category} names to ${targetLang}.
Return ONLY a JSON object where keys are the original English names and values are the translations.
Do not include any explanation or markdown formatting.

Names to translate:
${JSON.stringify(names, null, 2)}`;

  console.log(`Translating ${items.length} ${category} to ${targetLang}...`);

  const { text } = await generateText({
    model,
    prompt,
    temperature: 0.3,
  });

  // Parse the JSON response
  let translations: { [name: string]: string };
  try {
    // Extract JSON from response (handle thinking/reasoning prefix)
    let cleanText = text;

    // Remove markdown code blocks
    cleanText = cleanText.replace(/```json\n?|\n?```/g, "");

    // Find the first { and last } to extract JSON object
    const firstBrace = cleanText.indexOf("{");
    const lastBrace = cleanText.lastIndexOf("}");

    if (firstBrace === -1 || lastBrace === -1) {
      throw new Error("No JSON object found in response");
    }

    cleanText = cleanText.slice(firstBrace, lastBrace + 1);
    translations = JSON.parse(cleanText);
  } catch (e) {
    console.error("Failed to parse AI response:", text);
    throw new Error(`Failed to parse translation response: ${e}`);
  }

  // Map translations back to IDs
  const result: { [id: string]: string } = {};
  for (const item of items) {
    result[item.id.toString()] = translations[item.name] || item.name;
  }

  return result;
}

// Build translation map for all languages
async function buildTranslationMap(
  items: IGDBItem[],
  languages: string[],
  category: string
): Promise<TranslationMap> {
  const map: TranslationMap = {};

  // Add English (original) first
  map["en"] = {};
  for (const item of items) {
    map["en"][item.id.toString()] = item.name;
  }

  // Translate to each target language
  for (const lang of languages) {
    if (lang === "en") continue;
    map[lang] = await translateItems(items, lang, category);
    // Rate limiting between translations
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }

  return map;
}

// Write translation file
async function writeTranslationFile(
  filename: string,
  data: TranslationMap
): Promise<void> {
  const dir = new URL("../src/i18n", import.meta.url).pathname;
  await Bun.write(`${dir}/${filename}`, JSON.stringify(data, null, 2));
  console.log(`Written: src/i18n/${filename}`);
}

// Main
async function main() {
  const { languages } = parseArgs();
  console.log(`Target languages: ${languages.join(", ")}`);

  // Initialize IGDB client
  const clientId = process.env.TWITCH_CLIENT_ID;
  const clientSecret = process.env.TWITCH_CLIENT_SECRET;

  if (!clientId || !clientSecret) {
    console.error("Error: TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET required");
    process.exit(1);
  }

  const client = new IGDBClient(clientId, clientSecret);

  // Create i18n directory
  const i18nDir = new URL("../src/i18n", import.meta.url).pathname;
  await Bun.write(`${i18nDir}/.gitkeep`, "");

  // Fetch and translate genres
  const genres = await fetchGenres(client);
  const genreTranslations = await buildTranslationMap(genres, languages, "genres");
  await writeTranslationFile("genres.json", genreTranslations);

  // Fetch and translate themes
  const themes = await fetchThemes(client);
  const themeTranslations = await buildTranslationMap(themes, languages, "themes");
  await writeTranslationFile("themes.json", themeTranslations);

  console.log("\nTranslation generation complete!");
}

main().catch((err) => {
  console.error("Error:", err);
  process.exit(1);
});
