// ignore_for_file: avoid_print
//
// Üretilen DB'nin sanity check'i — seed sonrası bir kez çalıştırılır.
//
// Çalıştırma: dart run tool/verify_db.dart
//
// Doğrular:
//  - Her set için 1000 kayıt var
//  - Rarity dağılımı: WordRarityMath.rarityForIndex ile uyumlu
//  - PRAGMA user_version = 1

import 'package:sqlite3/sqlite3.dart';

const _dbPath = 'assets/db/lingoduel_words.db';

const _expectedDist = {
  'A':    {'common': 400, 'uncommon': 300, 'rare': 225, 'epic': 75},
  'BI':   {'common': 300, 'uncommon': 300, 'rare': 250, 'epic': 125, 'legendary': 25},
  'BII':  {'common': 300, 'uncommon': 300, 'rare': 250, 'epic': 125, 'legendary': 25},
  'BIII': {'common': 300, 'uncommon': 300, 'rare': 250, 'epic': 125, 'legendary': 25},
  'CI':   {'common': 250, 'uncommon': 250, 'rare': 250, 'epic': 190, 'legendary': 50, 'mythic': 10},
  'CII':  {'common': 250, 'uncommon': 250, 'rare': 250, 'epic': 190, 'legendary': 50, 'mythic': 10},
  'CIII': {'common': 250, 'uncommon': 250, 'rare': 250, 'epic': 190, 'legendary': 50, 'mythic': 10},
};

void main() {
  final db = sqlite3.open(_dbPath);
  int hata = 0;

  // user_version
  final v = db.select('PRAGMA user_version').first['user_version'];
  print('PRAGMA user_version = $v ${v == 1 ? "✓" : "✗ beklenen 1"}');
  if (v != 1) hata++;

  // Set başı toplam
  final totals = db.select(
    'SELECT set_id, COUNT(*) c FROM words GROUP BY set_id ORDER BY set_id',
  );
  print('\nSet başına toplam:');
  for (final row in totals) {
    final ok = row['c'] == 1000;
    print('  ${row['set_id'].toString().padRight(5)} ${row['c']} ${ok ? "✓" : "✗ beklenen 1000"}');
    if (!ok) hata++;
  }

  // Rarity dağılımı
  print('\nRarity dağılımı:');
  for (final entry in _expectedDist.entries) {
    final setId = entry.key;
    final expected = entry.value;
    final actual = <String, int>{
      for (final r in db.select(
        'SELECT rarity, COUNT(*) c FROM words WHERE set_id = ? GROUP BY rarity',
        [setId],
      ))
        r['rarity'] as String: r['c'] as int,
    };
    for (final r in expected.entries) {
      final actualCount = actual[r.key] ?? 0;
      final ok = actualCount == r.value;
      print('  $setId ${r.key.padRight(10)} ${actualCount.toString().padLeft(4)} '
          '${ok ? "✓" : "✗ beklenen ${r.value}"}');
      if (!ok) hata++;
    }
  }

  db.dispose();

  print('');
  if (hata == 0) {
    print('✓ Tüm doğrulamalar geçti.');
  } else {
    print('✗ $hata hata bulundu.');
  }
}
