import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../game/word_rarity.dart';
import '../models/word_entry.dart';
import '../services/app_settings.dart';
import '../services/database_helper.dart';
import '../widgets/word_card.dart';

/// Tüm kelime setlerinde İngilizce/Türkçe arama yapan tam ekran.
/// CardsPanel sağ üst 🔍 ikonundan Navigator.push ile açılır.
class KelimeAramaEkrani extends StatefulWidget {
  const KelimeAramaEkrani({super.key});

  @override
  State<KelimeAramaEkrani> createState() => _KelimeAramaEkraniState();
}

class _KelimeAramaEkraniState extends State<KelimeAramaEkrani> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<WordEntry> _sonuclar  = const [];
  bool _araniyor             = false;
  bool _aramayapildi         = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextDegisti(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _sonuclar     = const [];
        _aramayapildi = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _araniyor = true);
      final result = await DatabaseHelper.searchWords(q);
      if (!mounted) return;
      setState(() {
        _sonuclar     = result;
        _araniyor     = false;
        _aramayapildi = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaPlan,
      appBar: AppBar(
        backgroundColor: AppColors.arkaPlan,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          autofocus: true,
          onChanged: _onTextDegisti,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Kelime ara… (en / tr)',
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear,
                        color: Colors.white38, size: 18),
                    onPressed: () {
                      _ctrl.clear();
                      _onTextDegisti('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_araniyor) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.cyan));
    }
    if (!_aramayapildi) {
      return const Center(
        child: Text('Öğrenmek istediğin kelimeyi yaz.',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
      );
    }
    if (_sonuclar.isEmpty) {
      return const Center(
        child: Text('Sonuç bulunamadı.',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _sonuclar.length,
      separatorBuilder: (_, _) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (_, i) => _sonucSatiri(_sonuclar[i]),
    );
  }

  Widget _sonucSatiri(WordEntry w) {
    return ListTile(
      onTap: () => _kelimeDetayGoster(w),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: RarityIcon(w.rarity, size: 26),
      title: Text(
        w.en,
        style: const TextStyle(
            color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        w.tr,
        style: TextStyle(
            color: w.rarity.color.withValues(alpha: 0.8), fontSize: 13),
      ),
      trailing: Text(
        w.setId,
        style: const TextStyle(color: Colors.white24, fontSize: 11),
      ),
    );
  }

  void _kelimeDetayGoster(WordEntry w) {
    AppSettings.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        height: MediaQuery.of(context).size.height * 0.55,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.koyuYuzey,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              '${w.setId} Seti  •  ${w.rarity.labelTr}',
              style: TextStyle(
                color: w.rarity.color.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: KelimeKarti(
                data: w.toMap(),
                onNewWord: () => Navigator.pop(sheetCtx),
                temaRengi: w.rarity.color,
                golgeRengi: w.rarity.color.withValues(alpha: 0.4),
                setId: w.setId,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Kartı çevirmek için uzun bas',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
