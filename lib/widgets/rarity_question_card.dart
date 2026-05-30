import 'package:flutter/material.dart';

import '../game/word_rarity.dart';

/// HTML "Dinamik Soru Kartları" tasarımının Flutter karşılığı.
///
/// Tek bir enderlik (rarity) seviyesine ait soru kartını çizer:
///  - enderliğe göre köşegen gradient arka plan + ince kenarlık,
///  - nabız gibi atan dış ışıltı (CSS `@keyframes pulse-*` karşılığı),
///  - sağ üst köşede yarı saydam SVG mücevher ([RarityIcon] / `assets/enderlik/`),
///  - enderlik etiketi + soru metni + süre rozeti.
///
/// Kullanım:
/// ```dart
/// RarityQuestionCard(
///   rarity: WordRarity.rare,
///   questionText: 'Belonging to or associated with the speaker.',
///   timerSeconds: 8,
/// )
/// ```
class RarityQuestionCard extends StatelessWidget {
  const RarityQuestionCard({
    super.key,
    required this.rarity,
    required this.questionText,
    this.timerSeconds = 8,
    this.hintText,
    this.onTap,
  });

  final WordRarity rarity;
  final String questionText;
  final int timerSeconds;

  /// Opsiyonel ikincil metin (Türkçe ipucu vb.). Verilirse soru altında
  /// ince bir ayraçla italik olarak gösterilir.
  final String? hintText;
  final VoidCallback? onTap;

  /// HTML'deki `--*-dark` / `--*-darker` gradient durakları.
  /// (Enum'daki `color` tek tonluk olduğu için gradient burada tutulur.)
  static const Map<WordRarity, List<Color>> _gradient = {
    WordRarity.common:    [Color(0xFF374151), Color(0xFF111827)],
    WordRarity.uncommon:  [Color(0xFF064E3B), Color(0xFF022C22)],
    WordRarity.rare:      [Color(0xFF1E3A8A), Color(0xFF172554)],
    WordRarity.epic:      [Color(0xFF581C87), Color(0xFF3B0764)],
    WordRarity.legendary: [Color(0xFF78350F), Color(0xFF451A03)],
    WordRarity.mythic:    [Color(0xFF7F1D1D), Color(0xFF450A0A)],
  };

  @override
  Widget build(BuildContext context) {
    final accent = rarity.color; // kenarlık + etiket + rozet vurgusu
    final gradient = RarityQuestionCard._gradient[rarity]!;
    const radius = BorderRadius.all(Radius.circular(24));

    // Statik glow: animasyon yok → RepaintBoundary içeriği değişmez,
    // soru geçişinde (AnimatedSwitcher fade) cache'lenmiş layer ucuza
    // kompozit edilir. Eskiden sonsuz blur pulse her karede yeniden
    // çiziliyordu (kasmanın ana kaynağı).
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 14,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.hardEdge, // mücevheri kırpar; hardEdge antialias'tan ucuz
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft, // 135deg
                end: Alignment.bottomRight,
                colors: gradient,
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Sağ üst köşedeki yarı saydam mücevher (160x160, top/right: -20).
                Positioned(
                  top: -20,
                  right: -20,
                  child: Opacity(
                    opacity: 0.20,
                    child: RarityIcon(rarity, size: 160),
                  ),
                ),
                // İçerik: sığıyorsa ortalanır, sığmıyorsa scroll edilir.
                // Sarı/siyah "bottom overflowed" çizgileri böylece görünmez,
                // ve kısa metinler de kartın tam boyunu kullanır.
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      vertical: 40,
                      horizontal: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 80, // 2× vertical padding
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                      Text(
                        rarity.labelTr.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4, // ~0.1em
                          shadows: const [
                            Shadow(
                              color: Color(0x80000000),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        questionText,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          shadows: [
                            Shadow(
                              color: Color(0xCC000000),
                              offset: Offset(0, 2),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      if (hintText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          hintText!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            shadows: const [
                              Shadow(
                                color: Color(0x99000000),
                                offset: Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _TimerBadge(accent: accent, seconds: timerSeconds),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// "8 sn" hap (pill) rozeti — CSS `.timer-badge`.
class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.accent, required this.seconds});

  final Color accent;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        boxShadow: [
          // inset gölge → BoxShadow ile birebir karşılığı yok; içe doğru
          // koyu bir ton yakın bir his verir.
          BoxShadow(
            color: const Color(0x66000000),
            blurRadius: 10,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Text(
        '$seconds sn',
        style: TextStyle(
          color: accent,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
