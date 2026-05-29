# LingoDuel — Oyun Olasılıkları ve Yüzdeler

---

## 1. Soru Puanlaması

| Cevap saniyesi (tıklama anında kalan süre) | Kazanılan puan |
|--------------------------------------------|---------------|
| 10, 9, 8, 7, 6, 5, 4 sn                   | sn kadar (4–10 p) |
| 3, 2, 1 sn                                 | 3 p (sabit taban) |
| Hiç tıklamadı / süre doldu                 | 0 p           |

> **Formül:** `puan = kalanSure > 3 ? kalanSure : 3`

---

## 2. Bot Davranışı

Her soru başında her bot için bağımsız zar atılır:

| Olay                  | Olasılık |
|-----------------------|----------|
| Cevap verir           | %85      |
| Timeout (cevap vermez)| %15      |

Cevap veren botlar için:

| Olay               | Olasılık |
|--------------------|----------|
| Doğru cevap        | %70      |
| Yanlış cevap       | %30      |

Bot cevap süresi (kalanSure): **1–9 saniye** arasında rastgele (düzgün dağılım).
Bot puanı da Sen'le aynı formülle hesaplanır: `puan = planSn > 3 ? planSn : 3`.

---

## 3. Kelime Sahiplenme (Claim) — Düello

Doğru cevap verildiğinde kelime sahiplenmek için ayrıca bir şans zarı atılır:

| Enderlik   | Sahiplenme şansı |
|------------|-----------------|
| Sıradan    | %20             |
| Sıradışı   | %20             |
| Ender      | %20             |
| Destansı   | %20             |
| Efsanevi   | %20             |
| Mistik     | %10             |

Sahiplenme başka birisinin kelimesini de çalabilir (`isSteal = true`) — sahip değiştirme oranı claim oranıyla aynıdır.

---

## 4. Enderlik Dağılımı (Set Başına 1000 Kelime)

### A Ligi (rank 0–999)

| Enderlik   | Rank aralığı | Adet | Oran |
|------------|-------------|------|------|
| Sıradan    | 0–399       | 400  | %40  |
| Sıradışı   | 400–699     | 300  | %30  |
| Ender      | 700–924     | 225  | %22.5|
| Destansı   | 925–999     | 75   | %7.5 |

### B Ligi (BI / BII / BIII, her biri 1000 kelime)

| Enderlik   | Rank aralığı | Adet | Oran |
|------------|-------------|------|------|
| Sıradan    | 0–299       | 300  | %30  |
| Sıradışı   | 300–599     | 300  | %30  |
| Ender      | 600–849     | 250  | %25  |
| Destansı   | 850–974     | 125  | %12.5|
| Efsanevi   | 975–999     | 25   | %2.5 |

### C Ligi (CI / CII / CIII, her biri 1000 kelime)

| Enderlik   | Rank aralığı | Adet | Oran |
|------------|-------------|------|------|
| Sıradan    | 0–249       | 250  | %25  |
| Sıradışı   | 250–499     | 250  | %25  |
| Ender      | 500–749     | 250  | %25  |
| Destansı   | 750–939     | 190  | %19  |
| Efsanevi   | 940–989     | 50   | %5   |
| Mistik     | 990–999     | 10   | %1   |

---

## 5. Tier = Kelime Zorluğu (Rank Limiti)

Bir odanın tier'ı, seçilen setteki en yüksek rank'i belirler. Düşük tier → yalnızca yaygın kelimeler:

| Tier | Rank cap (rank < N) | A liginde max enderlik | B liginde max enderlik | C liginde max enderlik |
|------|---------------------|------------------------|------------------------|------------------------|
| 100  | rank 0–99           | Sıradan                | Sıradan                | Sıradan                |
| 250  | rank 0–249          | Sıradan                | Sıradan                | Sıradan                |
| 500  | rank 0–499          | Sıradışı               | Sıradışı               | Sıradışı               |
| 1K   | rank 0–999 (tamamı) | Destansı               | Efsanevi               | Mistik                 |

---

## 6. LP Kazanç / Kayıp Tablosu

LP değişimi oynadığın odanın senin "max açabildiğin oda"ya kıyasla nerede olduğuna bağlıdır.

### Temel Tablo (atMax — max açabildiğin odada oynuyorsun)

| Sıra | LP değişimi |
|------|------------|
| 1.   | +12        |
| 2.   | +6         |
| 3.   | +4         |
| 4.   | −2         |
| 5.   | −3         |
| 6.   | −6         |

### Oda Türüne Göre Çarpanlar

| Oda durumu         | Pozitif çarpan | Negatif çarpan |
|--------------------|----------------|----------------|
| Max'ın üstünde     | ×1.5           | ×1 (değişmez)  |
| Tam max odada      | ×1             | ×1             |
| 1 kademe aşağıda   | ×0.5           | ×1 (değişmez)  |
| 2+ kademe aşağıda  | Sabit +2/+1/+1 | Sabit −2/−3/−6 |

**Örnek:** Max odanda 1. sıra → +12 LP. Max'ın üstünde 1. sıra → +18 LP.

### Soft Start (Kaybetme Koruması)

- **Koşul:** A grubunda (0–249 LP), daha önce hiç 250 LP'ye ulaşmamışsan.
- **Etki:** 4.–5.–6. sıra bitişlerde LP kaybı **0**'a çekilir.
- B ve C gruplarında soft start yoktur. 250 LP'ye bir kez ulaşan için bir daha aktifleşmez.

---

## 7. Kazanma Serisi (Win Streak) Bonusu

| Üst üste galibiyet | LP bonusu |
|--------------------|-----------|
| 1. galibiyet       | +0        |
| 2. galibiyet       | +2        |
| 3. galibiyet       | +3        |
| n. galibiyet       | +n        |

Bonus, taban LP'ye eklenir. İlk kayıpta seri sıfırlanır.

---

## 8. Galibiyet / Kayıp Eşiği (Oyuncu Sayısına Göre)

Üst yarı kazanır (yukarı yuvarlama):

| Oyuncu sayısı | Kazananlar          | Kaybedenler  |
|---------------|---------------------|--------------|
| 2 kişi        | 1.                  | 2.           |
| 3 kişi        | 1., 2.              | 3.           |
| 4 kişi        | 1., 2.              | 3., 4.       |
| 5 kişi        | 1., 2., 3.          | 4., 5.       |
| 6 kişi        | 1., 2., 3.          | 4., 5., 6.   |

---

## 9. Lig Grupları ve LP Eşikleri

| Grup | LP aralığı | Açılabilen oda kademe max |
|------|------------|--------------------------|
| A    | 0–1099     | A100 → A1K               |
| B    | 1100–2099  | B100 → B1K               |
| C    | 2100+      | C100 → C1K               |

Oda açmak için LP eşikleri:

| Oda   | Gereken LP |
|-------|-----------|
| A100  | 0         |
| A250  | 250       |
| A500  | 500       |
| A1K   | 1000      |
| B100  | 1100      |
| B250  | 1350      |
| B500  | 1600      |
| B1K   | 2100      |
| C100  | 2100      |
| C250  | 2350      |
| C500  | 2600      |
| C1K   | 3100      |

LP düştüğünde oda açma yetkisi **anlık** geri çekilir (kalıcı mezuniyet yoktur). LP 0'ın altına düşmez.

---

## 10. Maç Ayarları

| Parametre              | Değer                   |
|------------------------|-------------------------|
| Maç başına soru sayısı | 10                      |
| Soru süresi            | 10 saniye               |
| Reveal süresi          | 2 saniye                |
| Geri sayım (lobi→oyun) | 3 saniye                |
| Gösterilen kart sayısı (LingoCards) | 5          |

---

## 11. Fame (Şöhret) Puanı Çarpanları

| Enderlik   | Çarpan |
|------------|--------|
| Sıradan    | ×1     |
| Sıradışı   | ×3     |
| Ender      | ×10    |
| Destansı   | ×25    |
| Efsanevi   | ×75    |
| Mistik     | ×250   |

Unvanlar:

| Fame puanı | Unvan                  |
|------------|------------------------|
| 0–4        | Yeni Koleksiyoncu      |
| 5–39       | Kelime Avcı            |
| 40–149     | Sözcük Ustası          |
| 150–499    | Leksikon               |
| 500+       | Efsane Koleksiyoncu    |
