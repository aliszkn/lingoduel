import '../game/word_rarity.dart';

/// SQLite veritabanından (lib/services/database_helper.dart) çekilen tek kelime.
///
/// Eski [WordEntry] (lib/data/word_pool.dart) ile aynı alanları taşır, ek olarak
/// [setId] ve [rarity] içerir.
///   - [setId]: kelime hangi 1000'lik sete ait — 'A' | 'BI' | 'BII' | 'BIII'
///              | 'CI' | 'CII' | 'CIII'. (D, E ileride.)
///   - [rank] : set içi indeks (0-999). 0 = setin en yaygın kelimesi.
///   - [rarity]: ön-hesaplı; DB'de TEXT olarak (WordRarity.name) saklanır.
class WordEntry {
  final String en;
  final String tr;
  final String desc;
  final String descTr;
  final String others;
  final String ex;
  final String setId;
  final int rank;
  final WordRarity rarity;

  const WordEntry({
    required this.en,
    required this.tr,
    required this.desc,
    required this.descTr,
    required this.others,
    required this.ex,
    required this.setId,
    required this.rank,
    required this.rarity,
  });

  /// Geriye uyumlu üst seviye harfi (A/B/C). Lig hesaplarında kullanılır.
  String get level => setId.substring(0, 1).toUpperCase();

  /// Stabil kelime kimliği — ownership tablosunda PK olarak kullanılır.
  /// Örn: "BII-0042"
  String get wordId => '$setId-${rank.toString().padLeft(4, '0')}';

  /// SQLite satırından modele dönüştürür. `rarity` kolonu NULL ise
  /// [WordRarityMath.rarityForIndex] üzerinden indekse göre türetilir.
  factory WordEntry.fromRow(Map<String, Object?> row) {
    final setId = row['set_id'] as String;
    final rank = row['rank'] as int;
    final rarityStr = row['rarity'] as String?;
    return WordEntry(
      en:     row['en']      as String,
      tr:     row['tr']      as String,
      desc:   row['desc']    as String? ?? '',
      descTr: row['desc_tr'] as String? ?? '',
      others: row['others']  as String? ?? '',
      ex:     row['ex']      as String? ?? '',
      setId:  setId,
      rank:   rank,
      rarity: rarityStr != null
          ? WordRarityMath.fromDb(rarityStr)
          : WordRarityMath.rarityForIndex(setId: setId, index: rank),
    );
  }

  /// LingoCards Map-tabanlı UI için sözlük temsili (eski API uyumluluğu).
  Map<String, dynamic> toMap() => {
        'en':     en,
        'tr':     tr,
        'others': others,
        'ex':     ex,
        'desc':   desc,
        'descTr': descTr,
        'rank':   rank,
        'setId':  setId,
        'rarity': rarity.name,
      };
}
