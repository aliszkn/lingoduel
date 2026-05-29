import 'dart:math';
import 'word_rarity.dart';
import '../services/ownership_db.dart';

// ─── Sonuç modeli ─────────────────────────────────────────────────────────────

class ClaimResult {
  /// Sahiplenme gerçekleştiyse true (zar tutmadıysa false).
  final bool claimed;
  final WordRarity rarity;

  /// Kelime başka birisindeyken alındıysa true ("çalındı").
  final bool isSteal;

  /// Önceki sahip (çalma durumunda dolu, aksi hâlde null).
  final String? previousOwner;

  const ClaimResult({
    required this.claimed,
    required this.rarity,
    this.isSteal = false,
    this.previousOwner,
  });

  static ClaimResult miss(WordRarity rarity) =>
      ClaimResult(claimed: false, rarity: rarity);
}

// ─── Engine ───────────────────────────────────────────────────────────────────

/// Tetikleme algoritması — yeni setId tabanlı API.
///
///   // Düello: ilk doğru cevap veren oyuncuyu geçer
///   await OwnershipEngine.claimDuelWord(
///     setId: 'CI', rank: 137, playerId: 'Sen',
///   );
class OwnershipEngine {
  OwnershipEngine._();

  static final _rng = Random();

  /// Stabil kelime ID'si — ownership tablosunda PK.
  /// Format: `setId-NNNN` (örn. "BII-0042").
  static String wordIdOf(String setId, int rank) =>
      '$setId-${rank.toString().padLeft(4, '0')}';

  // ── Düello ──────────────────────────────────────────────────────────────────

  /// Düelloda soruya doğru cevap veren oyuncu için çağrılır.
  ///
  /// `WordRarity.duelClaimChance` üzerinden bir zar atılır; tutmazsa
  /// [ClaimResult.miss] döner ve sahiplenme gerçekleşmez. Tutarsa
  /// kelime kullanıcıya yazılır (önceki sahibi varsa `isSteal=true`).
  static Future<ClaimResult> claimDuelWord({
    required String setId,
    required int rank,
    required String playerId,
  }) async {
    final rarity = WordRarityMath.rarityForIndex(setId: setId, index: rank);
    if (_rng.nextDouble() >= rarity.duelClaimChance) {
      return ClaimResult.miss(rarity);
    }
    return _doClaim(
      wordId: wordIdOf(setId, rank),
      rarity: rarity,
      playerId: playerId,
      source: 'duel',
    );
  }

  // ── Sorgular ────────────────────────────────────────────────────────────────

  static Future<String?> getOwner(String setId, int rank) =>
      OwnershipDb.getOwner(wordIdOf(setId, rank));

  static Future<bool> isOwnedBy(String setId, int rank, String playerId) async {
    final owner = await OwnershipDb.getOwner(wordIdOf(setId, rank));
    return owner == playerId;
  }

  static Future<FameStats> getFameStats([String playerId = 'Sen']) =>
      OwnershipDb.getFameStats(playerId);

  // ── İç yardımcı ─────────────────────────────────────────────────────────────

  static Future<ClaimResult> _doClaim({
    required String wordId,
    required WordRarity rarity,
    required String playerId,
    required String source,
  }) async {
    final prev = await OwnershipDb.getOwner(wordId);
    final isSteal = prev != null && prev != playerId;
    await OwnershipDb.setOwner(
      wordId: wordId,
      rarity: rarity,
      ownerId: playerId,
      claimSource: source,
    );
    return ClaimResult(
      claimed: true,
      rarity: rarity,
      isSteal: isSteal,
      previousOwner: isSteal ? prev : null,
    );
  }
}
