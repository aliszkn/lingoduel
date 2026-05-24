import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../services/app_settings.dart';
import '../models/question_model.dart';
import '../data/word_pool.dart';
import 'result_screen.dart';

class OyunOdasiEkrani extends StatefulWidget {
  final Map<String, dynamic> odaBilgisi;
  const OyunOdasiEkrani({super.key, required this.odaBilgisi});

  @override
  State<OyunOdasiEkrani> createState() => _OyunOdasiEkraniState();
}

class _OyunOdasiEkraniState extends State<OyunOdasiEkrani> {
  static const int _soruSuresi = 10; // her sorunun süresi (saniye)
  static const int _soruSayisi =
      20; // maç başına sabit soru sayısı (en küçük lig havuzuna eşit, tekrar olmaz)

  bool isOdaSahibi = true;
  bool isOyunBasladi = false;
  bool isBenHazirim = false;
  List<Map<String, dynamic>> oyuncular = [];
  // Banlanan oyuncu isimleri — yeni bot eklerken bu isim kullanılmaz
  final Set<String> _banliIsimler = {};

  Timer? _zamanlayici;
  int kalanSure = _soruSuresi;
  QuestionModel? aktifSoru;
  List<String> mevcutSiklar = [];

  // Liga göre filtrelenmiş kelime havuzu (initState'te doldurulur).
  late final List<WordEntry> _havuz;

  // Soru sırası: havuz karıştırılıp ilk _soruSayisi kadarı kullanılır — tekrar yok
  late List<int> _soruSirasi;
  int kacinciSoru = 0;
  int get toplamSoru =>
      _havuz.length < _soruSayisi ? _havuz.length : _soruSayisi;

  final _random = Random();

  @override
  void initState() {
    super.initState();
    final int kapasite = widget.odaBilgisi['kapasite'];
    oyuncular.add({'isim': 'Sen', 'puan': 0, 'hazir': true, 'sahip': true});
    for (int i = 1; i < kapasite; i++) {
      oyuncular.add({
        'isim': 'Bot $i',
        'puan': 0,
        'hazir': true,
        'sahip': false,
      });
    }

    // Odanın liginden kelime havuzunu çek ve karıştır — tekrar yok
    final String lig = (widget.odaBilgisi['lig'] as String?) ?? '';
    _havuz = WordPool.forLeague(lig);
    _soruSirasi = List.generate(_havuz.length, (i) => i)..shuffle(_random);
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  // Bot AI: her soru geçişinde botlar için rastgele puan hesapla
  void _botlariSimulaEt() {
    for (final oyuncu in oyuncular) {
      if (oyuncu['isim'] == 'Sen') continue;
      // %60 ihtimalle doğru cevap, puan = 1-10 arası rastgele
      if (_random.nextDouble() < 0.60) {
        oyuncu['puan'] = (oyuncu['puan'] as int) + _random.nextInt(10) + 1;
      }
    }
  }

  Widget _oyuncuSeridi(int kapasite) {
    final List<Map<String, dynamic>> liste = isOyunBasladi
        ? (List<Map<String, dynamic>>.from(oyuncular)
            ..sort((a, b) => (b['puan'] as int).compareTo(a['puan'] as int)))
        : oyuncular;

    return Container(
      height: 110,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.yuzey,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: kapasite,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (_, i) =>
            i < liste.length ? _oyuncuKarti(liste[i]) : _bosKart(),
      ),
    );
  }

  Widget _oyuncuKarti(Map<String, dynamic> oyuncu) {
    final bool benMiyim = oyuncu['isim'] == 'Sen';
    final bool hazir = oyuncu['hazir'] == true;
    final bool sahip = oyuncu['sahip'] == true;

    return GestureDetector(
      onTap: () => _oyuncuAtSorgusu(oyuncu['isim']),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: benMiyim ? AppColors.sari : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.arkaPlan,
                    child: Icon(
                      Icons.person,
                      size: 26,
                      color: hazir ? AppColors.sari : Colors.white24,
                    ),
                  ),
                ),
                if (sahip)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.kirmizi,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.yuzey, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
                if (!hazir && !sahip && !isOyunBasladi)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.yuzey, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.hourglass_empty_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              oyuncu['isim'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: benMiyim ? AppColors.sari : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
            Text(
              '${oyuncu['puan']}p',
              style: TextStyle(
                color: benMiyim ? AppColors.sari : Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bosKart() {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white10,
            child: Icon(
              Icons.person_outline_rounded,
              size: 24,
              color: Colors.white24,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Boş',
            style: TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          SizedBox(height: 13),
        ],
      ),
    );
  }

  void _oyuncuAtSorgusu(String isim) {
    if (isOyunBasladi || !isOdaSahibi || isim == 'Sen') return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.yuzey,
        title: Text(
          "$isim adlı oyuncuyu ne yapmak istersin?",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              _oyuncuyuKaldir(isim);
              messenger.showSnackBar(
                SnackBar(
                  content: Text("$isim odadan atıldı."),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: const Text("At", style: TextStyle(color: AppColors.sari)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _banlaOnay(isim);
            },
            child: const Text(
              "Banla",
              style: TextStyle(
                color: AppColors.kirmizi,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _oyuncuyuKaldir(String isim) {
    AppSettings.mediumImpact();
    setState(() {
      oyuncular.removeWhere((o) => o['isim'] == isim);
      // Boş yere yeni bir bot ekle ki oyun başlatma kontrolü tıkanmasın.
      // Banlı isimler atlanır.
      final mevcutBotNumaralari = oyuncular
          .where((o) => (o['isim'] as String).startsWith('Bot '))
          .map((o) => int.tryParse((o['isim'] as String).substring(4)) ?? 0)
          .toSet();
      int botNo = 1;
      while (mevcutBotNumaralari.contains(botNo) ||
          _banliIsimler.contains('Bot $botNo')) {
        botNo++;
      }
      oyuncular.add({
        'isim': 'Bot $botNo',
        'puan': 0,
        'hazir': true,
        'sahip': false,
      });
    });
  }

  void _banlaOnay(String isim) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.yuzey,
        title: Text(
          "$isim kalıcı olarak banlansın mı?",
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          "Banlı oyuncu bu oturum boyunca tekrar odaya alınmaz.",
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("İptal", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              setState(() => _banliIsimler.add(isim));
              _oyuncuyuKaldir(isim);
              messenger.showSnackBar(
                SnackBar(
                  content: Text("$isim banlandı."),
                  backgroundColor: AppColors.kirmizi,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              "BANLA",
              style: TextStyle(
                color: AppColors.kirmizi,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _oyunuBaslat() {
    final int kapasite = widget.odaBilgisi['kapasite'];
    if (oyuncular.length < kapasite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Oda tam dolmadan oyun başlatılamaz!")),
      );
      return;
    }
    if (!oyuncular.every((o) => o['hazir'] == true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Herkes hazır olmadan oyun başlatılamaz!"),
        ),
      );
      return;
    }
    AppSettings.heavyImpact();
    setState(() {
      isOyunBasladi = true;
    });
    _yeniSoruHazirla();
  }

  void _yeniSoruHazirla() {
    if (kacinciSoru >= toplamSoru) {
      _zamanlayici?.cancel();
      oyuncular.sort((a, b) => (b['puan'] as int).compareTo(a['puan'] as int));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ResultScreen(players: List<Map<String, dynamic>>.from(oyuncular)),
        ),
      );
      return;
    }

    // Sıradaki kelimeyi al — tekrar yok
    final WordEntry word = _havuz[_soruSirasi[kacinciSoru]];
    kacinciSoru++;

    // 4 yanlış şıkkı aynı lig havuzundan rastgele seç (zorluk seviyesi eşleşsin)
    final yanlislar =
        (_havuz.where((w) => w.en != word.en).toList()..shuffle(_random))
            .take(4)
            .map((w) => w.en)
            .toList();

    final soru = QuestionModel(
      desc: word.desc,
      descTr: word.descTr,
      answer: word.en,
      wrong1: yanlislar[0],
      wrong2: yanlislar[1],
      wrong3: yanlislar[2],
      wrong4: yanlislar[3],
    );
    final siklar = List<String>.from(soru.allOptions)..shuffle(_random);

    setState(() {
      aktifSoru = soru;
      mevcutSiklar = siklar;
      kalanSure = _soruSuresi;
    });

    _zamanlayici?.cancel();
    _zamanlayici = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (kalanSure > 0) {
        setState(() => kalanSure--);
      } else {
        AppSettings.heavyImpact();
        _botlariSimulaEt(); // süre dolunca botlar da cevap verir
        _yeniSoruHazirla();
      }
    });
  }

  void _cevapKontrol(String secilenCevap) {
    if (!isOyunBasladi || kalanSure == 0 || aktifSoru == null) return;

    if (secilenCevap == aktifSoru!.answer) {
      AppSettings.mediumImpact();
      final int kazanilanPuan = kalanSure;
      setState(() {
        final benimOyuncu = oyuncular.firstWhere((o) => o['isim'] == 'Sen');
        benimOyuncu['puan'] = (benimOyuncu['puan'] as int) + kazanilanPuan;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "DOĞRU! +$kazanilanPuan Puan",
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.greenAccent,
          duration: const Duration(milliseconds: 500),
        ),
      );
    } else {
      AppSettings.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "YANLIŞ!",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.redAccent,
          duration: Duration(milliseconds: 500),
        ),
      );
    }

    _botlariSimulaEt(); // kullanıcı cevap verince botlar da cevap verir
    _yeniSoruHazirla();
  }

  @override
  Widget build(BuildContext context) {
    final int kapasite = widget.odaBilgisi['kapasite'];

    return Scaffold(
      backgroundColor: AppColors.arkaPlan,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Column(
                    children: [
                      Text(
                        widget.odaBilgisi['isim'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "${widget.odaBilgisi['lig']} LİGİ",
                        style: const TextStyle(
                          color: AppColors.kirmizi,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.yuzey,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      isOyunBasladi
                          ? "$kacinciSoru / $toplamSoru"
                          : "${oyuncular.length}/$kapasite",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _oyuncuSeridi(kapasite),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isOyunBasladi ? AppColors.cyan : AppColors.yuzey,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOyunBasladi
                            ? AppColors.cyanKoyu
                            : Colors.white12,
                        width: 2,
                      ),
                      boxShadow: isOyunBasladi
                          ? [
                              const BoxShadow(
                                color: AppColors.cyan,
                                blurRadius: 20,
                              ),
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isOyunBasladi) ...[
                          const Icon(
                            Icons.access_time_rounded,
                            color: Colors.white38,
                            size: 36,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Oyuncular\nBekleniyor",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ] else if (aktifSoru != null) ...[
                          Text(
                            aktifSoru!.desc,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                          if (kalanSure <= 5) ...[
                            const SizedBox(height: 14),
                            const Divider(color: Colors.black26, height: 1),
                            const SizedBox(height: 10),
                            Text(
                              aktifSoru!.descTr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.65),
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "$kalanSure sn",
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
              decoration: const BoxDecoration(
                color: AppColors.koyuYuzey,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: !isOyunBasladi
                  ? (isOdaSahibi
                        ? GestureDetector(
                            onTap: _oyunuBaslat,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: AppColors.kirmizi,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Center(
                                child: Text(
                                  "OYUNU BAŞLAT",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : GestureDetector(
                            onTap: () {
                              AppSettings.selectionClick();
                              setState(() {
                                isBenHazirim = !isBenHazirim;
                                oyuncular.firstWhere(
                                  (o) => o['isim'] == 'Sen',
                                )['hazir'] = isBenHazirim;
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: isBenHazirim
                                    ? AppColors.sari
                                    : AppColors.yuzey,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: isBenHazirim
                                      ? Colors.transparent
                                      : Colors.white24,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  isBenHazirim ? "HAZIRIM!" : "HAZIR OL",
                                  style: TextStyle(
                                    color: isBenHazirim
                                        ? Colors.black
                                        : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ))
                  : (mevcutSiklar.length == 5
                        ? Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _cevapSikki(mevcutSiklar[0])),
                                  const SizedBox(width: 12),
                                  Expanded(child: _cevapSikki(mevcutSiklar[1])),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _cevapSikki(mevcutSiklar[2])),
                                  const SizedBox(width: 12),
                                  Expanded(child: _cevapSikki(mevcutSiklar[3])),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _cevapSikki(mevcutSiklar[4]),
                            ],
                          )
                        : const SizedBox()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cevapSikki(String metin) {
    return GestureDetector(
      onTap: () => _cevapKontrol(metin),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.yuzey,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Text(
            metin,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
