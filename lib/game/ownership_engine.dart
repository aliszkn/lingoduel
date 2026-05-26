import 'dart:math';
import 'word_rarity.dart';
import '../services/ownership_db.dart';

// ─── Sonuç modeli ─────────────────────────────────────────────────────────────

class ClaimResult {
  /// Sahiplenme gerçekleştiyse true (zar tutmadıysa false).
  final bool claimed;
  final RarityLevel rarity;

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

  static ClaimResult miss(RarityLevel rarity) =>
      ClaimResult(claimed: false, rarity: rarity);
}

// ─── Engine ───────────────────────────────────────────────────────────────────

/// Tetikleme algoritması.
///
/// Kullanım örnekleri:
///
///   // Flash kart: kart açıldığında çağrılır
///   final result = await OwnershipEngine.tryClaimFlashcard(
///     level: 'A', rank: 5,
///   );
///   if (result.claimed) showClaimBanner(result);
///
///   // Düello: ilk doğru cevap veren oyuncuyu geçer
///   await OwnershipEngine.claimDuelWord(
///     level: 'B', rank: 30, playerId: 'Sen',
///   );
class OwnershipEngine {
  OwnershipEngine._();

  static final _rng = Random();

  // WordEntry.level + WordEntry.rank → stabil kelime ID'si ("A01" … "C80")
  static String wordIdOf(String level, int rank) =>
      '$level${rank.toString().padLeft(2, '0')}';

  // ── Flash kart ──────────────────────────────────────────────────────────────

  /// Flash kart her çevrildiğinde (ön → arka) çağrılır.
  ///
  /// Zar atılır; olasılık tutarsa kelime sahiplenilir.
  /// Önceki sahibi varsa ve farklı bir oyuncuysa [ClaimResult.isSteal] = true.
  static Future<ClaimResult> tryClaimFlashcard({
    required String level,
    required int rank,
    String playerId = 'Sen',
  }) async {
    final rarity = WordRarity.fromRank(rank);
    if (_rng.nextDouble() >= rarity.flashcardClaimChance) {
      return ClaimResult.miss(rarity);
    }
    return _doClaim(
      wordId: wordIdOf(level, rank),
      rarity: rarity,
      playerId: playerId,
      source: 'flashcard',
    );
  }

  // ── Düello ──────────────────────────────────────────────────────────────────

  /// Düelloda soruya ilk doğru cevap veren oyuncu çağrılır.
  ///
  /// Olasılık yoktur — doğru cevap her zaman sahiplenmeyi tetikler.
  static Future<ClaimResult> claimDuelWord({
    required String level,
    required int rank,
    required String playerId,
  }) async {
    final rarity = WordRarity.fromRank(rank);
    return _doClaim(
      wordId: wordIdOf(level, rank),
      rarity: rarity,
      playerId: playerId,
      source: 'duel',
    );
  }

  // ── Sorgular ────────────────────────────────────────────────────────────────

  static Future<String?> getOwner(String level, int rank) =>
      OwnershipDb.getOwner(wordIdOf(level, rank));

  static Future<bool> isOwnedBy(String level, int rank, String playerId) async {
    final owner = await OwnershipDb.getOwner(wordIdOf(level, rank));
    return owner == playerId;
  }

  static Future<FameStats> getFameStats([String playerId = 'Sen']) =>
      OwnershipDb.getFameStats(playerId);

  // ── İç yardımcı ─────────────────────────────────────────────────────────────

  static Future<ClaimResult> _doClaim({
    required String wordId,
    required RarityLevel rarity,
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
