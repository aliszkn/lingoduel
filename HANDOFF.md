# LingoDuel — Devir / Yeni Bilgisayar Kurulum Rehberi

> Bu dosya, projeyi **yeni bir bilgisayarda birebir aynı şekilde** çalıştırmak ve
> yeni bir Claude oturumuna projeyi tam tanıtmak için yazıldı.
> Son güncelleme: 2026-05-30.

---

## 0. Yeni Claude'a ilk mesaj (kopyala-yapıştır)

> "Bu bir Flutter/Dart dil öğrenme oyunu (LingoDuel). Repo kökündeki `HANDOFF.md`,
> `CLAUDE.md` ve `.claude/plans/swirling-watching-papert.md` dosyalarını oku;
> proje durumu, mimari ve multiplayer yol haritası orada. Çalışma kurallarım
> `HANDOFF.md` § 'Çalışma Prensipleri' bölümünde. Backend Nakama (Docker);
> `server/README.md`'ye bak."

---

## 1. Proje Nedir?

- **LingoDuel**: Flutter/Dart ile yazılmış, İngilizce kelime öğreten **çok oyunculu düello** oyunu.
- 14.000 kelimelik önceden doldurulmuş **SQLite** veritabanı (`assets/db/lingoduel_words.db`).
- 6 kademeli **enderlik (rarity)** sistemi; set+tier model (A/B/C × 100/250/500/1K).
- Lig puanı (LP), kazanma serisi, kelime sahipliği (ownership), maç geçmişi.
- **Backend: Nakama** (Heroic Labs, Docker) — sunucu-otoriter gerçek zamanlı maç.

---

## 2. Yeni Bilgisayarda Kurulması Gerekenler

### 2.1 Flutter / Dart
- **Flutter 3.44.0 (stable)**, **Dart 3.12.0** (pubspec `sdk: ^3.11.5`).
- Kur: https://docs.flutter.dev/get-started/install/windows
- `flutter doctor` ile tüm tikleri tamamla.

### 2.2 Android geliştirme
- **Android Studio** (SDK + platform-tools) veya en az Android SDK.
- Fiziksel cihaz: **USB hata ayıklama (USB debugging)** açık. (Mevcut cihaz: Samsung SM S711B, Android 15.)
- (Opsiyonel) Windows masaüstü hedefi için: **Developer Mode** açık olmalı (symlink desteği).

### 2.3 Backend için Docker
- **Docker Desktop** (Windows). Mevcut sürüm: Docker 29.x.
- Kur: https://www.docker.com/products/docker-desktop/ → başlat (sistem tepsisinde balina "running").

### 2.4 Editör + araçlar
- **VS Code** + Flutter/Dart eklentileri (DevTools dahil).
- **Node.js** (yalnızca `tool/enrich_words.js` kelime zenginleştirme aracı için — şu an ASKIDA, zorunlu değil).
- **Git** + GitHub erişimi (repo: `https://github.com/aliszkn/lingoduel`).

---

## 3. İlk Çalıştırma Adımları (yeni bilgisayar)

```bash
# 1) Repoyu klonla
git clone https://github.com/aliszkn/lingoduel
cd lingoduel

# 2) Flutter bağımlılıkları
flutter pub get

# 3) Bağlı cihazları gör
flutter devices

# 4) Uygulamayı çalıştır (fiziksel Android cihazda)
flutter run -d <cihaz_id>
```

### Backend'i (Nakama) ayağa kaldır
```bash
cd server
docker compose up        # ilk seferde imajlar iner (~birkaç dk)
```
- Konsol: http://127.0.0.1:7351  (admin / password — yalnız LOKAL)
- Client HTTP API: 127.0.0.1:7350, serverKey `defaultkey`
- Detay: `server/README.md`

---

## 4. ⚠️ MAKİNEYE ÖZEL AYARLAR (yeni bilgisayarda MUTLAKA değiştir)

Bunlar eski bilgisayara göre sabitlenmiş; yeni makinede güncellenmeli:

1. **LAN IP — `lib/services/nakama_service.dart`**
   ```dart
   static const String _kAndroidDevHost = '192.168.1.103';
   ```
   Fiziksel Android cihaz host bilgisayara bu IP'den ulaşır. Yeni bilgisayarın
   WiFi/Ethernet IP'sini `ipconfig` ile bul ve buraya yaz. (Emülatör için `10.0.2.2`.)

2. **Windows Firewall — 7350 portu**
   Telefonun bilgisayara bağlanabilmesi için (Yönetici PowerShell):
   ```powershell
   netsh advfirewall firewall add rule name="Nakama-7350-inbound" dir=in action=allow protocol=TCP localport=7350 profile=private,domain
   ```

3. **Telefon ve bilgisayar AYNI WiFi ağında olmalı.**
   Test: telefon tarayıcısından `http://<bilgisayar-ip>:7350/healthcheck` → `{}` görmeli.

---

## 5. Kodun Şu Anki Durumu (Multiplayer Yol Haritası)

Detaylı plan: `.claude/plans/swirling-watching-papert.md`

| Faz | Konu | Durum |
|-----|------|-------|
| **0** | Backend + kimlik (Nakama, anonim cihaz auth) | ✅ Tamam, canlı doğrulandı |
| **1** | Kalıcı profil sunucuya (LP/seri/maç/isim → Nakama Storage) | ✅ Tamam |
| **2** | Lobi/oda (gerçek oda listesi, presence, WebSocket) | ✅ Tamam |
| **3** | Sunucu-otoriter maç çekirdeği (timer/skor sunucuda) | ✅ Tamam |
| **4** | Sunucu-tarafı botlar + yeniden bağlanma | ✅ Tamam (canlı 2-cihaz testi bekliyor) |
| **5** | Sertleştirme (rate-limit, mesaj doğrulama, prod config) | 🟡 Kısmen |

### Faz 5 — açık kalanlar
- **Cevap anti-cheat**: Client `correct`'i kendi hesaplıyor → değiştirilmiş client hile
  yapabilir. Gerçek koruma için **kelime DB'si sunucuya** taşınıp cevap doğruluğu
  sunucuda hesaplanmalı. (Kelime zenginleştirme pipeline'ına bağlı — bkz. § 7.)
- SSL/TLS + gerçek hosting (Heroic Cloud veya VPS) — `server/docker-compose.prod.yml` hazır.
- Gerçek matchmaking, sohbet moderasyonu, yük testi.

### İki çalışma modu (önemli)
`lib/screens/game_screen.dart` içinde `_gercekCoklu` bayrağı:
- `false` → **bot modu** (tek cihaz, tamamen yerel — eski deneyim, hiç değişmedi).
- `true`  → **gerçek çok oyunculu** (matchId varsa). Sunucu olaylarıyla sürülür.

---

## 6. Mimari Harita (yeni Claude için hızlı yön)

```
lib/
  main.dart                      → başlangıç: AppSettings, OwnershipDb, DB, ses preload,
                                    RarityIcon precache, Nakama bağlan+profil yükle
  screens/
    home_screen.dart             → ProfilePanel, CardsPanel, DuelPanel (oda listesi/kurma)
    game_screen.dart             → oyun döngüsü (1700+ satır): bot modu + sunucu-güdümlü mod
    result_screen.dart           → maç sonu, LP değişimi, kazanma serisi
    search_screen.dart           → kelime arama (debounce'lu)
  services/
    nakama_service.dart          → TÜM backend: auth, profil sync, soket, oda RPC,
                                    maç opcode'ları, yeniden bağlanma
    app_settings.dart            → LP/seri/sayaç/kullanıcı adı/ses/haptik (shared_preferences)
    database_helper.dart         → 14k kelime SQLite (compute eşiği ile isolate)
    ownership_db.dart            → kelime sahipliği + maç geçmişi (ayrı SQLite)
  game/                          → word_rarity, match_scoring, league_rules, ownership_engine
  widgets/                       → rarity_question_card, word_card

server/                          → Nakama backend (Docker)
  docker-compose.yml             → LOKAL geliştirme (varsayılan creds — yalnız local)
  docker-compose.prod.yml        → PRODUCTION şablonu (.env'den secret okur)
  .env.example                   → prod secret şablonu (gerçek .env git'e GİRMEZ)
  modules/
    rooms.lua                    → oda CRUD RPC + create_room match_handler maçı açar
    match_handler.lua            → AUTHORITATIVE maç döngüsü: lobby→countdown→soru→reveal→bitti
                                    + sunucu botları + rate-limit + mesaj doğrulama

tool/                            → seed_db.dart (DB üretimi), enrich_words.js (ASKIDA), words.txt
```

### Nakama OpCode tablosu (client ↔ server, `match_handler.lua` ve `nakama_service.dart` senkron)
| Code | Yön | Anlam |
|------|-----|-------|
| 1 | C→S | HAZIR durumu |
| 5 | C→S | CEVAP {qi, correct} |
| 10 | S→C | SORU_GELDI {qi} |
| 11 | S→C | SAYAC {sn} |
| 12 | S→C | REVEAL {qi, sonuclar} |
| 13 | S→C | SKOR {leaderboard} |
| 14 | S→C | MAC_BITTI {sirali} |
| 15 | S→C | RESYNC {phase,qi,sn,leaderboard} (yeniden bağlanan oyuncuya) |

---

## 7. Askıya Alınan İş: Kelime Veritabanı Zenginleştirme

- Amaç: `tool/words.txt` (7000 İngilizce kelime) → 6 alanlı sözlük
  (`en, tr, desc, desc_tr, others, ex`) → `database.json`.
- `tool/enrich_words.js` mevcut (API key placeholder; gerçek key `GEMINI_API_KEY`
  ortam değişkeninden okunur — repoya ASLA gerçek key yazma).
- **Neden askıda**: Gemini ücretsiz kota=0; billing min. ödeme istedi (TR'de ~500 TL);
  Groq ücretsiz rate-limit'e takıldı.
- **Sonraki seçenekler** (karar verilmedi):
  1. Fully offline Python pipeline: NLTK (lemma/tanım/örnek) + Argos Translate (offline TR).
  2. Node + MyMemory free API (key yok, günde ~50k kelime limiti).
  3. Çalışan ücretsiz-kotalı bir Gemini/başka LLM key'i.
- Bu iş **anti-cheat (Faz 5)** için ön koşul: doğru cevaplar sunucuda olmalı.

---

## 8. Çalışma Prensipleri (her kod üretiminde geçerli — kullanıcı talebi)

Kullanıcı bu 5 performans/stabilite prensibini varsayılan kabul etmemi istedi:
1. **Pagination** — büyük listeleri sayfalı çek, RAM şişirme.
2. **Asenkronluk** — main thread'i bloklama (compute/isolate eşiği, await+timeout, mounted).
3. **Rate Limit & Debounce** — gereksiz istek/buton-spam'i engelle (300-400ms debounce, guard).
4. **Connection Pool** — REST/WebSocket client'ları singleton; her istekte yeni bağlantı açma.
5. **Cache/TTL** — sunucu/DB verisini yerelde cache'le; offline'da makul davran.

Diğer notlar:
- İletişim **Türkçe**. Türkçe karakter kaynak kodda değişken adlarında dikkatli kullanılmalı
  (geçmişte `_popupGörünür` derleme hatası verdi → ASCII'ye çevrildi).
- "Sen" sabit dizesi = kullanıcının iç anahtarı (bot modunda). UI'da gerçek isim
  `AppSettings.kullaniciAdi`'dan gelir.
- Bot modu DOKUNULMAZ — tek cihaz deneyimini bozma.

---

## 9. Bilinen Ortam Tuhaflıkları

- Bu makinenin ağında **SSL araya giriyordu**; `NODE_TLS_REJECT_UNAUTHORIZED=0` ortamda
  ayarlıydı (Node API çağrıları bu yüzden axios ile çalıştı). Yeni ağda gerekmeyebilir.
- `docker-compose.yml`'de `version: '3'` satırı obsolete uyarısı verir — zararsız.
- Windows PowerShell varsayılan; `&&` çalışmaz, `;` veya `if ($?)` kullan.

---

## 10. Git

- Repo: `https://github.com/aliszkn/lingoduel`  (branch: `main`)
- Git kullanıcısı: aliszkn
- `.env`, `tool/node_modules/`, devtools çöpleri `.gitignore`'da.
- Yeni bilgisayarda: `git clone` → `flutter pub get` → § 4 makineye-özel ayarlar → çalıştır.

---

## 11. Claude Hafıza Dosyaları (taşınmaz — bu doc bunları özetler)

Eski bilgisayarda Claude'un kalıcı hafızası şurada (repo DIŞI, makineye özel):
`C:\Users\ahmet\.claude\projects\C--Users-ahmet-lingoduel\memory\`
- `multiplayer-hedefi.md` — multiplayer Faz 0-5 detaylı durum (bu doc § 5 ile aynı özü taşır).
- `perf-prensipler.md` — § 8'deki 5 prensip.

Yeni bilgisayarda bu hafıza olmayacak; yeni Claude'a § 0'daki mesajı verip bu dosyayı
okutman yeterli.
