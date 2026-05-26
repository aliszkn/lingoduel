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

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    sfxAcik = _prefs.getBool(_kSfx) ?? true;
    muzikAcik = _prefs.getBool(_kMuzik) ?? false;
    titresimAcik = _prefs.getBool(_kTitresim) ?? true;
    duelloDavetleriAcik = _prefs.getBool(_kDuelloDavet) ?? true;
    mesajBildirimleriAcik = _prefs.getBool(_kMesajBildirim) ?? true;
    playerLP          = _prefs.getInt(_kPlayerLP) ?? 0;
    softStartCompleted = _prefs.getBool(_kSoftStartCompleted) ?? false;
  }

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

  static Future<void> resetSoftStart() async {
    softStartCompleted = false;
    await _prefs.setBool(_kSoftStartCompleted, false);
  }

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
