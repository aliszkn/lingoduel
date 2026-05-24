# Projem: LingoDuel

## Ne yapıyor?
Dil öğrenme oyunu

## Yapılan sprintler:
- Sprint 1: Crash'ler çözüldü
- Sprint 2: Oyun mantığı düzeltildi
- Sprint 3: Eski API temizlendi
- Sprint 4: Veri saklama eklendi (shared_preferences + AppSettings)
- Sprint 5: Renk sabitleri (AppColors)
- Sprint 6: İçerik genişletme + şifreli oda + oyun ekranı tasarımı (2026-05-21)

## Sıradaki:
- Henüz planlanmadı

## Önemli notlar:
- Gemini API entegrasyonu yok
- main.dart bölündü (screens/, models/, services/, core/)
- AppSettings.init() main()'de çağrılır — kaldırılırsa LateInitializationError
- "Sen" oyuncusu = kullanıcı (game_screen, result_screen sarı vurgu mantığı buna göre)

---

## 2026-05-21 — Faaliyet Raporu

### Sprint 6 — İçerik genişletme
- **Kelime havuzu** (`home_screen.dart` CardsPanel): A1, A2, B1, B2, C1, C2 seviyelerinin her biri 30'ar kelimeye çıkarıldı (toplam 180 kelime). Her kelime rank popülaritesine göre sıralı — `100/250/500/1K` kapsam filtresi artık anlamlı.
- **Şifreli odalar:**
  - `aktifOdalar` listesindeki "Arkadaşlarla Özel" odasına `'sifre': '1234'` eklendi (test için).
  - `OdaKurModal` artık girilen şifreyi `'sifre'` alanına kaydediyor.
  - Şifreli odaya tıklayınca eski snackbar yerine gerçek `_SifreDialog` (StatefulWidget) açılıyor.
  - Yanlış şifre → kırmızı kenarlık + hata mesajı + haptic. Doğru şifre → odaya geçiş.

### Bug fix'ler
- **main.dart regression:** Sprint 4/5 import'ları (`AppSettings`, `AppColors`) ve `await AppSettings.init()` çağrısı eksikti — IDE buffer'ı eski sürümü diske yazmıştı. Geri eklendi.
- **`BaskaKullaniciProfili` butonları işlevsizdi:** `isArkadas`, `onArkadasEkle`, `onMesajAt` callback parametreleri eklendi. 3 çağrı yeri (ProfilePanel, SohbetEkrani, ArkadasEkleModal) doğru callback'leri geçecek şekilde güncellendi. "Mesaj At" artık DM'i açıyor, "Arkadaş Ekle" arkadaş listesine ekliyor.
- **`result_screen` sarı vurgu yanlıştı:** `i == 0` (birinci) yerine `players[i]['isim'] == 'Sen'` mantığı — sıralamadan bağımsız olarak kullanıcının satırı vurgulanıyor.
- **`result_screen` TypeError:** `game_screen.dart`'tan `List.from(oyuncular)` her zaman `List<dynamic>` döndüğü için `List<Map<String,dynamic>>` parametresine cast hatası atıyordu. `List<Map<String, dynamic>>.from(oyuncular)` ile düzeltildi.

### Oyun ekranı yeniden tasarımı (`game_screen.dart`)
- Eski tasarım: `Stack + Align` ile oyuncu daireleri merkezdeki soru kartının etrafına yerleştirilmişti — kart genişledikçe çakışıyordu.
- Yeni tasarım: **üstte yatay oyuncu şeridi** + **ortada büyük soru kartı** + altta cevap paneli (değişmedi).
- `_pozisyonlariGetir(kapasite)` Alignment haritaları silindi.
- Yeni helper'lar: `_oyuncuSeridi`, `_oyuncuKarti`, `_bosKart`.
- "Sen" kartı sarı kenarlık + sarı yazı; oda sahibi kırmızı yıldız rozeti; hazır değil → kum saati rozeti.
- Oyun başlayınca liste **canlı leaderboard** olarak puana göre sıralanıyor; lobide giriş sırası korunuyor.

### Tekrarlanan sorun: IDE buffer overwrite
Sprint 6 sırasında home_screen.dart 2 kez "geri döndü" — IDE'de açık olan buffer benim diske yazdığım sürümün üzerine yazmış. Workaround: değişiklik yapacağım dosyaları kullanıcı IDE'de kapatmalı veya "Revert File / Reload from disk" çalıştırmalı.
