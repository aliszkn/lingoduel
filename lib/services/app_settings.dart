import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama ayarları + titreşim wrapper.
///
/// Kullanım:
/// - main()'de `await AppSettings.init()` çağrılmalı.
/// - Haptik için `HapticFeedback.X()` yerine `AppSettings.X()` kullan;
///   titreşim ayarı kapalıysa hiçbir şey yapmaz.
class AppSettings {
  static const _kSfx = 'sfx_acik';
  static const _kMuzik = 'muzik_acik';
  static const _kTitresim = 'titresim_acik';
  static const _kDuelloDavet = 'duello_davetleri_acik';
  static const _kMesajBildirim = 'mesaj_bildirimleri_acik';
  static const _kPlayerLP           = 'player_lp';
  static const _kSoftStartCompleted = 'soft_start_completed';
  static const _kToplamMac          = 'toplam_mac';
  static const _kKazanilanMac       = 'kazanilan_mac';
  static const _kKazanmaSerisi      = 'kazanma_serisi';
  static const _kKullaniciAdi      = 'kullanici_adi';

  /// Bir maç kaydedildiğinde value artırılır.
  /// ProfilePanel bunu dinleyip geçmişi otomatik yeniler.
  static final matchSavedNotifier = ValueNotifier<int>(0);

  static late SharedPreferences _prefs;

  // Senkron erişim için cache'lenmiş değerler (varsayılan + load sonrası gerçek).
  static bool sfxAcik = true;
  static bool muzikAcik = false;
  static bool titresimAcik = true;
  static bool duelloDavetleriAcik = true;
  static bool mesajBildirimleriAcik = true;

  /// Oyuncunun lig puanı (LP). Hiçbir zaman 0'ın altına düşmez.
  static int playerLP = 0;

  /// Oyuncu en az bir kez 250 LP'ye ulaştıysa true.
  /// Bu nokta geçildiğinde A-grubu soft start kalıcı olarak biter.
  static bool softStartCompleted = false;

  /// Tamamlanmış toplam maç sayısı (Profil ekranında "Toplam Maç" karşılığı).
  static int toplamMac = 0;

  /// Kazanılan maç sayısı — sıralama 1, 2 veya 3 ise kazanım sayılır.
  static int kazanilanMac = 0;

  /// Üst üste galibiyet sayısı. Galibiyette artar, kayıpta sıfırlanır.
  static int kazanmaSerisi = 0;

  /// Profil ekranında ve oyun kartında görünen kullanıcı adı.
  static String kullaniciAdi = 'LingoUstası99';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    sfxAcik = _prefs.getBool(_kSfx) ?? true;
    muzikAcik = _prefs.getBool(_kMuzik) ?? false;
    titresimAcik = _prefs.getBool(_kTitresim) ?? true;
    duelloDavetleriAcik = _prefs.getBool(_kDuelloDavet) ?? true;
    mesajBildirimleriAcik = _prefs.getBool(_kMesajBildirim) ?? true;
    playerLP          = _prefs.getInt(_kPlayerLP) ?? 0;
    softStartCompleted = _prefs.getBool(_kSoftStartCompleted) ?? false;
    toplamMac          = _prefs.getInt(_kToplamMac) ?? 0;
    kazanilanMac       = _prefs.getInt(_kKazanilanMac) ?? 0;
    kazanmaSerisi      = _prefs.getInt(_kKazanmaSerisi) ?? 0;
    kullaniciAdi       = _prefs.getString(_kKullaniciAdi) ?? 'LingoUstası99';
  }

  /// Maç sonunda çağrılır. [won] galibiyet yarısında (üst yarı) bitirildiyse true.
  /// Galibiyette kazanma serisi artar, kayıpta sıfırlanır.
  /// Sayaçlar diskte güncellenir.
  static Future<void> recordMatchResult(bool won) async {
    toplamMac += 1;
    if (won) {
      kazanilanMac += 1;
      kazanmaSerisi += 1;
    } else {
      kazanmaSerisi = 0;
    }
    await _prefs.setInt(_kToplamMac, toplamMac);
    await _prefs.setInt(_kKazanilanMac, kazanilanMac);
    await _prefs.setInt(_kKazanmaSerisi, kazanmaSerisi);
  }

  /// 0-100 aralığında kazanma oranı; hiç maç yoksa null döner.
  static double? get kazanmaOraniYuzde =>
      toplamMac == 0 ? null : (kazanilanMac / toplamMac) * 100;

  /// Üst üste galibiyet bonusu (LP). İlk galibiyet (seri=1) bonussuz;
  /// 2. galibiyet +2, 3. +3, …, n. +n.
  static int get seriBonusu => kazanmaSerisi >= 2 ? kazanmaSerisi : 0;

  static Future<void> setSfx(bool v) async {
    sfxAcik = v;
    await _prefs.setBool(_kSfx, v);
  }

  static Future<void> setMuzik(bool v) async {
    muzikAcik = v;
    await _prefs.setBool(_kMuzik, v);
  }

  static Future<void> setTitresim(bool v) async {
    titresimAcik = v;
    await _prefs.setBool(_kTitresim, v);
  }

  static Future<void> setDuelloDavet(bool v) async {
    duelloDavetleriAcik = v;
    await _prefs.setBool(_kDuelloDavet, v);
  }

  static Future<void> setMesajBildirim(bool v) async {
    mesajBildirimleriAcik = v;
    await _prefs.setBool(_kMesajBildirim, v);
  }

  static Future<void> setPlayerLP(int lp) async {
    playerLP = lp < 0 ? 0 : lp;
    await _prefs.setInt(_kPlayerLP, playerLP);
    // 250 LP'ye ilk kez ulaşıldığında soft start kalıcı olarak biter.
    if (!softStartCompleted && playerLP >= 250) {
      softStartCompleted = true;
      await _prefs.setBool(_kSoftStartCompleted, true);
    }
  }

  static Future<void> setKullaniciAdi(String isim) async {
    kullaniciAdi = isim.trim().isEmpty ? 'LingoUstası99' : isim.trim();
    await _prefs.setString(_kKullaniciAdi, kullaniciAdi);
  }

  static Future<void> resetSoftStart() async {
    softStartCompleted = false;
    await _prefs.setBool(_kSoftStartCompleted, false);
  }

  // ── Ses wrapper'lar ─ sfxAcik kapalıysa hiçbir şey yapmaz ───────────────
  // Her ses için ayrı player → önceden yüklenir, gecikme sıfırlanır.
  static final _pDogru     = AudioPlayer();
  static final _pYanlis    = AudioPlayer();
  static final _pKazanma   = AudioPlayer();
  static final _pKaybetme  = AudioPlayer();

  /// Açılışta: her player'ı SFX için yapılandır + asset baytlarını ısıt.
  /// ReleaseMode.stop → ses bitince kaynak serbest bırakılmaz, tekrar çalar.
  static Future<void> sesPreload() async {
    for (final p in [_pDogru, _pYanlis, _pKazanma, _pKaybetme]) {
      try {
        await p.setReleaseMode(ReleaseMode.stop);
      } catch (_) {}
    }
    try {
      await Future.wait([
        _pDogru.setSource(AssetSource('sesler/dogru.mp3')),
        _pYanlis.setSource(AssetSource('sesler/yanlis.mp3')),
        _pKazanma.setSource(AssetSource('sesler/mac_kazanma.mp3')),
        _pKaybetme.setSource(AssetSource('sesler/mac_kaybetme.mp3')),
      ]);
    } catch (_) {}
  }

  static Future<void> _calar(AudioPlayer p, String dosya) async {
    if (!sfxAcik) return;
    try {
      await p.stop();                              // önceki çalmayı sıfırla
      await p.play(AssetSource('sesler/$dosya'));  // baştan çal (güvenilir)
    } catch (_) {}
  }

  static Future<void> sesDogru()        => _calar(_pDogru,    'dogru.mp3');
  static Future<void> sesYanlis()       => _calar(_pYanlis,   'yanlis.mp3');
  static Future<void> sesMacKazanma()   => _calar(_pKazanma,  'mac_kazanma.mp3');
  static Future<void> sesMacKaybetme()  => _calar(_pKaybetme, 'mac_kaybetme.mp3');

  // ── Haptik wrapper'lar ─ titresimAcik kapalıysa hiçbir şey yapmaz ────────
  static void lightImpact() {
    if (titresimAcik) HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (titresimAcik) HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    if (titresimAcik) HapticFeedback.heavyImpact();
  }

  static void selectionClick() {
    if (titresimAcik) HapticFeedback.selectionClick();
  }
}
