import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../game/word_rarity.dart';

// ─── Veri modelleri ──────────────────────────────────────────────────────────

class OwnershipRecord {
  final String wordId;      // "A01" … "C80" (eski) / "BII-0042" (yeni, GÖREV 3+)
  final WordRarity rarity;
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
  final int epic;
  final int legendary;
  final int mythic;

  const FameStats({
    required this.common,
    required this.uncommon,
    required this.rare,
    required this.epic,
    required this.legendary,
    required this.mythic,
  });

  int get totalOwned =>
      common + uncommon + rare + epic + legendary + mythic;

  /// fame = Σ (sahip olunan × WordRarityExt.fameMultiplier)
  int get famePoints =>
      common    * WordRarity.common.fameMultiplier +
      uncommon  * WordRarity.uncommon.fameMultiplier +
      rare      * WordRarity.rare.fameMultiplier +
      epic      * WordRarity.epic.fameMultiplier +
      legendary * WordRarity.legendary.fameMultiplier +
      mythic    * WordRarity.mythic.fameMultiplier;

  /// Koleksiyoncu unvanı. Eşikler yeni multiplier'lara göre ileride tunelenebilir.
  String get title {
    if (famePoints >= 500) return 'EFSANE KOLEKSIYONCU';
    if (famePoints >= 150) return 'LEKSIKON';
    if (famePoints >= 40)  return 'SÖZCÜK USTASI';
    if (famePoints >= 5)   return 'KELİME AVCI';
    return 'YENİ KOLEKSIYONCU';
  }

  static const FameStats empty = FameStats(
    common: 0, uncommon: 0, rare: 0, epic: 0, legendary: 0, mythic: 0,
  );
}

/// Maç geçmişindeki tek bir kelimenin sonucu.
class MatchWordResult {
  final String wordId;         // "A-0001"
  final String en;
  final String tr;
  final String desc;           // İngilizce soru metni
  final String descTr;         // Türkçe soru metni
  final WordRarity rarity;
  final bool? correct;         // true=doğru, false=yanlış, null=cevapsız
  final int? cevapSaniyesi;    // Tıklama anındaki kalanSure; null = cevapsız

  const MatchWordResult({
    required this.wordId,
    required this.en,
    required this.tr,
    required this.desc,
    required this.descTr,
    required this.rarity,
    required this.correct,
    required this.cevapSaniyesi,
  });
}

/// Bir maçın tüm kayıt bilgileri.
class MatchRecord {
  final int id;
  final int playedAt;        // millisecondsSinceEpoch
  final String setId;
  final String tier;
  final int position;        // oyuncunun bitiş sırası (1 tabanlı)
  final int playerCount;
  final List<MatchWordResult> words;

  const MatchRecord({
    required this.id,
    required this.playedAt,
    required this.setId,
    required this.tier,
    required this.position,
    required this.playerCount,
    required this.words,
  });
}

// ─── DB servisi ──────────────────────────────────────────────────────────────

// Veritabanı şeması (referans):
//
//   CREATE TABLE word_ownership (
//     word_id      TEXT PRIMARY KEY,    -- "A01" … (eski) / "BII-0042" (yeni)
//     rarity       TEXT NOT NULL,       -- 6 değerden biri (WordRarity.name)
//     owner_id     TEXT NOT NULL,
//     claim_source TEXT NOT NULL,       -- 'flashcard' | 'duel'
//     claimed_at   INTEGER NOT NULL
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
      version: 3,
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
        await db.execute('''
          CREATE TABLE match_history (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            played_at    INTEGER NOT NULL,
            set_id       TEXT NOT NULL,
            tier         TEXT NOT NULL,
            position     INTEGER NOT NULL,
            player_count INTEGER NOT NULL,
            words_json   TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldV, newV) async {
        // v1→v2: wordId format değişti; eski kayıtlar silinir.
        if (oldV < 2) await db.delete('word_ownership');
        // v2→v3: maç geçmişi tablosu eklendi.
        if (oldV < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS match_history (
              id           INTEGER PRIMARY KEY AUTOINCREMENT,
              played_at    INTEGER NOT NULL,
              set_id       TEXT NOT NULL,
              tier         TEXT NOT NULL,
              position     INTEGER NOT NULL,
              player_count INTEGER NOT NULL,
              words_json   TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  static Database get _d {
    assert(_db != null, 'OwnershipDb.init() çağrılmadan kullanılamaz');
    return _db!;
  }

  /// Kelimeyi kimin sahiplendiğini döner; sahip yoksa null.
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

  /// Kelimeyi verilen oyuncuya atar (önceki sahibinin üzerine yazar → çalma).
  static Future<void> setOwner({
    required String wordId,
    required WordRarity rarity,
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

  /// Oyuncunun sahip olduğu kelime istatistiklerini (nadirliğe göre) döner.
  static Future<FameStats> getFameStats(String playerId) async {
    final rows = await _d.rawQuery('''
      SELECT rarity, COUNT(*) AS cnt
      FROM word_ownership
      WHERE owner_id = ?
      GROUP BY rarity
    ''', [playerId]);

    final counts = <WordRarity, int>{
      for (final r in WordRarity.values) r: 0,
    };
    final lookup = {for (final r in WordRarity.values) r.name: r};
    for (final row in rows) {
      final wr = lookup[row['rarity'] as String];
      if (wr != null) counts[wr] = row['cnt'] as int;
    }
    return FameStats(
      common:    counts[WordRarity.common]!,
      uncommon:  counts[WordRarity.uncommon]!,
      rare:      counts[WordRarity.rare]!,
      epic:      counts[WordRarity.epic]!,
      legendary: counts[WordRarity.legendary]!,
      mythic:    counts[WordRarity.mythic]!,
    );
  }

  /// Oyuncunun sahip olduğu tüm kelimeler (en son sahiplenilenden başlar).
  static Future<List<OwnershipRecord>> getOwnedWords(String playerId) async {
    final rows = await _d.query(
      'word_ownership',
      where: 'owner_id = ?',
      whereArgs: [playerId],
      orderBy: 'claimed_at DESC',
    );
    return rows.map((r) => OwnershipRecord(
      wordId:      r['word_id']      as String,
      rarity:      WordRarityMath.fromDb(r['rarity'] as String),
      ownerId:     r['owner_id']     as String,
      claimSource: r['claim_source'] as String,
      claimedAt:   r['claimed_at']   as int,
    )).toList();
  }

  /// Test / geliştirme için tüm sahiplikleri sıfırlar.
  static Future<void> resetAll() async {
    await _d.delete('word_ownership');
  }

  // ── Maç Geçmişi ───────────────────────────────────────────────────────────

  /// Bir maçı geçmişe kaydeder. Fire-and-forget çağrılabilir (await opsiyonel).
  static Future<void> saveMatch({
    required String setId,
    required String tier,
    required int position,
    required int playerCount,
    required List<MatchWordResult> words,
  }) async {
    final wordsJson = jsonEncode(words.map((w) => {
      'id':      w.wordId,
      'en':      w.en,
      'tr':      w.tr,
      'desc':    w.desc,
      'desc_tr': w.descTr,
      'rarity':  w.rarity.name,
      'correct': w.correct,
      'sn':      w.cevapSaniyesi,
    }).toList());
    await _d.insert('match_history', {
      'played_at':    DateTime.now().millisecondsSinceEpoch,
      'set_id':       setId,
      'tier':         tier,
      'position':     position,
      'player_count': playerCount,
      'words_json':   wordsJson,
    });
  }

  /// En son [limit] maç kaydını döner (en yeni önce).
  static Future<List<MatchRecord>> getMatchHistory({int limit = 30}) async {
    final rows = await _d.query(
      'match_history',
      orderBy: 'played_at DESC',
      limit: limit,
    );
    return rows.map((r) {
      final raw = jsonDecode(r['words_json'] as String) as List;
      final words = raw.map((w) => MatchWordResult(
        wordId:        w['id']      as String,
        en:            w['en']      as String,
        tr:            w['tr']      as String,
        desc:          (w['desc']    as String?) ?? '',
        descTr:        (w['desc_tr'] as String?) ?? '',
        rarity:        WordRarityMath.fromDb(w['rarity'] as String),
        correct:       w['correct']  as bool?,
        cevapSaniyesi: w['sn']       as int?,
      )).toList();
      return MatchRecord(
        id:          r['id']           as int,
        playedAt:    r['played_at']    as int,
        setId:       r['set_id']       as String,
        tier:        r['tier']         as String,
        position:    r['position']     as int,
        playerCount: r['player_count'] as int,
        words:       words,
      );
    }).toList();
  }
}
