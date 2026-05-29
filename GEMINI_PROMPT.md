# LingoDuel — Tam Tanıtım Promptu (Gemini için)

> Bu dosyayı Gemini'ye olduğu gibi yapıştır. Sonunda kendi sorunu/tartışmak istediğin konuyu ekle.

---

Merhaba Gemini. Sana **LingoDuel** adlı bir mobil dil öğrenme oyununun tasarımını detaylı anlatacağım. Bu oyunun **nadirlik (rarity) ve kelime sahiplenme sistemini** geliştirmek istiyorum; senden tasarım fikirleri, denge analizi ve mekanik önerileri alacağım. Önce her sistemi tam olarak anla, sonra sorularıma cevap ver — eksik bilgi varsa sorabilirsin, varsayım yapma.

---

## 1) Proje Künyesi

- **Adı:** LingoDuel (içinde "LingoCards" alt modu da var)
- **Platform:** Flutter / Dart (Android, iOS, Windows, macOS, Linux)
- **Depolama:** `shared_preferences` (kullanıcı ayarları + LP) + `sqflite` (kelime sahiplikleri)
- **Dil çifti:** İngilizce → Türkçe (oyuncu Türk, hedef dil İngilizce)
- **Backend:** Yok. Tamamen yerel/offline. "Çok oyunculu" görünen kısımlar simüle (botlar + sahte kullanıcı listesi).
- **Oyuncu kimliği:** "Sen" sabit string'i. Henüz auth yok.

## 2) Ana Akışlar / Paneller

Uygulama, 3 panel arası geçiş yapılan tek bir `AnaKontrolMerkezi` ekranından oluşur (alt bar):

1. **LingoCards (öğrenme modu)** — Flashcard sistemi
2. **Profile** — Profil, LP rozeti, ün kartı, arkadaş/mesaj listesi, ayarlar
3. **LingoDuel (lobby + maç)** — Oda listesi, oda kurma, gerçek oyun ekranı

## 3) Kelime Havuzu (`lib/data/word_pool.dart`)

Tüm içerik tek dosyada sabit kodlu:

- **CEFR Seviyeleri:** `A` (başlangıç), `B` (orta), `C` (ileri)
- Her seviyede **80 kelime**, popülariteye göre `rank: 1-80` sıralı (1 = en yaygın)
- Toplam **240 kelime**
- Her `WordEntry` şu alanlara sahip:
  - `en` (İngilizce kelime — cevap)
  - `tr` (Türkçe karşılık)
  - `desc` (İngilizce tanım — oyunda soru)
  - `descTr` (Türkçe tanım — son 5sn'de gösterilir)
  - `others` (sinonimler / ek anlamlar)
  - `ex` (İngilizce örnek cümle)
  - `level` ('A'|'B'|'C')
  - `rank` (1-80)

**Kapsam (popülerlik) filtresi** — kullanıcı flashcard panelinde 4 sınırdan birini seçer:

| Kapsam | rank ≤ | Lig kodu örnekleri |
|---|---|---|
| İlk 100 | 20  | A100, B100, C100 |
| İlk 250 | 40  | A250, B250, C250 |
| İlk 500 | 60  | A500, B500, C500 |
| İlk 1K  | 80  | A1K,  B1K,  C1K  |

(Yani veri büyüdükçe bu eşikler güncellenecek. Şu an her tier 20'lik aralık.)

## 4) Lig Sistemi (`lib/game/league_models.dart`, `league_rules.dart`)

**12 oda** sabit: 3 lig grubu × 4 kademe.

```
A100 (eşik:    0 LP)   A250 (250)   A500 ( 500)   A1K (1000)
B100 (eşik: 1100 LP)   B250 (1350)  B500 (1600)   B1K (2100)
C100 (eşik: 2100 LP)   C250 (2350)  C500 (2600)   C1K (3100)
```

- **`createThreshold`**: oyuncu bu LP'ye ulaşmadan o odayı **açamaz** (kurmak için).
- **`groupOf(lp)`**: anlık harf grubu — LP < 1100 → A, 1100-2099 → B, ≥ 2100 → C.
- **`maxCreatableRoom(lp)`**: oyuncunun açabileceği en yüksek oda. LP düşerse anlık geri gider (kalıcı mezuniyet yok).
- **`canJoin(lp, room)`**: kendi grubu ve altındaki tüm odalara LP fark etmeksizin girilebilir; üst gruba eşik olmadan girilemez.

`B1K` ve `C100` aynı eşikteyken (2100 LP) `levelIndex` farkıyla ayrışır — yani C grubu sıralamada bir basamak yukarıdadır.

## 5) Puanlama / LP Sistemi (`lib/game/match_scoring.dart`)

**6 oyunculu maç sonu sıralamasına göre** kazanç/kayıp:

| Sıra | Taban LP (atMax) | Sabit (2+ alt) |
|------|------------------|----------------|
| 1.   | +12 | +2 |
| 2.   |  +6 | +1 |
| 3.   |  +4 | +1 |
| 4.   |  −2 | −2 |
| 5.   |  −3 | −3 |
| 6.   |  −6 | −6 |

**Oda seviyesi farkı çarpanları** (oyuncunun max açabildiği oda ile oynanan odanın `levelIndex` farkı):

- `aboveMax` (üst lig odasında): **pozitif sonuç ×1.5**, negatif değişmez (risk/ödül)
- `atMax` (tam yetkili odada): taban tablo (×1.0)
- `oneLevelBelow` (1 kademe aşağı): **pozitif sonuç ×0.5**, negatif değişmez
- `twoOrMoreBelow` (2+ kademe aşağı): **sabit minimal tablo** (alt odalarda farm engelleme)

### Soft Start

- Yalnızca **A grubu giriş aralığında (0–249 LP)** geçerli.
- `softStartCompleted` flag'i: oyuncu hayatında bir kez 250 LP'ye ulaştıysa kalıcı `true`.
- Soft start aktifken (`!softStartCompleted && lp < 250`): **negatif LP kaybı 0'a sabitlenir** (sadece kazanırsın).
- Sonradan LP düşerse soft start geri **gelmez** — tek seferlik.
- B ve C grubunda soft start hiç yoktur.

## 6) Oda Erişim UI Davranışı

Lobide oda listesinde her oda için kart:

- **Erişimsiz** (üst grup) → opaklık %45, "YETERSİZ SEVİYE" rozeti, kilit ikonu.
- **Avantajlı** (LP yetiyor ama oyuncunun max açabildiğinin üstünde) → "AVANTAJLI" turuncu rozet.
- **Dolu** → ikon kapalı, "Bu oda şu an dolu" toast.
- **Şifreli** → kilit ikonu, tıklayınca `_SifreDialog` açılır (yanlış şifre → kırmızı border + hata mesajı).

Oda kurma modali aynı şekilde kilit/açık ayrımı yapar; eşiğe ulaşılmamış odaya tıklayınca toast'la "X için Y LP gerekiyor" der.

## 7) Oyun Ekranı (`game_screen.dart`)

- 2-6 oyunculu maç. Bot oyuncular simüle.
- Üstte **yatay oyuncu şeridi** (sen sarı vurgu, oda sahibi kırmızı yıldız, hazır değil → kum saati).
- Ortada büyük **soru kartı** (`desc` = İngilizce tanım gösterilir; son 5 sn'de `descTr` Türkçe tanım açılır).
- Altta cevap girişi paneli.
- Oyun başlayınca leaderboard puana göre **canlı sıralanır**; lobide giriş sırası korunur.
- Maç bitince `ResultScreen`'e geçilir; LP değişimi `MatchScoring.calculateLPChange` ile hesaplanır, `AppSettings.setPlayerLP` ile kalıcı yazılır.

## 8) Nadirlik / Sahiplenme Sistemi — **Geliştirmek istediğim ana mekanik**

### 8.1 Nadirlik kademeleri (`lib/game/word_rarity.dart`)

`rank` 1-80'i 4 eşit dilime böler:

| Rank   | Nadirlik     | Renk             | Flash kart claim % | Ün çarpanı |
|--------|--------------|------------------|--------------------|------------|
| 1-20   | `common`     | beyaz/gri        | %10                | ×1         |
| 21-40  | `uncommon`   | yeşil (#4CAF50)  | %4                 | ×3         |
| 41-60  | `rare`       | mavi  (#2979FF)  | %1                 | ×10        |
| 61-80  | `legendary`  | altın (#FFD600)  | %0.2               | ×50        |

Yani **en nadir kelimeler aynı zamanda en az popüler olanlar** — ironik bir tasarım: en seyrek karşılaşılan kelime için en seyrek tetikleme.

### 8.2 Sahiplenme algoritması (`ownership_engine.dart`)

İki tetikleme yolu var:

**(A) Flashcard mod (`tryClaimFlashcard`)**:
- Kullanıcı kartı **uzun basışla çevirdiğinde** (ön → arka), bir kez `Random().nextDouble()` ile yukarıdaki yüzdeye karşı zar atılır.
- Tutarsa kelime DB'de o oyuncuya yazılır (`source: 'flashcard'`).
- Kelimenin **önceki sahibi varsa ve farklı bir oyuncuysa**, üstüne yazılır → `isSteal = true` (çalma mekaniği).
- Sonuç kullanıcıya renkli `SnackBar` ile bildirilir: "apple sahiplenildi! (RARE)" veya "apple çalındı! (LEGENDARY)".

**(B) Düello mod (`claimDuelWord`)**:
- Soruya **ilk doğru cevap veren oyuncu** kelimeyi otomatik kazanır.
- Olasılık yok, garanti sahiplenme.
- ⚠️ Şu an **bu fonksiyon hazır ama oyun ekranında henüz çağrılmıyor** — entegrasyonu yapılacak.

### 8.3 Veri şeması (`ownership_db.dart`, SQLite)

```sql
CREATE TABLE word_ownership (
  word_id      TEXT PRIMARY KEY,    -- "A01" ... "C80"
  rarity       TEXT NOT NULL,       -- 'common'|'uncommon'|'rare'|'legendary'
  owner_id     TEXT NOT NULL,       -- 'Sen' veya başka oyuncu adı
  claim_source TEXT NOT NULL,       -- 'flashcard' | 'duel'
  claimed_at   INTEGER NOT NULL     -- ms epoch
);
CREATE INDEX idx_wo_owner ON word_ownership(owner_id);
```

- `word_id` formatı: `level + zero-padded rank` → "A01", "B07", "C80".
- `ConflictAlgorithm.replace` ile her sahiplenme **önceki kaydı siler** → çalma otomatik.
- Bir kelimenin tek bir sahibi olabilir (PK).

### 8.4 Ün (Fame) sistemi

`FameStats` modeli:

```dart
famePoints = common*1 + uncommon*3 + rare*10 + legendary*50

title:
  ≥ 500 → 'EFSANE KOLEKSIYONCU'
  ≥ 150 → 'LEKSIKON'
  ≥  40 → 'SÖZCÜK USTASI'
  ≥   5 → 'KELİME AVCI'
  else  → 'YENİ KOLEKSIYONCU'
```

Profile panelinde LP rozetinin altında ün kartı görünür: unvan + puan + sahip olunan kelime sayısı + her tier için renkli noktalı sayaç.

### 8.5 Mevcut UI göstergeleri

Flashcard widget'ında:
- Sağ üstte küçük **nadirlik chip'i** (etiket renkli)
- Sol üstte sahip Sen ise **sarı yıldız ikonu**
- Arka yüzde aynı şekilde (chip koyu varyant)

## 9) Önemli Tasarım Kısıtları & Felsefe

- **Backend yok:** Çalma mekaniği şu an gerçek başka oyunculara karşı işlemiyor — sadece teorik olarak `owner_id` farklı olsa çalma sayılacak. Henüz başka oyuncu DB'ye yazmıyor.
- **Para birimi yok:** Henüz coin/gem/store yok. Ödüller şu an sadece LP ve sahiplik.
- **Pay-to-win yapılmayacak** — geliştirme yönü serbest oyun (free play) + sezon/sosyal mekanik.
- **CEFR'a sadık kalmak istiyorum** — yapay zorluk dengelemek için kelimeleri yanlış seviyeye atmıyorum.
- **"Soft start" gibi mekanikler tek seferlik** olmalı; oyuncu LP'sini düşürerek kolay kelime farmlamasın diye `aboveMax` çarpanı düşük tutuldu.

## 10) Şu an çözülmemiş/açık sorular (bunlar üzerine fikrini soracağım)

1. **Nadirlik eşleştirmesi ironisi**: En yaygın (rank 1) kelime = en kolay sahiplenilen (common). Mantıklı mı, yoksa ters mi olmalı? (Rank 1'in herkes tarafından bilinmesi onu daha "değerli mi yoksa daha mı sıradan" yapar?)
2. **Çalma motivasyonu**: Oyuncu zaten sahiplendiği kelimeyi tekrar çalmaya çalışmaz mı boşa mı? Sahiplenilmiş kelime tekrar tıklandığında ne olmalı?
3. **Düello entegrasyonu**: Ortak bir soru kartında ilk doğru cevap veren kelimeyi kazanır. Ama bu sahiplik **kalıcı mı** olmalı, **maç bazlı mı**, yoksa düello kazananı bir **şampiyonluk turu** mu hak etmeli?
4. **Ün noktasının somut faydası**: Şu an `famePoints` sadece unvanı belirliyor. Liderlik tablosu, profil kartında görünüm, oda kurma yetkisi vb. nasıl eklenmeli?
5. **Geri kazanma / kaybetme**: Bir kelimeyi çalmak kolaysa (her flashcard'da %10), oyuncu hiç "kaybetme acısı" hissetmez. Yoksa bir kelimeyi **belirli süre savunma** mekanizması mı ekleyelim?
6. **Sezon resetlemeleri**: Sahiplikler ve ün her sezon sıfırlansın mı, yoksa kalıcı koleksiyon mu olsun?
7. **Yeni nadirlik kademesi**: 4 yeterli mi? "Mitik" gibi 5. kademe rank 80'in bile üstünde **özel kelimeler** mi olmalı?

---

## Bu prompttan beklediğim şey

Sana sorular soracağım — her cevapta:
- Bu **mevcut sisteme** uygun olmalı (yukarıdaki kısıtları ihlal etmemeli).
- **Ekonomik dengeyi** düşünmelisin (yüzdeler, çarpanlar, eşikler).
- Önce **tasarım fikrini** anlat, sonra istersem **Flutter/Dart implementasyon önerisi** ver (mevcut sınıf adlarını kullan: `OwnershipEngine`, `WordRarity`, `FameStats`, `OwnershipDb`).
- Belirsizlik varsa **varsayım yapma**, "şunu netleştirir misin?" diye sor.

Hazırsan, ilk sorum şu: **[buraya kendi sorunu yaz]**
