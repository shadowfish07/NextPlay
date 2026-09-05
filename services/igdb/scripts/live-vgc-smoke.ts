import { VgcRatingService } from "../src/vgc-rating-service";

const steamId = 620;
const service = new VgcRatingService({ dbPath: ":memory:" });
let failure: unknown;

try {
  const rating = await service.getRating(steamId);
  if (
    !rating ||
    rating.steamId !== steamId ||
    rating.stale ||
    !["scored", "early_access"].includes(rating.status) ||
    rating.sourceUrl !== `https://videogamescritic.com/game/${steamId}`
  ) {
    throw new Error("Live VGC scrape returned an invalid rating contract");
  }
} catch (error) {
  failure = error;
} finally {
  await service.close();
}

if (failure) {
  console.error("Live VGC scrape failed:", failure);
  process.exit(1);
}
