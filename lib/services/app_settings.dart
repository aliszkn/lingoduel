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

  static late SharedPreferences _prefs;

  // Senkron erişim için cache'lenmiş değerler (varsayılan + load sonrası gerçek).
  static bool sfxAcik = true;
  static bool muzikAcik = false;
  static bool titresimAcik = true;
  static bool duelloDavetleriAcik = true;
  static bool mesajBildirimleriAcik = true;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    sfxAcik = _prefs.getBool(_kSfx) ?? true;
    muzikAcik = _prefs.getBool(_kMuzik) ?? false;
    titresimAcik = _prefs.getBool(_kTitresim) ?? true;
    duelloDavetleriAcik = _prefs.getBool(_kDuelloDavet) ?? true;
    mesajBildirimleriAcik = _prefs.getBool(_kMesajBildirim) ?? true;
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
