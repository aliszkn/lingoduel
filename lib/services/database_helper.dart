import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/word_entry.dart';

/// 14.000 kelimelik önceden doldurulmuş (pre-populated) SQLite veritabanını yönetir.
///
/// **Beklenen şema** — `assets/db/lingoduel_words.db` içinde hazır olmalı:
///
///   CREATE TABLE words (
///     set_id   TEXT NOT NULL,    -- 'A'|'BI'|'BII'|'BIII'|'CI'|'CII'|'CIII'
///     rank     INTEGER NOT NULL, -- 0-999, set içi indeks (0 = en yaygın)
///     en       TEXT NOT NULL,
///     tr       TEXT NOT NULL,
///     desc     TEXT,
///     desc_tr  TEXT,
///     others   TEXT,
///     ex       TEXT,
///     rarity   TEXT,             -- ön-hesaplı; NULL ise koddan türetilir
///     PRIMARY KEY (set_id, rank)
///   );
///   CREATE INDEX idx_words_set ON words(set_id);
///
/// **Lazy loading:** Cihazda kopya yoksa asset bir kez kopyalanır. `getWordsBySetId`
/// yalnızca seçilen setin 1000 kelimesini RAM'e taşır; 14.000'in tamamı yüklenmez.
///
/// **Sürümleme:** İçerik değişince [_dbVersion] artırılır → eski kopya silinip
/// yeniden kopyalanır. (PRAGMA user_version üzerinden takip.)
class DatabaseHelper {
  DatabaseHelper._();

  static const String _assetPath = 'assets/db/lingoduel_words.db';
  static const String _assetVersionPath = 'assets/db/version.txt';
  static const String _dbFileName = 'lingoduel_words.db';

  /// Şu an mevcut olan set kimlikleri (UI listeleri için tek-kaynak).
  /// D ve E setleri ileride buraya eklenir.
  static const List<String> kAllSetIds = [
    'A', 'BI', 'BII', 'BIII', 'CI', 'CII', 'CIII',
  ];

  static Database? _db;

  /// Lazy: ilk çağrıda asset kopyalanır + bağlantı açılır.
  static Future<Database> get database async {
    return _db ??= await _open();
  }

  /// İsteğe bağlı erken init (main()'de). `database` getter'ı zaten lazy.
  static Future<void> init() async => database;

  static Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbFileName);

    // Asset DB'nin sürümünü `version.txt`'ten oku (tool/seed_db.dart yazar).
    // Her seed run'da timestamp olarak artar; cihazdaki kopya eskiyse tazelenir.
    final assetVersion = await _readAssetVersion();

    final exists = await databaseExists(path);
    if (!exists) {
      await _copyAssetTo(path);
    } else if (await _readUserVersion(path) < assetVersion) {
      // İçerik güncellendi — yerel kopyayı tazele.
      await deleteDatabase(path);
      await _copyAssetTo(path);
    }

    final db = await openDatabase(path);
    // Asset DB zaten doğru user_version ile gelir (seed_db PRAGMA yazıyor);
    // burada üzerine yazmak gerekmez. Ama yeniden kopyalama olmayan açılışta
    // bir-no-op olarak korur.
    await db.execute('PRAGMA user_version = $assetVersion');
    return db;
  }

  /// `assets/db/version.txt` içeriğini int olarak döner. Dosya yoksa veya
  /// parse edilemezse 0 (her açılışta tazele etkisi).
  static Future<int> _readAssetVersion() async {
    try {
      final s = await rootBundle.loadString(_assetVersionPath);
      return int.tryParse(s.trim()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> _copyAssetTo(String path) async {
    await Directory(p.dirname(path)).create(recursive: true);
    final data = await rootBundle.load(_assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    await File(path).writeAsBytes(bytes, flush: true);
  }

  static Future<int> _readUserVersion(String path) async {
    final probe = await openDatabase(path, readOnly: true);
    try {
      final rows = await probe.rawQuery('PRAGMA user_version');
      final v = rows.isEmpty ? null : rows.first.values.first;
      return v is int ? v : 0;
    } finally {
      await probe.close();
    }
  }

  // ── Sorgular ───────────────────────────────────────────────────────────────

  /// Verilen setin doldurulmuş kelimelerini (rank artan) döner.
  /// LingoCards filter bar + LingoDuel oda kurulumu bunu kullanır.
  ///
  /// `en` veya `tr` alanı boş olan satırlar (henüz doldurulmamış placeholder'lar)
  /// otomatik atlanır — DB'de 1000 satır olsa da oyun yalnızca gerçek kelimeleri
  /// görür.
  static Future<List<WordEntry>> getWordsBySetId(String setId) async {
    final db = await database;
    final rows = await db.query(
      'words',
      where: "set_id = ? AND en != '' AND tr != ''",
      whereArgs: [setId],
      orderBy: 'rank ASC',
    );
    return rows.map(WordEntry.fromRow).toList();
  }

  /// Setin ilk [rankCap] kelimesini (rank < rankCap, rank ASC) döner.
  /// Tier'lı oda havuzu için kullanılır. Boş placeholder satırlar atlanır.
  /// Örn. getWordsBySetIdCapped('BI', 250) → BI rank 0-249.
  static Future<List<WordEntry>> getWordsBySetIdCapped(
      String setId, int rankCap) async {
    final db = await database;
    final rows = await db.query(
      'words',
      where: "set_id = ? AND en != '' AND tr != '' AND rank < ?",
      whereArgs: [setId, rankCap],
      orderBy: 'rank ASC',
    );
    return rows.map(WordEntry.fromRow).toList();
  }

  /// `wordId` listesine karşılık gelen kelimeleri döner (wordId → WordEntry).
  /// wordId formatı: "setId-NNNN" (örn. "A-0042", "BII-0137").
  /// Bulunamayan ya da boş olan kelimeler sonuca dahil edilmez.
  static Future<Map<String, WordEntry>> getWordsByWordIds(
      List<String> wordIds) async {
    final result = <String, WordEntry>{};
    if (wordIds.isEmpty) return result;

    // setId → rank listesi olarak grupla
    final bySet = <String, List<int>>{};
    for (final wid in wordIds) {
      final dash = wid.lastIndexOf('-');
      if (dash <= 0) continue;
      final setId = wid.substring(0, dash);
      final rank = int.tryParse(wid.substring(dash + 1));
      if (rank != null) bySet.putIfAbsent(setId, () => []).add(rank);
    }

    final db = await database;
    for (final entry in bySet.entries) {
      final placeholders = entry.value.map((_) => '?').join(',');
      final rows = await db.query(
        'words',
        where:
            "set_id = ? AND en != '' AND tr != '' AND rank IN ($placeholders)",
        whereArgs: [entry.key, ...entry.value],
      );
      for (final row in rows) {
        final we = WordEntry.fromRow(row);
        result[we.wordId] = we;
      }
    }
    return result;
  }

  /// Setteki dolu kelime sayısı (UI rozeti). Boş placeholder'ları saymaz.
  static Future<int> countBySetId(String setId) async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM words WHERE set_id = ? AND en != '' AND tr != ''",
      [setId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Tüm setlerde `en` veya `tr` alanında arama (büyük/küçük harf duyarsız).
  /// Sonuçlar rank'e göre artan sırada döner (yaygın kelimeler önce).
  static Future<List<WordEntry>> searchWords(String query,
      {int limit = 60}) async {
    if (query.trim().isEmpty) return const [];
    final db = await database;
    final rows = await db.query(
      'words',
      where: "(en LIKE ? OR tr LIKE ?) AND en != '' AND tr != ''",
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'rank ASC',
      limit: limit,
    );
    return rows.map(WordEntry.fromRow).toList();
  }

  /// Eski API geçişi için: bir seviyenin (A/B/C) TÜM dolu kelimelerini birleştirir.
  /// 3 set × 1000 kelime → büyük liste; lobi/ön-yükleme dışında kullanılmamalı.
  /// Boş placeholder satırları atlanır.
  static Future<List<WordEntry>> getWordsByLevel(String level) async {
    final db = await database;
    final rows = await db.query(
      'words',
      where: "set_id LIKE ? AND en != '' AND tr != ''",
      whereArgs: ['$level%'],
      orderBy: 'set_id ASC, rank ASC',
    );
    return rows.map(WordEntry.fromRow).toList();
  }

  /// Geliştirme: yerel kopyayı silip yeniden kopyalanmaya zorlar.
  static Future<void> resetLocalCopy() async {
    await _db?.close();
    _db = null;
    final path = p.join(await getDatabasesPath(), _dbFileName);
    await deleteDatabase(path);
  }
}
