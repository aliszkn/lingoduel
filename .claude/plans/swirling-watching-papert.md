# Faz 3 — Sunucu-Otoriter Maç Çekirdeği

## Context

Faz 0-2 tamamlandı: Nakama backend ayakta, lobi gerçek, WebSocket bağlantısı çalışıyor.
Faz 2'de oyunun "aynı seed → aynı sorular" kısmı istemcide üretiliyor; timer, skor ve
cevap doğrulama tamamen client-tarıflı. Bu plan **timer'ı ve skor hesabını sunucuya taşır**:
kimse sayacı manipüle edip yüksek puan yazamaz. Cevabın doğruluğu (kelime DB sunucuda olmadığı
için) şimdilik client self-report olarak kalır; doğruluk anti-cheat'i Faz 5'e ertelenir.
Bot modu **hiç değişmez** — tek-cihaz deneyimi korunur.

---

## Mimari (kısa)

```
Client ─── HAZIR (op1) ────────────────────────────────► Server
           CEVAP (op5) {qi, correct}                     match_loop (1s tick)
                                                         │
Server ◄── SORU_GELDI (op10) {qi}                        │ soru yönetimi
           SAYAC     (op11) {sn}                         │ timer
           REVEAL    (op12) {qi, sonuclar}               │ skor
           SKOR      (op13) {leaderboard}                │
           MAC_BITTI (op14) {final_sirali}               ▼
```

Client seed'i **hâlâ rooms.lua `create_room` RPC'sinde** üretilir ve match başlangıç
parametresi olarak geçer. Her client aynı seed → `_soruSirasi` deterministik. Sunucu
sadece index (`qi`) yayınlar; kelime içeriğini client yerel DB'den çözer.

---

## Yeni OpCode tablosu (nakama_service.dart'a eklenecek)

| Yön | Code | İsim | Data |
|-----|------|------|------|
| C→S | 5  | kOpCevapGonder      | `{qi, correct}` |
| S→C | 10 | kOpSoruGeldi        | `{qi}` |
| S→C | 11 | kOpSayacGuncellendi | `{sn}` |
| S→C | 12 | kOpReveal           | `{qi, sonuclar:[{userId,puan,dogru}]}` |
| S→C | 13 | kOpSkorGuncellendi  | `{leaderboard:[{userId,isim,puan}]}` |
| S→C | 14 | kOpMacBitti         | `{sirali:[{userId,isim,puan,sira}]}` |

Op 1 (HAZIR_DEGISTI) ve op 2 (OYUN_BASLIYOR) Faz 2'den korunur (lobby için).

---

## Dosyalar

### 1. `server/modules/match_handler.lua` (YENİ ~220 satır)
Nakama authoritative match handler. 6 zorunlu fonksiyon:

**match_init(context, setupstate)**
- `setupstate` = `{seed, kapasite, totalQuestions=10}`
- Başlangıç state: `{phase="lobby", seed, kapasite, totalQ, qi=-1, sn=10, revealLeft=0, cdLeft=0, players={}, answers={}}`
- tickrate = 1 (saniyede 1 tick)
- label = `""` (relayed match'ten fark — listelemeye gerek yok, roomlar storage'da)

**match_join_attempt** → dolu değilse kabul et

**match_join** → `state.players[userId] = {isim=presence.username, puan=0, hazir=false, answered=false}`

**match_leave** → oyuncuyu sil; eğer kimse kalmadıysa nil döndür (match sona erer)

**match_loop(context, dispatcher, tick, state, messages)**
- Her gelen mesajı işle (HAZIR op1, CEVAP op5)
- Phase state machine (aşağıda)
- return nil → maç biter; return state → devam

**match_terminate** → temizlik, nil

#### match_loop state machine

```
lobby:
  HAZIR mesajı gelince → player.hazir = true
  Koşul: ≥2 oyuncu AND hepsi hazır → phase="countdown", cdLeft=3
  Her tick: SKOR yayınla (lobi leaderboard günceller)

countdown:
  cdLeft-- her tick; SAYAC(cdLeft) yayınla
  cdLeft==0 → phase="question", qi=0, _soruAc()

question:
  CEVAP op5 gelince → answers[userId]={correct, sn=state.sn}; player.answered=true
  sn-- her tick; SAYAC(sn) yayınla
  sn==0 OR hepsi cevapladı → _yargila()

reveal:
  revealLeft-- her tick
  revealLeft==0 → qi < totalQ-1 ? _soruAc() : _macBitti()

_soruAc():
  phase="question", sn=10, answers={}, tüm player.answered=false
  SORU_GELDI({qi}) yayınla

_yargila():
  Her oyuncu için: puan += correct ? (sn>3 ? sn : 3) : 0
  REVEAL({qi, sonuclar}) yayınla
  SKOR({leaderboard}) yayınla
  phase="reveal", revealLeft=2

_macBitti():
  sıralama hesapla; MAC_BITTI({sirali}) yayınla
  phase="finished"; return nil (match terminate)
```

### 2. `server/modules/rooms.lua` (GÜNCELLEME ~10 satır değişiklik)
`create_room` RPC'sinde, Storage yazımından ÖNCE:
```lua
local seed = math.random(0, 2147483647)
local match_id = nk.match_create("match_handler", {
  seed = seed, kapasite = data.kapasite, totalQuestions = 10
})
room.matchId = match_id
room.seed = seed
```
Artık client `_matchOlusturVeGuncelle()` çağırmaya gerek yok.

### 3. `lib/services/nakama_service.dart` (GÜNCELLEME ~15 satır)
- `kOpCevapGonder = 5`, `kOpSoruGeldi = 10`, `kOpSayacGuncellendi = 11`,
  `kOpReveal = 12`, `kOpSkorGuncellendi = 13`, `kOpMacBitti = 14`
- `cevapGonder(matchId, qi, correct)` metodu ekle:
  ```dart
  void cevapGonder(String matchId, int qi, bool correct) {
    _socket?.sendMatchData(matchId: matchId, opCode: kOpCevapGonder,
      data: utf8.encode(jsonEncode({'qi': qi, 'correct': correct})));
  }
  ```

### 4. `lib/screens/game_screen.dart` (GÜNCELLEME ~120 satır)
`_gercekCoklu` modunda yeni davranış; bot modu **değişmez**.

**initState** — `_gercekCoklu` için seed de al:
```dart
_seed = widget.odaBilgisi['seed'] as int? ?? _random.nextInt(0x7fffffff);
```
`_soruSirasi` önceden oluşturulur (seed ile) ama `_yeniSoruHazirla` çağrılmaz —
sunucudan SORU_GELDI beklenir.

**`_lobiMesajiGeldi`** genişletilir (yeni opcodes eklenir):
- `kOpSoruGeldi` (10): `_serverSoruAc(qi)` — yerel soru üret (seed+qi ile), UI'ı hazırla
- `kOpSayacGuncellendi` (11): `setState(() => kalanSure = sn)` — server saati
- `kOpReveal` (12): `_serverRevealIsle(sonuclar)` — sunucu skorlarını uygula, reveal UI aç
- `kOpSkorGuncellendi` (13): `_serverSkorGuncelle(leaderboard)` — oyuncu listesini güncelle
- `kOpMacBitti` (14): `_serverMacBitti(sirali)` — ResultScreen'e geç

**`_serverSoruAc(qi)`**:
- `_aktifSoruIndex = qi`
- Yerel DB'den kelimeyi çöz: `_havuz[_soruSirasi[qi]]`
- Soru ve şıkları üret (mevcut `_soruVeSiklariHazirla` mantığı reuse edilir)
- `_revealAktif = false; _secilenCevap = null; kalanSure = 10`
- setState → UI yeni soruyu gösterir

**`_cevapKontrol`** — `_gercekCoklu` modunda:
- Yerel UI güncellemesi (avatar, seçim) aynen kalır
- `NakamaService.instance.cevapGonder(matchId, qi, dogru)` ekle
- Yerel `_puanHesapla` çağrılmaz (sunucu hesaplar)

**`_gercekCoklu` modunda DEVRE DIŞI kalan kısımlar:**
- `_zamanlayici` (Timer.periodic countdown) — sunucu tick'i kalanSure'yi günceller
- `_yargila()` çağrısı — sunucu REVEAL gönderir
- `_botlariniPlanla/Acikla` — bot yok (gerçek mod)
- `_yeniSoruHazirla` → `_sonrakiSoruHazirla` zinciri — sunucu SORU_GELDI yönlendirir
- Yerel maç sonu hesabı — MAC_BITTI'den gelen `sirali` doğrudan kullanılır

**`_serverRevealIsle(sonuclar)`**:
- Oyuncu listesindeki puanları sunucudan gelen değerlerle güncelle
- `_revealAktif = true` → mevcut reveal UI çalışır (2sn bekler, sonra sunucu SORU_GELDI bekler)
- Popup (`_popupGoster`) doğru/yanlış için çalışmaya devam eder

**`_serverMacBitti(sirali)`**:
- `Navigator.pushReplacement → ResultScreen`
- `players` listesini `sirali`'dan oluştur (sunucu sıralama)
- `AppSettings.recordMatchResult` + `OwnershipDb.saveMatch` hâlâ client'ta (Faz 4/5'e kadar)

---

## Kaldırılan / Pasifize Edilen (sadece `_gercekCoklu` modunda)
- `_matchOlusturVeGuncelle()` — sunucu `create_room` RPC'sinde zaten matchId üretiyor
- `_oyunuSeedileBaslat()` → yerini `_lobiMesajiGeldi → kOpSoruGeldi` alıyor
- `oyunBaslatMesajiGonder` (op2) — lobi "Başlat" butonu artık `_oyunuBaslat()`'ı değil,
  sunucuya HAZIR mesajı göndermeyi tetikler; sunucu tüm hazır olunca başlatır

---

## Dokunulmayacaklar
- Bot modu (tüm `_gercekCoklu == false` dalları) → değişmez
- `MatchScoring`, `OwnershipEngine` (LP/claim hesabı) → Faz 4/5'e kadar client'ta
- `AppSettings`, profil sync, maç geçmişi → değişmez
- UI widget'ları (RarityQuestionCard, cevap şıkları, oyuncu şeridi, ResultScreen) → değişmez

---

## Doğrulama
1. `flutter analyze` — sıfır error, bot modu aynen çalışıyor
2. Nakama log'larında `match_handler` modülü yüklenmiş: `Registered Lua match handler`
3. `create_room` RPC → dönen JSON'da `matchId` dolu
4. 2 client ile test:
   - Her ikisi odaya katılır, hazır olur
   - Sunucu 3-2-1 countdown başlatır
   - Aynı soru, aynı sıra her iki ekranda
   - Sunucu `SAYAC` tick'leri her saniye geliyor (debug log)
   - Cevap → `REVEAL` → `SKOR` akışı sunucudan
   - Son soruda `MAC_BITTI` ile ResultScreen

## Efor Notu
- `match_handler.lua`: ~220 satır yeni Lua kodu
- `game_screen.dart`: ~120 satır değişiklik (bot modu dokunulmaz)
- `rooms.lua`: ~10 satır değişiklik
- `nakama_service.dart`: ~15 satır ekleme
Toplam: orta büyüklükte, 1 oturumda tamamlanabilir.
