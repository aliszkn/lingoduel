// ignore_for_file: avoid_print
// Hızlı peek — DB'de hangi kelimeler var?
import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.open('assets/db/lingoduel_words.db');

  final total = db.select('SELECT COUNT(*) c FROM words').first['c'];
  print('Toplam kayıt: $total');

  final perSet = db.select(
    'SELECT set_id, COUNT(*) c FROM words GROUP BY set_id ORDER BY set_id',
  );
  print('Set başına:');
  for (final r in perSet) {
    print('  ${r['set_id']}: ${r['c']}');
  }

  final ver = db.select('PRAGMA user_version').first['user_version'];
  print('user_version: $ver');

  print('\nA setinden ilk 5 ham satır:');
  final rows = db.select('SELECT * FROM words LIMIT 5');
  for (final r in rows) {
    print('  $r');
  }

  db.dispose();
}
