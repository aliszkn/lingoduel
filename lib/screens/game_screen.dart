import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nakama/nakama.dart' show MatchData, MatchPresenceEvent;
import '../core/app_colors.dart';
import '../game/match_scoring.dart';
import '../game/ownership_engine.dart';
import '../services/app_settings.dart';
import '../services/database_helper.dart';
import '../services/nakama_service.dart';
import '../services/ownership_db.dart';
import '../models/question_model.dart';
import '../models/word_entry.dart';
import '../widgets/rarity_question_card.dart';
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
      10; // maç başına sabit soru sayısı

  bool isOdaSahibi = true;
  bool isOyunBasladi = false;
  bool isBenHazirim = false;
  List<Map<String, dynamic>> oyuncular = [];
  // Banlanan oyuncu isimleri — yeni bot eklerken bu isim kullanılmaz
  final Set<String> _banliIsimler = {};

  // ── Faz 2: Gerçek çok oyunculu lobi ───────────────────────────────────────
  /// true = Nakama matchId ile gerçek lobi; false = eski bot modu
  late final bool _gercekCoklu;
  /// Nakama match ID (gerçek çok oyunculu modda dolu)
  late final String? _matchId;
  /// Nakama room ID (Lua Storage'daki oda kaydı)
  late final String? _roomId;
  /// Gerçek oyuncular: userId → isim
  final Map<String, String> _gercekOyuncular = {};
  StreamSubscription<MatchPresenceEvent>? _presenceSub;
  StreamSubscription<MatchData>?          _dataSub;

  // Rate-limit & debounce guard'ları (Prensip 3)
  /// Oyun başlatma idempotency: true olunca ikinci çağrı yok sayılır.
  bool _oyunBaslatildi = false;
  /// "Hazır ol" için son soket gönderim zamanı — 400ms throttle.
  DateTime? _sonHazirGonderim;

  // ── Faz 3: Sunucu-güdümlü oyun döngüsü ───────────────────────────────────
  /// create_room'dan gelen rastgele seed (tüm clientlerde aynı soru sırası).
  late final int _seed;
  /// Sunucunun gönderdiği aktif soru indeksi (cevapGonder için gerekli).
  int _aktifSoruIndex = 0;
  /// Maç sonu sinyali geldi mi (yeniden bağlanmayı durdurmak için).
  bool _macBitti = false;

  Timer? _zamanlayici;
  int kalanSure = _soruSuresi;
  QuestionModel? aktifSoru;
  WordEntry? _aktifKelime; // setId+rank claim için saklanır
  List<String> mevcutSiklar = [];

  /// Bu maçta sahiplenilen kelimeler — ResultScreen'e geçirilir.
  final List<WordEntry> _kazanilanKelimeler = [];

  /// Maçta sorulan tüm kelimeler (göründükleri sırayla) — geçmiş kaydı için.
  final List<WordEntry> _macdaGorunenKelimeler = [];

  /// wordId → true (doğru) / false (yanlış). Yoksa null (cevapsız).
  final Map<String, bool> _cevapDurumu = {};

  /// wordId → tıklama anındaki kalanSure. Yoksa null (cevapsız).
  final Map<String, int> _cevapSaniyesiMap = {};

  /// Kullanıcının son soruda seçtiği şık — reveal görselleri için.
  /// null = henüz seçmedi (veya süre doldu).
  String? _secilenCevap;

  /// Cevap tıklandığı andaki `kalanSure` — hızlı cevap daha fazla puan.
  /// null = henüz tıklamadı.
  int? _cevapKalanSure;

  /// Reveal fazı aktif mi? Aktifken şıklar tıklanamaz, timer durur.
  bool _revealAktif = false;

  /// Lobi sohbeti — oyun başlamadan önce odaki oyuncular mesajlaşır.
  /// Şema: {'isim': String, 'text': String, 'mine': bool, 'ts': int}
  final List<Map<String, dynamic>> _chatMesajlari = [];
  final TextEditingController _chatCtrl = TextEditingController();
  final ScrollController _chatScrollCtrl = ScrollController();
  Timer? _botChatZamanlayici;

  /// Lobiden oyuna geçiş geri sayımı. null = aktif değil, aksi halde
  /// gösterilecek tam sayı (3 → 2 → 1 → 0'da oyun başlar).
  int? _geriSayim;
  Timer? _geriSayimZamanlayici;

  /// Botların aralıklı atacağı kısa mock mesajlar.
  static const List<String> _botMesajHavuzu = <String>[
    'merhaba',
    'hadi başlayalım',
    'iyi şanslar herkese',
    'kolay gelsin',
    'hazırım',
    'lets go',
    'glhf',
    'bu set zor olacak',
    'çoktan hazırım',
    'bekleyelim biraz',
    'selam',
    'kim hazır?',
  ];

  // Odanın setId'sine göre çekilen kelime havuzu (DB'den async yüklenir).
  List<WordEntry> _havuz = const [];
  bool _havuzYukleniyor = true;

  // ── Animasyon state'leri ────────────────────────────────────────────────
  /// Floating puan popup: null = gizli, int = gösterilecek puan.
  int? _popupPuan;
  bool _popupGorunum = false;
  /// Reveal sonucu göstergesi (doğru / yanlış / cevapsız).
  String? _revealMesaj; // 'dogru' | 'yanlis' | null

  // ── Sonraki soru ön-hesaplama (reveal fazında hazırlanır) ───────────────
  QuestionModel? _sonrakiSoru;
  WordEntry? _sonrakiKelime;
  List<String>? _sonrakiSiklar;

  // Soru sırası: havuz karıştırılıp ilk _soruSayisi kadarı kullanılır — tekrar yok
  List<int> _soruSirasi = const [];
  int kacinciSoru = 0;
  int get toplamSoru =>
      _havuz.length < _soruSayisi ? _havuz.length : _soruSayisi;

  final _random = Random();

  @override
  void initState() {
    super.initState();
    // Faz 2/3: gerçek çok oyunculu mod tespiti
    _matchId     = widget.odaBilgisi['matchId'] as String?;
    _roomId      = widget.odaBilgisi['roomId']  as String?;
    _gercekCoklu = _matchId != null && _matchId!.isNotEmpty; // ignore: unnecessary_non_null_assertion
    // Faz 3: rooms.lua'dan gelen seed (tüm clientlerde deterministik soru sırası)
    _seed = (widget.odaBilgisi['seed'] as num?)?.toInt() ??
        _random.nextInt(0x7fffffff);

    final int kapasite = widget.odaBilgisi['kapasite'];

    if (_gercekCoklu) {
      // Gerçek çok oyunculu: sadece kendimizi ekle, diğerleri presence'tan gelir.
      oyuncular.add({'isim': 'Sen', 'puan': 0, 'hazir': false, 'sahip': true});
      _gercekOyuncular[NakamaService.instance.userId ?? ''] =
          AppSettings.kullaniciAdi;
      _lobiDinlemeBaslat();
      // Faz 4: beklenmedik soket kopuşunda yeniden bağlan
      NakamaService.instance.onSoketKapandi = _soketKoptu;
      // Host ise match'i oluştur (henüz oluşturulmamışsa) + odayı güncelle.
      isOdaSahibi = widget.odaBilgisi['hostId'] == NakamaService.instance.userId;
      // ignore: unnecessary_non_null_assertion
      if (isOdaSahibi && (_matchId == null || _matchId!.isEmpty)) {
        _matchOlusturVeGuncelle();
      }
    } else {
      // Bot modu (eski davranış)
      oyuncular.add({'isim': 'Sen', 'puan': 0, 'hazir': true, 'sahip': true});
      for (int i = 1; i < kapasite; i++) {
        oyuncular.add({'isim': 'Bot $i', 'puan': 0, 'hazir': true, 'sahip': false});
      }
      _botChatZamanlayici = Timer.periodic(
        Duration(milliseconds: 4000 + _random.nextInt(4000)),
        (_) => _botMesajiAt(),
      );
    }

    // Odanın setId + tier'ından kelime havuzunu DB'den çek — tekrar yok
    final String setId = (widget.odaBilgisi['setId'] as String?) ?? 'A';
    final String tier  = (widget.odaBilgisi['tier']  as String?) ?? '1K';
    _havuzuYukle(setId, tier);
  }

  // ── Faz 2: Lobi dinleme ───────────────────────────────────────────────────

  void _lobiDinlemeBaslat() {
    _presenceSub?.cancel();
    _dataSub?.cancel();
    _presenceSub = NakamaService.instance.onMatchPresence?.listen(_presenceGeldi);
    _dataSub     = NakamaService.instance.onMatchData?.listen(_lobiMesajiGeldi);
  }

  // ── Faz 4: Yeniden bağlanma ───────────────────────────────────────────────
  bool _yenidenBaglaniyor = false;

  /// Soket beklenmedik kapandığında çağrılır → maç bitmemişse rejoin dener.
  void _soketKoptu() {
    if (!mounted || _yenidenBaglaniyor) return;
    if (_macBitti) return; // maç zaten bittiyse uğraşma
    _yenidenBaglan();
  }

  Future<void> _yenidenBaglan() async {
    _yenidenBaglaniyor = true;
    final mid = _matchId ?? widget.odaBilgisi['matchId'] as String?;
    if (mid == null) { _yenidenBaglaniyor = false; return; }

    // 3 deneme, artan bekleme ile (Prensip 3: aşırı istek atma)
    for (int deneme = 1; deneme <= 3 && mounted && !_macBitti; deneme++) {
      debugPrint('[Game] yeniden bağlanma denemesi $deneme/3');
      final ok = await NakamaService.instance.soketYenidenBaglan();
      if (ok) {
        _lobiDinlemeBaslat();                        // yeni soket → yeni stream
        final joined = await NakamaService.instance.macaKatil(mid);
        if (joined != null) {
          debugPrint('[Game] yeniden bağlanıldı, RESYNC bekleniyor');
          _yenidenBaglaniyor = false;
          return;                                    // sunucu RESYNC gönderecek
        }
      }
      await Future.delayed(Duration(seconds: 2 * deneme));
    }
    _yenidenBaglaniyor = false;
  }

  void _presenceGeldi(MatchPresenceEvent event) {
    if (!mounted) return;
    setState(() {
      for (final p in event.joins) {
        if (p.userId == NakamaService.instance.userId) continue;
        _gercekOyuncular[p.userId] = p.username;
        final varMi = oyuncular.any((o) => o['userId'] == p.userId);
        if (!varMi) {
          oyuncular.add({
            'isim':   p.username,
            'userId': p.userId,
            'puan':   0,
            'hazir':  false,
            'sahip':  false,
          });
        }
      }
      for (final p in event.leaves) {
        oyuncular.removeWhere((o) => o['userId'] == p.userId);
        _gercekOyuncular.remove(p.userId);
      }
    });
  }

  void _lobiMesajiGeldi(MatchData msg) {
    if (!mounted) return;
    try {
      final data = jsonDecode(utf8.decode(msg.data ?? [])) as Map<String, dynamic>;

      switch (msg.opCode) {
        // ── Faz 2: lobi opcode'ları ───────────────────────────────────────
        case kOpHazirDegisti:
          final uid   = data['userId'] as String?;
          final hazir = data['hazir']  as bool? ?? false;
          setState(() {
            for (final o in oyuncular) {
              if (o['userId'] == uid) { o['hazir'] = hazir; break; }
            }
          });

        case kOpOyunBasliyor:
          // Faz 2 bot-mod uyumluluğu (sunucu Faz 3'te bu opcode'u göndermez)
          if (!_gercekCoklu) {
            final seed = (data['seed'] as num).toInt();
            _oyunuSeedileBaslat(seed);
          }

        // ── Faz 3: sunucu-güdümlü oyun opcode'ları ───────────────────────
        case kOpSoruGeldi:
          final qi = (data['qi'] as num).toInt();
          _serverSoruAc(qi);

        case kOpSayacGuncellendi:
          final sn = (data['sn'] as num).toInt();
          if (isOyunBasladi) {
            setState(() => kalanSure = sn);
          }

        case kOpReveal:
          final sonuclar = data['sonuclar'] as List<dynamic>? ?? [];
          _serverRevealIsle(sonuclar);

        case kOpSkorGuncellendi:
          final board = data['leaderboard'] as List<dynamic>? ?? [];
          _serverSkorGuncelle(board);

        case kOpMacBitti:
          final sirali = data['sirali'] as List<dynamic>? ?? [];
          _serverMacBitti(sirali);

        case kOpResync:
          _serverResync(data);
      }
    } catch (_) {}
  }

  // ── Faz 4: Yeniden bağlanınca sunucu durumunu uygula ──────────────────────
  void _serverResync(Map<String, dynamic> data) {
    if (!mounted) return;
    final phase = data['phase'] as String?;
    final qi    = (data['qi'] as num?)?.toInt() ?? 0;
    final sn    = (data['sn'] as num?)?.toInt() ?? 10;
    final board = data['leaderboard'] as List<dynamic>? ?? [];

    _serverSkorGuncelle(board); // skorları + bot/oyuncu listesini geri yükle

    if (phase == 'question') {
      // Aktif soruyu yeniden üret ve kalan süreyi ayarla
      if (aktifSoru == null || _aktifSoruIndex != qi) {
        _serverSoruAc(qi);
      }
      setState(() => kalanSure = sn);
    } else if (phase == 'reveal') {
      setState(() => _revealAktif = true);
    }
    debugPrint('[Game] resync uygulandı: phase=$phase qi=$qi sn=$sn');
  }

  // ── Faz 3: Sunucu soru indeksi → yerel soru üret ──────────────────────────
  void _serverSoruAc(int qi) {
    if (!mounted) return;
    if (_havuz.length < 5 || qi >= _soruSirasi.length) return;

    final word = _havuz[_soruSirasi[qi]];
    final yanlislar =
        (_havuz.where((w) => w.en != word.en).toList()..shuffle(_random))
            .take(4)
            .map((w) => w.en)
            .toList();
    if (yanlislar.length < 4) return;

    final soru = QuestionModel(
      desc:    word.desc,
      descTr:  word.descTr,
      answer:  word.en,
      wrong1:  yanlislar[0],
      wrong2:  yanlislar[1],
      wrong3:  yanlislar[2],
      wrong4:  yanlislar[3],
    );
    final siklar = List<String>.from(soru.allOptions)..shuffle(_random);

    _aktifSoruIndex = qi;
    kacinciSoru     = qi + 1;
    _macdaGorunenKelimeler.add(word);

    setState(() {
      aktifSoru      = soru;
      _aktifKelime   = word;
      mevcutSiklar   = siklar;
      kalanSure      = 10;
      isOyunBasladi  = true;  // ilk soruda oyun ekranına geç
      _secilenCevap  = null;
      _cevapKalanSure = null;
      _revealAktif   = false;
      _revealMesaj   = null;
      _popupGorunum  = false;
      _popupPuan     = null;
      for (final o in oyuncular) {
        o['secim']       = null;
        o['cevapSaniyesi'] = null;
        o['planSn']      = null;
        o['planSecim']   = null;
        o['planDogru']   = null;
      }
    });
  }

  // ── Faz 3: Sunucu reveal sonuçlarını uygula ───────────────────────────────
  void _serverRevealIsle(List<dynamic> sonuclar) {
    if (!mounted) return;
    final myId = NakamaService.instance.userId;

    for (final s in sonuclar) {
      final uid       = s['userId']   as String?;
      final totalPuan = (s['totalPuan'] as num?)?.toInt() ?? 0;
      final dogru     = s['dogru']    as bool? ?? false;
      final qPuan     = (s['puan']    as num?)?.toInt() ?? 0;

      // Leaderboard'u güncelle (bot satırı yoksa ekler)
      final orow = _oyuncuBulVeyaEkle(uid, null);
      if (orow != null && orow.isNotEmpty) orow['puan'] = totalPuan;

      // "Sen"in sonucunu reveal UI'a yansıt
      if (uid == myId && _secilenCevap != null) {
        if (_aktifKelime != null) {
          _cevapDurumu[_aktifKelime!.wordId] = dogru;
        }
        setState(() {
          _revealMesaj = dogru ? 'dogru' : 'yanlis';
          if (dogru) {
            _popupPuan     = qPuan;
            _popupGorunum  = true;
          }
        });
        if (dogru) {
          AppSettings.sesDogru();
          Future.delayed(const Duration(milliseconds: 1400), () {
            if (mounted) setState(() => _popupGorunum = false);
          });
          // Kelime sahiplenme hâlâ client-side (Faz 5'te sunucuya taşınır)
          final word = _aktifKelime;
          if (word != null) {
            OwnershipEngine.claimDuelWord(
              setId: word.setId, rank: word.rank, playerId: 'Sen',
            ).then((result) {
              if (!mounted || !result.claimed) return;
              setState(() => _kazanilanKelimeler.add(word));
            });
          }
        } else {
          AppSettings.sesYanlis();
          setState(() => _revealMesaj = 'yanlis');
        }
      }
    }

    // Reveal fazını başlat; sunucu 2sn sonra SORU_GELDI gönderir
    _revealBaslat();
  }

  /// Leaderboard girişine karşılık gelen oyuncu satırını bulur; yoksa
  /// (sunucu botu veya sonradan katılan) yeni satır ekler. Faz 4.
  Map<String, dynamic>? _oyuncuBulVeyaEkle(String? uid, String? isim) {
    if (uid == null) return null;
    final myId = NakamaService.instance.userId;
    if (uid == myId) {
      return oyuncular.firstWhere((o) => o['isim'] == 'Sen',
          orElse: () => oyuncular.isNotEmpty ? oyuncular.first : <String, dynamic>{});
    }
    for (final o in oyuncular) {
      if (o['userId'] == uid) return o;
    }
    // Bilinmeyen → sunucu botu / geç katılan oyuncu: ekle
    final yeni = {
      'isim':  isim ?? 'Oyuncu',
      'userId': uid,
      'puan':  0,
      'hazir': true,
      'sahip': false,
    };
    oyuncular.add(yeni);
    return yeni;
  }

  // ── Faz 3/4: Sunucu leaderboard'unu uygula (botlar dahil) ────────────────
  void _serverSkorGuncelle(List<dynamic> board) {
    if (!mounted) return;
    setState(() {
      for (final entry in board) {
        final uid  = entry['userId'] as String?;
        final puan = (entry['puan'] as num?)?.toInt() ?? 0;
        final isim = entry['isim'] as String?;
        final o = _oyuncuBulVeyaEkle(uid, isim);
        if (o != null && o.isNotEmpty) {
          o['puan'] = puan;
          if (isim != null && o['isim'] != 'Sen') o['isim'] = isim;
        }
      }
    });
  }

  // ── Faz 3: Maç bitti → ResultScreen'e geç ────────────────────────────────
  void _serverMacBitti(List<dynamic> sirali) {
    if (!mounted) return;
    _macBitti = true;
    _zamanlayici?.cancel();

    // Sunucu sıralamasından oyuncu listesini yeniden kur
    final List<Map<String, dynamic>> finalPlayers = [];
    int? benimSira;
    final myId = NakamaService.instance.userId;

    for (final s in sirali) {
      final uid  = s['userId'] as String?;
      final isim = s['isim']   as String? ?? 'Oyuncu';
      final puan = (s['puan']  as num?)?.toInt() ?? 0;
      final sira = (s['sira']  as num?)?.toInt() ?? 0;
      final benMiyim = uid == myId;
      finalPlayers.add({
        'isim':  benMiyim ? AppSettings.kullaniciAdi : isim,
        'puan':  puan,
        'hazir': true,
        'sahip': benMiyim,
        if (uid != null) 'userId': uid,
      });
      if (benMiyim) benimSira = sira;
    }

    // Profil sayaçlarını güncelle (hâlâ client-side)
    if (benimSira != null) {
      AppSettings.recordMatchResult(
          MatchScoring.isWin(benimSira, finalPlayers.length));
    }
    OwnershipDb.saveMatch(
      setId:       widget.odaBilgisi['setId'] as String,
      tier:        widget.odaBilgisi['tier']  as String,
      position:    benimSira ?? finalPlayers.length,
      playerCount: finalPlayers.length,
      words: _macdaGorunenKelimeler.map((w) => MatchWordResult(
        wordId:        w.wordId,
        en:            w.en,
        tr:            w.tr,
        desc:          w.desc,
        descTr:        w.descTr,
        rarity:        w.rarity,
        correct:       _cevapDurumu[w.wordId],
        cevapSaniyesi: _cevapSaniyesiMap[w.wordId],
      )).toList(),
    );
    AppSettings.matchSavedNotifier.value++;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          players:            List<Map<String, dynamic>>.from(finalPlayers),
          odaSetId:           widget.odaBilgisi['setId'] as String,
          odaTier:            widget.odaBilgisi['tier']  as String,
          kazanilanKelimeler: List<WordEntry>.from(_kazanilanKelimeler),
        ),
      ),
    );
  }

  Future<void> _matchOlusturVeGuncelle() async {
    final mid = await NakamaService.instance.macOlustur();
    if (mid == null || !mounted) return;
    // odaBilgisi matchId'yi güncelle ki diğerleri katılabilsin
    widget.odaBilgisi['matchId'] = mid;
    final rid = _roomId ?? widget.odaBilgisi['roomId'] as String?;
    if (rid != null) {
      await NakamaService.instance.odaGuncelle(
        roomId: rid, dolu: oyuncular.length, matchId: mid,
      );
    }
    debugPrint('[Game] match oluşturuldu: $mid');
  }

  void _oyunuSeedileBaslat(int seed) {
    // İdempotency guard — çift-tık veya çift mesaj aynı oyunu iki kez başlatmasın.
    if (_oyunBaslatildi) return;
    _oyunBaslatildi = true;

    // Gelen seed ile soruları karıştır — tüm oyuncularda aynı sıra
    _soruSirasi = List.generate(_havuz.length, (i) => i)
        ..shuffle(Random(seed));
    // Boş slotları botlarla doldur (oyun mekaniği için gerekli)
    final kapasite = widget.odaBilgisi['kapasite'] as int;
    int botNo = 1;
    while (oyuncular.length < kapasite) {
      while (_banliIsimler.contains('Bot $botNo')) { botNo++; }
      oyuncular.add({'isim': 'Bot $botNo', 'puan': 0, 'hazir': true, 'sahip': false});
      botNo++;
    }
    _geriSayimBaslat();
  }

  /// Tier → rank üst sınırı (rank < cap). '1K' setin tamamını açar.
  static int _tierRankCap(String tier) {
    switch (tier) {
      case '100': return 100;
      case '250': return 250;
      case '500': return 500;
      default:    return 1000; // '1K' veya bilinmeyen → tamamı
    }
  }

  Future<void> _havuzuYukle(String setId, String tier) async {
    final words = await DatabaseHelper.getWordsBySetIdCapped(
      setId, _tierRankCap(tier),
    );
    if (!mounted) return;
    setState(() {
      _havuz = words;
      // Faz 3: gerçek çok oyunculu modda sunucu seed'ini kullan (tüm clientler
      // aynı soru sırasını üretir). Bot modunda rastgele karıştır.
      _soruSirasi = List.generate(_havuz.length, (i) => i)
        ..shuffle(_gercekCoklu ? Random(_seed) : _random);
      _havuzYukleniyor = false;
    });
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    _botChatZamanlayici?.cancel();
    _geriSayimZamanlayici?.cancel();
    _chatCtrl.dispose();
    _chatScrollCtrl.dispose();
    _presenceSub?.cancel();
    _dataSub?.cancel();
    // Gerçek çok oyunculu: maçtan ayrıl + odayı temizle
    if (_gercekCoklu) {
      // Faz 4: callback'i temizle ki kasıtlı kapanış rejoin tetiklemesin
      NakamaService.instance.onSoketKapandi = null;
      final mid = _matchId ?? widget.odaBilgisi['matchId'] as String?;
      final rid = _roomId  ?? widget.odaBilgisi['roomId']  as String?;
      if (mid != null) NakamaService.instance.macBirak(mid);
      if (rid != null && isOdaSahibi) NakamaService.instance.odaSil(rid);
    }
    super.dispose();
  }

  // 3sn cap: cevap saniyesi (tıklama anı kalanSure) > 3 → sn puan (4-10);
  // ≤ 3 → 3 puan sabit. Hem Sen hem botlar için.
  int _puanHesapla(int sn) => sn > 3 ? sn : 3;

  // Soru başında her bot için karar verir: cevap verecek mi (planSn null
  // → timeout) yoksa hangi saniyede ve hangi şıkka tıklayacak. UI'da
  // henüz hiçbir şey gösterilmez — secim/cevapSaniyesi null kalır,
  // tick'lerde `_botlariniAcikla` ile açığa çıkarılır.
  void _botlariniPlanla() {
    final dogru = aktifSoru?.answer;
    if (dogru == null) return;
    final yanlislar = mevcutSiklar.where((s) => s != dogru).toList();
    for (final oyuncu in oyuncular) {
      if (oyuncu['isim'] == 'Sen') continue;
      final cevapVerecek = _random.nextDouble() < 0.85;
      if (!cevapVerecek) {
        oyuncu['planSn'] = null;
        oyuncu['planSecim'] = null;
        oyuncu['planDogru'] = null;
        continue;
      }
      final dogruBilecek = _random.nextDouble() < 0.70;
      final secim = dogruBilecek
          ? dogru
          : (yanlislar.isEmpty
              ? dogru
              : yanlislar[_random.nextInt(yanlislar.length)]);
      // planSn 1-9: tick'lerle hizalı; ilk tick (kalanSure 10→9) en hızlı.
      oyuncu['planSn'] = _random.nextInt(_soruSuresi - 1) + 1;
      oyuncu['planSecim'] = secim;
      oyuncu['planDogru'] = dogruBilecek;
    }
  }

  // Timer her tick'te çağırır. Plan'ı `kalanSure`'ye eşit olan botların
  // sadece secim/cevapSaniyesi'ni set'ler (avatar canlı görünsün diye).
  // Puan ekleme `_yargila`'da reveal anında toplu yapılır.
  void _botlariniAcikla(int sn) {
    for (final o in oyuncular) {
      if (o['isim'] == 'Sen') continue;
      if (o['secim'] != null) continue;
      if (o['planSn'] == sn) {
        o['secim'] = o['planSecim'];
        o['cevapSaniyesi'] = sn;
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
              benMiyim ? AppSettings.kullaniciAdi : oyuncu['isim'] as String,
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
    if (!_gercekCoklu && oyuncular.length < kapasite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Oda tam dolmadan oyun başlatılamaz!")),
      );
      return;
    }
    if (!oyuncular.every((o) => o['hazir'] == true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Herkes hazır olmadan oyun başlatılamaz!")),
      );
      return;
    }
    if (_havuzYukleniyor || _havuz.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kelime havuzu hâlâ yükleniyor...")),
      );
      return;
    }
    AppSettings.heavyImpact();
    _botChatZamanlayici?.cancel();

    if (_gercekCoklu) {
      // Faz 3: sunucu başlatır. "Başlat" butonu host'u hazır yapar.
      // Tüm oyuncular hazır olunca sunucu countdown → SORU_GELDI gönderir.
      setState(() {
        isBenHazirim = true;
        oyuncular.firstWhere((o) => o['isim'] == 'Sen')['hazir'] = true;
      });
      final mid = _matchId ?? widget.odaBilgisi['matchId'] as String?;
      if (mid != null) NakamaService.instance.hazirMesajiGonder(mid, true);
    } else {
      _geriSayimBaslat();
    }
  }

  /// "OYUNU BAŞLAT" sonrası ani geçişi yumuşatır: 3 → 2 → 1 göster, sonra
  /// `_geriSayimBitti()` ile gerçek oyun başlasın.
  void _geriSayimBaslat() {
    if (_geriSayim != null) return; // çift tıklama koruması
    setState(() => _geriSayim = 3);
    AppSettings.selectionClick();
    _geriSayimZamanlayici = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = (_geriSayim ?? 0) - 1;
      if (next <= 0) {
        _geriSayimZamanlayici?.cancel();
        _geriSayimBitti();
      } else {
        AppSettings.selectionClick();
        setState(() => _geriSayim = next);
      }
    });
  }

  void _geriSayimBitti() {
    AppSettings.heavyImpact();
    setState(() {
      _geriSayim = null;
      isOyunBasladi = true;
    });
    _yeniSoruHazirla();
  }

  void _yeniSoruHazirla() {
    // Havuz çok küçükse (< 5) yanlış şık üretilemez → güvenli çıkış.
    if (_havuz.length < 5) {
      _zamanlayici?.cancel();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Bu tier/set kombinasyonunda yeterli kelime yok (en az 5 gerekli).'),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
      return;
    }
    if (kacinciSoru >= toplamSoru) {
      _zamanlayici?.cancel();
      oyuncular.sort((a, b) => (b['puan'] as int).compareTo(a['puan'] as int));
      // "Sen"in sıralaması (1-tabanlı). Profil sayaçlarını güncelle.
      final benimSira =
          oyuncular.indexWhere((o) => o['isim'] == 'Sen') + 1;
      if (benimSira >= 1) {
        AppSettings.recordMatchResult(
          MatchScoring.isWin(benimSira, oyuncular.length),
        );
      }
      // Maç geçmişini kaydet (fire-and-forget) + ProfilePanel'i uyar.
      OwnershipDb.saveMatch(
        setId:       widget.odaBilgisi['setId'] as String,
        tier:        widget.odaBilgisi['tier']  as String,
        position:    benimSira,
        playerCount: oyuncular.length,
        words:       _macdaGorunenKelimeler.map((w) => MatchWordResult(
          wordId:        w.wordId,
          en:            w.en,
          tr:            w.tr,
          desc:          w.desc,
          descTr:        w.descTr,
          rarity:        w.rarity,
          correct:       _cevapDurumu[w.wordId],
          cevapSaniyesi: _cevapSaniyesiMap[w.wordId],
        )).toList(),
      );
      AppSettings.matchSavedNotifier.value++; // ProfilePanel'i uyar
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            players: List<Map<String, dynamic>>.from(oyuncular),
            odaSetId: widget.odaBilgisi['setId'] as String,
            odaTier: widget.odaBilgisi['tier'] as String,
            kazanilanKelimeler: List<WordEntry>.from(_kazanilanKelimeler),
          ),
        ),
      );
      return;
    }

    // Ön-hesaplanmış soru varsa kullan (reveal fazında hazırlandı → sıfır gecikme).
    final WordEntry word;
    final QuestionModel soru;
    final List<String> siklar;

    if (_sonrakiSoru != null && _sonrakiKelime != null && _sonrakiSiklar != null) {
      word   = _sonrakiKelime!;
      soru   = _sonrakiSoru!;
      siklar = _sonrakiSiklar!;
      _sonrakiSoru   = null;
      _sonrakiKelime = null;
      _sonrakiSiklar = null;
    } else {
      // Ön-hesaplama yoksa (ilk soru veya hızlı geçiş) anında hesapla.
      word = _havuz[_soruSirasi[kacinciSoru]];
      final yanlislar =
          (_havuz.where((w) => w.en != word.en).toList()..shuffle(_random))
              .take(4)
              .map((w) => w.en)
              .toList();
      soru = QuestionModel(
        desc: word.desc,
        descTr: word.descTr,
        answer: word.en,
        wrong1: yanlislar[0],
        wrong2: yanlislar[1],
        wrong3: yanlislar[2],
        wrong4: yanlislar[3],
      );
      siklar = List<String>.from(soru.allOptions)..shuffle(_random);
    }

    kacinciSoru++;
    _macdaGorunenKelimeler.add(word); // geçmiş kaydı için

    setState(() {
      aktifSoru = soru;
      _aktifKelime = word;
      mevcutSiklar = siklar;
      kalanSure = _soruSuresi;
      _secilenCevap = null;
      _cevapKalanSure = null;
      _revealAktif = false;
      _revealMesaj = null;
      _popupGorunum = false;
      _popupPuan = null;
      for (final o in oyuncular) {
        o['secim'] = null;
        o['cevapSaniyesi'] = null;
        o['planSn'] = null;
        o['planSecim'] = null;
        o['planDogru'] = null;
      }
    });
    _botlariniPlanla();

    _zamanlayici?.cancel();
    _zamanlayici = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (kalanSure > 0) {
        setState(() {
          kalanSure--;
          _botlariniAcikla(kalanSure);
        });
        if (_herkesCevapladi()) {
          AppSettings.heavyImpact();
          _yargila();
        }
      } else {
        AppSettings.heavyImpact();
        _yargila();
      }
    });
  }

  /// Erken ilerleme kontrolü: Sen tıkladıysa ve her bot ya cevap verdiyse
  /// (secim != null) ya timeout'luysa (planSn == null), true döner.
  /// Sen tıklamadıysa daima false — spoiler/şüphe sızıntısı yok.
  bool _herkesCevapladi() {
    if (_secilenCevap == null) return false;
    for (final o in oyuncular) {
      if (o['isim'] == 'Sen') continue;
      final acilmis = o['secim'] != null;
      final timeoutBot = o['planSn'] == null;
      if (!acilmis && !timeoutBot) return false;
    }
    return true;
  }

  /// Reveal fazını başlatır.
  /// Bot modunda 2sn sonra _yeniSoruHazirla çağrılır.
  /// Gerçek modda (Faz 3) sonraki soruyu sunucu kOpSoruGeldi ile tetikler.
  void _revealBaslat() {
    if (_revealAktif) return;
    _zamanlayici?.cancel();
    setState(() => _revealAktif = true);
    if (_gercekCoklu) return; // sunucu SORU_GELDI → _serverSoruAc ile çıkış
    _sonrakiSoruHazirla(); // bot modunda ön-hesapla
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _yeniSoruHazirla();
    });
  }

  /// Reveal fazında arka planda bir sonraki soruyu hazırlar.
  void _sonrakiSoruHazirla() {
    if (kacinciSoru >= toplamSoru) return;
    final word = _havuz[_soruSirasi[kacinciSoru]];
    final yanlislar =
        (_havuz.where((w) => w.en != word.en).toList()..shuffle(_random))
            .take(4)
            .map((w) => w.en)
            .toList();
    if (yanlislar.length < 4) return; // havuz küçükse ön-hesaplama atla
    _sonrakiSoru = QuestionModel(
      desc: word.desc,
      descTr: word.descTr,
      answer: word.en,
      wrong1: yanlislar[0],
      wrong2: yanlislar[1],
      wrong3: yanlislar[2],
      wrong4: yanlislar[3],
    );
    _sonrakiKelime = word;
    _sonrakiSiklar = List<String>.from(_sonrakiSoru!.allOptions)..shuffle(_random);
  }

  /// Kullanıcı bir şıkka tıkladığında: sadece seçim kaydedilir. Doğru/yanlış
  /// reveal, puan ekleme, claim ve snackbar — hepsi timer 0'a düştüğünde
  /// `_yargila()` içinde gerçekleşir.
  void _cevapKontrol(String secilenCevap) {
    if (!isOyunBasladi || _revealAktif || aktifSoru == null) return;
    if (_secilenCevap != null) return; // çift tap koruması
    AppSettings.mediumImpact();
    final bool dogru = secilenCevap == aktifSoru!.answer;
    setState(() {
      _secilenCevap   = secilenCevap;
      _cevapKalanSure = kalanSure;
      final ben = oyuncular.firstWhere((o) => o['isim'] == 'Sen');
      ben['secim']       = secilenCevap;
      ben['cevapSaniyesi'] = kalanSure;
    });
    if (_gercekCoklu) {
      // Faz 3: cevabı sunucuya gönder — sunucu skoru hesaplar
      final mid = _matchId ?? widget.odaBilgisi['matchId'] as String?;
      if (mid != null) {
        NakamaService.instance.cevapGonder(mid, _aktifSoruIndex, dogru);
      }
      // Maç geçmişi için yerel kayıt (cevap saniyesi)
      if (_aktifKelime != null) {
        _cevapSaniyesiMap[_aktifKelime!.wordId] = kalanSure;
      }
    }
  }

  /// Timer 0 anında soruyu sonuçlandırır: doğru ise puan + claim + snackbar,
  /// yanlış ise snackbar; ardından reveal fazını başlatır.
  void _yargila() {
    if (_revealAktif || aktifSoru == null) return;
    final String? secilen = _secilenCevap;
    final String dogru = aktifSoru!.answer;

    // Cevap durumu + cevap saniyesini geçmiş kaydı için sakla (tıklandıysa).
    if (_aktifKelime != null && secilen != null) {
      _cevapDurumu[_aktifKelime!.wordId] = secilen == dogru;
      if (_cevapKalanSure != null) {
        _cevapSaniyesiMap[_aktifKelime!.wordId] = _cevapKalanSure!;
      }
    }

    // Sen'in seçimi `_cevapKontrol`'de, botlarınki tick'lerde yazıldı.
    // Burada sadece puan/claim/snackbar mantığı.

    if (secilen != null && secilen == dogru) {
      AppSettings.sesDogru();
      final int sn = _cevapKalanSure ?? 0;
      final int kazanilanPuan = _puanHesapla(sn);
      setState(() {
        final benimOyuncu = oyuncular.firstWhere((o) => o['isim'] == 'Sen');
        benimOyuncu['puan'] = (benimOyuncu['puan'] as int) + kazanilanPuan;
        _revealMesaj = 'dogru';
        _popupPuan = kazanilanPuan;
        _popupGorunum = true;
      });
      // Popup 1.4sn sonra kaybolur
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _popupGorunum = false);
      });
      final word = _aktifKelime;
      if (word != null) {
        OwnershipEngine.claimDuelWord(
          setId: word.setId,
          rank: word.rank,
          playerId: 'Sen',
        ).then((result) {
          if (!mounted || !result.claimed) return;
          setState(() => _kazanilanKelimeler.add(word));
        });
      }
    } else if (secilen != null) {
      AppSettings.sesYanlis();
      setState(() => _revealMesaj = 'yanlis');
    }
    // secilen == null → cevapsız; sadece reveal.

    // Botların puanlarını reveal anında topluca yaz — leaderboard tek
    // seferde oturur, planSn tick'lerinde sızıntı olmaz.
    setState(() {
      for (final o in oyuncular) {
        if (o['isim'] == 'Sen') continue;
        if (o['planDogru'] == true && o['planSn'] != null) {
          final int sn = o['planSn'] as int;
          o['puan'] = (o['puan'] as int) + _puanHesapla(sn);
        }
      }
    });

    _revealBaslat();
  }

  // ─── Lobi sohbeti ────────────────────────────────────────────────────────

  void _botMesajiAt() {
    if (!mounted || isOyunBasladi) return;
    // %40 ihtimalle bu tick'te kimse konuşmaz — doğal duraksamalar.
    if (_random.nextDouble() < 0.4) return;
    final botlar = oyuncular.where((o) => o['isim'] != 'Sen').toList();
    if (botlar.isEmpty) return;
    final bot = botlar[_random.nextInt(botlar.length)];
    final mesaj = _botMesajHavuzu[_random.nextInt(_botMesajHavuzu.length)];
    setState(() {
      _chatMesajlari.add({
        'isim': bot['isim'],
        'text': mesaj,
        'mine': false,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    });
    _chatScrolleAlta();
  }

  void _benMesajGonder() {
    final t = _chatCtrl.text.trim();
    if (t.isEmpty || isOyunBasladi) return;
    AppSettings.mediumImpact();
    setState(() {
      _chatMesajlari.add({
        'isim': 'Sen',
        'text': t,
        'mine': true,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      _chatCtrl.clear();
    });
    _chatScrolleAlta();
  }

  void _chatScrolleAlta() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chatScrollCtrl.hasClients) return;
      _chatScrollCtrl.animateTo(
        _chatScrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
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
                        "${widget.odaBilgisi['setId']} • ${widget.odaBilgisi['tier']} ODA",
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
                child: Stack(
                  children: [
                    SizedBox.expand(
                      child: _geriSayim != null
                          ? _geriSayimEkrani()
                          : !isOyunBasladi
                              ? _lobiSohbeti()
                              : (aktifSoru != null && _aktifKelime != null)
                                  // Geçiş efekti yok → soru anında değişir,
                                  // kasma sıfır (iki kart üst üste gelmez).
                                  ? RarityQuestionCard(
                                      rarity: _aktifKelime!.rarity,
                                      questionText: aktifSoru!.desc,
                                      timerSeconds: kalanSure,
                                      hintText: kalanSure <= 5
                                          ? aktifSoru!.descTr
                                          : null,
                                    )
                                  : _bekleniyorKarti(),
                    ),
                    // ── Floating puan popup ────────────────────────────
                    if (_popupPuan != null)
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        // Yükselme Transform tabanlı (AnimatedSlide) → layout yok.
                        child: AnimatedSlide(
                          offset: _popupGorunum
                              ? Offset.zero
                              : const Offset(0, 0.4),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 400),
                          opacity: _popupGorunum ? 1.0 : 0.0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.greenAccent.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Text(
                                '+$_popupPuan Puan',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ),
                      ),
                    // ── Inline reveal mesajı ──────────────────────────
                    if (_revealMesaj == 'yanlis')
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.kirmizi.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'YANLIŞ',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
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
              child: _geriSayim != null
                  ? const SizedBox(
                      width: double.infinity,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 22),
                          child: Text(
                            'Oyun başlıyor...',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    )
                  : !isOyunBasladi
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
                              // Gerçek çok oyunculu: 400ms throttle ile hazır mesajı gönder
                              if (_gercekCoklu) {
                                final now = DateTime.now();
                                final son = _sonHazirGonderim;
                                if (son == null ||
                                    now.difference(son).inMilliseconds >= 400) {
                                  _sonHazirGonderim = now;
                                  final mid = _matchId ??
                                      widget.odaBilgisi['matchId'] as String?;
                                  if (mid != null) {
                                    NakamaService.instance.hazirMesajiGonder(
                                        mid, isBenHazirim);
                                  }
                                }
                              }
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

  Widget _bekleniyorKarti() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.yuzey,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12, width: 2),
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.access_time_rounded, color: Colors.white38, size: 36),
        SizedBox(height: 10),
        Text(
          "Oyuncular\nBekleniyor",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );

  Widget _geriSayimEkrani() => Container(
    decoration: BoxDecoration(
      color: AppColors.yuzey,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.cyan.withValues(alpha: 0.3),
        width: 2,
      ),
    ),
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'OYUN BAŞLIYOR',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            key: ValueKey(_geriSayim),
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Text(
              '${_geriSayim ?? ''}',
              style: TextStyle(
                color: AppColors.cyan,
                fontSize: 120,
                fontWeight: FontWeight.w900,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: AppColors.cyan.withValues(alpha: 0.45),
                    blurRadius: 32,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hazır ol...',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _lobiSohbeti() => Container(
    decoration: BoxDecoration(
      color: AppColors.yuzey,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12, width: 2),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.cyan.withValues(alpha: 0.8),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'ODA SOHBETİ',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.hourglass_top_rounded,
                color: Colors.white24,
                size: 14,
              ),
              const SizedBox(width: 4),
              const Text(
                'Oyuncular Bekleniyor',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white12, height: 1),
        Expanded(
          child: _chatMesajlari.isEmpty
              ? Center(
                  child: Text(
                    'Henüz mesaj yok.\nİlk yazan sen ol!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _chatScrollCtrl,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  itemCount: _chatMesajlari.length,
                  itemBuilder: (context, i) {
                    final m = _chatMesajlari[i];
                    return _chatBalonu(
                      isim: m['isim'] as String,
                      text: m['text'] as String,
                      mine: m['mine'] as bool,
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _benMesajGonder(),
                  maxLength: 120,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Mesaj yaz...',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.koyuYuzey,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: AppColors.cyan.withValues(alpha: 0.15),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _benMesajGonder,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.send_rounded,
                      color: AppColors.cyan,
                      size: 20,
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

  Widget _chatBalonu({
    required String isim,
    required String text,
    required bool mine,
  }) {
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = mine
        ? AppColors.cyan.withValues(alpha: 0.18)
        : AppColors.koyuYuzey;
    final borderColor = mine
        ? AppColors.cyan.withValues(alpha: 0.35)
        : Colors.white12;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 2),
              child: Text(
                isim,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cevapSikki(String metin) {
    final bool dogruMu = _revealAktif && metin == aktifSoru?.answer;
    final bool kullanicininYanlisi = _revealAktif &&
        metin == _secilenCevap &&
        metin != aktifSoru?.answer;
    // Cevap işaretlendi ama timer henüz dolmadı — nötr cyan vurgu.
    final bool seciliBekliyor = !_revealAktif && metin == _secilenCevap;

    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    if (dogruMu) {
      bgColor = Colors.greenAccent.withValues(alpha: 0.18);
      borderColor = Colors.greenAccent;
      textColor = Colors.greenAccent;
    } else if (kullanicininYanlisi) {
      bgColor = AppColors.kirmizi.withValues(alpha: 0.18);
      borderColor = AppColors.kirmizi;
      textColor = AppColors.kirmizi;
    } else if (seciliBekliyor) {
      bgColor = AppColors.cyan.withValues(alpha: 0.12);
      borderColor = AppColors.cyan;
      textColor = AppColors.cyan;
    } else {
      bgColor = AppColors.yuzey;
      borderColor = Colors.white12;
      textColor = Colors.white;
    }

    final bool tikSiklarKilitli = _revealAktif || _secilenCevap != null;
    // Canlı oyunda spoiler guard: Sen tıklamadan önce kimsenin seçimi
    // görünmez. Reveal'de (soru bitti) Sen tıklamasan bile herkes görünür.
    final bool secimleriGoster = _secilenCevap != null || _revealAktif;
    final List<Map<String, dynamic>> seciler = secimleriGoster
        ? oyuncular.where((o) => o['secim'] == metin).toList()
        : const [];
    return _TapScale(
      disabled: tikSiklarKilitli,
      onTap: () => _cevapKontrol(metin),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: borderColor,
                width:
                    (dogruMu || kullanicininYanlisi || seciliBekliyor) ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                metin,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          if (seciler.isNotEmpty)
            Positioned(
              top: -12, // avatar yarısı kutunun üst çizgisinin üstünde
              right: 10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final o in seciler)
                    TweenAnimationBuilder<double>(
                      key: ValueKey('${o['isim']}_$metin'),
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.elasticOut,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: _miniAvatarSecim(o),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniAvatarSecim(Map<String, dynamic> o) {
    final benMiyim = o['isim'] == 'Sen';
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: benMiyim ? AppColors.sari : Colors.white38,
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: 9,
          backgroundColor: AppColors.arkaPlan,
          child: Icon(
            Icons.person,
            size: 12,
            color: benMiyim ? AppColors.sari : Colors.white70,
          ),
        ),
      ),
    );
  }
}

/// Tıklandığında hafifçe küçülen (0.94×) basılma hissi veren widget.
class _TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool disabled;

  const _TapScale({
    required this.child,
    required this.onTap,
    this.disabled = false,
  });

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _basili = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.disabled ? null : widget.onTap,
      onTapDown: widget.disabled ? null : (_) => setState(() => _basili = true),
      onTapUp: widget.disabled ? null : (_) => setState(() => _basili = false),
      onTapCancel: widget.disabled ? null : () => setState(() => _basili = false),
      child: AnimatedScale(
        scale: _basili ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
