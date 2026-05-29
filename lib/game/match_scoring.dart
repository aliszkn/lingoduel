import 'dart:math' show max;
import 'league_models.dart';
import 'league_rules.dart';

// ─── Veri Modelleri ───────────────────────────────────────────────────────────

/// Bir oyuncunun maç sonu LP sonucu
class PlayerMatchResult {
  final String playerId;

  /// Maçtaki sıralama (1–6)
  final int position;

  final int lpBefore;
  final int lpChange;

  /// lpBefore + lpChange, 0'ın altına düşmez
  final int lpAfter;

  final RoomDefinition room;

  const PlayerMatchResult({
    required this.playerId,
    required this.position,
    required this.lpBefore,
    required this.lpChange,
    required this.lpAfter,
    required this.room,
  });

  @override
  String toString() =>
      'PlayerMatchResult($playerId pos:$position lp:$lpBefore→$lpAfter '
      '[${ lpChange >= 0 ? '+' : ''}$lpChange])';
}

/// Bir maçın tüm oyuncularının sonuçlarını içeren özet
class MatchOutcome {
  final RoomDefinition room;
  final List<PlayerMatchResult> results;

  const MatchOutcome({required this.room, required this.results});
}

// ─── Merdiven Tabloları ───────────────────────────────────────────────────────
//
// Oyuncu sayısından bağımsız genelleştirilmiş LP tabloları.
// Kazananlar (üst yarı): en iyi → daha düşük sıralıya.
// Kaybedenler (alt yarı): eşiğe en yakın → en alta.
// 6 kişilik maçta birebir eski _kBaseLP / _kFixedLP değerlerini verir.

const List<int> _kBasePos  = [12, 6, 4];  // kazananlar taban LP (atMax)
const List<int> _kFixedPos = [2, 1, 1];   // kazananlar sabit LP (2+ alt seviye)
const List<int> _kNeg      = [-2, -3, -6]; // kaybedenler (her seviyede aynı)

// ─── Oda Seviyesi Farkı ───────────────────────────────────────────────────────

enum _LevelDiff {
  /// Oyuncunun max açabildiği odanın üzerinde (Risk/Ödül: +x1.5)
  aboveMax,

  /// Tam max açılabilir odada (taban puan)
  atMax,

  /// Tam 1 kademe aşağıda (+x0.5)
  oneLevelBelow,

  /// 2+ kademe aşağıda (sabit puan tablosu)
  twoOrMoreBelow,
}

// ─── Puanlama Motoru ──────────────────────────────────────────────────────────

class MatchScoring {
  MatchScoring._();

  /// Galibiyet eşiği: üst yarı (yukarı yuvarlama) kazanır.
  /// 2k→1, 3k→2, 4k→2, 5k→3, 6k→3.
  static bool isWin(int position, int playerCount) =>
      position <= (playerCount + 1) ~/ 2;

  /// Oyuncu sayısına duyarlı LP merdiveni.
  /// Kazananlar (pozisyon ≤ winnerCount): pos listesinden alır.
  /// Kaybedenler: neg listesinden alır (en iyi kaybeden en düşük ceza).
  static int _ladder(
    int position,
    int playerCount,
    List<int> pos,
    List<int> neg,
  ) {
    final w = (playerCount + 1) ~/ 2; // kazanan sayısı
    if (position <= w) {
      return pos[(position - 1).clamp(0, pos.length - 1)];
    }
    final loserRank = position - w; // 1 = eşiğe en yakın kaybeden
    return neg[(loserRank - 1).clamp(0, neg.length - 1)];
  }

  /// Tek bir oyuncunun maç sonu LP değişimini hesaplar.
  ///
  /// [position]    : Maçtaki sıralama (1 tabanlı)
  /// [playerLp]    : Maç ÖNCESI LP
  /// [room]        : Oynanan oda
  /// [playerCount] : Odadaki toplam oyuncu sayısı (varsayılan 6)
  ///
  /// Dönen değer doğrudan `playerLp` üzerine eklenir; lpAfter = playerLp + sonuç.
  static int calculateLPChange({
    required int position,
    required int playerLp,
    required RoomDefinition room,
    bool softStartCompleted = false,
    int playerCount = 6,
  }) {
    assert(position >= 1 && position <= playerCount,
        'Sıralama 1-$playerCount arasında olmalı');

    final diff      = _levelDiff(playerLp, room);
    final isGain    = isWin(position, playerCount);
    final softStart = LeagueRules.isSoftStart(
      playerLp, softStartCompleted: softStartCompleted,
    );

    switch (diff) {
      // ── 2+ kademe aşağı: sabit tablo ──────────────────────────────────
      case _LevelDiff.twoOrMoreBelow:
        final pts = _ladder(position, playerCount, _kFixedPos, _kNeg);
        if (!isGain && softStart) return 0;
        return pts;

      // ── Max odanın üstü: pozitif x1.5, negatif değişmez ──────────────
      case _LevelDiff.aboveMax:
        final base = _ladder(position, playerCount, _kBasePos, _kNeg);
        if (!isGain) return softStart ? 0 : base;
        return (base * 1.5).round();

      // ── Tam max odada: taban puan ──────────────────────────────────────
      case _LevelDiff.atMax:
        final base = _ladder(position, playerCount, _kBasePos, _kNeg);
        if (!isGain && softStart) return 0;
        return base;

      // ── 1 kademe aşağı: pozitif x0.5, negatif değişmez ───────────────
      case _LevelDiff.oneLevelBelow:
        final base = _ladder(position, playerCount, _kBasePos, _kNeg);
        if (!isGain) return softStart ? 0 : base;
        return (base * 0.5).round();
    }
  }

  /// Tam bir maçın (6 oyuncu) sonuçlarını hesaplar ve [MatchOutcome] döner.
  ///
  /// [playerEntries] record listesi: her kayıtta `playerId`, `lpBefore`, `position`.
  static MatchOutcome calculateMatchOutcome({
    required RoomDefinition room,
    required List<({String playerId, int lpBefore, int position})> playerEntries,
  }) {
    assert(playerEntries.length == 6, 'Bir maçta tam 6 oyuncu olmalı');

    final results = playerEntries.map((e) {
      final change = calculateLPChange(
        position: e.position,
        playerLp: e.lpBefore,
        room: room,
      );
      return PlayerMatchResult(
        playerId:  e.playerId,
        position:  e.position,
        lpBefore:  e.lpBefore,
        lpChange:  change,
        lpAfter:   max(0, e.lpBefore + change), // LP 0'ın altına düşmez
        room:      room,
      );
    }).toList();

    return MatchOutcome(room: room, results: results);
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  static _LevelDiff _levelDiff(int playerLp, RoomDefinition room) {
    final maxRoom = LeagueRules.maxCreatableRoom(playerLp);
    final diff    = maxRoom.levelIndex - room.levelIndex;

    if (diff <  0) return _LevelDiff.aboveMax;
    if (diff == 0) return _LevelDiff.atMax;
    if (diff == 1) return _LevelDiff.oneLevelBelow;
    return _LevelDiff.twoOrMoreBelow;
  }
}
