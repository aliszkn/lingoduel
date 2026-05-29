import 'package:flutter/material.dart';

import '../game/word_rarity.dart';
import '../widgets/rarity_question_card.dart';

/// HTML "Dinamik Soru Kartları" sayfasının Flutter karşılığı:
/// 6 enderlik seviyesini responsive bir grid'de gösterir
/// (dar ekran 1 sütun, ≥768 px 2 sütun, ≥1024 px 3 sütun).
class RarityCardsDemoScreen extends StatelessWidget {
  const RarityCardsDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // CSS --app-bg
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 1024
                ? 3
                : width >= 768
                    ? 2
                    : 1;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 48,
                    mainAxisSpacing: 48,
                    childAspectRatio: 0.85,
                    children: [
                      for (final rarity in WordRarity.values)
                        RarityQuestionCard(
                          rarity: rarity,
                          questionText:
                              'Belonging to or associated with the speaker.',
                          timerSeconds: 8,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
