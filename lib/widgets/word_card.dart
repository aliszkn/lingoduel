import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../game/word_rarity.dart';
import '../services/app_settings.dart';

/// Öğrenme kartı — ön yüz İngilizce kelime, uzun basınca Türkçe anlam.
/// Tıklanınca [onNewWord] tetiklenir (yeni kelime / kapat).
class KelimeKarti extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onNewWord;
  final Color temaRengi;
  final Color golgeRengi;
  final String setId; // 'A' | 'BI' | 'BII' | 'BIII' | 'CI' | 'CII' | 'CIII'

  const KelimeKarti({
    super.key,
    required this.data,
    required this.onNewWord,
    required this.temaRengi,
    required this.golgeRengi,
    required this.setId,
  });

  @override
  State<KelimeKarti> createState() => _KelimeKartiState();
}

class _KelimeKartiState extends State<KelimeKarti> {
  bool isFlipped  = false;
  bool isPressed  = false;

  @override
  Widget build(BuildContext context) {
    final rank   = widget.data['rank'] as int;
    final rarity = WordRarityMath.rarityForIndex(setId: widget.setId, index: rank);

    return GestureDetector(
      onTapDown:    (_) => setState(() => isPressed = true),
      onTapUp:      (_) => setState(() => isPressed = false),
      onTapCancel:  ()  => setState(() => isPressed = false),
      onTap: () {
        widget.onNewWord();
        setState(() => isFlipped = false);
      },
      onLongPress: () {
        AppSettings.heavyImpact();
        setState(() => isFlipped = !isFlipped);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(bottom: 16, top: isPressed ? 6 : 0),
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(minHeight: isFlipped ? 160.0 : 90.0),
        decoration: BoxDecoration(
          color: isFlipped ? widget.temaRengi : AppColors.yuzey,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isPressed
              ? []
              : [
                  BoxShadow(
                    color: isFlipped
                        ? widget.golgeRengi
                        : AppColors.kartGolge,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: isFlipped ? _buildBack(rarity) : _buildFront(rarity),
      ),
    );
  }

  Widget _rarityChip(WordRarity rarity, {bool dark = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: rarity.color.withValues(alpha: dark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: rarity.color.withValues(alpha: dark ? 0.5 : 0.35),
            width: 0.8,
          ),
        ),
        child: Text(
          rarity.label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: dark ? Colors.black87 : rarity.color,
            letterSpacing: 0.5,
          ),
        ),
      );

  Widget _buildFront(WordRarity rarity) => Stack(
        children: [
          Center(
            child: Text(
              widget.data['en'],
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(top: 0, right: 0, child: _rarityChip(rarity)),
        ],
      );

  Widget _buildBack(WordRarity rarity) => Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.data['tr'].toUpperCase(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Anlamlar: ${widget.data['others']}",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withValues(alpha: 0.6),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(color: Colors.black12, height: 20),
              Text(
                widget.data['ex'],
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Positioned(
              top: 0, right: 0, child: _rarityChip(rarity, dark: true)),
        ],
      );
}
