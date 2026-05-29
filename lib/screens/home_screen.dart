import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../game/league_models.dart';
import '../game/league_rules.dart';
import '../game/match_scoring.dart';
import '../game/word_rarity.dart';
import '../game/word_sets.dart';
import '../game/ownership_engine.dart';
import '../models/word_entry.dart';
import '../services/app_settings.dart';
import '../services/database_helper.dart';
import '../services/ownership_db.dart';
import 'game_screen.dart';

// ==========================================
// --- PANELLER ARASI GEÇİŞ (ANA YAPI) ---
// ==========================================
class AnaKontrolMerkezi extends StatefulWidget {
  const AnaKontrolMerkezi({super.key});

  @override
  State<AnaKontrolMerkezi> createState() => _AnaKontrolMerkeziState();
}

class _AnaKontrolMerkeziState extends State<AnaKontrolMerkezi> {
  int aktifPanel = 1;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: aktifPanel,
            children: [CardsPanel(), ProfilePanel(), DuelPanel()],
          ),
          Positioned(
            bottom: 30,
            left: 30,
            right: 30,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.yuzey,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _navButon(Icons.bolt_rounded, "Cards", 0, AppColors.cyan),
                  _navButon(Icons.person_rounded, "Profile", 1, AppColors.sari),
                  _navButon(Icons.bolt_rounded, "Duel", 2, AppColors.kirmizi),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButon(IconData icon, String etiket, int index, Color aktifRenk) {
    final bool seciliMi = aktifPanel == index;
    return GestureDetector(
      onTap: () {
        AppSettings.lightImpact();
        setState(() => aktifPanel = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: seciliMi
              ? aktifRenk.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: seciliMi ? aktifRenk : Colors.white24, size: 26),
            if (seciliMi) const SizedBox(width: 6),
            if (seciliMi)
              Text(
                etiket,
                style: TextStyle(
                  color: aktifRenk,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// --- PANEL 1: LINGO CARDS (ÖĞRENME) ---
// ==========================================
class CardsPanel extends StatefulWidget {
  const CardsPanel({super.key});

  @override
  State<CardsPanel> createState() => _CardsPanelState();
}

class _CardsPanelState extends State<CardsPanel> {
  static const int _kKartAdedi = 5;

  String secilenSetId = 'A';
  String secilenTier = '1K'; // varsayılan: tüm kelimeler (mevcut davranış korunur)
  WordRarity secilenRarity = WordRarity.common;

  /// Aktif set + tier'ın cap'li kelime listesi (DB'den çekilir, RAM'de cache'lenir).
  List<WordEntry> _setKelimeleri = const [];

  /// Set/tier yüklemesi devam ediyor mu (UI spinner için).
  bool _setYukleniyor = true;

  /// Ekranda gösterilen N rastgele kelime (setId/tier/enderlik değişince yenilenir).
  List<Map<String, dynamic>> ekrandakiKelimeler = [];

  @override
  void initState() {
    super.initState();
    _havuzuYukle(secilenSetId, secilenTier);
  }

  /// Verilen set + tier'a göre kelime havuzunu DB'den çeker, kart örneklerini yeniler.
  Future<void> _havuzuYukle(String setId, String tier) async {
    setState(() => _setYukleniyor = true);
    final int cap = switch (tier) {
      '100' => 100,
      '250' => 250,
      '500' => 500,
      _ => 1000, // '1K' ve bilinmeyen → setin tamamı
    };
    final words = await DatabaseHelper.getWordsBySetIdCapped(setId, cap);
    if (!mounted) return;
    setState(() {
      _setKelimeleri = words;
      _setYukleniyor = false;
    });
    kelimeleriGetir();
  }

  /// Aktif set + enderlik filtresine göre kelime havuzu (Map listesi).
  List<Map<String, dynamic>> _aktifHavuz() => _setKelimeleri
      .where((w) => w.rarity == secilenRarity)
      .map((w) => w.toMap())
      .toList()
    ..shuffle();

  void kelimeleriGetir() {
    final havuz = _aktifHavuz();
    final miktar = havuz.length < _kKartAdedi ? havuz.length : _kKartAdedi;
    setState(() {
      ekrandakiKelimeler = havuz.isEmpty ? [] : havuz.sublist(0, miktar);
    });
  }

  void tekKelimeDegistir(int index) {
    AppSettings.selectionClick();
    final havuz = _aktifHavuz();
    if (havuz.isEmpty) return;
    setState(() {
      ekrandakiKelimeler[index] = havuz.first;
    });
  }

  Widget _secimButonu(String yazi, bool seciliMi, VoidCallback tiklama) {
    return GestureDetector(
      onTap: tiklama,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: seciliMi ? AppColors.cyan : AppColors.butonArka,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: seciliMi ? AppColors.cyan : Colors.white12),
        ),
        child: Text(
          yazi,
          style: TextStyle(
            color: seciliMi ? Colors.black : Colors.white60,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.cyan,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Lingo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              const Text(
                'Cards',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: AppColors.cyan,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 15, 24, 6),
          child: Text(
            'SET (1000 KELİME)',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              for (String s in DatabaseHelper.kAllSetIds)
                _secimButonu(s, secilenSetId == s, () {
                  if (secilenSetId == s) return;
                  setState(() {
                    secilenSetId = s;
                    if (WordRarityMath.isLockedForSetAndTier(
                        s, secilenTier, secilenRarity)) {
                      secilenRarity = WordRarity.common;
                    }
                  });
                  _havuzuYukle(s, secilenTier);
                }),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 15, 24, 6),
          child: Text(
            'KADEMESİ',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              for (final t in ['100', '250', '500', '1K'])
                _secimButonu(t, secilenTier == t, () {
                  if (secilenTier == t) return;
                  AppSettings.selectionClick();
                  setState(() {
                    secilenTier = t;
                    if (WordRarityMath.isLockedForSetAndTier(
                        secilenSetId, t, secilenRarity)) {
                      secilenRarity = WordRarity.common;
                    }
                  });
                  _havuzuYukle(secilenSetId, t);
                }),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 15, 24, 6),
          child: Text(
            'ENDERLİK',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              for (WordRarity r in WordRarity.values) _enderlikButonu(r),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: _setYukleniyor
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.cyan),
                )
              : ekrandakiKelimeler.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Bu enderlikte henüz kelime yok.',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      itemCount: ekrandakiKelimeler.length,
                      itemBuilder: (context, index) {
                        return KelimeKarti(
                          key: ValueKey(
                            '$secilenSetId-${ekrandakiKelimeler[index]['en']}',
                          ),
                          data: ekrandakiKelimeler[index],
                          onNewWord: () => tekKelimeDegistir(index),
                          temaRengi: AppColors.cyan,
                          golgeRengi: AppColors.cyanKoyu,
                          setId: secilenSetId,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  /// Enderlik filtre butonu. Set'in maks enderliğinin üzerindeki seviyeler
  /// kilit ikonu ile gri renkte gösterilir ve tıklanamaz.
  Widget _enderlikButonu(WordRarity r) {
    final secili = secilenRarity == r;
    final kilitli = WordRarityMath.isLockedForSetAndTier(
        secilenSetId, secilenTier, r);
    return GestureDetector(
      onTap: kilitli
          ? null
          : () {
              if (secilenRarity == r) return;
              AppSettings.selectionClick();
              setState(() => secilenRarity = r);
              kelimeleriGetir();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: kilitli
              ? AppColors.butonArka.withValues(alpha: 0.4)
              : (secili ? r.color : AppColors.butonArka),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: kilitli
                ? Colors.white12
                : (secili ? r.color : r.color.withValues(alpha: 0.35)),
          ),
        ),
        child: Row(
          children: [
            if (kilitli)
              const Icon(Icons.lock, size: 12, color: Colors.white38)
            else
              RarityIcon(r, size: 18),
            const SizedBox(width: 6),
            Text(
              r.labelTr,
              style: TextStyle(
                color: kilitli
                    ? Colors.white38
                    : (secili ? Colors.black : Colors.white70),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// --- PANEL 2: PROFİL VE SOSYAL PANEL ---
// ==========================================

class ProfilePanel extends StatefulWidget {
  const ProfilePanel({super.key});

  @override
  State<ProfilePanel> createState() => _ProfilePanelState();
}

class _ProfilePanelState extends State<ProfilePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  IconData aktifAvatar = Icons.person_rounded;

  List<MatchRecord> _macGecmisi = [];
  bool _gecmisYukleniyor = true;
  final Set<int> _acikMaclar = {}; // açık maç kartı id'leri

  Map<String, Map<String, dynamic>> tumKullanicilar = {
    'Ahmet_Can': {'durum': 'Çevrimiçi', 'aktif': true, 'isDuel': false},
    'Zeynep01': {'durum': 'Düelloda', 'aktif': false, 'isDuel': true},
    'MehmetK': {
      'durum': 'Son görülme 2 saat önce',
      'aktif': false,
      'isDuel': false,
    },
    'Selin_Ay': {'durum': 'Çevrimiçi', 'aktif': true, 'isDuel': false},
    'Kemal_X': {'durum': 'A Ligi Düellosu', 'aktif': false, 'isDuel': false},
    'AyseV': {'durum': 'B Ligi Zamana Karşı', 'aktif': true, 'isDuel': false},
    'Mert_Oynuyor': {
      'durum': 'Telefon Rehberinden',
      'aktif': true,
      'isDuel': false,
    },
    'Ceren99': {
      'durum': 'Telefon Rehberinden',
      'aktif': false,
      'isDuel': false,
    },
  };

  List<String> arkadasListem = ['Ahmet_Can', 'Zeynep01', 'MehmetK'];
  List<String> engellenenListem = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    AppSettings.matchSavedNotifier.addListener(_reloadGecmis);
    _reloadGecmis(); // ilk yükleme
  }

  @override
  void dispose() {
    _tabController.dispose();
    AppSettings.matchSavedNotifier.removeListener(_reloadGecmis);
    super.dispose();
  }

  void _reloadGecmis() {
    OwnershipDb.getMatchHistory().then((records) {
      if (!mounted) return;
      setState(() {
        _macGecmisi = records;
        _gecmisYukleniyor = false;
      });
    });
  }

  void _ayarlariAc() {
    AppSettings.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AyarlarEkrani()),
    ).then((_) => setState(() {}));
  }

  void _postaPaneliAc() {
    AppSettings.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PostaKutusuModal(),
    );
  }

  void _sohbetPaneliAc(String isim) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SohbetEkrani(
        isim: isim,
        arkadasMi: arkadasListem.contains(isim),
        data: tumKullanicilar[isim],
        onArkadasEkle: () => setState(() {
          if (!arkadasListem.contains(isim)) arkadasListem.add(isim);
        }),
        onArkadasCikar: () => setState(() => arkadasListem.remove(isim)),
        onEngelle: () => setState(() {
          arkadasListem.remove(isim);
          if (!engellenenListem.contains(isim)) engellenenListem.add(isim);
        }),
      ),
    );
  }

  void _avatarSeciciAc() {
    AppSettings.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: AppColors.arkaPlan,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Text(
              "Avatar Seç",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                padding: const EdgeInsets.all(24),
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                children: [
                  _avatarSecenek(Icons.person_rounded),
                  _avatarSecenek(Icons.sentiment_satisfied_alt_rounded),
                  _avatarSecenek(Icons.local_fire_department_rounded),
                  _avatarSecenek(Icons.cruelty_free_rounded),
                  _avatarSecenek(Icons.rocket_launch_rounded),
                  _avatarSecenek(Icons.ac_unit_rounded),
                  _avatarSecenek(Icons.sports_esports_rounded),
                  _avatarSecenek(Icons.pets_rounded),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: GestureDetector(
                onTap: () {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Galeriden seçme özelliği yakında!"),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.yuzey,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_rounded, color: Colors.white60),
                      SizedBox(width: 8),
                      Text(
                        "Galeriden Yükle",
                        style: TextStyle(
                          color: Colors.white60,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarSecenek(IconData ikon) {
    final bool secili = aktifAvatar == ikon;
    return GestureDetector(
      onTap: () {
        AppSettings.selectionClick();
        setState(() => aktifAvatar = ikon);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: secili
              ? AppColors.sari.withValues(alpha: 0.2)
              : AppColors.yuzey,
          shape: BoxShape.circle,
          border: Border.all(
            color: secili ? AppColors.sari : Colors.white10,
            width: 2,
          ),
        ),
        child: Icon(
          ikon,
          color: secili ? AppColors.sari : Colors.white,
          size: 30,
        ),
      ),
    );
  }

  void _arkadasEklePaneliAc() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ArkadasEkleModal(
        tumKullanicilar: tumKullanicilar,
        arkadasListem: arkadasListem,
        engellenenListem: engellenenListem,
        onEkle: (isim) => setState(() => arkadasListem.add(isim)),
        onCikar: (isim) => setState(() => arkadasListem.remove(isim)),
        onEngelle: (isim) {
          setState(() {
            arkadasListem.remove(isim);
            if (!engellenenListem.contains(isim)) engellenenListem.add(isim);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$isim engellendi."),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onEngelKaldir: (isim) => setState(() => engellenenListem.remove(isim)),
        onMesajAc: (isim) => _sohbetPaneliAc(isim),
      ),
    );
  }

  void _arkadasCikarOnay(String isim) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.yuzey,
        title: Text(
          "$isim arkadaşlıktan çıkarılsın mı?",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Bu kişi arkadaş listenden silinecek. İstediğin zaman tekrar ekleyebilirsin.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("İPTAL", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              setState(() => arkadasListem.remove(isim));
              messenger.showSnackBar(
                SnackBar(
                  content: Text("$isim arkadaşlıktan çıkarıldı."),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              "ÇIKAR",
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

  void _engelleSor(String isim) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.yuzey,
        title: Text(
          "$isim Engellensin mi?",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          "Bu kişi size mesaj atamayacak, arkadaş listesinden silinecek.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("İPTAL", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              setState(() {
                arkadasListem.remove(isim);
                if (!engellenenListem.contains(isim)) {
                  engellenenListem.add(isim);
                }
              });
              messenger.showSnackBar(
                SnackBar(content: Text("$isim engellendi.")),
              );
            },
            child: const Text(
              "ENGELLE",
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Ayarlar / Posta satırı ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ikonButon(Icons.settings_rounded, _ayarlariAc),
              _ikonButon(Icons.mail_outline_rounded, _postaPaneliAc,
                  bildirimVar: true),
            ],
          ),
        ),
        // ── Avatar + Bilgi Row ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _avatarSeciciAc,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.yuzey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.sari.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Icon(aktifAvatar, size: 44, color: AppColors.sari),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.cyan,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.arkaPlan, width: 2),
                      ),
                      child: const Icon(Icons.edit_rounded,
                          color: Colors.black, size: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: _profilBilgiKolonu()),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Stats chip satırı ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _statsChipSatiri(),
        ),
        const SizedBox(height: 10),
        // ── TabBar ─────────────────────────────────────────────────────
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.sari,
          labelColor: AppColors.sari,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: "Arkadaşlar"),
            Tab(text: "Mesajlar"),
            Tab(text: "Geçmiş"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildArkadaslarSekmesi(),
              _buildMesajlarSekmesi(),
              _buildGecmisSekmesi(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Yeni yardımcı metodlar ─────────────────────────────────────────────────

  Widget _ikonButon(IconData ikon, VoidCallback onTap,
      {bool bildirimVar = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.yuzey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ikon, color: Colors.white, size: 22),
          ),
          if (bildirimVar)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.kirmizi,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profilBilgiKolonu() {
    final lp        = AppSettings.playerLP;
    final group     = LeagueRules.groupOf(lp);
    final maxRoom   = LeagueRules.maxCreatableRoom(lp);
    final softStart = LeagueRules.isSoftStart(lp,
        softStartCompleted: AppSettings.softStartCompleted);
    final nextRooms = kAllRooms
        .where((r) => r.createThreshold > lp)
        .toList();
    final nextThr   = nextRooms.isNotEmpty
        ? nextRooms.first.createThreshold : null;
    final curThr    = maxRoom.createThreshold;
    final progress  = nextThr != null && nextThr > curThr
        ? (lp - curThr) / (nextThr - curThr) : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "LingoUstası99",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 5),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.sari.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.sari.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.sari, size: 11),
                  const SizedBox(width: 4),
                  Text(
                    '${group.name} LİGİ  •  ${maxRoom.id}  •  $lp LP',
                    style: TextStyle(
                      color: AppColors.sari,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            if (softStart)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('SOFT',
                    style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 8,
                        fontWeight: FontWeight.w900)),
              ),
          ],
        ),
        if (nextThr != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppColors.sari.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.sari.withValues(alpha: 0.6)),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$lp / $nextThr LP',
            style: TextStyle(
              color: AppColors.sari.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _statsChipSatiri() {
    final macStr = _formatlaSayi(AppSettings.toplamMac);
    final kazanStr = AppSettings.kazanmaOraniYuzde == null
        ? '—'
        : '%${AppSettings.kazanmaOraniYuzde!.round()}';

    return FutureBuilder<FameStats>(
      future: OwnershipEngine.getFameStats(),
      builder: (context, snap) {
        final kelimeStr =
            snap.hasData ? _formatlaSayi(snap.data!.totalOwned) : '—';
        return Row(
          children: [
            Expanded(
              child: _minikStatChip('$kelimeStr Kelime', AppColors.cyan,
                  Icons.workspace_premium_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _minikStatChip(
                  '$macStr Maç', AppColors.cyan, Icons.sports_esports_rounded),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _minikStatChip('$kazanStr Kazan', AppColors.kirmizi,
                  Icons.emoji_events_rounded),
            ),
          ],
        );
      },
    );
  }

  Widget _minikStatChip(String yazi, Color renk, IconData ikon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, color: renk, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              yazi,
              style: TextStyle(
                color: renk,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Binlik ayraçlı sayı: 1240 → "1,240", 42 → "42".
  String _formatlaSayi(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _buildArkadaslarSekmesi() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  AppSettings.mediumImpact();
                  _arkadasEklePaneliAc();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.sari.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.sari.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_add_rounded,
                        color: AppColors.sari,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Arkadaş Ekle",
                        style: TextStyle(
                          color: AppColors.sari,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () {
                AppSettings.mediumImpact();
                _engellenenlerModaliAc();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.kirmizi.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.kirmizi.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.block_flipped,
                      color: AppColors.kirmizi,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${engellenenListem.length}',
                      style: const TextStyle(
                        color: AppColors.kirmizi,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (String isim in arkadasListem) _arkadasKarti(isim),
      ],
    );
  }

  void _engellenenlerModaliAc() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (modalContext, modalSetState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.arkaPlan,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Engellenenler",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: engellenenListem.isEmpty
                    ? const Center(
                        child: Text(
                          "Engellediğin kimse yok.",
                          style: TextStyle(color: Colors.white38),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          for (String isim in List<String>.from(
                            engellenenListem,
                          ))
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.yuzey,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: AppColors.kirmizi.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: AppColors.arkaPlan,
                                    child: Icon(
                                      Icons.block_flipped,
                                      color: AppColors.kirmizi,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      isim,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      AppSettings.mediumImpact();
                                      setState(
                                        () => engellenenListem.remove(isim),
                                      );
                                      modalSetState(() {});
                                    },
                                    child: const Text(
                                      "Engeli Kaldır",
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arkadasKarti(String isim) {
    final kisi = tumKullanicilar[isim];
    if (kisi == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.yuzey,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.arkaPlan,
            child: Icon(
              Icons.person,
              color: kisi['aktif'] ? Colors.white : Colors.white24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isim,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kisi['durum'],
                  style: TextStyle(
                    color: kisi['isDuel']
                        ? AppColors.kirmizi
                        : (kisi['aktif'] ? Colors.greenAccent : Colors.white38),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white38),
            color: AppColors.yuzey,
            onSelected: (deger) {
              if (deger == 'profil') {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => BaskaKullaniciProfili(
                    isim: isim,
                    data: kisi,
                    isArkadas: arkadasListem.contains(isim),
                    onArkadasEkle: () => setState(() {
                      if (!arkadasListem.contains(isim)) {
                        arkadasListem.add(isim);
                      }
                    }),
                    onMesajAt: () => _sohbetPaneliAc(isim),
                  ),
                );
              } else if (deger == 'mesaj') {
                _sohbetPaneliAc(isim);
              } else if (deger == 'cikar') {
                _arkadasCikarOnay(isim);
              } else if (deger == 'engelle') {
                _engelleSor(isim);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profil',
                child: Row(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 18),
                    SizedBox(width: 8),
                    Text("Profili Gör"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mesaj',
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Text("Mesaj At"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cikar',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_outlined, size: 18),
                    SizedBox(width: 8),
                    Text("Arkadaşlıktan Çıkar"),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'engelle',
                child: Row(
                  children: [
                    Icon(
                      Icons.block_flipped,
                      size: 18,
                      color: AppColors.kirmizi,
                    ),
                    SizedBox(width: 8),
                    Text("Engelle", style: TextStyle(color: AppColors.kirmizi)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMesajlarSekmesi() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
      children: [
        _mesajKarti("Ahmet_Can", "Rövanş atalım mı?", "12:45", okunmadi: true),
        _mesajKarti(
          "Zeynep01",
          "Yeni rekorumu gördün mü?",
          "Dün",
          okunmadi: false,
        ),
      ],
    );
  }

  Widget _mesajKarti(
    String isim,
    String sonMesaj,
    String zaman, {
    required bool okunmadi,
  }) {
    return GestureDetector(
      onTap: () {
        AppSettings.lightImpact();
        _sohbetPaneliAc(isim);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: okunmadi
              ? AppColors.yuzey
              : AppColors.yuzey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: okunmadi
                ? AppColors.sari.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.arkaPlan,
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isim,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        zaman,
                        style: TextStyle(
                          color: okunmadi ? AppColors.sari : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sonMesaj,
                    style: TextStyle(
                      fontSize: 13,
                      color: okunmadi ? Colors.white : Colors.white60,
                      fontWeight: okunmadi
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.white38,
                size: 20,
              ),
              color: AppColors.yuzey,
              onSelected: (deger) {
                final messenger = ScaffoldMessenger.of(context);
                if (deger == 'okundu') {
                  AppSettings.lightImpact();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text("$isim sohbeti okundu işaretlendi."),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                } else if (deger == 'sessiz') {
                  AppSettings.lightImpact();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text("$isim sessize alındı."),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                } else if (deger == 'sil') {
                  AppSettings.mediumImpact();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text("$isim ile sohbet silindi."),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'okundu',
                  child: Row(
                    children: [
                      Icon(Icons.mark_chat_read_outlined, size: 18),
                      SizedBox(width: 8),
                      Text("Okundu İşaretle"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'sessiz',
                  child: Row(
                    children: [
                      Icon(Icons.volume_off_outlined, size: 18),
                      SizedBox(width: 8),
                      Text("Sessize Al"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'sil',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text("Sohbeti Sil", style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Geçmiş sekmesi ─────────────────────────────────────────────────────────

  Widget _buildGecmisSekmesi() {
    if (_gecmisYukleniyor) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.sari),
      );
    }
    if (_macGecmisi.isEmpty) {
      return const Center(
        child: Text(
          'Henüz maç oynamadın.',
          style: TextStyle(color: Colors.white38, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _macGecmisi.length,
      itemBuilder: (_, i) => _macKarti(_macGecmisi[i]),
    );
  }

  Widget _macKarti(MatchRecord r) {
    final acik = _acikMaclar.contains(r.id);
    final tarih = DateTime.fromMillisecondsSinceEpoch(r.playedAt);
    final tarihStr =
        '${tarih.day}.${tarih.month}.${tarih.year}  '
        '${tarih.hour}:${tarih.minute.toString().padLeft(2, '0')}';
    final kazandiMi = MatchScoring.isWin(r.position, r.playerCount);
    final pozisyonRenk = kazandiMi ? Colors.greenAccent : AppColors.kirmizi;

    return GestureDetector(
      onTap: () {
        AppSettings.selectionClick();
        setState(() {
          acik ? _acikMaclar.remove(r.id) : _acikMaclar.add(r.id);
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.yuzey,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Başlık satırı ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(
                    '#${r.position}',
                    style: TextStyle(
                      color: pozisyonRenk,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.setId} • ${r.tier} ODA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          tarihStr,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${r.words.length} soru',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    acik ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white38,
                    size: 20,
                  ),
                ],
              ),
            ),
            // ── Kelime pilleri (açıksa) ──
            if (acik)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: r.words.map(_kelimePili).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kelimePili(MatchWordResult w) {
    final Color c = w.correct == null
        ? Colors.white24               // cevapsız
        : w.correct! ? Colors.greenAccent : AppColors.kirmizi;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        w.en,
        style: TextStyle(
          color: c,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ==========================================
// --- PANEL 3: LINGO DUEL (LOBİ) ---
// ==========================================
class DuelPanel extends StatefulWidget {
  const DuelPanel({super.key});

  @override
  State<DuelPanel> createState() => _DuelPanelState();
}

class _DuelPanelState extends State<DuelPanel> {
  final Color duelRed = AppColors.kirmizi;
  String aramaMetni = "";

  List<String> seciliSetIdler = List<String>.from(DatabaseHelper.kAllSetIds);
  List<String> seciliTierlar = List<String>.from(kAllRoomTiers);
  bool sadeceBosOdalar = false;
  bool sifrelileriGizle = false;

  List<Map<String, dynamic>> aktifOdalar = [
    {
      'isim': 'Çaylaklar Toplanın',
      'setId': 'A',
      'tier': '100',
      'dolu': 2,
      'kapasite': 6,
      'sifreli': false,
    },
    {
      'isim': 'İngilizce Geliştirme',
      'setId': 'BI',
      'tier': '250',
      'dolu': 6,
      'kapasite': 6,
      'sifreli': false,
    },
    {
      'isim': 'Zamana Karşı',
      'setId': 'BII',
      'tier': '500',
      'dolu': 4,
      'kapasite': 6,
      'sifreli': false,
    },
    {
      'isim': 'Hızlı Maç',
      'setId': 'CIII',
      'tier': '1K',
      'dolu': 1,
      'kapasite': 2,
      'sifreli': false,
    },
    {
      'isim': 'Arkadaşlarla Özel',
      'setId': 'BIII',
      'tier': '1K',
      'dolu': 2,
      'kapasite': 6,
      'sifreli': true,
      'sifre': '1234',
    },
  ];

  void _odaKurPaneliAc() {
    AppSettings.heavyImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => OdaKurModal(
        playerLP: AppSettings.playerLP,
        onOdaEkle: (yeniOda) {
          setState(() {
            aktifOdalar.insert(0, yeniOda);
          });
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OyunOdasiEkrani(odaBilgisi: yeniOda),
              ),
            ).then((_) => setState(() {})); // LP değişince DuelPanel yenilenir
          });
        },
      ),
    );
  }

  void _filtrePaneliAc() {
    AppSettings.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OdaFiltreModal(
        mevcutSetIdler: seciliSetIdler,
        mevcutTierlar: seciliTierlar,
        mevcutSadeceBos: sadeceBosOdalar,
        mevcutSifresiz: sifrelileriGizle,
        onFiltreUygula: (setIdler, tierlar, bos, sifresiz) {
          setState(() {
            seciliSetIdler = setIdler;
            seciliTierlar = tierlar;
            sadeceBosOdalar = bos;
            sifrelileriGizle = sifresiz;
          });
        },
      ),
    );
  }

  Future<void> _sifreSor(Map<String, dynamic> oda) async {
    final bool? basarili = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _SifreDialog(
        odaAdi: (oda['isim'] ?? 'Şifreli Oda').toString(),
        dogruSifre: (oda['sifre'] ?? '').toString(),
        duelRed: duelRed,
      ),
    );
    if (basarili == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OyunOdasiEkrani(odaBilgisi: oda)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> gosterilecekOdalar = aktifOdalar.where((
      oda,
    ) {
      final bool isimUyar = oda['isim'].toLowerCase().contains(
        aramaMetni.toLowerCase(),
      );
      final bool ligUyar = seciliSetIdler.contains(oda['setId']) &&
          seciliTierlar.contains(oda['tier']);
      final bool boslukUyar = sadeceBosOdalar
          ? (oda['dolu'] < oda['kapasite'])
          : true;
      final bool sifreUyar = sifrelileriGizle
          ? (oda['sifreli'] == false)
          : true;
      return isimUyar && ligUyar && boslukUyar && sifreUyar;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: duelRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bolt_rounded, color: duelRed, size: 28),
              ),
              const SizedBox(width: 12),
              const Text(
                'Lingo',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
              Text(
                'Duel',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  color: duelRed,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: _LpBadge(lp: AppSettings.playerLP, renk: duelRed, compact: true),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.yuzey,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: TextField(
                    onChanged: (deger) => setState(() => aramaMetni = deger),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Oda Ara...",
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.white38,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _filtrePaneliAc,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        (seciliSetIdler.length < DatabaseHelper.kAllSetIds.length ||
                            seciliTierlar.length < kAllRoomTiers.length ||
                            sadeceBosOdalar ||
                            sifrelileriGizle)
                        ? duelRed
                        : AppColors.yuzey,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color:
                          (seciliSetIdler.length < DatabaseHelper.kAllSetIds.length ||
                              seciliTierlar.length < kAllRoomTiers.length ||
                              sadeceBosOdalar ||
                              sifrelileriGizle)
                          ? duelRed
                          : Colors.white12,
                    ),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    color:
                        (seciliSetIdler.length < DatabaseHelper.kAllSetIds.length ||
                            seciliTierlar.length < kAllRoomTiers.length ||
                            sadeceBosOdalar ||
                            sifrelileriGizle)
                        ? Colors.black
                        : Colors.white60,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 10, 24, 6),
          child: Text(
            'AKTİF ODALAR',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: gosterilecekOdalar.isEmpty
              ? const Center(
                  child: Text(
                    "Aradığınız kriterde oda bulunamadı.",
                    style: TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: gosterilecekOdalar.length,
                  itemBuilder: (context, index) {
                    return _odaKarti(gosterilecekOdalar[index]);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 100),
          child: GestureDetector(
            onTap: _odaKurPaneliAc,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: duelRed,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: AppColors.kirmiziKoyu, offset: Offset(0, 5)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_box_rounded, color: Colors.black, size: 24),
                  SizedBox(width: 8),
                  Text(
                    "YENİ ODA KUR",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _odaKarti(Map<String, dynamic> oda) {
    final bool doluMu = oda['dolu'] >= oda['kapasite'];
    final RoomDefinition? room = roomForSetAndTier(
      oda['setId'] as String,
      oda['tier'] as String,
    );
    final int playerLP = AppSettings.playerLP;
    final bool girebilir =
        room != null && LeagueRules.canJoin(playerLP, room);
    final bool aboveMax = girebilir &&
        room.levelIndex > LeagueRules.maxCreatableRoom(playerLP).levelIndex;

    return GestureDetector(
      onTap: () {
        AppSettings.mediumImpact();
        if (!girebilir) {
          final grubAdi = room != null
              ? 'Bu oda ${room.league.name} ligine ait. '
                  '${room.league.name} ligine girmek için '
                  '${room.league == LeagueGroup.B ? '1100' : '2100'} LP gerekiyor.'
              : 'Bu odaya giriş yetkiniz yok.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(grubAdi)),
          );
          return;
        }
        if (doluMu) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Bu oda şu an dolu.")));
          return;
        }
        if (oda['sifreli'] == true) {
          _sifreSor(oda);
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OyunOdasiEkrani(odaBilgisi: oda),
          ),
        ).then((_) => setState(() {})); // LP güncellenince DuelPanel yenilenir
      },
      child: Opacity(
        opacity: girebilir ? 1.0 : 0.45,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.yuzey,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: !girebilir
                  ? Colors.white12
                  : doluMu
                      ? Colors.white10
                      : duelRed.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            oda['isim'],
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: doluMu ? Colors.white38 : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (oda['sifreli']) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.lock_rounded,
                            color: Colors.white38,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: duelRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "${oda['setId']} • ${oda['tier']} ODA",
                            style: TextStyle(
                              color: duelRed,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Erişim / risk-ödül badge'i
                        if (!girebilir)
                          _erisimBadge(
                            Icons.lock_outline_rounded,
                            'YETERSİZ SEVİYE',
                            Colors.white38,
                          )
                        else if (aboveMax)
                          _erisimBadge(
                            Icons.trending_up_rounded,
                            'AVANTAJLI',
                            Colors.orangeAccent,
                          ),
                        const SizedBox(width: 8),
                        Text(
                          "${oda['dolu']}/${oda['kapasite']} Oyuncu",
                          style: TextStyle(
                            color: doluMu ? Colors.white24 : Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                !girebilir
                    ? Icons.block_rounded
                    : doluMu
                        ? Icons.not_interested_rounded
                        : Icons.arrow_forward_ios_rounded,
                color: !girebilir
                    ? Colors.white24
                    : doluMu
                        ? Colors.white24
                        : duelRed,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _erisimBadge(IconData ikon, String etiket, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: renk.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 9, color: renk),
          const SizedBox(width: 3),
          Text(
            etiket,
            style: TextStyle(
              color: renk,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- ŞİFRELİ ODA DIALOG ---
// ==========================================
class _SifreDialog extends StatefulWidget {
  final String odaAdi;
  final String dogruSifre;
  final Color duelRed;

  const _SifreDialog({
    required this.odaAdi,
    required this.dogruSifre,
    required this.duelRed,
  });

  @override
  State<_SifreDialog> createState() => _SifreDialogState();
}

class _SifreDialogState extends State<_SifreDialog> {
  final TextEditingController _ctrl = TextEditingController();
  String? _hata;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _dene() {
    AppSettings.lightImpact();
    final girilen = _ctrl.text.trim();
    final dogru = widget.dogruSifre.trim();
    if (dogru.isNotEmpty && girilen == dogru) {
      AppSettings.heavyImpact();
      Navigator.of(context).pop(true);
    } else {
      AppSettings.selectionClick();
      setState(() => _hata = 'Şifre hatalı. Tekrar dene.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.yuzey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.duelRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lock_rounded,
                    color: widget.duelRed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.odaAdi,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Bu oda şifreli. Katılmak için odanın şifresini gir.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.butonArka,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hata != null ? widget.duelRed : Colors.white12,
                ),
              ),
              child: TextField(
                controller: _ctrl,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) {
                  if (_hata != null) setState(() => _hata = null);
                },
                onSubmitted: (_) => _dene(),
                decoration: const InputDecoration(
                  hintText: 'Şifre',
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.key_rounded, color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),
            ),
            if (_hata != null) ...[
              const SizedBox(height: 8),
              Text(
                _hata!,
                style: TextStyle(
                  color: widget.duelRed,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    AppSettings.lightImpact();
                    Navigator.of(context).pop(false);
                  },
                  child: const Text(
                    'İPTAL',
                    style: TextStyle(
                      color: Colors.white54,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: _dene,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.duelRed,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'KATIL',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// --- MODAL EKRANLARI ---
// ==========================================
class OdaFiltreModal extends StatefulWidget {
  final List<String> mevcutSetIdler;
  final List<String> mevcutTierlar;
  final bool mevcutSadeceBos;
  final bool mevcutSifresiz;
  final Function(List<String>, List<String>, bool, bool) onFiltreUygula;

  const OdaFiltreModal({
    super.key,
    required this.mevcutSetIdler,
    required this.mevcutTierlar,
    required this.mevcutSadeceBos,
    required this.mevcutSifresiz,
    required this.onFiltreUygula,
  });

  @override
  State<OdaFiltreModal> createState() => _OdaFiltreModalState();
}

class _OdaFiltreModalState extends State<OdaFiltreModal> {
  List<String> seciliSetIdler = [];
  List<String> seciliTierlar = [];
  bool sadeceBosOdalar = false;
  bool sifrelileriGizle = false;

  @override
  void initState() {
    super.initState();
    seciliSetIdler = List.from(widget.mevcutSetIdler);
    seciliTierlar = List.from(widget.mevcutTierlar);
    sadeceBosOdalar = widget.mevcutSadeceBos;
    sifrelileriGizle = widget.mevcutSifresiz;
  }

  Widget _toggleButon({
    required String etiket,
    required bool seciliMi,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: seciliMi ? AppColors.kirmizi : AppColors.butonArka,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seciliMi ? AppColors.kirmizi : Colors.white12,
          ),
        ),
        child: Center(
          child: Text(
            etiket,
            style: TextStyle(
              color: seciliMi ? Colors.black : Colors.white60,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _filtreButonu(String setId) {
    final bool seciliMi = seciliSetIdler.contains(setId);
    return _toggleButon(
      etiket: setId,
      seciliMi: seciliMi,
      onTap: () {
        AppSettings.lightImpact();
        setState(() {
          if (seciliMi) {
            seciliSetIdler.remove(setId);
          } else {
            seciliSetIdler.add(setId);
          }
        });
      },
    );
  }

  Widget _tierFiltreButonu(String tier) {
    final bool seciliMi = seciliTierlar.contains(tier);
    return _toggleButon(
      etiket: tier,
      seciliMi: seciliMi,
      onTap: () {
        AppSettings.lightImpact();
        setState(() {
          if (seciliMi) {
            seciliTierlar.remove(tier);
          } else {
            seciliTierlar.add(tier);
          }
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: AppColors.arkaPlan,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Filtrele",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 25),
          const Text(
            "KELİME SETİ",
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          for (final lig in LeagueGroup.values) ...[
            if (lig != LeagueGroup.A) const SizedBox(height: 10),
            Row(
              children: [
                for (final set in wordSetsByLeague(lig))
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _filtreButonu(set.id),
                    ),
                  ),
                if (lig == LeagueGroup.A)
                  const Expanded(flex: 2, child: SizedBox.shrink()),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            "ODA KADEMESİ",
            style: TextStyle(
              color: Colors.white24,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final tier in kAllRoomTiers)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _tierFiltreButonu(tier),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            decoration: BoxDecoration(
              color: AppColors.yuzey,
              borderRadius: BorderRadius.circular(15),
            ),
            child: SwitchListTile(
              title: const Text(
                "Sadece Boş Odaları Göster",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              activeThumbColor: AppColors.kirmizi,
              activeTrackColor: AppColors.kirmizi.withValues(alpha: 0.3),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white10,
              value: sadeceBosOdalar,
              onChanged: (deger) => setState(() => sadeceBosOdalar = deger),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.yuzey,
              borderRadius: BorderRadius.circular(15),
            ),
            child: SwitchListTile(
              title: const Text(
                "Şifreli Odaları Gizle",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              activeThumbColor: AppColors.kirmizi,
              activeTrackColor: AppColors.kirmizi.withValues(alpha: 0.3),
              inactiveThumbColor: Colors.white38,
              inactiveTrackColor: Colors.white10,
              value: sifrelileriGizle,
              onChanged: (deger) => setState(() => sifrelileriGizle = deger),
            ),
          ),
          const SizedBox(height: 30),
          GestureDetector(
            onTap: () {
              AppSettings.heavyImpact();
              widget.onFiltreUygula(
                seciliSetIdler,
                seciliTierlar,
                sadeceBosOdalar,
                sifrelileriGizle,
              );
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.kirmizi,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Text(
                  "SONUÇLARI GÖSTER",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class OdaKurModal extends StatefulWidget {
  final int playerLP;
  final Function(Map<String, dynamic>) onOdaEkle;
  const OdaKurModal({super.key, required this.playerLP, required this.onOdaEkle});

  @override
  State<OdaKurModal> createState() => _OdaKurModalState();
}

class _OdaKurModalState extends State<OdaKurModal> {
  final TextEditingController _isimController = TextEditingController();
  final TextEditingController _sifreController = TextEditingController();
  double oyuncuSayisi = 2;
  bool sifreliMi = false;
  String secilenSetId = 'A';
  String secilenTier = '100';

  @override
  void dispose() {
    _isimController.dispose();
    _sifreController.dispose();
    super.dispose();
  }

  /// Ortak button şablonu (set ve tier butonları aynı görsel).
  Widget _gateliButon({
    required String etiket,
    required bool seciliMi,
    required bool acabilir,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: seciliMi
              ? AppColors.kirmizi
              : acabilir
                  ? AppColors.butonArka
                  : AppColors.butonArka.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seciliMi
                ? AppColors.kirmizi
                : acabilir
                    ? Colors.white12
                    : Colors.white12.withValues(alpha: 0.3),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              etiket,
              style: TextStyle(
                color: seciliMi
                    ? Colors.black
                    : acabilir
                        ? Colors.white60
                        : Colors.white24,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            if (!acabilir)
              const Positioned(
                top: 4,
                right: 6,
                child: Icon(
                  Icons.lock_rounded,
                  size: 8,
                  color: Colors.white24,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _setButonu(WordSetDefinition set) {
    // Set'in min tier'ı (lig giriş LP'si): A100 / B100 / C100
    final RoomDefinition minRoom = roomForSetAndTier(set.id, '100')!;
    final bool acabilir = LeagueRules.canCreate(widget.playerLP, minRoom);
    return _gateliButon(
      etiket: set.id,
      seciliMi: secilenSetId == set.id,
      acabilir: acabilir,
      onTap: () {
        if (!acabilir) {
          AppSettings.selectionClick();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${set.league.name} ligine giriş için '
                '${minRoom.createThreshold} LP gerekiyor. '
                'Şu anki LP: ${widget.playerLP}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        AppSettings.lightImpact();
        setState(() {
          secilenSetId = set.id;
          // Seçilen yeni setin ligine göre tier'lar yeniden gate'lenir;
          // mevcut tier seçimi geçersizleşmişse 100'e düş.
          final tierRoom = roomForSetAndTier(set.id, secilenTier);
          if (tierRoom == null ||
              !LeagueRules.canCreate(widget.playerLP, tierRoom)) {
            secilenTier = '100';
          }
        });
      },
    );
  }

  Widget _tierButonu(String tier) {
    final RoomDefinition? room = roomForSetAndTier(secilenSetId, tier);
    final bool acabilir =
        room != null && LeagueRules.canCreate(widget.playerLP, room);
    return _gateliButon(
      etiket: tier,
      seciliMi: secilenTier == tier,
      acabilir: acabilir,
      onTap: () {
        if (!acabilir) {
          AppSettings.selectionClick();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '$secilenSetId • $tier odası için '
                '${room?.createThreshold ?? 0} LP gerekiyor. '
                'Şu anki LP: ${widget.playerLP}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        AppSettings.lightImpact();
        setState(() => secilenTier = tier);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: const BoxDecoration(
          color: AppColors.arkaPlan,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Oda Kur",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 25),
              const Text(
                "ODA ADI",
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.yuzey,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white12),
                ),
                child: TextField(
                  controller: _isimController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: "Örn: Pratik Odası",
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "OYUNCU SAYISI",
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    "${oyuncuSayisi.toInt()} Kişi",
                    style: const TextStyle(
                      color: AppColors.kirmizi,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Slider(
                value: oyuncuSayisi,
                min: 2,
                max: 6,
                divisions: 4,
                activeColor: AppColors.kirmizi,
                inactiveColor: AppColors.yuzey,
                onChanged: (deger) => setState(() => oyuncuSayisi = deger),
              ),
              const SizedBox(height: 15),
              const Text(
                "KELİME SETİ",
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              for (final lig in LeagueGroup.values) ...[
                if (lig != LeagueGroup.A) const SizedBox(height: 10),
                Row(
                  children: [
                    for (final set in wordSetsByLeague(lig))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _setButonu(set),
                        ),
                      ),
                    // A satırı tek butonlu — sağ tarafı boş doldur
                    if (lig == LeagueGroup.A)
                      const Expanded(flex: 2, child: SizedBox.shrink()),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              const Text(
                "ODA KADEMESİ",
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final tier in kAllRoomTiers)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _tierButonu(tier),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 25),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.yuzey,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: SwitchListTile(
                  title: const Text(
                    "Özel (Şifreli) Oda",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  activeThumbColor: AppColors.kirmizi,
                  activeTrackColor: AppColors.kirmizi.withValues(alpha: 0.3),
                  inactiveThumbColor: Colors.white38,
                  inactiveTrackColor: Colors.white10,
                  value: sifreliMi,
                  onChanged: (deger) => setState(() => sifreliMi = deger),
                ),
              ),
              if (sifreliMi) ...[
                const SizedBox(height: 15),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.yuzey,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.kirmizi.withValues(alpha: 0.5),
                    ),
                  ),
                  child: TextField(
                    controller: _sifreController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: "Oda Şifresi Belirle",
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(
                        Icons.lock_rounded,
                        color: Colors.white38,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 30),
              GestureDetector(
                onTap: () {
                  AppSettings.heavyImpact();
                  String odaAdi = _isimController.text.trim();
                  if (odaAdi.isEmpty) odaAdi = "Yeni Oda";
                  widget.onOdaEkle({
                    'isim': odaAdi,
                    'setId': secilenSetId,
                    'tier': secilenTier,
                    'dolu': 1,
                    'kapasite': oyuncuSayisi.toInt(),
                    'sifreli': sifreliMi,
                    'sifre': sifreliMi ? _sifreController.text.trim() : '',
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.kirmizi,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Center(
                    child: Text(
                      "OLUŞTUR",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class PostaKutusuModal extends StatelessWidget {
  const PostaKutusuModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.arkaPlan,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const Text(
            "POSTA KUTUSU",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _postaKarti(
                  "GÜNCELLEME",
                  "V1.0.5 Yayında! Yeni Duel lobisi eklendi.",
                  "Yeni",
                  isUpdate: true,
                ),
                _postaKarti(
                  "ÖDÜL",
                  "Liderlik Sıralaması: 2.lik ödülü olarak 500 Elmas kazandın!",
                  "Şimdi",
                  isReward: true,
                ),
                _postaKarti(
                  "DUYURU",
                  "Sunucularımız bu gece 02:00'de bakıma girecektir.",
                  "1sa",
                  isInfo: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _postaKarti(
    String baslik,
    String icerik,
    String zaman, {
    bool isUpdate = false,
    bool isReward = false,
    bool isInfo = false,
  }) {
    final Color vurguRengi = isUpdate
        ? AppColors.cyan
        : (isReward ? AppColors.sari : Colors.white38);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.yuzey,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: vurguRengi.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                baslik,
                style: TextStyle(
                  color: vurguRengi,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
              Text(
                zaman,
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            icerik,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (isReward) ...[
            const SizedBox(height: 15),
            Builder(
              builder: (ctx) => GestureDetector(
                onTap: () {
                  AppSettings.heavyImpact();
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text("Ödül hesabına yüklendi! 🎁"),
                      backgroundColor: AppColors.sari,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: vurguRengi,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      "ÖDÜLÜ AL",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SohbetEkrani extends StatefulWidget {
  final String isim;
  final bool arkadasMi;
  final Map<String, dynamic>? data;
  final VoidCallback? onArkadasEkle;
  final VoidCallback? onArkadasCikar;
  final VoidCallback? onEngelle;

  const SohbetEkrani({
    super.key,
    required this.isim,
    this.arkadasMi = true,
    this.data,
    this.onArkadasEkle,
    this.onArkadasCikar,
    this.onEngelle,
  });

  @override
  State<SohbetEkrani> createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends State<SohbetEkrani> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  late bool _isArkadas;
  // Yerel mesaj geçmişi. Backend olmadığı için sadece bu oturumda durur.
  // Schema: {'text': String, 'mine': bool}
  late List<Map<String, dynamic>> _mesajlar;

  @override
  void initState() {
    super.initState();
    _isArkadas = widget.arkadasMi;
    _mesajlar = [
      {'text': 'Hey, LingoDuel oynayalım mı?', 'mine': false},
      {'text': 'Olur, 5 dakikaya geliyorum!', 'mine': true},
    ];
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _gonder() {
    final metin = _msgCtrl.text.trim();
    if (metin.isEmpty) return;
    AppSettings.lightImpact();
    setState(() {
      _mesajlar.add({'text': metin, 'mine': true});
      _msgCtrl.clear();
    });
    // En alta kaydır
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.arkaPlan,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.yuzey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.isim,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                  ),
                  color: AppColors.yuzey,
                  onSelected: (deger) {
                    final messenger = ScaffoldMessenger.of(context);
                    if (deger == 'profil') {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => BaskaKullaniciProfili(
                          isim: widget.isim,
                          data: widget.data,
                          isArkadas: _isArkadas,
                          onMesajAt: () {}, // zaten sohbetteyiz
                        ),
                      );
                    } else if (deger == 'ekle_cikar') {
                      if (_isArkadas) {
                        widget.onArkadasCikar?.call();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              "${widget.isim} arkadaşlıktan çıkarıldı.",
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      } else {
                        widget.onArkadasEkle?.call();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text("${widget.isim} arkadaş eklendi."),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                      setState(() => _isArkadas = !_isArkadas);
                    } else if (deger == 'engelle') {
                      widget.onEngelle?.call();
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        SnackBar(content: Text("${widget.isim} engellendi.")),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'profil',
                      child: Row(
                        children: [
                          Icon(Icons.account_circle_outlined, size: 18),
                          SizedBox(width: 8),
                          Text("Profili Gör"),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'ekle_cikar',
                      child: Row(
                        children: [
                          Icon(
                            _isArkadas
                                ? Icons.person_remove_outlined
                                : Icons.person_add_outlined,
                            size: 18,
                            color: _isArkadas ? Colors.white : AppColors.sari,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isArkadas ? "Arkadaşlıktan Çıkar" : "Arkadaş Ekle",
                            style: TextStyle(
                              color: _isArkadas ? Colors.white : AppColors.sari,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'engelle',
                      child: Row(
                        children: [
                          Icon(
                            Icons.block_flipped,
                            size: 18,
                            color: AppColors.kirmizi,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Engelle",
                            style: TextStyle(color: AppColors.kirmizi),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white60,
                    size: 30,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(24),
              itemCount: _mesajlar.length,
              itemBuilder: (_, i) {
                final m = _mesajlar[i];
                final mine = m['mine'] == true;
                return Align(
                  alignment: mine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: mine ? AppColors.sari : AppColors.yuzey,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: mine
                            ? const Radius.circular(20)
                            : Radius.zero,
                        bottomRight: mine
                            ? Radius.zero
                            : const Radius.circular(20),
                      ),
                    ),
                    child: Text(
                      m['text'].toString(),
                      style: TextStyle(
                        color: mine ? Colors.black : Colors.white,
                        fontWeight: mine ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.yuzey,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(color: Colors.white),
                      onSubmitted: (_) => _gonder(),
                      textInputAction: TextInputAction.send,
                      decoration: const InputDecoration(
                        hintText: "Mesaj yaz...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, color: AppColors.sari),
                    onPressed: _gonder,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  // Kalıcı ayarlardan yükle — uygulama kapatıp açıldığında değer korunur
  bool sfxAcik = AppSettings.sfxAcik;
  bool muzikAcik = AppSettings.muzikAcik;
  bool titresimAcik = AppSettings.titresimAcik;
  bool duelloDavetleriAcik = AppSettings.duelloDavetleriAcik;
  bool mesajBildirimleriAcik = AppSettings.mesajBildirimleriAcik;

  int get _lp => AppSettings.playerLP;

  Future<void> _lpDegistir(int delta) async {
    AppSettings.lightImpact();
    await AppSettings.setPlayerLP(_lp + delta);
    setState(() {});
  }

  Future<void> _lpSifirla() async {
    AppSettings.heavyImpact();
    await AppSettings.setPlayerLP(0);
    await AppSettings.resetSoftStart();
    await OwnershipDb.resetAll();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.arkaPlan,
      appBar: AppBar(
        backgroundColor: AppColors.arkaPlan,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "AYARLAR",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          _bolumBasligi("SES VE TİTREŞİM"),
          _switchAyari(
            Icons.volume_up_outlined,
            "Ses Efektleri (SFX)",
            sfxAcik,
            (val) {
              setState(() => sfxAcik = val);
              AppSettings.setSfx(val);
            },
          ),
          _switchAyari(Icons.music_note_outlined, "Oyun İçi Müzik", muzikAcik, (
            val,
          ) {
            setState(() => muzikAcik = val);
            AppSettings.setMuzik(val);
          }),
          _switchAyari(
            Icons.vibration_rounded,
            "Dokunsal Titreşim",
            titresimAcik,
            (val) {
              setState(() => titresimAcik = val);
              AppSettings.setTitresim(val);
            },
          ),
          const SizedBox(height: 25),
          _bolumBasligi("BİLDİRİMLER"),
          _switchAyari(
            Icons.notifications_active_outlined,
            "Düello Davetleri",
            duelloDavetleriAcik,
            (val) {
              setState(() => duelloDavetleriAcik = val);
              AppSettings.setDuelloDavet(val);
            },
          ),
          _switchAyari(
            Icons.chat_bubble_outline_rounded,
            "Yeni Mesajlar",
            mesajBildirimleriAcik,
            (val) {
              setState(() => mesajBildirimleriAcik = val);
              AppSettings.setMesajBildirim(val);
            },
          ),
          const SizedBox(height: 25),
          _bolumBasligi("TEST — LP AYARI"),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events_outlined, color: AppColors.sari, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "Mevcut LP: $_lp",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${LeagueRules.groupOf(_lp).name} Grubu",
                      style: TextStyle(
                        color: AppColors.sari.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final delta in [-100, -50, 50, 100, 250])
                      GestureDetector(
                        onTap: () => _lpDegistir(delta),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: delta < 0
                                ? AppColors.kirmizi.withValues(alpha: 0.15)
                                : Colors.greenAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: delta < 0
                                  ? AppColors.kirmizi.withValues(alpha: 0.4)
                                  : Colors.greenAccent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            delta > 0 ? "+$delta" : "$delta",
                            style: TextStyle(
                              color: delta < 0 ? AppColors.kirmizi : Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _lpSifirla,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Center(
                      child: Text(
                        "SIFIRLA",
                        style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () {
              AppSettings.heavyImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.kirmizi.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppColors.kirmizi.withValues(alpha: 0.5),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: AppColors.kirmizi),
                  SizedBox(width: 8),
                  Text(
                    "HESAPTAN ÇIKIŞ YAP",
                    style: TextStyle(
                      color: AppColors.kirmizi,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bolumBasligi(String baslik) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4),
    child: Text(
      baslik,
      style: const TextStyle(
        color: Colors.white24,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _switchAyari(
    IconData ikon,
    String metin,
    bool deger,
    Function(bool) onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.yuzey,
        borderRadius: BorderRadius.circular(15),
      ),
      child: SwitchListTile(
        activeThumbColor: AppColors.sari,
        activeTrackColor: AppColors.sari.withValues(alpha: 0.3),
        inactiveThumbColor: Colors.white38,
        inactiveTrackColor: Colors.white10,
        secondary: Icon(ikon, color: deger ? AppColors.sari : Colors.white60),
        title: Text(
          metin,
          style: TextStyle(
            color: deger ? Colors.white : Colors.white60,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        value: deger,
        onChanged: onChanged,
      ),
    );
  }
}

class ArkadasEkleModal extends StatefulWidget {
  final Map<String, Map<String, dynamic>> tumKullanicilar;
  final List<String> arkadasListem;
  final List<String> engellenenListem;
  final Function(String) onEkle;
  final Function(String) onCikar;
  final Function(String) onEngelle;
  final Function(String) onEngelKaldir;
  final Function(String) onMesajAc;

  const ArkadasEkleModal({
    super.key,
    required this.tumKullanicilar,
    required this.arkadasListem,
    required this.engellenenListem,
    required this.onEkle,
    required this.onCikar,
    required this.onEngelle,
    required this.onEngelKaldir,
    required this.onMesajAc,
  });

  @override
  State<ArkadasEkleModal> createState() => _ArkadasEkleModalState();
}

class _ArkadasEkleModalState extends State<ArkadasEkleModal> {
  String aramaMetni = "";

  @override
  Widget build(BuildContext context) {
    final List<String> gosterilecekKisiler = aramaMetni.isEmpty
        ? ['Kemal_X', 'AyseV', 'Mert_Oynuyor']
        : widget.tumKullanicilar.keys
              .where((k) => k.toLowerCase().contains(aramaMetni.toLowerCase()))
              .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.arkaPlan,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Arkadaş Ekle",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.yuzey,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white12),
              ),
              child: TextField(
                onChanged: (text) => setState(() => aramaMetni = text),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "Kullanıcı adı ara...",
                  hintStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.white38),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                if (aramaMetni.isEmpty)
                  const Text(
                    'ÖNERİLEN KİŞİLER',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                if (aramaMetni.isNotEmpty)
                  const Text(
                    'ARAMA SONUÇLARI',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                const SizedBox(height: 12),
                for (String isim in gosterilecekKisiler) _kisiEkleKarti(isim),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kisiEkleKarti(String isim) {
    if (!widget.tumKullanicilar.containsKey(isim)) return const SizedBox();
    final kisi = widget.tumKullanicilar[isim]!;
    final bool arkadasMi = widget.arkadasListem.contains(isim);
    final bool engelliMi = widget.engellenenListem.contains(isim);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.yuzey,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: engelliMi
              ? AppColors.kirmizi.withValues(alpha: 0.5)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.arkaPlan,
            child: Icon(
              Icons.person,
              color: engelliMi ? AppColors.kirmizi : Colors.white60,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isim,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    decoration: engelliMi
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: engelliMi ? Colors.white38 : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  engelliMi ? "Engellendi" : kisi['durum'],
                  style: TextStyle(
                    color: engelliMi ? AppColors.kirmizi : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white38),
            color: AppColors.yuzey,
            onSelected: (deger) {
              if (deger == 'profil') {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => BaskaKullaniciProfili(
                    isim: isim,
                    data: kisi,
                    isArkadas: arkadasMi,
                    onArkadasEkle: () {
                      widget.onEkle(isim);
                      setState(() {});
                    },
                    onMesajAt: () {
                      Navigator.pop(context);
                      widget.onMesajAc(isim);
                    },
                  ),
                );
              } else if (deger == 'mesaj') {
                Navigator.pop(context);
                widget.onMesajAc(isim);
              } else if (deger == 'ekle') {
                widget.onEkle(isim);
                setState(() {});
              } else if (deger == 'cikar') {
                widget.onCikar(isim);
                setState(() {});
              } else if (deger == 'engelle') {
                widget.onEngelle(isim);
                setState(() {});
              } else if (deger == 'engel_kaldir') {
                widget.onEngelKaldir(isim);
                setState(() {});
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profil',
                child: Row(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 18),
                    SizedBox(width: 8),
                    Text("Profili Gör"),
                  ],
                ),
              ),
              if (!engelliMi)
                const PopupMenuItem(
                  value: 'mesaj',
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 18),
                      SizedBox(width: 8),
                      Text("Mesaj At"),
                    ],
                  ),
                ),
              if (engelliMi)
                const PopupMenuItem(
                  value: 'engel_kaldir',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: Colors.greenAccent,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Engeli Kaldır",
                        style: TextStyle(color: Colors.greenAccent),
                      ),
                    ],
                  ),
                )
              else if (arkadasMi)
                const PopupMenuItem(
                  value: 'cikar',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_outlined, size: 18),
                      SizedBox(width: 8),
                      Text("Arkadaşlıktan Çıkar"),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'ekle',
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_add_outlined,
                        size: 18,
                        color: AppColors.sari,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Arkadaşlarıma Ekle",
                        style: TextStyle(color: AppColors.sari),
                      ),
                    ],
                  ),
                ),
              if (!engelliMi)
                const PopupMenuItem(
                  value: 'engelle',
                  child: Row(
                    children: [
                      Icon(
                        Icons.block_flipped,
                        size: 18,
                        color: AppColors.kirmizi,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "Engelle",
                        style: TextStyle(color: AppColors.kirmizi),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- ORTAK BİLEŞEN: DOKUNSAL KELİME KARTI ---
// ==========================================
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
  bool isFlipped = false;
  bool isPressed = false;

  @override
  Widget build(BuildContext context) {
    final rank   = widget.data['rank'] as int;
    final rarity = WordRarityMath.rarityForIndex(setId: widget.setId, index: rank);

    return GestureDetector(
      onTapDown: (_) => setState(() => isPressed = true),
      onTapUp: (_) => setState(() => isPressed = false),
      onTapCancel: () => setState(() => isPressed = false),
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
                    color: isFlipped ? widget.golgeRengi : AppColors.kartGolge,
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
      Positioned(top: 0, right: 0, child: _rarityChip(rarity, dark: true)),
    ],
  );
}

// ==========================================
// --- BAŞKA KULLANICI PROFİLİ MODALI ---
// ==========================================
class BaskaKullaniciProfili extends StatelessWidget {
  final String isim;
  final Map<String, dynamic>? data;
  final bool isArkadas;
  final VoidCallback? onArkadasEkle;
  final VoidCallback? onMesajAt;

  const BaskaKullaniciProfili({
    super.key,
    required this.isim,
    this.data,
    this.isArkadas = false,
    this.onArkadasEkle,
    this.onMesajAt,
  });

  @override
  Widget build(BuildContext context) {
    final String durum = data != null ? data!['durum'] : "Çevrimdışı";
    final bool isDuel = data != null ? data!['isDuel'] : false;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.arkaPlan,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 16),
            ],
          ),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.yuzey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: const Center(
              child: Icon(Icons.person, size: 60, color: Colors.white60),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isim,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            durum,
            style: TextStyle(
              color: isDuel ? AppColors.kirmizi : Colors.greenAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 25),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.yuzey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          "Lig",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "A LİGİ",
                          style: TextStyle(
                            color: AppColors.sari,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.yuzey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          "Kazanma",
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "%54",
                          style: TextStyle(
                            color: AppColors.cyan,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: isArkadas
                        ? null
                        : () {
                            final messenger = ScaffoldMessenger.of(context);
                            AppSettings.mediumImpact();
                            Navigator.pop(context);
                            onArkadasEkle?.call();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text("$isim arkadaş listene eklendi."),
                              ),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isArkadas ? AppColors.yuzey : AppColors.sari,
                        borderRadius: BorderRadius.circular(15),
                        border: isArkadas
                            ? Border.all(color: Colors.white12)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isArkadas
                                ? Icons.check_circle_rounded
                                : Icons.person_add_rounded,
                            color: isArkadas ? Colors.white60 : Colors.black,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isArkadas ? "ARKADAŞSINIZ" : "ARKADAŞ EKLE",
                            style: TextStyle(
                              color: isArkadas ? Colors.white60 : Colors.black,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      AppSettings.mediumImpact();
                      Navigator.pop(context);
                      if (onMesajAt != null) {
                        onMesajAt!();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.yuzey,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "MESAJ AT",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- LP ROZET WİDGET'I (ortak kullanım) ---
// ==========================================
class _LpBadge extends StatelessWidget {
  final int lp;
  final Color renk;
  /// compact=true → sadece rozet chip'i, progress bar yok (Row içinde güvenli)
  final bool compact;

  const _LpBadge({required this.lp, required this.renk, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final group    = LeagueRules.groupOf(lp);
    final maxRoom  = LeagueRules.maxCreatableRoom(lp);
    final softStart = LeagueRules.isSoftStart(
      lp, softStartCompleted: AppSettings.softStartCompleted,
    );

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: renk.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, color: renk, size: 13),
          const SizedBox(width: 5),
          Text(
            '${group.name} LİGİ • ${maxRoom.id}',
            style: TextStyle(
              color: renk,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$lp LP',
            style: TextStyle(
              color: renk.withValues(alpha: 0.8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (softStart) ...[
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SOFT',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (compact) return chip;

    // Tam versiyon: chip + progress bar
    final nextRooms = kAllRooms.where((r) => r.createThreshold > lp).toList();
    final int? nextThreshold =
        nextRooms.isNotEmpty ? nextRooms.first.createThreshold : null;
    final int currentThreshold = maxRoom.createThreshold;
    final double progress = nextThreshold != null && nextThreshold > currentThreshold
        ? (lp - currentThreshold) / (nextThreshold - currentThreshold)
        : 1.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip,
        if (nextThreshold != null) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: renk.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      renk.withValues(alpha: 0.6),
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$lp / $nextThreshold LP',
                  style: TextStyle(
                    color: renk.withValues(alpha: 0.5),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
