import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 6 kademeli enderlik sistemi (eski 4'lü RarityLevel'in yerine).
enum WordRarity { common, uncommon, rare, epic, legendary, mythic }

extension WordRarityExt on WordRarity {
  /// İngilizce upper-case etiket (rozet/koleksiyon başlıkları).
  String get label {
    switch (this) {
      case WordRarity.common:    return 'COMMON';
      case WordRarity.uncommon:  return 'UNCOMMON';
      case WordRarity.rare:      return 'RARE';
      case WordRarity.epic:      return 'EPIC';
      case WordRarity.legendary: return 'LEGENDARY';
      case WordRarity.mythic:    return 'MYTHIC';
    }
  }

  /// Türkçe kullanıcı yüzü etiketi.
  String get labelTr {
    switch (this) {
      case WordRarity.common:    return 'Sıradan';
      case WordRarity.uncommon:  return 'Sıradışı';
      case WordRarity.rare:      return 'Ender';
      case WordRarity.epic:      return 'Destansı';
      case WordRarity.legendary: return 'Efsanevi';
      case WordRarity.mythic:    return 'Mistik';
    }
  }

  /// Birincil UI rengi (kart kenarlığı / rozet).
  /// `assets/enderlik/` ikon setiyle senkronize palet.
  Color get color {
    switch (this) {
      case WordRarity.common:    return const Color(0xFF9BA2AD);
      case WordRarity.uncommon:  return const Color(0xFF4ADE80);
      case WordRarity.rare:      return const Color(0xFF5B9BFF);
      case WordRarity.epic:      return const Color(0xFFC18BFF);
      case WordRarity.legendary: return const Color(0xFFFCD34D);
      case WordRarity.mythic:    return const Color(0xFFFF7088);
    }
  }

  /// İkonun yaydığı ışıltı tonu (alfa dahil). Common için neredeyse şeffaf.
  Color get glow {
    switch (this) {
      case WordRarity.common:    return const Color(0x009BA2AD);
      case WordRarity.uncommon:  return const Color(0x4234D058);
      case WordRarity.rare:      return const Color(0x4D3B82F6);
      case WordRarity.epic:      return const Color(0x57A855F7);
      case WordRarity.legendary: return const Color(0x6BFBA316);
      case WordRarity.mythic:    return const Color(0x80FF3D63);
    }
  }

  /// SVG asset yolu. `assets/enderlik/` klasöründeki tasarım ikonu.
  /// Enum adı (İngilizce) → Türkçe dosya adı eşlemesi.
  String get assetPath {
    switch (this) {
      case WordRarity.common:    return 'assets/enderlik/enderlik_siradan.svg';
      case WordRarity.uncommon:  return 'assets/enderlik/enderlik_siradisi.svg';
      case WordRarity.rare:      return 'assets/enderlik/enderlik_ender.svg';
      case WordRarity.epic:      return 'assets/enderlik/enderlik_destansi.svg';
      case WordRarity.legendary: return 'assets/enderlik/enderlik_efsanevi.svg';
      case WordRarity.mythic:    return 'assets/enderlik/enderlik_mistik.svg';
    }
  }

  /// Düelloda doğru cevap verildiğinde sahiplenme (claim) olasılığı.
  /// Mythic hariç tüm enderlikler %20; mythic %10 (yarı).
  /// Sonuç: belirli bir doğru cevabın kart kazandırma şansı ~%20.
  double get duelClaimChance {
    switch (this) {
      case WordRarity.common:    return 0.20;
      case WordRarity.uncommon:  return 0.20;
      case WordRarity.rare:      return 0.20;
      case WordRarity.epic:      return 0.20;
      case WordRarity.legendary: return 0.20;
      case WordRarity.mythic:    return 0.10;
    }
  }

  /// Fame puanı çarpanı (koleksiyon skoru).
  int get fameMultiplier {
    switch (this) {
      case WordRarity.common:    return 1;
      case WordRarity.uncommon:  return 3;
      case WordRarity.rare:      return 10;
      case WordRarity.epic:      return 25;
      case WordRarity.legendary: return 75;
      case WordRarity.mythic:    return 250;
    }
  }
}

/// Set içi dağılım & yardımcı statik fonksiyonlar.
class WordRarityMath {
  WordRarityMath._();

  /// Set kimliğinden (A / BI / BII / BIII / CI / CII / CIII) üst seviye harfi.
  static String levelOf(String setId) {
    if (setId.isEmpty) throw ArgumentError('setId boş olamaz');
    return setId.substring(0, 1).toUpperCase();
  }

  /// 1000 kelimelik set içinde, 0-999 indeksine göre enderliği döner.
  ///
  /// Sabit dağılımlar (set başına):
  ///   A:  400C / 300U / 225R / 75E
  ///   B:  300C / 300U / 250R / 125E / 25L
  ///   C:  250C / 250U / 250R / 190E / 50L / 10M
  ///
  /// DB'de `rarity` kolonu önceden doldurulduysa burayı çağırmaya gerek yok;
  /// bu fonksiyon DB seed yazımında ve fallback olarak kullanılır.
  static WordRarity rarityForIndex({required String setId, required int index}) {
    assert(index >= 0 && index < 1000, 'index 0-999 aralığında olmalı');
    final level = levelOf(setId);
    switch (level) {
      case 'A':
        if (index < 400) return WordRarity.common;
        if (index < 700) return WordRarity.uncommon;
        if (index < 925) return WordRarity.rare;
        return WordRarity.epic;
      case 'B':
        if (index < 300) return WordRarity.common;
        if (index < 600) return WordRarity.uncommon;
        if (index < 850) return WordRarity.rare;
        if (index < 975) return WordRarity.epic;
        return WordRarity.legendary;
      case 'C':
        if (index < 250) return WordRarity.common;
        if (index < 500) return WordRarity.uncommon;
        if (index < 750) return WordRarity.rare;
        if (index < 940) return WordRarity.epic;
        if (index < 990) return WordRarity.legendary;
        return WordRarity.mythic;
      default:
        // D / E seviyeleri ileride eklenirse buraya gelir.
        throw ArgumentError('Bilinmeyen set seviyesi: $level (setId=$setId)');
    }
  }

  /// SQLite TEXT → enum.
  static WordRarity fromDb(String s) => WordRarity.values.byName(s);

  /// Verilen setin desteklediği maksimum enderlik.
  /// A → epic, B → legendary, C → mythic. UI'da bu seviyeden yüksek
  /// enderlik butonları kilitli gösterilir.
  static WordRarity maxRarityForSet(String setId) {
    switch (levelOf(setId)) {
      case 'A': return WordRarity.epic;
      case 'B': return WordRarity.legendary;
      case 'C': return WordRarity.mythic;
      default:
        throw ArgumentError('Bilinmeyen set seviyesi: $setId');
    }
  }

  /// `rarity`, `setId` için desteklenmiyorsa true (UI kilit kontrolü).
  static bool isLockedForSet(String setId, WordRarity rarity) =>
      rarity.index > maxRarityForSet(setId).index;

  /// Set + tier kombinasyonunda ulaşılabilecek maksimum enderlik.
  /// `rarityForIndex(setId, cap-1)` → o tier'daki son kelimenin raritysi
  /// = havuzda varolan en yüksek enderlik seviyesi.
  static WordRarity maxRarityForSetAndTier(String setId, String tier) {
    final int cap = switch (tier) {
      '100' => 100,
      '250' => 250,
      '500' => 500,
      _     => 1000, // '1K' ve bilinmeyen → setin tamamı
    };
    return rarityForIndex(setId: setId, index: cap - 1);
  }

  /// Set + tier havuzunda belirtilen rarity kilitli mi?
  static bool isLockedForSetAndTier(
          String setId, String tier, WordRarity rarity) =>
      rarity.index > maxRarityForSetAndTier(setId, tier).index;
}

/// Tek başına SVG enderlik ikonu. `assets/enderlik/` setinden çekilir.
///
/// Liste/rozet boyutu: 22–28 px, kart/detay: 40–64 px (tasarım rehberi).
class RarityIcon extends StatelessWidget {
  const RarityIcon(this.rarity, {super.key, this.size = 22});

  final WordRarity rarity;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      rarity.assetPath,
      width: size,
      height: size,
    );
  }
}
