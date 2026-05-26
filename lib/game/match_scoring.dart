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

// ─── Sabit Tablo: Taban LP ────────────────────────────────────────────────────
//
// Oyuncunun açabildiği en yüksek odada (atMax) oynadığında geçerli taban değer.

const Map<int, int> _kBaseLP = {
  1: 12,
  2:  6,
  3:  4,
  4: -2,
  5: -3,
  6: -6,
};

// ─── Sabit Tablo: 2+ Alt Seviye (Kolay Puan Filtresi) ────────────────────────

const Map<int, int> _kFixedLP = {
  1:  2,
  2:  1,
  3:  1,
  4: -2,
  5: -3,
  6: -6,
};

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

  /// Tek bir oyuncunun maç sonu LP değişimini hesaplar.
  ///
  /// [position]  : Maçtaki sıralama (1–6)
  /// [playerLp]  : Maç ÖNCESI LP
  /// [room]      : Oynanan oda
  ///
  /// Dönen değer doğrudan `playerLp` üzerine eklenir; lpAfter = playerLp + sonuç.
  static int calculateLPChange({
    required int position,
    required int playerLp,
    required RoomDefinition room,
    bool softStartCompleted = false,
  }) {
    assert(position >= 1 && position <= 6, 'Sıralama 1-6 arasında olmalı');

    final diff       = _levelDiff(playerLp, room);
    final isGain     = position <= 3;
    final softStart  = LeagueRules.isSoftStart(
      playerLp, softStartCompleted: softStartCompleted,
    );

    switch (diff) {
      // ── 2+ kademe aşağı: sabit tablo ──────────────────────────────────
      case _LevelDiff.twoOrMoreBelow:
        final pts = _kFixedLP[position]!;
        if (!isGain && softStart) return 0;
        return pts;

      // ── Max odanın üstü: pozitif x1.5, negatif değişmez ──────────────
      case _LevelDiff.aboveMax:
        final base = _kBaseLP[position]!;
        if (!isGain) return softStart ? 0 : base;
        return (base * 1.5).round();

      // ── Tam max odada: taban puan ──────────────────────────────────────
      case _LevelDiff.atMax:
        final base = _kBaseLP[position]!;
        if (!isGain && softStart) return 0;
        return base;

      // ── 1 kademe aşağı: pozitif x0.5, negatif değişmez ───────────────
      case _LevelDiff.oneLevelBelow:
        final base = _kBaseLP[position]!;
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
