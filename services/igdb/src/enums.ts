// IGDB API Enum Mappings
// Reference: https://api-docs.igdb.com/#age-rating

// Age Rating Organizations
export const AgeRatingOrganization: Record<number, string> = {
  1: "ESRB",
  2: "PEGI",
  3: "CERO",
  4: "USK",
  5: "GRAC",
  6: "CLASS_IND",
  7: "ACB",
};

// Age Rating Categories (rating values)
// Key format: "organization_ratingCategory"
export const AgeRatingCategory: Record<string, string> = {
  // ESRB (org 1)
  "1_6": "RP",
  "1_7": "EC",
  "1_8": "E",
  "1_9": "E10+",
  "1_10": "T",
  "1_11": "M",
  "1_12": "AO",
  // PEGI (org 2)
  "2_1": "3",
  "2_2": "7",
  "2_3": "12",
  "2_4": "16",
  "2_5": "18",
  "2_10": "T",
  "2_11": "M",
  "2_12": "18",
  // CERO (org 3)
  "3_13": "A",
  "3_14": "B",
  "3_15": "C",
  "3_16": "D",
  "3_17": "Z",
  // USK (org 4)
  "4_18": "0",
  "4_19": "6",
  "4_20": "12",
  "4_21": "16",
  "4_22": "18",
  // GRAC (org 5)
  "5_23": "ALL",
  "5_24": "12",
  "5_25": "15",
  "5_26": "18",
  "5_27": "Testing",
  // CLASS_IND (org 6)
  "6_28": "L",
  "6_29": "10",
  "6_30": "12",
  "6_31": "14",
  "6_32": "16",
  "6_33": "18",
  // ACB (org 7)
  "7_34": "G",
  "7_35": "PG",
  "7_36": "M",
  "7_37": "MA15+",
  "7_38": "R18+",
  "7_39": "RC",
};

// Game Status
export const GameStatus: Record<number, string> = {
  0: "Released",
  2: "Alpha",
  3: "Beta",
  4: "Early Access",
  5: "Offline",
  6: "Cancelled",
  7: "Rumored",
  8: "Delisted",
};

// Language Support Types
export const LanguageSupportType: Record<number, string> = {
  1: "Audio",
  2: "Subtitles",
  3: "Interface",
};
