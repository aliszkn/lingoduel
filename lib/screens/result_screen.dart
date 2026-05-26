import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../game/league_models.dart';
import '../game/league_rules.dart';
import '../game/match_scoring.dart';
import '../services/app_settings.dart';

class ResultScreen extends StatefulWidget {
  final List<Map<String, dynamic>> players;
  final String odaLig;

  const ResultScreen({
    super.key,
    required this.players,
    required this.odaLig,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final int _lpChange;
  late final int _lpBefore;
  late final int _lpAfter;

  @override
  void initState() {
    super.initState();
    _lpBefore = AppSettings.playerLP;

    final int senIndex = widget.players.indexWhere((p) => p['isim'] == 'Sen');
    final RoomDefinition? room = roomById(widget.odaLig);

    if (senIndex >= 0 && room != null) {
      _lpChange = MatchScoring.calculateLPChange(
        position: senIndex + 1, // players sıralamaya göre gelir (0 = 1.)
        playerLp: _lpBefore,
        room: room,
        softStartCompleted: AppSettings.softStartCompleted,
      );
    } else {
      _lpChange = 0;
    }

    _lpAfter = (_lpBefore + _lpChange).clamp(0, 99999);
    AppSettings.setPlayerLP(_lpAfter); // kalıcı yaz (async, UI etkilemez)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaPlan,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "MAÇ BİTTİ!",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.sari,
                ),
              ),
              const SizedBox(height: 30),
              for (int i = 0; i < widget.players.length; i++)
                _oyuncuSatiri(i, widget.players[i]['isim'] == 'Sen'),
              const SizedBox(height: 30),
              _lpDegisimKarti(),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: GestureDetector(
                  onTap: () {
                    AppSettings.mediumImpact();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: AppColors.cyan,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Center(
                      child: Text(
                        "LOBİYE DÖN",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _oyuncuSatiri(int i, bool benMiyim) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: benMiyim
            ? AppColors.sari.withValues(alpha: 0.1)
            : AppColors.yuzey,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: benMiyim ? AppColors.sari : Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                "#${i + 1}",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: benMiyim ? AppColors.sari : Colors.white38,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                widget.players[i]['isim'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: benMiyim ? AppColors.sari : Colors.white,
                ),
              ),
            ],
          ),
          Text(
            "${widget.players[i]['puan']} Puan",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: benMiyim ? AppColors.sari : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lpDegisimKarti() {
    final bool kazan = _lpChange > 0;
    final bool hic = _lpChange == 0;
    final Color renk = hic
        ? Colors.white38
        : kazan
            ? Colors.greenAccent
            : AppColors.kirmizi;

    final bool softStart = LeagueRules.isSoftStart(
      _lpBefore, softStartCompleted: AppSettings.softStartCompleted,
    );
    final bool newGroup =
        LeagueRules.groupOf(_lpBefore) != LeagueRules.groupOf(_lpAfter);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: renk.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  hic
                      ? Icons.shield_outlined
                      : kazan
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                  color: renk,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  hic
                      ? '0 LP'
                      : '${kazan ? '+' : ''}$_lpChange LP',
                  style: TextStyle(
                    color: renk,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$odaLigStr  •  $_lpBefore → $_lpAfter LP',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            if (softStart && hic) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Soft Start: kaybetme koruması aktifti',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (newGroup) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Yeni lig grubu: ${LeagueRules.groupOf(_lpAfter).name}!',
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get odaLigStr => widget.odaLig;
}
