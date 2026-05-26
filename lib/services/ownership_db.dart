import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../game/word_rarity.dart';

// ─── Veri modelleri ──────────────────────────────────────────────────────────

class OwnershipRecord {
  final String wordId;      // "A01" … "C80"
  final RarityLevel rarity;
  final String ownerId;
  final String claimSource; // 'flashcard' | 'duel'
  final int claimedAt;      // millisecondsSinceEpoch

  const OwnershipRecord({
    required this.wordId,
    required this.rarity,
    required this.ownerId,
    required this.claimSource,
    required this.claimedAt,
  });
}

class FameStats {
  final int common;
  final int uncommon;
  final int rare;
  final int legendary;

  const FameStats({
    required this.common,
    required this.uncommon,
    required this.rare,
    required this.legendary,
  });

  int get totalOwned => common + uncommon + rare + legendary;

  // fame = sahip olunan × nadirlik çarpanı
  int get famePoints =>
      common * 1 + uncommon * 3 + rare * 10 + legendary * 50;

  // Koleksiyoncu unvanı
  String get title {
    if (famePoints >= 500)  return 'EFSANE KOLEKSIYONCU';
    if (famePoints >= 150)  return 'LEKSIKON';
    if (famePoints >= 40)   return 'SÖZCÜK USTASI';
    if (famePoints >= 5)    return 'KELİME AVCI';
    return 'YENİ KOLEKSIYONCU';
  }

  static const FameStats empty = FameStats(
    common: 0, uncommon: 0, rare: 0, legendary: 0,
  );
}

// ─── DB servisi ──────────────────────────────────────────────────────────────

// Veritabanı şeması (referans):
//
//   CREATE TABLE word_ownership (
//     word_id      TEXT PRIMARY KEY,    -- "A01" … "C80"
//     rarity       TEXT NOT NULL,       -- 'common'|'uncommon'|'rare'|'legendary'
//     owner_id     TEXT NOT NULL,       -- 'Sen' veya başka oyuncu adı
//     claim_source TEXT NOT NULL,       -- 'flashcard' | 'duel'
//     claimed_at   INTEGER NOT NULL     -- milisaniye epoch
//   );
//   CREATE INDEX idx_wo_owner ON word_ownership(owner_id);

class OwnershipDb {
  OwnershipDb._();

  static Database? _db;

  static Future<void> init() async {
    if (_db != null) return;
    final dbPath = p.join(await getDatabasesPath(), 'ownership.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE word_ownership (
            word_id      TEXT PRIMARY KEY,
            rarity       TEXT NOT NULL,
            owner_id     TEXT NOT NULL,
            claim_source TEXT NOT NULL,
            claimed_at   INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_wo_owner ON word_ownership(owner_id)',
        );
      },
    );
  }

  static Database get _d {
    assert(_db != null, 'OwnershipDb.init() çağrılmadan kullanılamaz');
    return _db!;
  }

  // Kelimeyi kimin sahiplendiğini döner; sahip yoksa null.
  static Future<String?> getOwner(String wordId) async {
    final rows = await _d.query(
      'word_ownership',
      columns: ['owner_id'],
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['owner_id'] as String;
  }

  // Kelimeyi verilen oyuncuya atar (önceki sahibinin üzerine yazar → çalma).
  static Future<void> setOwner({
    required String wordId,
    required RarityLevel rarity,
    required String ownerId,
    required String claimSource,
  }) async {
    await _d.insert(
      'word_ownership',
      {
        'word_id':      wordId,
        'rarity':       rarity.name,
        'owner_id':     ownerId,
        'claim_source': claimSource,
        'claimed_at':   DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Oyuncunun sahip olduğu kelime istatistiklerini (nadirliğe göre) döner.
  static Future<FameStats> getFameStats(String playerId) async {
    final rows = await _d.rawQuery('''
      SELECT rarity, COUNT(*) AS cnt
      FROM word_ownership
      WHERE owner_id = ?
      GROUP BY rarity
    ''', [playerId]);

    int common = 0, uncommon = 0, rare = 0, legendary = 0;
    for (final row in rows) {
      final count = row['cnt'] as int;
      switch (row['rarity'] as String) {
        case 'common':    common    = count; break;
        case 'uncommon':  uncommon  = count; break;
        case 'rare':      rare      = count; break;
        case 'legendary': legendary = count; break;
      }
    }
    return FameStats(
      common: common,
      uncommon: uncommon,
      rare: rare,
      legendary: legendary,
    );
  }

  // Oyuncunun sahip olduğu tüm kelimeler (en son sahiplenilenden başlar).
  static Future<List<OwnershipRecord>> getOwnedWords(String playerId) async {
    final rows = await _d.query(
      'word_ownership',
      where: 'owner_id = ?',
      whereArgs: [playerId],
      orderBy: 'claimed_at DESC',
    );
    return rows.map((r) => OwnershipRecord(
      wordId:      r['word_id']      as String,
      rarity:      WordRarity.fromDb(r['rarity'] as String),
      ownerId:     r['owner_id']     as String,
      claimSource: r['claim_source'] as String,
      claimedAt:   r['claimed_at']   as int,
    )).toList();
  }

  // Test / geliştirme için tüm sahiplikleri sıfırlar.
  static Future<void> resetAll() async {
    await _d.delete('word_ownership');
  }
}
