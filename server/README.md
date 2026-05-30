# LingoDuel Backend (Nakama) — Lokal Geliştirme

Faz 0: gerçek zamanlı multiplayer için sunucu altyapısı. Bu klasör lokal
geliştirme içindir; client (Flutter) buraya bağlanıp kimlik alır.

## Ön Koşul: Docker Desktop

Nakama bir Docker container'ı olarak çalışır. Önce **Docker Desktop**
kurulmalı (Windows):

1. https://www.docker.com/products/docker-desktop/ → indir & kur.
2. Docker Desktop'ı başlat (sistem tepsisinde balina ikonu "running" olmalı).
3. Terminalde doğrula:  `docker --version`  ve  `docker compose version`

## Sunucuyu Başlat

```
cd server
docker compose up
```
İlk çalıştırmada imajlar inilir (~birkaç dk). "nakama1 ... startup complete"
benzeri log görünce hazırdır.

- **Konsol (yönetim paneli):** http://127.0.0.1:7351  (admin / password)
- **Client HTTP API:** 127.0.0.1 : 7350,  serverKey = `defaultkey`

Durdurmak: `Ctrl+C`, sonra `docker compose down`. (Veriyi de silmek için
`docker compose down -v`.)

## Sıradaki Adım (Faz 0 — client tarafı)

Sunucu ayağa kalkınca:
1. Flutter'a `nakama: ^1.3.0` paketi eklenir.
2. `lib/services/nakama_service.dart` — bağlantı + **anonim cihaz kimliği**
   (authenticateDevice) servisi yazılır.
3. `main.dart`'ta başlangıçta oturum açılır; `userId` elde edilir.
   ("Sen" sabit kimliği yerini gerçek hesaba bırakmaya başlar.)

Bu adımları, sunucu çalışırken **canlı test ederek** ekleyeceğiz.

## Faz 5 — Sertleştirme (Hardening)

### Maç handler güvenliği (TAMAMLANDI — `match_handler.lua`)
- **Rate limit:** oyuncu başına tick (1sn) başına en fazla `MAX_MSG_PER_TICK` (8)
  mesaj işlenir; üstü flood sayılıp yoksayılır.
- **Mesaj doğrulama:** `OP_CEVAP` yalnız soru fazında, `qi` güncel soruyla
  eşleşiyorsa ve ilk cevapsa kabul edilir (bayat/sahte indeks reddedilir).
  `OP_HAZIR` yalnız lobide işlenir; bilinmeyen gönderici yoksayılır.
- **Otoriter skor/timer:** Faz 3'ten beri sunucuda (client puanını yazamaz).

### Açık kalan anti-cheat (kelime DB'sine bağlı — BEKLEMEDE)
- Şu an client `OP_CEVAP`'te `correct` alanını **kendisi** hesaplıyor → değiştirilmiş
  client her zaman `correct=true` yollayabilir. Gerçek koruma için **doğru cevap
  sunucuda** bilinmeli: 14k kelime DB'si (veya en azından maçın soru→cevap eşlemesi)
  sunucuya taşınıp cevap doğruluğu sunucuda hesaplanmalı.
- Bu, askıya alınan kelime zenginleştirme pipeline'ına bağlı; veri hazır olunca yapılır.

### Production dağıtımı (`docker-compose.prod.yml` + `.env`)
1. `cp .env.example .env` → tüm değerleri **güçlü/rastgele** doldur (defaultkey/password DEĞİL).
2. `docker compose -f docker-compose.prod.yml up -d`
3. Postgres portu (5432) ve konsol portu (7351) **public açılmaz** (prod compose'da yok).
   Konsola SSH tüneli/VPN ile eriş.
4. **SSL:** Nakama'yı doğrudan açma; önüne TLS sonlandıran reverse proxy
   (Caddy/Nginx/Traefik) koy, 443 → 7350. Client'ta `_ssl = true` + gerçek host yap.
5. Client `NakamaService._serverKey` değeri `.env`'deki `NAKAMA_SERVER_KEY` ile eşleşmeli.
6. Hosting kararı: **Heroic Cloud** (yönetilen) ya da kendi VPS'inde self-host.

### Henüz yapılmadı (ileride)
- Sohbet moderasyonu (sustur/şikâyet) — önce sunucu-tarafı gerçek sohbet gerekiyor.
- Analitik / hata izleme.
- Maç-ortası kopma UX'i (reconnection altyapısı Faz 4'te hazır; UI cilası eksik).
