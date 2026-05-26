/// Harf grubu: A (başlangıç), B (orta), C (üst)
enum LeagueGroup { A, B, C }

/// Oda kademesi: 100, 250, 500, 1K
enum RoomTier { t100, t250, t500, t1K }

/// Bir oda tipinin tüm özelliklerini tutan değişmez veri sınıfı.
class RoomDefinition {
  /// Hangi harf grubuna ait
  final LeagueGroup league;

  /// Kademe (100 / 250 / 500 / 1K)
  final RoomTier tier;

  /// Bu odayı AÇABİLMEK için gereken minimum LP
  final int createThreshold;

  /// 0-11 arası global sıralama (seviye fark hesabında kullanılır)
  final int levelIndex;

  const RoomDefinition({
    required this.league,
    required this.tier,
    required this.createThreshold,
    required this.levelIndex,
  });

  /// "A500", "B1K" gibi insan-okunabilir kimlik
  String get id {
    final tierStr = switch (tier) {
      RoomTier.t100 => '100',
      RoomTier.t250 => '250',
      RoomTier.t500 => '500',
      RoomTier.t1K  => '1K',
    };
    return '${league.name}$tierStr';
  }

  @override
  String toString() => 'Room($id)';

  @override
  bool operator ==(Object other) =>
      other is RoomDefinition && other.levelIndex == levelIndex;

  @override
  int get hashCode => levelIndex;
}

// ─── 12 Odanın Sabit Listesi ─────────────────────────────────────────────────
//
// Not: B1K ve C100 aynı eşiğe (2100 LP) sahiptir; levelIndex farklıdır.

const List<RoomDefinition> kAllRooms = [
  // ─ A Ligi ─
  RoomDefinition(league: LeagueGroup.A, tier: RoomTier.t100,  createThreshold: 0,    levelIndex: 0),
  RoomDefinition(league: LeagueGroup.A, tier: RoomTier.t250,  createThreshold: 250,  levelIndex: 1),
  RoomDefinition(league: LeagueGroup.A, tier: RoomTier.t500,  createThreshold: 500,  levelIndex: 2),
  RoomDefinition(league: LeagueGroup.A, tier: RoomTier.t1K,   createThreshold: 1000, levelIndex: 3),
  // ─ B Ligi ─
  RoomDefinition(league: LeagueGroup.B, tier: RoomTier.t100,  createThreshold: 1100, levelIndex: 4),
  RoomDefinition(league: LeagueGroup.B, tier: RoomTier.t250,  createThreshold: 1350, levelIndex: 5),
  RoomDefinition(league: LeagueGroup.B, tier: RoomTier.t500,  createThreshold: 1600, levelIndex: 6),
  RoomDefinition(league: LeagueGroup.B, tier: RoomTier.t1K,   createThreshold: 2100, levelIndex: 7),
  // ─ C Ligi ─
  RoomDefinition(league: LeagueGroup.C, tier: RoomTier.t100,  createThreshold: 2100, levelIndex: 8),
  RoomDefinition(league: LeagueGroup.C, tier: RoomTier.t250,  createThreshold: 2350, levelIndex: 9),
  RoomDefinition(league: LeagueGroup.C, tier: RoomTier.t500,  createThreshold: 2600, levelIndex: 10),
  RoomDefinition(league: LeagueGroup.C, tier: RoomTier.t1K,   createThreshold: 3100, levelIndex: 11),
];

/// ID (örn: "A500") üzerinden oda tanımını döner; bulunamazsa null.
RoomDefinition? roomById(String id) {
  for (final room in kAllRooms) {
    if (room.id == id) return room;
  }
  return null;
}
