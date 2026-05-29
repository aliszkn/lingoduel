// LingoDuel kelime veritabanı seed scripti.
//
// Çalıştırma:
//   dart run tool/seed_db.dart                  → JSON kaynaklardan DB üret
//   dart run tool/seed_db.dart --dummy          → 7000 placeholder ile DB üret
//   dart run tool/seed_db.dart --init-templates → 7 boş JSON şablonu oluştur
//
// Çıktı: assets/db/lingoduel_words.db
// Şema:  lib/services/database_helper.dart yorum bloğu.
//
// NOT: Script Flutter SDK'sına bağlı DEĞİL — Dart VM'in FFI transformer'ı
// `package:flutter` import'unda crash ediyor (NativeCallable bug). Bu yüzden
// aşağıdaki [_kSetIds] ve [_rarityForIndex] sabitleri, `lib/` içindeki
// karşılıkları (`DatabaseHelper.kAllSetIds`, `WordRarityMath.rarityForIndex`)
// ile manuel olarak senkronize tutulmalı. D/E setleri eklenince iki yere de
// ekle.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

const _outPath = 'assets/db/lingoduel_words.db';
const _dataDir = 'tool/seed_data';
const _wordsPerSet = 1000;

/// Tek-kaynak: `DatabaseHelper.kAllSetIds` ile senkron.
const List<String> _kSetIds = [
  'A', 'BI', 'BII', 'BIII', 'CI', 'CII', 'CIII',
];

/// 6 rarity adı (DB'de WordRarity.name TEXT olarak saklanır).
/// `lib/game/word_rarity.dart` enum sırası ile senkron olmalı.
const List<String> _kRarities = [
  'common', 'uncommon', 'rare', 'epic', 'legendary', 'mythic',
];

void main(List<String> args) {
  if (args.contains('--init-templates')) {
    _initTemplates();
    return;
  }

  final bool dummy = args.contains('--dummy');
  _buildDb(dummy: dummy);
}

// ─── Rarity dağılımı (WordRarityMath.rarityForIndex ile senkron) ─────────────

/// Setin lig harfi (A/B/C) + 0-999 indeks → rarity adı.
///
/// A:  400 common / 300 uncommon / 225 rare / 75 epic
/// B:  300 common / 300 uncommon / 250 rare / 125 epic / 25 legendary
/// C:  250 common / 250 uncommon / 250 rare / 190 epic / 50 legendary / 10 mythic
String _rarityForIndex(String setId, int index) {
  assert(index >= 0 && index < _wordsPerSet);
  final lig = setId.substring(0, 1).toUpperCase();
  switch (lig) {
    case 'A':
      if (index < 400) return 'common';
      if (index < 700) return 'uncommon';
      if (index < 925) return 'rare';
      return 'epic';
    case 'B':
      if (index < 300) return 'common';
      if (index < 600) return 'uncommon';
      if (index < 850) return 'rare';
      if (index < 975) return 'epic';
      return 'legendary';
    case 'C':
      if (index < 250) return 'common';
      if (index < 500) return 'uncommon';
      if (index < 750) return 'rare';
      if (index < 940) return 'epic';
      if (index < 990) return 'legendary';
      return 'mythic';
    default:
      throw ArgumentError('Bilinmeyen set seviyesi: $lig (setId=$setId)');
  }
}

// ─── Mod 1: Şablon JSON dosyalarını üret ─────────────────────────────────────

void _initTemplates() {
  Directory(_dataDir).createSync(recursive: true);

  final encoder = const JsonEncoder.withIndent('  ');
  Map<String, String> blank() => {
        'en': '',
        'tr': '',
        'desc': '',
        'desc_tr': '',
        'others': '',
        'ex': '',
      };

  int created = 0;
  for (final setId in _kSetIds) {
    final file = File(p.join(_dataDir, '$setId.json'));
    if (file.existsSync()) {
      stdout.writeln('atlandı (var): ${file.path}');
      continue;
    }
    final entries = List.generate(_wordsPerSet, (_) => blank());
    file.writeAsStringSync(encoder.convert(entries));
    stdout.writeln('oluşturuldu: ${file.path} ($_wordsPerSet kayıt)');
    created++;
  }
  stdout.writeln('✓ $created şablon dosyası oluşturuldu.');
}

// ─── Mod 2: DB üret (--dummy veya JSON'lardan) ───────────────────────────────

void _buildDb({required bool dummy}) {
  // 1. Çıktıyı temizle
  final outFile = File(_outPath);
  outFile.parent.createSync(recursive: true);
  if (outFile.existsSync()) outFile.deleteSync();

  // 2. SQLite aç (yeni dosya)
  final db = sqlite3.open(_outPath);

  try {
    // 3. Şema
    db.execute('''
      CREATE TABLE words (
        set_id   TEXT NOT NULL,
        rank     INTEGER NOT NULL,
        en       TEXT NOT NULL,
        tr       TEXT NOT NULL,
        desc     TEXT,
        desc_tr  TEXT,
        others   TEXT,
        ex       TEXT,
        rarity   TEXT,
        PRIMARY KEY (set_id, rank)
      )
    ''');
    db.execute('CREATE INDEX idx_words_set ON words(set_id)');

    // 4. Hazırlıklı insert
    final stmt = db.prepare('''
      INSERT INTO words (set_id, rank, en, tr, desc, desc_tr, others, ex, rarity)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''');

    try {
      for (final setId in _kSetIds) {
        final raw =
            dummy ? _generateDummy(setId) : _loadFromJson(setId);

        // Kısmi doluluk: kullanıcı henüz 1000 kelimeyi tamamlamadıysa kalanı
        // boş satırlarla doldur. Böylece DB hep 1000 satır/set olur ve rarity
        // dağılımı bozulmaz.
        if (raw.length > _wordsPerSet) {
          throw StateError(
            '$setId: en fazla $_wordsPerSet kayıt olmalı, ${raw.length} bulundu',
          );
        }
        final entries = List<Map<String, dynamic>>.generate(
          _wordsPerSet,
          (i) => i < raw.length ? raw[i] : const <String, dynamic>{},
        );

        db.execute('BEGIN');
        int dolu = 0;
        for (int i = 0; i < entries.length; i++) {
          final w = entries[i];
          // Hem `descTr` (camelCase) hem `desc_tr` (snake_case) kabul edilir —
          // kullanıcı JSON'larında karışık kullanım var.
          final en = (w['en'] ?? '').toString();
          if (en.isNotEmpty) dolu++;
          stmt.execute([
            setId,
            i,
            en,
            w['tr'] ?? '',
            w['desc'] ?? '',
            w['desc_tr'] ?? w['descTr'] ?? '',
            w['others'] ?? '',
            w['ex'] ?? '',
            _rarityForIndex(setId, i),
          ]);
        }
        db.execute('COMMIT');
        stdout.writeln('$setId: $_wordsPerSet satır ($dolu dolu, ${_wordsPerSet - dolu} boş)');
      }
    } finally {
      stmt.dispose();
    }

    // 5. Versiyon damgası — her seed run'da artar. DatabaseHelper bunu okuyup
    //    cihaz DB'nin user_version'ı ile karşılaştırır; küçükse asset'i tazeler.
    final version = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    db.execute('PRAGMA user_version = $version');

    // version.txt — DatabaseHelper bunu rootBundle ile okur (asset DB'yi açmaya
    // gerek kalmadan sürüm karşılaştırması).
    File(p.join(outFile.parent.path, 'version.txt'))
        .writeAsStringSync('$version\n');

    final kb = outFile.lengthSync() ~/ 1024;
    stdout.writeln('✓ DB üretildi: $_outPath ($kb KB)');
    stdout.writeln('  Versiyon: $version');
    stdout.writeln('  Rarity sözlüğü: ${_kRarities.join(", ")}');
  } finally {
    db.dispose();
  }
}

// ─── Kaynak yükleyiciler ─────────────────────────────────────────────────────

List<Map<String, dynamic>> _loadFromJson(String setId) {
  final file = File(p.join(_dataDir, '$setId.json'));
  if (!file.existsSync()) {
    throw StateError(
      'Eksik kaynak: ${file.path}\n'
      'İpucu: önce şablonları üret → dart run tool/seed_db.dart --init-templates',
    );
  }
  final raw = jsonDecode(file.readAsStringSync()) as List;
  return raw.cast<Map<String, dynamic>>();
}

List<Map<String, dynamic>> _generateDummy(String setId) =>
    List.generate(_wordsPerSet, (i) {
      final rank = i.toString().padLeft(4, '0');
      return {
        'en': 'Word_${setId}_$rank',
        'tr': 'Kelime_${setId}_$rank',
        'desc': 'Placeholder description for $setId rank $i.',
        'desc_tr': '$setId setinin $i. kelimesi için tanım.',
        'others': '—',
        'ex': 'This is an example for Word_${setId}_$rank.',
      };
    });
