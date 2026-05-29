import 'league_models.dart';

/// 1000 kelimelik tek bir set'in metadata'sı.
///
/// Set, **kelime havuzu içeriği**ni tanımlar (BI = B'nin 1. 1000 kelimesi).
/// LP eşiği yoktur — odanın LP eşiği ayrıca [RoomTier] üzerinden gelir.
///
/// Bir oda iki boyutludur:
///   - `setId`: hangi 1000 kelime (A / BI / BII / BIII / CI / CII / CIII)
///   - `tier` : LP kademesi (100 / 250 / 500 / 1K) — `kAllRooms` üzerinden
///
/// D ve E setleri eklendiğinde [kAllWordSets] sonuna yazılır.
class WordSetDefinition {
  /// 'A' | 'BI' | 'BII' | 'BIII' | 'CI' | 'CII' | 'CIII'
  final String id;

  /// Üst harf grubu — `kAllRooms` ile birleştirip RoomDefinition bulmak için.
  final LeagueGroup league;

  /// 0-6 arası global sıralama (UI sıralaması).
  final int orderIndex;

  const WordSetDefinition({
    required this.id,
    required this.league,
    required this.orderIndex,
  });

  @override
  bool operator ==(Object other) =>
      other is WordSetDefinition && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// 7 set'in sabit listesi (UI tek-kaynak).
const List<WordSetDefinition> kAllWordSets = [
  WordSetDefinition(id: 'A',    league: LeagueGroup.A, orderIndex: 0),
  WordSetDefinition(id: 'BI',   league: LeagueGroup.B, orderIndex: 1),
  WordSetDefinition(id: 'BII',  league: LeagueGroup.B, orderIndex: 2),
  WordSetDefinition(id: 'BIII', league: LeagueGroup.B, orderIndex: 3),
  WordSetDefinition(id: 'CI',   league: LeagueGroup.C, orderIndex: 4),
  WordSetDefinition(id: 'CII',  league: LeagueGroup.C, orderIndex: 5),
  WordSetDefinition(id: 'CIII', league: LeagueGroup.C, orderIndex: 6),
];

/// Oda kademeleri (LP eşiği boyutu) — UI tek-kaynak.
const List<String> kAllRoomTiers = ['100', '250', '500', '1K'];

/// ID üzerinden set tanımını döner; bulunamazsa null.
WordSetDefinition? wordSetById(String id) {
  for (final s in kAllWordSets) {
    if (s.id == id) return s;
  }
  return null;
}

/// Verilen ligin altındaki tüm setler (UI gruplaması için).
List<WordSetDefinition> wordSetsByLeague(LeagueGroup league) =>
    kAllWordSets.where((s) => s.league == league).toList();

/// `setId` + `tier` → eski 12-oda kataloğundaki [RoomDefinition].
///
/// LP eşiği ve `LeagueRules.canCreate/canJoin/MatchScoring` tüm hesapları
/// hâlâ [RoomDefinition] üzerinden çalışıyor — bu fonksiyon ikisini köprüler.
///
/// Örnek: roomForSetAndTier('BII', '500') → kAllRooms içindeki B500 odası.
RoomDefinition? roomForSetAndTier(String setId, String tier) {
  final set = wordSetById(setId);
  if (set == null) return null;
  final ligLetter = set.league.name; // 'A' | 'B' | 'C'
  return roomById('$ligLetter$tier');
}
