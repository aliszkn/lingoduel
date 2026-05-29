# Devir Paketi: Enderlik (Rarity) İkonları

## Genel Bakış
Mobil koleksiyon uygulaması için **6 seviyelik enderlik (rarity) ikon seti**. Her seviye kendi
mücevher kesimi (şekli) ve klasik oyun renk koduyla temsil edilir; enderlik arttıkça parıltı ve
süsleme artar. İkonlar **kenar sayısı ilerlemesi** mantığını izler: şekilsiz taş → üçgen → kare →
beşgen → altıgen → yuvarlak.

| # | Seviye    | İngilizce  | Şekil               | Ana Renk   | Asset |
|---|-----------|------------|---------------------|------------|-------|
| 1 | Sıradan   | Common     | Sekizgen (mat taş)  | `#9BA2AD`  | `enderlik_siradan.svg` |
| 2 | Sıradışı  | Uncommon   | Üçgen (3)           | `#4ADE80`  | `enderlik_siradisi.svg` |
| 3 | Ender     | Rare       | Kare (4)            | `#5B9BFF`  | `enderlik_ender.svg` |
| 4 | Destansı  | Epic       | Beşgen (5)          | `#C18BFF`  | `enderlik_destansi.svg` |
| 5 | Efsanevi  | Legendary  | Altıgen (6) + ışıltı| `#FCD34D`  | `enderlik_efsanevi.svg` |
| 6 | Mistik    | Mythic     | Yuvarlak (∞) + aura | `#FF7088`  | `enderlik_mistik.svg` |

> Önizleme için `reference_icons.png` (koyu zeminde tüm set) ve
> `reference_showcase.html` (tarayıcıda aç) dosyalarına bak.

## Bu Paketteki Dosyalar Hakkında
Bu set **doğrudan kullanıma hazırdır** — bir HTML prototipi değil, gerçek üretim asset'leri ve
çalışan Dart kodudur:

- `assets/enderlik/*.svg` — 6 adet vektör ikon (64×64 viewBox, gradyan parıltı gömülü). Her boyutta keskin.
- `enderlik.dart` — `Enderlik` enum'u (seviye, ad, renk, glow, asset yolu) + iki hazır widget:
  `EnderlikIcon` ve `EnderlikBadge`.
- `reference_icons.png`, `reference_showcase.html` — yalnızca görsel referans, koda dahil edilmez.

Senin (Claude Code'un) görevi bu dosyaları mevcut Flutter projesine **entegre etmek** —
yeniden çizmek değil.

## Kurulum (Flutter)

### 1. SVG paketini ekle
`pubspec.yaml` → `dependencies`:
```yaml
dependencies:
  flutter_svg: ^2.0.10
```

### 2. Asset'leri kopyala ve tanımla
`assets/enderlik/` klasörünü proje köküne kopyala, sonra `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/enderlik/
```

### 3. Dart dosyasını ekle
`enderlik.dart` dosyasını `lib/` altına (ör. `lib/models/enderlik.dart` veya
`lib/widgets/enderlik.dart`) koy. Dosyanın başındaki `import` yollarını projenin yapısına göre
gerektiğinde düzelt. Asset yolu `assets/enderlik/enderlik_<key>.svg` olarak sabittir; klasörü
farklı bir yere koyarsan `Enderlik.assetPath` getter'ını güncelle.

### 4. `flutter pub get` çalıştır.

## Kullanım

```dart
import 'enderlik.dart';

// Sadece ikon
EnderlikIcon(Enderlik.efsanevi, size: 40)

// İkon + isim rozeti (renkli pill)
EnderlikBadge(Enderlik.destansi)

// Sadece ikon, metin gizli
EnderlikBadge(Enderlik.mistik, showText: false, iconSize: 28)

// Seviyenin rengini bir Text'te kullan
Text('Ender', style: TextStyle(color: Enderlik.ender.renk))

// String / int eşleme (ör. backend'den gelen veri)
final e = Enderlik.values.byName('mistik');        // 'mistik' -> Enderlik.mistik
final byLevel = Enderlik.values[seviye - 1];        // 1..6
```

### `Enderlik` enum API
| Üye          | Tip      | Açıklama |
|--------------|----------|----------|
| `seviye`     | `int`    | 1 (sıradan) … 6 (mistik) |
| `ad`         | `String` | Türkçe görünen ad ("Efsanevi") |
| `adEn`       | `String` | İngilizce karşılık ("Legendary") |
| `renk`       | `Color`  | Seviyenin ana rengi (metin/vurgu) |
| `glow`       | `Color`  | İkonun ışık rengi (alfa dahil); sıradan saydam |
| `assetPath`  | `String` | SVG asset yolu |

## Tasarım Token'ları

### Renkler (her seviyenin ana rengi)
```
Sıradan   #9BA2AD     Destansı  #C18BFF
Sıradışı  #4ADE80     Efsanevi  #FCD34D
Ender     #5B9BFF     Mistik    #FF7088
```
Her ikon SVG'sinin içinde 5 tonluk bir renk rampası (açıktan koyuya facet gölgeleri) ve
seviyeye özel radyal parıltı gradyanı gömülüdür — ek styling gerekmez.

### Önerilen kullanım boyutları
- Liste satırı / rozet: **22–28 px**
- Kart / detay: **40–64 px**
- En küçük okunabilir boyut: **20 px** (test edildi, `reference_showcase.html` içinde mevcut)

İkonlar 64×64 viewBox'tadır ve vektördür; istenen boyuta sorunsuz ölçeklenir.

## Notlar / İsteğe Bağlı İyileştirmeler
- İkonlar şu an **statiktir**. Üst seviyeler (efsanevi, mistik) için hafif animasyon
  (parıltı nabzı, mistik aura dönüşü) istenirse, asset'leri `AnimatedBuilder` /
  `flutter_animate` ile sarmalayarak eklenebilir — SVG'leri değiştirmeye gerek yok.
- Koyu tema için tasarlandı. Açık zeminde de okunurlar ama parıltı efekti koyu zeminde
  en iyi görünür.
- `flutter_svg` SVG filtrelerini sınırlı destekler; bu yüzden parıltılar `feGaussianBlur`
  yerine radyal gradyan ile yapıldı — tüm platformlarda birebir render edilir.
