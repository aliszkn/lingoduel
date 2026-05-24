import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/app_settings.dart';

class ResultScreen extends StatelessWidget {
  final List<Map<String, dynamic>> players;

  const ResultScreen({super.key, required this.players});

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
                players[i]['isim'],
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: benMiyim ? AppColors.sari : Colors.white,
                ),
              ),
            ],
          ),
          Text(
            "${players[i]['puan']} Puan",
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
              for (int i = 0; i < players.length; i++)
                _oyuncuSatiri(i, players[i]['isim'] == 'Sen'),
              const SizedBox(height: 40),
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
}
