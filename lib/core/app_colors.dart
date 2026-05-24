import 'package:flutter/material.dart';

/// Uygulama genelinde kullanılan renk sabitleri.
///
/// Tüm hex renkler tek noktadan yönetilir. Tema değişikliği gerekirse
/// sadece bu dosyada güncelleme yapmak yeterlidir.
class AppColors {
  AppColors._(); // örnek oluşturulamaz

  // ── Arka planlar ve yüzeyler ─────────────────────────────────────────
  static const arkaPlan = Color(0xFF05090F);   // Ana koyu arka plan
  static const yuzey = Color(0xFF1B2536);      // Kart / panel yüzeyi
  static const koyuYuzey = Color(0xFF111827);  // Oyun ekranı alt paneli
  static const butonArka = Color(0xFF162032);  // Seçim butonu arka planı
  static const kartGolge = Color(0xFF0D1420);  // Kelime kartı 3D gölgesi

  // ── Panel tema renkleri ──────────────────────────────────────────────
  static const cyan = Color(0xFF00E5FF);          // Cards paneli vurgu
  static const cyanKoyu = Color(0xFF0097A7);      // Cards kartı gölgesi
  static const sari = Color(0xFFFFD600);          // Profile paneli vurgu
  static const kirmizi = Color(0xFFFF3D00);       // Duel paneli vurgu
  static const kirmiziKoyu = Color(0xFFBF2E00);   // Duel butonu gölgesi
}
