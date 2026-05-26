import 'package:flutter/material.dart';

enum RarityLevel { common, uncommon, rare, legendary }

extension RarityLevelExt on RarityLevel {
  String get label {
    switch (this) {
      case RarityLevel.common:    return 'COMMON';
      case RarityLevel.uncommon:  return 'UNCOMMON';
      case RarityLevel.rare:      return 'RARE';
      case RarityLevel.legendary: return 'LEGENDARY';
    }
  }

  Color get color {
    switch (this) {
      case RarityLevel.common:    return Colors.white54;
      case RarityLevel.uncommon:  return const Color(0xFF4CAF50);
      case RarityLevel.rare:      return const Color(0xFF2979FF);
      case RarityLevel.legendary: return const Color(0xFFFFD600);
    }
  }

  // Flash kart açılışında sahiplenme olasılığı (zor/koleksiyoncu preset)
  double get flashcardClaimChance {
    switch (this) {
      case RarityLevel.common:    return 0.10;  // ~10 açılışta 1
      case RarityLevel.uncommon:  return 0.04;  // ~25 açılışta 1
      case RarityLevel.rare:      return 0.01;  // ~100 açılışta 1
      case RarityLevel.legendary: return 0.002; // ~500 açılışta 1
    }
  }

  int get fameMultiplier {
    switch (this) {
      case RarityLevel.common:    return 1;
      case RarityLevel.uncommon:  return 3;
      case RarityLevel.rare:      return 10;
      case RarityLevel.legendary: return 50;
    }
  }
}

class WordRarity {
  WordRarity._();

  // WordEntry.rank (1-80 içi) → nadirlik
  // rank 1-20  = X100 tier = Common
  // rank 21-40 = X250 tier = Uncommon
  // rank 41-60 = X500 tier = Rare
  // rank 61-80 = X1K tier  = Legendary
  static RarityLevel fromRank(int rank) {
    if (rank <= 20) return RarityLevel.common;
    if (rank <= 40) return RarityLevel.uncommon;
    if (rank <= 60) return RarityLevel.rare;
    return RarityLevel.legendary;
  }

  static RarityLevel fromDb(String s) => RarityLevel.values.byName(s);
}
