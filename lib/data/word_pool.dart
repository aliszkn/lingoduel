/// Tüm kelime verisi için tek kaynak.
///
/// Hem **LingoDuel** (oyun ekranı, lig bazlı soru havuzu) hem **LingoCards**
/// (kart paneli, seviye+kapsam filtresi) bu dosyadan beslenir.
///
/// Yapı:
/// - Her [WordEntry] bir CEFR seviyesine (A/B/C) ve seviye içi rank'a sahip.
/// - Düşük rank = daha yaygın kelime.
/// - Lig adı → max rank eşlemesi [WordPool.forLeague] içinde.
///
/// Mevcut örnek veri:
/// - A/B/C her biri 80 kelime (rank 1-80) = toplam 240 kelime.
/// - Lig tier'ları kümülatif: A100 ⊂ A250 ⊂ A500 ⊂ A1K.
/// - X100 = 20, X250 = 40, X500 = 60, X1K = 80 kelime.
/// - Veri büyüdükçe [WordPool._capForLeague] eşik değerleri güncellenebilir
///   (örn. A100 → 100 olacak şekilde).
class WordEntry {
  final String en; // İngilizce kelime (cevap)
  final String tr; // Türkçe karşılık
  final String desc; // İngilizce tanım (oyunda soru olarak gösterilir)
  final String descTr; // Türkçe tanım (oyunda 5sn kala gösterilir)
  final String others; // Sinonim / ek anlam (kartlarda ek bilgi)
  final String ex; // İngilizce örnek cümle (kartlarda gösterilir)
  final String level; // 'A' | 'B' | 'C'
  final int rank; // Seviye içi popülarite (1 = en yaygın)

  const WordEntry({
    required this.en,
    required this.tr,
    required this.desc,
    required this.descTr,
    required this.others,
    required this.ex,
    required this.level,
    required this.rank,
  });

  /// LingoCards Map-tabanlı UI için sözlük temsili.
  Map<String, dynamic> toMap() => {
    'en': en,
    'tr': tr,
    'others': others,
    'ex': ex,
    'desc': desc,
    'descTr': descTr,
    'rank': rank,
  };
}

class WordPool {
  WordPool._();

  /// Lig kodundan filtrelenmiş kelime listesi döner.
  ///
  /// Bilinmeyen lig kodu → boş liste.
  /// LingoDuel oyun ekranı bunu kullanır.
  static List<WordEntry> forLeague(String lig) {
    if (lig.isEmpty) return const [];
    final level = lig.substring(0, 1);
    final cap = _capForLeague(lig);
    if (cap == 0) return const [];
    return _all.where((w) => w.level == level && w.rank <= cap).toList();
  }

  /// Verilen seviyedeki TÜM kelimeleri döner (rank artan).
  static List<WordEntry> forLevel(String level) {
    return _all.where((w) => w.level == level).toList();
  }

  static int _capForLeague(String lig) {
    if (lig.endsWith('1K')) return 80;
    if (lig.endsWith('500')) return 60;
    if (lig.endsWith('250')) return 40;
    if (lig.endsWith('100')) return 20;
    return 0;
  }

  // dart format off
  static const List<WordEntry> _all = [
    // ── A LEVEL ────────────────────────────────────────────────────────────

    // A100 (rank 1-20)
    WordEntry(level: 'A', rank: 1,  en: 'Water',  tr: 'Su',           others: 'İçecek',         ex: 'Please give me a glass of water.', desc: 'A clear liquid that has no color, smell, or taste.', descTr: 'Renksiz, kokusuz ve tatsız sıvı; içeriz.'),
    WordEntry(level: 'A', rank: 2,  en: 'Day',    tr: 'Gün',          others: '24 saatlik dilim',ex: 'Have a nice day!',                 desc: 'A period of 24 hours.',                              descTr: '24 saatlik zaman dilimi.'),
    WordEntry(level: 'A', rank: 3,  en: 'Apple',  tr: 'Elma',         others: 'Kırmızı meyve',  ex: 'I eat an apple every morning.',    desc: 'A round red or green fruit with a stem.',            descTr: 'Kırmızı veya yeşil yuvarlak meyve.'),
    WordEntry(level: 'A', rank: 4,  en: 'Mother', tr: 'Anne',         others: 'Valide',         ex: 'My mother is a teacher.',          desc: 'A female parent.',                                   descTr: 'Çocuğun kadın ebeveyni; valide.'),
    WordEntry(level: 'A', rank: 5,  en: 'Father', tr: 'Baba',         others: 'Peder',          ex: 'My father works hard.',            desc: 'A male parent.',                                     descTr: 'Çocuğun erkek ebeveyni; peder.'),
    WordEntry(level: 'A', rank: 6,  en: 'House',  tr: 'Ev',           others: 'Konut',          ex: 'This is my house.',                desc: 'A building where people live.',                      descTr: 'İnsanların yaşadığı yapı.'),
    WordEntry(level: 'A', rank: 7,  en: 'Love',   tr: 'Aşk / sevgi',  others: 'Aşk',            ex: 'Love is everywhere.',              desc: 'A strong feeling of caring for someone.',            descTr: 'Birine duyulan güçlü sevgi hissi.'),
    WordEntry(level: 'A', rank: 8,  en: 'Family', tr: 'Aile',         others: 'Hane',           ex: 'I love my family.',                desc: 'A group of people related to each other.',           descTr: 'Birbirine bağlı insanlar topluluğu.'),
    WordEntry(level: 'A', rank: 9,  en: 'Night',  tr: 'Gece',         others: 'Akşam sonrası',  ex: 'Good night!',                      desc: 'The time when it is dark outside.',                  descTr: 'Dışarısının karanlık olduğu zaman.'),
    WordEntry(level: 'A', rank: 10, en: 'Child',  tr: 'Çocuk',        others: 'Evlat',          ex: 'The child is playing.',            desc: 'A young human being.',                               descTr: 'Genç insan; küçük yaştaki kişi.'),
    WordEntry(level: 'A', rank: 11, en: 'Car',    tr: 'Araba',        others: 'Otomobil',       ex: 'My car is red.',                   desc: 'A vehicle with four wheels used to travel.',         descTr: 'Dört tekerlekli yolcu taşıtı.'),
    WordEntry(level: 'A', rank: 12, en: 'School', tr: 'Okul',         others: 'Eğitim kurumu',  ex: 'We go to school every day.',       desc: 'A place where children learn.',                      descTr: 'Çocukların eğitim gördüğü yer.'),
    WordEntry(level: 'A', rank: 13, en: 'Milk',   tr: 'Süt',          others: 'Beyaz içecek',   ex: 'I drink milk in the morning.',     desc: 'A white liquid produced by cows.',                   descTr: 'İnek ve benzeri hayvanların verdiği beyaz sıvı.'),
    WordEntry(level: 'A', rank: 14, en: 'Eat',    tr: 'Yemek (eylem)',others: 'Tüketmek',       ex: 'I eat lunch at noon.',             desc: 'To put food in the mouth and swallow it.',           descTr: 'Gıdayı ağıza alıp yutmak.'),
    WordEntry(level: 'A', rank: 15, en: 'Sun',    tr: 'Güneş',        others: 'Yıldız',         ex: 'The sun is bright today.',         desc: 'The bright star we see in the sky during the day.',  descTr: 'Gündüz gökyüzünde gördüğümüz parlak yıldız.'),
    WordEntry(level: 'A', rank: 16, en: 'Big',    tr: 'Büyük',        others: 'İri',            ex: 'This is a big tree.',              desc: 'Of a large size; not small.',                        descTr: 'Büyük boyutlu; küçük olmayan.'),
    WordEntry(level: 'A', rank: 17, en: 'Moon',   tr: 'Ay',           others: 'Uydu',           ex: 'The moon is full tonight.',        desc: 'The bright object we see in the sky at night.',      descTr: 'Geceleri gökyüzünde gördüğümüz parlak gök cismi.'),
    WordEntry(level: 'A', rank: 18, en: 'Small',  tr: 'Küçük',        others: 'Ufak',           ex: 'A small cat.',                     desc: 'Of a little size; not big.',                         descTr: 'Küçük boyutlu; büyük olmayan.'),
    WordEntry(level: 'A', rank: 19, en: 'Friend', tr: 'Arkadaş',      others: 'Dost',           ex: 'She is my best friend.',           desc: 'A person you like and enjoy being with.',            descTr: 'Sevdiğin ve birlikte olmaktan hoşlandığın kişi.'),
    WordEntry(level: 'A', rank: 20, en: 'Dog',    tr: 'Köpek',        others: 'Evcil hayvan',   ex: 'The dog is barking.',              desc: 'A common pet that barks.',                           descTr: 'Havlayan evcil hayvan.'),

    // A250 (rank 21-40)
    WordEntry(level: 'A', rank: 21, en: 'Bread',     tr: 'Ekmek',     others: 'Gıda',           ex: 'Fresh bread is delicious.',        desc: 'A food made from flour and baked in an oven.',                descTr: 'Undan yapılan, fırında pişirilen yiyecek.'),
    WordEntry(level: 'A', rank: 22, en: 'Cat',       tr: 'Kedi',      others: 'Evcil hayvan',   ex: 'The cat is sleeping.',             desc: 'A small furry pet that says meow.',                           descTr: 'Miyavlayan tüylü evcil hayvan.'),
    WordEntry(level: 'A', rank: 23, en: 'Walk',      tr: 'Yürümek',   others: 'Adım atmak',     ex: 'I walk to work.',                  desc: 'To move forward on foot at a normal pace.',                   descTr: 'Normal hızda ayakla ilerlemek.'),
    WordEntry(level: 'A', rank: 24, en: 'Door',      tr: 'Kapı',      others: 'Giriş',          ex: 'Close the door, please.',          desc: 'A movable panel used to enter or leave a room.',              descTr: 'Odaya girip çıkmak için kullanılan açıklık.'),
    WordEntry(level: 'A', rank: 25, en: 'Run',       tr: 'Koşmak',    others: 'Hızla gitmek',   ex: 'They run every morning.',          desc: 'To move very quickly on foot.',                               descTr: 'Ayakla çok hızlı hareket etmek.'),
    WordEntry(level: 'A', rank: 26, en: 'Book',      tr: 'Kitap',     others: 'Eser',           ex: 'I like to read a book.',           desc: 'A set of printed pages bound together.',                      descTr: 'Bir araya getirilmiş basılı sayfalar.'),
    WordEntry(level: 'A', rank: 27, en: 'Sleep',     tr: 'Uyumak',    others: 'Dinlenmek',      ex: 'I sleep eight hours.',             desc: 'To rest with your eyes closed.',                              descTr: 'Gözler kapalı şekilde dinlenmek.'),
    WordEntry(level: 'A', rank: 28, en: 'Happy',     tr: 'Mutlu',     others: 'Sevinçli',       ex: 'She is very happy today.',         desc: 'Feeling joy or pleasure.',                                    descTr: 'Sevinç veya neşe hisseden.'),
    WordEntry(level: 'A', rank: 29, en: 'Window',    tr: 'Pencere',   others: 'Cam açıklık',    ex: 'Open the window.',                 desc: 'An opening in a wall with glass.',                            descTr: 'Duvardaki camlı açıklık.'),
    WordEntry(level: 'A', rank: 30, en: 'Sad',       tr: 'Üzgün',     others: 'Mutsuz',         ex: 'He looks sad.',                    desc: 'Feeling unhappy or sorrowful.',                               descTr: 'Mutsuz veya kederli hisseden.'),
    WordEntry(level: 'A', rank: 31, en: 'Tree',      tr: 'Ağaç',      others: 'Ağaç bitkisi',   ex: 'An old oak tree.',                 desc: 'A tall plant with a wooden trunk and branches.',              descTr: 'Uzun gövdesi ve dalları olan büyük bitki.'),
    WordEntry(level: 'A', rank: 32, en: 'Fish',      tr: 'Balık',     others: 'Su canlısı',     ex: 'We caught a fish.',                desc: 'An animal that lives in water and has fins.',                 descTr: 'Suda yaşayan, yüzgeçli hayvan.'),
    WordEntry(level: 'A', rank: 33, en: 'Red',       tr: 'Kırmızı',   others: 'Al renk',        ex: 'A red rose.',                      desc: 'The color of blood or fire.',                                 descTr: 'Kan veya ateş rengi.'),
    WordEntry(level: 'A', rank: 34, en: 'Blue',      tr: 'Mavi',      others: 'Gök rengi',      ex: 'The blue sky.',                    desc: 'The color of the sky on a clear day.',                        descTr: 'Berrak günde gökyüzünün rengi.'),
    WordEntry(level: 'A', rank: 35, en: 'Green',     tr: 'Yeşil',     others: 'Yemyeşil',       ex: 'Green leaves in spring.',          desc: 'The color of grass and leaves.',                              descTr: 'Çimen ve yaprak rengi.'),
    WordEntry(level: 'A', rank: 36, en: 'White',     tr: 'Beyaz',     others: 'Beyaz renk',     ex: 'A white shirt.',                   desc: 'The color of snow or milk.',                                  descTr: 'Kar veya süt rengi.'),
    WordEntry(level: 'A', rank: 37, en: 'Black',     tr: 'Siyah',     others: 'Kara renk',      ex: 'A black cat.',                     desc: 'The darkest color; the opposite of white.',                   descTr: 'En koyu renk; beyazın zıttı.'),
    WordEntry(level: 'A', rank: 38, en: 'Hot',       tr: 'Sıcak',     others: 'Yakıcı',         ex: 'Hot coffee.',                      desc: 'Having a high temperature.',                                  descTr: 'Yüksek ısıya sahip.'),
    WordEntry(level: 'A', rank: 39, en: 'Cold',      tr: 'Soğuk',     others: 'Buz gibi',       ex: 'A cold day in winter.',            desc: 'Having a low temperature.',                                   descTr: 'Düşük ısıya sahip.'),
    WordEntry(level: 'A', rank: 40, en: 'Good',      tr: 'İyi',       others: 'Güzel',          ex: 'A good idea.',                     desc: 'Of high quality; pleasant.',                                  descTr: 'Kaliteli; hoş olan.'),

    // A500 (rank 41-60)
    WordEntry(level: 'A', rank: 41, en: 'Bad',       tr: 'Kötü',        others: 'Fena',            ex: 'Bad weather today.',           desc: 'Of low quality; not pleasant.',                              descTr: 'Kalitesiz; hoş olmayan.'),
    WordEntry(level: 'A', rank: 42, en: 'Easy',      tr: 'Kolay',       others: 'Basit',           ex: 'The test was easy.',           desc: 'Not difficult to do.',                                       descTr: 'Yapması zor olmayan.'),
    WordEntry(level: 'A', rank: 43, en: 'Difficult', tr: 'Zor',         others: 'Çetin',           ex: 'This problem is difficult.',   desc: 'Hard to do or understand.',                                  descTr: 'Yapması veya anlaması zor.'),
    WordEntry(level: 'A', rank: 44, en: 'Plan',      tr: 'Plan',        others: 'Tasarı',          ex: 'We need a good plan.',         desc: 'A set of ideas about what to do.',                           descTr: 'Ne yapılacağına dair fikirler dizisi.'),
    WordEntry(level: 'A', rank: 45, en: 'Journey',   tr: 'Yolculuk',    others: 'Seyahat',         ex: 'A long journey home.',         desc: 'A trip from one place to another.',                          descTr: 'Bir yerden başka yere gidiş.'),
    WordEntry(level: 'A', rank: 46, en: 'Country',   tr: 'Ülke',        others: 'Vatan',           ex: 'Which country are you from?',  desc: 'A nation with its own government.',                          descTr: 'Kendi hükümeti olan bağımsız bölge.'),
    WordEntry(level: 'A', rank: 47, en: 'Future',    tr: 'Gelecek',     others: 'İleriki zaman',   ex: 'The future is bright.',        desc: 'The time that has not yet happened.',                        descTr: 'Henüz yaşanmamış zaman.'),
    WordEntry(level: 'A', rank: 48, en: 'Past',      tr: 'Geçmiş',      others: 'Eski zaman',      ex: 'Forget the past.',             desc: 'The time that has already happened.',                        descTr: 'Yaşanmış, geride kalmış zaman.'),
    WordEntry(level: 'A', rank: 49, en: 'Decision',  tr: 'Karar',       others: 'Hüküm',           ex: 'It was a tough decision.',     desc: 'A choice you make after thinking.',                          descTr: 'Düşünerek verilen seçim.'),
    WordEntry(level: 'A', rank: 50, en: 'Modern',    tr: 'Modern',      others: 'Çağdaş',          ex: 'A modern building.',           desc: 'Belonging to the present time; current.',                    descTr: 'Şimdiki zamana ait; çağdaş.'),
    WordEntry(level: 'A', rank: 51, en: 'Travel',    tr: 'Seyahat etmek',others: 'Gezmek',         ex: 'I love to travel.',            desc: 'To go from one place to another, often far.',                descTr: 'Bir yerden başka yere gitmek.'),
    WordEntry(level: 'A', rank: 52, en: 'Memory',    tr: 'Hatıra',      others: 'Anı',             ex: 'A happy childhood memory.',    desc: 'Something you remember from the past.',                      descTr: 'Geçmişten hatırlanan şey.'),
    WordEntry(level: 'A', rank: 53, en: 'Allow',     tr: 'İzin vermek', others: 'Onaylamak',       ex: 'Smoking is not allowed.',      desc: 'To give permission for something.',                          descTr: 'Bir şeye onay vermek.'),
    WordEntry(level: 'A', rank: 54, en: 'Dream',     tr: 'Rüya / hayal',others: 'Tasavvur',        ex: 'Follow your dreams.',          desc: 'Images or stories your mind creates when sleeping.',         descTr: 'Uyurken zihnin yarattığı görüntüler.'),
    WordEntry(level: 'A', rank: 55, en: 'Choice',    tr: 'Seçim',       others: 'Tercih',          ex: 'You have a choice.',           desc: 'The act of picking one option from many.',                   descTr: 'Birkaç seçenekten birini seçme.'),
    WordEntry(level: 'A', rank: 56, en: 'Famous',    tr: 'Ünlü',        others: 'Tanınmış',        ex: 'A famous singer.',             desc: 'Known by many people.',                                      descTr: 'Çok kişi tarafından tanınan.'),
    WordEntry(level: 'A', rank: 57, en: 'Holiday',   tr: 'Tatil',       others: 'İzin günü',       ex: 'Happy holidays!',              desc: 'A day or period of rest from work.',                         descTr: 'İşten uzak dinlenme zamanı.'),
    WordEntry(level: 'A', rank: 58, en: 'Healthy',   tr: 'Sağlıklı',    others: 'Sıhhatli',        ex: 'Eat healthy food.',            desc: 'In good physical condition.',                                descTr: 'İyi fiziksel durumda olan.'),
    WordEntry(level: 'A', rank: 59, en: 'Promise',   tr: 'Söz vermek',  others: 'Vaat',            ex: 'I promise to come.',           desc: 'To say you will definitely do something.',                   descTr: 'Bir şeyi kesinlikle yapacağını söylemek.'),
    WordEntry(level: 'A', rank: 60, en: 'Goal',      tr: 'Hedef',       others: 'Amaç',            ex: 'Set a clear goal.',            desc: 'Something you want to achieve.',                             descTr: 'Ulaşmak istediğin amaç.'),

    // A1K (rank 61-80)
    WordEntry(level: 'A', rank: 61, en: 'Strange',  tr: 'Garip',     others: 'Tuhaf',          ex: 'A strange noise.',                 desc: 'Unusual or unexpected.',                                       descTr: 'Olağandışı veya beklenmeyen.'),
    WordEntry(level: 'A', rank: 62, en: 'Bridge',   tr: 'Köprü',     others: 'Geçit',          ex: 'Cross the bridge.',                desc: 'A structure that lets you cross over a river or road.',        descTr: 'Nehir veya yol üzerinden geçiş yapısı.'),
    WordEntry(level: 'A', rank: 63, en: 'Useful',   tr: 'Faydalı',   others: 'Yararlı',        ex: 'A useful tool.',                   desc: 'Helpful for doing something.',                                 descTr: 'Bir iş için yararlı.'),
    WordEntry(level: 'A', rank: 64, en: 'Notice',   tr: 'Fark etmek',others: 'Algılamak',      ex: 'Did you notice that?',             desc: 'To see or become aware of something.',                         descTr: 'Bir şeyi görmek veya farkına varmak.'),
    WordEntry(level: 'A', rank: 65, en: 'Suggest',  tr: 'Önermek',   others: 'Teklif etmek',   ex: 'I suggest we leave now.',          desc: 'To offer an idea for someone to consider.',                    descTr: 'Düşünülmesi için fikir sunmak.'),
    WordEntry(level: 'A', rank: 66, en: 'Improve',  tr: 'Geliştirmek',others: 'İlerletmek',    ex: 'Practice helps you improve.',      desc: 'To make better.',                                              descTr: 'Daha iyi hâle getirmek.'),
    WordEntry(level: 'A', rank: 67, en: 'Boring',   tr: 'Sıkıcı',    others: 'Bunaltıcı',      ex: 'The movie was boring.',            desc: 'Not interesting; dull.',                                       descTr: 'İlginç olmayan; bunaltıcı.'),
    WordEntry(level: 'A', rank: 68, en: 'Mention',  tr: 'Bahsetmek', others: 'Söz etmek',      ex: 'Mention it briefly.',              desc: 'To say or write something briefly.',                           descTr: 'Bir şeyi kısaca söylemek veya yazmak.'),
    WordEntry(level: 'A', rank: 69, en: 'Crowded',  tr: 'Kalabalık', others: 'Yoğun',          ex: 'A crowded street.',                desc: 'Full of people.',                                              descTr: 'İnsanla dolu.'),
    WordEntry(level: 'A', rank: 70, en: 'Polite',   tr: 'Kibar',     others: 'Nazik',          ex: 'Be polite to elders.',             desc: 'Showing good manners.',                                        descTr: 'İyi davranışlar gösteren.'),
    WordEntry(level: 'A', rank: 71, en: 'Music',    tr: 'Müzik',     others: 'Melodi',         ex: 'I love music.',                    desc: 'Sounds arranged in a pleasing way.',                           descTr: 'Hoş şekilde düzenlenmiş sesler.'),
    WordEntry(level: 'A', rank: 72, en: 'Dance',    tr: 'Dans',      others: 'Dans etmek',     ex: 'They dance together.',             desc: 'To move your body to music.',                                  descTr: 'Müzikle vücudunu hareket ettirmek.'),
    WordEntry(level: 'A', rank: 73, en: 'Garden',   tr: 'Bahçe',     others: 'Bahçe alanı',    ex: 'Flowers in the garden.',           desc: 'A piece of land where plants and flowers grow.',               descTr: 'Bitki ve çiçek yetişen alan.'),
    WordEntry(level: 'A', rank: 74, en: 'River',    tr: 'Nehir',     others: 'Akarsu',         ex: 'A long river.',                    desc: 'A large natural stream of water.',                             descTr: 'Büyük doğal su akışı.'),
    WordEntry(level: 'A', rank: 75, en: 'Mountain', tr: 'Dağ',       others: 'Tepe',           ex: 'A high mountain.',                 desc: 'A very high hill, often with a peak.',                         descTr: 'Çok yüksek doğal yükselti.'),
    WordEntry(level: 'A', rank: 76, en: 'Beach',    tr: 'Plaj',      others: 'Sahil',          ex: 'A sunny beach.',                   desc: 'An area of sand or stones next to the sea.',                   descTr: 'Deniz kenarındaki kumlu alan.'),
    WordEntry(level: 'A', rank: 77, en: 'Summer',   tr: 'Yaz',       others: 'Sıcak mevsim',   ex: 'Summer vacation.',                 desc: 'The warmest season of the year.',                              descTr: 'Yılın en sıcak mevsimi.'),
    WordEntry(level: 'A', rank: 78, en: 'Winter',   tr: 'Kış',       others: 'Soğuk mevsim',   ex: 'Winter is here.',                  desc: 'The coldest season of the year.',                              descTr: 'Yılın en soğuk mevsimi.'),
    WordEntry(level: 'A', rank: 79, en: 'Color',    tr: 'Renk',      others: 'Boya tonu',      ex: 'My favorite color.',               desc: 'A property of light such as red, blue, or green.',             descTr: 'Kırmızı, mavi, yeşil gibi ışık özelliği.'),
    WordEntry(level: 'A', rank: 80, en: 'Picture',  tr: 'Resim',     others: 'Görsel',         ex: 'A nice picture.',                  desc: 'A drawing, painting, or photograph.',                          descTr: 'Çizim, tablo veya fotoğraf.'),

    // ── B LEVEL ────────────────────────────────────────────────────────────

    // B100 (rank 1-20)
    WordEntry(level: 'B', rank: 1,  en: 'Result',      tr: 'Sonuç',           others: 'Netice',         ex: 'The final result is positive.',     desc: 'What happens because of an action.',                           descTr: 'Bir eylem sonucu ortaya çıkan.'),
    WordEntry(level: 'B', rank: 2,  en: 'Reason',      tr: 'Sebep',           others: 'Gerekçe',        ex: 'There is no reason to worry.',      desc: 'The cause or explanation for something.',                      descTr: 'Bir şeyin nedeni veya açıklaması.'),
    WordEntry(level: 'B', rank: 3,  en: 'Achieve',     tr: 'Başarmak',        others: 'Elde etmek',     ex: 'Achieve your dreams.',              desc: 'To succeed in doing something difficult.',                     descTr: 'Zor bir şeyde başarılı olmak.'),
    WordEntry(level: 'B', rank: 4,  en: 'Consider',    tr: 'Düşünmek',        others: 'Değerlendirmek', ex: 'Please consider my offer.',         desc: 'To think carefully about something.',                          descTr: 'Bir şeyi dikkatle düşünmek.'),
    WordEntry(level: 'B', rank: 5,  en: 'Opportunity', tr: 'Fırsat',          others: 'İmkan',          ex: 'A golden opportunity.',             desc: 'A chance to do something good.',                               descTr: 'İyi bir şey yapmak için imkân.'),
    WordEntry(level: 'B', rank: 6,  en: 'Manage',      tr: 'Yönetmek',        others: 'İdare etmek',    ex: 'She manages the team well.',        desc: 'To control or direct something.',                              descTr: 'Bir şeyi kontrol veya idare etmek.'),
    WordEntry(level: 'B', rank: 7,  en: 'Discover',    tr: 'Keşfetmek',       others: 'Bulmak',         ex: 'They discovered a new species.',    desc: 'To find something for the first time.',                        descTr: 'Bir şeyi ilk kez bulmak.'),
    WordEntry(level: 'B', rank: 8,  en: 'Method',      tr: 'Yöntem',          others: 'Usul',           ex: 'A scientific method.',              desc: 'A particular way of doing something.',                         descTr: 'Bir işi yapmanın belli bir yolu.'),
    WordEntry(level: 'B', rank: 9,  en: 'Behavior',    tr: 'Davranış',        others: 'Tavır',          ex: 'His behavior is strange.',          desc: 'The way a person acts.',                                       descTr: 'Kişinin hareket ediş biçimi.'),
    WordEntry(level: 'B', rank: 10, en: 'Effort',      tr: 'Çaba',            others: 'Gayret',         ex: 'Make an effort.',                   desc: 'Hard work to achieve something.',                              descTr: 'Bir şeyi başarmak için sıkı çalışma.'),
    WordEntry(level: 'B', rank: 11, en: 'Solution',    tr: 'Çözüm',           others: 'Çare',           ex: 'I found a solution.',               desc: 'A way to solve a problem.',                                    descTr: 'Bir sorunun çözüm yolu.'),
    WordEntry(level: 'B', rank: 12, en: 'Avoid',       tr: 'Kaçınmak',        others: 'Sakınmak',       ex: 'Avoid junk food.',                  desc: 'To stay away from something.',                                 descTr: 'Bir şeyden uzak durmak.'),
    WordEntry(level: 'B', rank: 13, en: 'Influence',   tr: 'Etki',            others: 'Tesir',          ex: 'A bad influence.',                  desc: 'The power to affect someone or something.',                    descTr: 'Birini veya bir şeyi etkileme gücü.'),
    WordEntry(level: 'B', rank: 14, en: 'Reduce',      tr: 'Azaltmak',        others: 'İndirgemek',     ex: 'Reduce your sugar intake.',         desc: 'To make smaller in amount or size.',                           descTr: 'Miktarı veya boyutu küçültmek.'),
    WordEntry(level: 'B', rank: 15, en: 'Argue',       tr: 'Tartışmak',       others: 'Münakaşa etmek', ex: 'They argue all the time.',          desc: 'To disagree with someone, often loudly.',                      descTr: 'Biriyle anlaşmazlığa düşmek.'),
    WordEntry(level: 'B', rank: 16, en: 'Challenge',   tr: 'Meydan okuma',    others: 'Zorluk',         ex: 'A new challenge awaits.',           desc: 'Something difficult that tests your ability.',                 descTr: 'Yeteneğini sınayan zorluk.'),
    WordEntry(level: 'B', rank: 17, en: 'Society',     tr: 'Toplum',          others: 'Cemiyet',        ex: 'Modern society is complex.',        desc: 'A large group of people living together.',                     descTr: 'Birlikte yaşayan büyük insan grubu.'),
    WordEntry(level: 'B', rank: 18, en: 'Realize',     tr: 'Fark etmek',      others: 'Anlamak',        ex: 'I realize my mistake.',             desc: 'To suddenly understand something.',                            descTr: 'Bir şeyi birdenbire anlamak.'),
    WordEntry(level: 'B', rank: 19, en: 'Reaction',    tr: 'Tepki',           others: 'Karşı çıkış',    ex: 'A quick reaction.',                 desc: 'What you do or feel in response to something.',                descTr: 'Bir şeye karşı verilen yanıt.'),
    WordEntry(level: 'B', rank: 20, en: 'Curious',     tr: 'Meraklı',         others: 'Merak eden',     ex: 'Cats are curious.',                 desc: 'Wanting to know or learn about something.',                    descTr: 'Bir şeyi öğrenmek isteyen.'),

    // B250 (rank 21-40)
    WordEntry(level: 'B', rank: 21, en: 'Encourage',   tr: 'Cesaretlendirmek',others: 'Teşvik etmek',   ex: 'Encourage your friends.',           desc: 'To give someone confidence or hope.',                          descTr: 'Birine güven veya umut vermek.'),
    WordEntry(level: 'B', rank: 22, en: 'Recognize',   tr: 'Tanımak',         others: 'Ayırt etmek',    ex: 'I recognize that voice.',           desc: 'To know someone or something you have seen before.',           descTr: 'Önceden gördüğünü hatırlamak.'),
    WordEntry(level: 'B', rank: 23, en: 'Concern',     tr: 'Endişe',          others: 'Kaygı',          ex: 'A growing concern.',                desc: 'A feeling of worry.',                                          descTr: 'Kaygı hissi.'),
    WordEntry(level: 'B', rank: 24, en: 'Express',     tr: 'İfade etmek',     others: 'Dile getirmek',  ex: 'Express your feelings.',            desc: 'To show your thoughts or feelings.',                           descTr: 'Düşünce veya hisleri dışa vurmak.'),
    WordEntry(level: 'B', rank: 25, en: 'Confidence',  tr: 'Özgüven',         others: 'Güven',          ex: 'She speaks with confidence.',       desc: 'Belief in your own ability.',                                  descTr: 'Kendi yeteneğine olan inanç.'),
    WordEntry(level: 'B', rank: 26, en: 'Independent', tr: 'Bağımsız',        others: 'Özerk',          ex: 'An independent thinker.',           desc: 'Not controlled by others.',                                    descTr: 'Başkalarınca kontrol edilmeyen.'),
    WordEntry(level: 'B', rank: 27, en: 'Pretend',     tr: 'Numara yapmak',   others: 'Mış gibi yapmak',ex: 'Pretend to be calm.',               desc: 'To act as if something is true when it is not.',               descTr: 'Bir şey gerçek değilken öyleymiş gibi davranmak.'),
    WordEntry(level: 'B', rank: 28, en: 'Approve',     tr: 'Onaylamak',       others: 'Tasdik etmek',   ex: 'The boss approved the plan.',       desc: 'To agree that something is good or acceptable.',               descTr: 'Bir şeyin iyi olduğunu kabul etmek.'),
    WordEntry(level: 'B', rank: 29, en: 'Sensitive',   tr: 'Hassas',          others: 'Duyarlı',        ex: 'A sensitive topic.',                desc: 'Easily affected by feelings or situations.',                   descTr: 'His ve durumlardan kolay etkilenen.'),
    WordEntry(level: 'B', rank: 30, en: 'Determine',   tr: 'Belirlemek',      others: 'Saptamak',       ex: 'Determine the cause.',              desc: 'To decide or find out exactly.',                               descTr: 'Kesin olarak karar vermek veya bulmak.'),
    WordEntry(level: 'B', rank: 31, en: 'Establish',   tr: 'Kurmak',          others: 'Tesis etmek',    ex: 'Establish a new rule.',             desc: 'To start or create something that will last.',                 descTr: 'Kalıcı bir şey başlatmak veya yaratmak.'),
    WordEntry(level: 'B', rank: 32, en: 'Maintain',    tr: 'Korumak',         others: 'Sürdürmek',      ex: 'Maintain a good attitude.',         desc: 'To keep something in good condition.',                         descTr: 'Bir şeyi iyi durumda tutmak.'),
    WordEntry(level: 'B', rank: 33, en: 'Demonstrate', tr: 'Göstermek',       others: 'Kanıtlamak',     ex: 'Demonstrate the method.',           desc: 'To show clearly how something works.',                         descTr: 'Bir şeyin nasıl çalıştığını net göstermek.'),
    WordEntry(level: 'B', rank: 34, en: 'Compromise',  tr: 'Uzlaşma',         others: 'Taviz',          ex: 'Reach a compromise.',               desc: 'An agreement where each side gives up something.',             descTr: 'Her tarafın taviz verdiği anlaşma.'),
    WordEntry(level: 'B', rank: 35, en: 'Hesitate',    tr: 'Tereddüt etmek',  others: 'Duraksamak',     ex: 'Do not hesitate to ask.',           desc: 'To pause before doing or saying something.',                   descTr: 'Bir şeyi yapmadan önce durmak.'),
    WordEntry(level: 'B', rank: 36, en: 'Indicate',    tr: 'Belirtmek',       others: 'Göstermek',      ex: 'The arrow indicates north.',        desc: 'To point out or show.',                                        descTr: 'İşaret etmek veya göstermek.'),
    WordEntry(level: 'B', rank: 37, en: 'Implement',   tr: 'Uygulamak',       others: 'Hayata geçirmek',ex: 'Implement the policy.',             desc: 'To put a plan or decision into action.',                       descTr: 'Plan veya kararı eyleme dökmek.'),
    WordEntry(level: 'B', rank: 38, en: 'Acquire',     tr: 'Edinmek',         others: 'Elde etmek',     ex: 'Acquire new skills.',               desc: 'To get or obtain something.',                                  descTr: 'Bir şeyi elde etmek.'),
    WordEntry(level: 'B', rank: 39, en: 'Adequate',    tr: 'Yeterli',         others: 'Kafi',           ex: 'Adequate preparation is key.',      desc: 'Enough for what is needed.',                                   descTr: 'Gereken kadar; kâfi.'),
    WordEntry(level: 'B', rank: 40, en: 'Diverse',     tr: 'Çeşitli',         others: 'Farklı türlerde',ex: 'A diverse team.',                   desc: 'Including many different kinds.',                              descTr: 'Farklı türleri içeren.'),

    // B500 (rank 41-60)
    WordEntry(level: 'B', rank: 41, en: 'Acknowledge', tr: 'Kabul etmek',         others: 'Tanımak',           ex: 'Acknowledge your mistakes.',         desc: 'To accept or admit that something is true.',                descTr: 'Bir şeyin doğru olduğunu kabul etmek.'),
    WordEntry(level: 'B', rank: 42, en: 'Genuine',     tr: 'Hakiki',              others: 'Gerçek',            ex: 'A genuine smile.',                   desc: 'Real and not fake.',                                        descTr: 'Gerçek ve sahte olmayan.'),
    WordEntry(level: 'B', rank: 43, en: 'Resolve',     tr: 'Çözmek',              others: 'Karara bağlamak',   ex: 'Resolve the conflict.',              desc: 'To find an answer to a problem.',                           descTr: 'Bir soruna cevap bulmak.'),
    WordEntry(level: 'B', rank: 44, en: 'Pursue',      tr: 'Peşinden gitmek',     others: 'Sürdürmek',         ex: 'Pursue your passion.',               desc: 'To follow or try to achieve something.',                    descTr: 'Bir şeyin peşine düşmek.'),
    WordEntry(level: 'B', rank: 45, en: 'Distinguish', tr: 'Ayırt etmek',         others: 'Fark etmek',        ex: 'Distinguish right from wrong.',      desc: 'To see the difference between things.',                     descTr: 'Şeyler arasındaki farkı görmek.'),
    WordEntry(level: 'B', rank: 46, en: 'Tendency',    tr: 'Eğilim',              others: 'Meyil',             ex: 'A growing tendency.',                desc: 'A natural way of behaving.',                                descTr: 'Doğal davranış biçimi.'),
    WordEntry(level: 'B', rank: 47, en: 'Anticipate',  tr: 'Önceden tahmin etmek',others: 'Beklemek',          ex: 'Anticipate the problem.',            desc: 'To expect something to happen.',                            descTr: 'Bir şeyin olacağını beklemek.'),
    WordEntry(level: 'B', rank: 48, en: 'Subsequent',  tr: 'Sonraki',             others: 'Müteakip',          ex: 'Subsequent events proved him right.',desc: 'Coming after something else.',                              descTr: 'Bir şeyden sonra gelen.'),
    WordEntry(level: 'B', rank: 49, en: 'Vague',       tr: 'Belirsiz',            others: 'Müphem',            ex: 'A vague answer.',                    desc: 'Not clear or specific.',                                    descTr: 'Net veya kesin olmayan.'),
    WordEntry(level: 'B', rank: 50, en: 'Substantial', tr: 'Önemli',              others: 'Hatırı sayılır',    ex: 'Substantial progress.',              desc: 'Large in amount or importance.',                            descTr: 'Miktar veya önem olarak büyük.'),
    WordEntry(level: 'B', rank: 51, en: 'Convey',      tr: 'İletmek',             others: 'Aktarmak',          ex: 'Convey my regards.',                 desc: 'To communicate a message or feeling.',                      descTr: 'Bir mesaj veya his aktarmak.'),
    WordEntry(level: 'B', rank: 52, en: 'Sophisticated',tr: 'Karmaşık',           others: 'Gelişmiş',          ex: 'A sophisticated system.',            desc: 'Highly developed or complex.',                              descTr: 'İleri düzeyde gelişmiş.'),
    WordEntry(level: 'B', rank: 53, en: 'Inevitable',  tr: 'Kaçınılmaz',          others: 'Mukadder',          ex: 'Change is inevitable.',              desc: 'Certain to happen; unavoidable.',                           descTr: 'Olması kesin; engellenemez.'),
    WordEntry(level: 'B', rank: 54, en: 'Reluctant',   tr: 'İsteksiz',            others: 'Çekingen',          ex: 'Reluctant to agree.',                desc: 'Not willing to do something.',                              descTr: 'Bir şeyi yapmaya gönülsüz.'),
    WordEntry(level: 'B', rank: 55, en: 'Resemble',    tr: 'Benzemek',            others: 'Andırmak',          ex: 'You resemble your father.',          desc: 'To look like someone or something.',                        descTr: 'Birine veya bir şeye benzer görünmek.'),
    WordEntry(level: 'B', rank: 56, en: 'Subtle',      tr: 'İnce',                others: 'Hafif',             ex: 'A subtle difference.',               desc: 'Not obvious; hard to notice.',                              descTr: 'Bariz olmayan; fark edilmesi zor.'),
    WordEntry(level: 'B', rank: 57, en: 'Coherent',    tr: 'Tutarlı',             others: 'Bağlantılı',        ex: 'A coherent argument.',               desc: 'Logical and well-organized.',                               descTr: 'Mantıklı ve düzgün.'),
    WordEntry(level: 'B', rank: 58, en: 'Evident',     tr: 'Belli',               others: 'Aşikar',            ex: 'Evident from the start.',            desc: 'Clear and easy to see.',                                    descTr: 'Açık ve görmesi kolay.'),
    WordEntry(level: 'B', rank: 59, en: 'Justify',     tr: 'Haklı çıkarmak',      others: 'Mazur göstermek',   ex: 'Justify your actions.',              desc: 'To show that something is right.',                          descTr: 'Bir şeyin doğru olduğunu göstermek.'),
    WordEntry(level: 'B', rank: 60, en: 'Occur',       tr: 'Meydana gelmek',      others: 'Vuku bulmak',       ex: 'Accidents can occur.',               desc: 'To happen.',                                                descTr: 'Olmak; gerçekleşmek.'),

    // B1K (rank 61-80)
    WordEntry(level: 'B', rank: 61, en: 'Represent',   tr: 'Temsil etmek',    others: 'Vekalet etmek',  ex: 'She represents her team.',          desc: 'To stand for or act on behalf of something.',                 descTr: 'Bir şey adına hareket etmek.'),
    WordEntry(level: 'B', rank: 62, en: 'Suppose',     tr: 'Farz etmek',      others: 'Sanmak',         ex: 'Suppose it rains tomorrow.',        desc: 'To assume something is true.',                                descTr: 'Bir şeyin doğru olduğunu varsaymak.'),
    WordEntry(level: 'B', rank: 63, en: 'Vary',        tr: 'Değişmek',        others: 'Farklılaşmak',   ex: 'Prices vary by region.',            desc: 'To be different from each other.',                            descTr: 'Birbirinden farklı olmak.'),
    WordEntry(level: 'B', rank: 64, en: 'Depend',      tr: 'Bağlı olmak',     others: 'Dayanmak',       ex: 'Success depends on effort.',        desc: 'To rely on someone or something.',                            descTr: 'Birine veya bir şeye dayanmak.'),
    WordEntry(level: 'B', rank: 65, en: 'Prefer',      tr: 'Tercih etmek',    others: 'Yeğlemek',       ex: 'I prefer tea to coffee.',           desc: 'To like one thing more than another.',                        descTr: 'Bir şeyi diğerinden daha çok sevmek.'),
    WordEntry(level: 'B', rank: 66, en: 'Predict',     tr: 'Öngörmek',        others: 'Kestirmek',      ex: 'Predict the outcome.',              desc: 'To say what will happen in the future.',                      descTr: 'Gelecekte ne olacağını söylemek.'),
    WordEntry(level: 'B', rank: 67, en: 'Conclude',    tr: 'Sonuç çıkarmak',  others: 'Bitirmek',       ex: 'Conclude the meeting.',             desc: 'To decide something after thinking about it.',                descTr: 'Düşündükten sonra karara varmak.'),
    WordEntry(level: 'B', rank: 68, en: 'Observe',     tr: 'Gözlemlemek',     others: 'Müşahede etmek', ex: 'Observe the stars.',                desc: 'To watch carefully.',                                         descTr: 'Dikkatle izlemek.'),
    WordEntry(level: 'B', rank: 69, en: 'Explore',     tr: 'Araştırmak',      others: 'Keşfe çıkmak',   ex: 'Explore new lands.',                desc: 'To travel through an area to learn about it.',                descTr: 'Bir bölgeyi öğrenmek için gezmek.'),
    WordEntry(level: 'B', rank: 70, en: 'Assume',      tr: 'Varsaymak',       others: 'Saymak',         ex: 'Assume you are right.',             desc: 'To accept something as true without proof.',                  descTr: 'Kanıt olmadan doğru kabul etmek.'),
    WordEntry(level: 'B', rank: 71, en: 'Claim',       tr: 'İddia etmek',     others: 'Talep etmek',    ex: 'He claims to know her.',            desc: 'To say something is true without proof.',                     descTr: 'Kanıtsız bir şey söylemek.'),
    WordEntry(level: 'B', rank: 72, en: 'Illustrate',  tr: 'Resmetmek',       others: 'Örneklemek',     ex: 'Illustrate the idea.',              desc: 'To explain by using examples or pictures.',                   descTr: 'Örnek veya resimle açıklamak.'),
    WordEntry(level: 'B', rank: 73, en: 'Examine',     tr: 'İncelemek',       others: 'Tetkik etmek',   ex: 'Examine the evidence.',             desc: 'To look at something closely and carefully.',                 descTr: 'Bir şeye yakından bakmak.'),
    WordEntry(level: 'B', rank: 74, en: 'Intend',      tr: 'Niyet etmek',     others: 'Tasarlamak',     ex: 'I intend to leave.',                desc: 'To plan to do something.',                                    descTr: 'Bir şeyi yapmayı planlamak.'),
    WordEntry(level: 'B', rank: 75, en: 'Identify',    tr: 'Saptamak',        others: 'Belirlemek',     ex: 'Identify the suspect.',             desc: 'To recognize who or what something is.',                      descTr: 'Bir şeyin ne olduğunu belirlemek.'),
    WordEntry(level: 'B', rank: 76, en: 'Propose',     tr: 'Önermek (resmi)', others: 'Sunmak',         ex: 'Propose a new plan.',               desc: 'To suggest a plan or idea.',                                  descTr: 'Plan veya fikir sunmak.'),
    WordEntry(level: 'B', rank: 77, en: 'React',       tr: 'Tepki vermek',    others: 'Cevap vermek',   ex: 'How will they react?',              desc: 'To respond to something.',                                    descTr: 'Bir şeye yanıt vermek.'),
    WordEntry(level: 'B', rank: 78, en: 'Refer',       tr: 'Başvurmak',       others: 'Atıfta bulunmak',ex: 'Refer to page ten.',                desc: 'To mention or look at something.',                            descTr: 'Bir şeye atıfta bulunmak.'),
    WordEntry(level: 'B', rank: 79, en: 'Define',      tr: 'Tanımlamak',      others: 'Açıklamak',      ex: 'Define the term.',                  desc: 'To explain the meaning of something.',                        descTr: 'Bir şeyin anlamını açıklamak.'),
    WordEntry(level: 'B', rank: 80, en: 'Emerge',      tr: 'Ortaya çıkmak',   others: 'Belirmek',       ex: 'A leader will emerge.',             desc: 'To come out or appear.',                                      descTr: 'Dışarı çıkmak veya görünmek.'),

    // ── C LEVEL ────────────────────────────────────────────────────────────

    // C100 (rank 1-20)
    WordEntry(level: 'C', rank: 1,  en: 'Inherent',    tr: 'Doğasında olan',     others: 'Asli',              ex: 'An inherent flaw.',                  desc: 'Existing as a natural part of something.',                  descTr: 'Bir şeyin doğal parçası olarak var olan.'),
    WordEntry(level: 'C', rank: 2,  en: 'Ambiguous',   tr: 'Belirsiz',           others: 'Çok anlamlı',       ex: 'An ambiguous statement.',            desc: 'Having more than one possible meaning.',                    descTr: 'Birden fazla anlamı olabilen.'),
    WordEntry(level: 'C', rank: 3,  en: 'Profound',    tr: 'Derin',              others: 'Engin',             ex: 'A profound thought.',                desc: 'Very deep in thought or meaning.',                          descTr: 'Düşünce veya anlam olarak çok derin.'),
    WordEntry(level: 'C', rank: 4,  en: 'Resilient',   tr: 'Dirençli',           others: 'Toparlanan',        ex: 'A resilient material.',              desc: 'Able to recover quickly from difficulties.',                descTr: 'Zorluklardan hızla toparlanabilen.'),
    WordEntry(level: 'C', rank: 5,  en: 'Meticulous',  tr: 'Titiz',              others: 'İnce eleyen',       ex: 'Meticulous attention to detail.',    desc: 'Showing great care for details.',                           descTr: 'Detaylara büyük özen gösteren.'),
    WordEntry(level: 'C', rank: 6,  en: 'Eloquent',    tr: 'Belagatli',          others: 'Hitabeti güçlü',    ex: 'An eloquent speaker.',               desc: 'Speaking or writing in a powerful way.',                    descTr: 'Etkili konuşan veya yazan.'),
    WordEntry(level: 'C', rank: 7,  en: 'Pragmatic',   tr: 'Pragmatik',          others: 'Faydacı',           ex: 'A pragmatic approach.',              desc: 'Practical rather than theoretical.',                        descTr: 'Teorik değil, pratik düşünen.'),
    WordEntry(level: 'C', rank: 8,  en: 'Plausible',   tr: 'Akla yatkın',        others: 'Makul',             ex: 'A plausible excuse.',                desc: 'Seeming reasonable or believable.',                         descTr: 'Makul veya inandırıcı görünen.'),
    WordEntry(level: 'C', rank: 9,  en: 'Tangible',    tr: 'Somut',              others: 'Elle tutulur',      ex: 'A tangible result.',                 desc: 'Able to be touched or clearly seen.',                       descTr: 'Dokunulabilen veya net görülebilen.'),
    WordEntry(level: 'C', rank: 10, en: 'Paramount',   tr: 'En önemli',          others: 'Üstün',             ex: 'Of paramount importance.',           desc: 'More important than anything else.',                        descTr: 'Her şeyden daha önemli.'),
    WordEntry(level: 'C', rank: 11, en: 'Prevalent',   tr: 'Yaygın',             others: 'Hakim',             ex: 'A prevalent belief.',                desc: 'Widespread or common in a particular area.',                descTr: 'Belirli bir alanda yaygın olan.'),
    WordEntry(level: 'C', rank: 12, en: 'Candid',      tr: 'Samimi',             others: 'Açık sözlü',        ex: 'A candid remark.',                   desc: 'Honest and straightforward in speech.',                     descTr: 'Konuşmada dürüst ve direkt.'),
    WordEntry(level: 'C', rank: 13, en: 'Lucid',       tr: 'Berrak',             others: 'Açık seçik',        ex: 'A lucid explanation.',               desc: 'Clear and easy to understand.',                             descTr: 'Net ve anlaması kolay.'),
    WordEntry(level: 'C', rank: 14, en: 'Arcane',      tr: 'Gizemli',            others: 'Sırlı',             ex: 'Arcane knowledge.',                  desc: 'Known only by a few people; mysterious.',                   descTr: 'Sadece az kişinin bildiği; gizemli.'),
    WordEntry(level: 'C', rank: 15, en: 'Compelling',  tr: 'İkna edici',         others: 'Sürükleyici',       ex: 'A compelling story.',                desc: 'Powerfully attracting attention.',                          descTr: 'Dikkati güçlü şekilde çeken.'),
    WordEntry(level: 'C', rank: 16, en: 'Cogent',      tr: 'İnandırıcı',         others: 'Mantıklı',          ex: 'A cogent argument.',                 desc: 'Clear, logical, and convincing.',                           descTr: 'Net, mantıklı ve ikna edici.'),
    WordEntry(level: 'C', rank: 17, en: 'Salient',     tr: 'Belirgin',           others: 'Göze çarpan',       ex: 'The salient points.',                desc: 'Most noticeable or important.',                             descTr: 'En göze çarpan veya önemli.'),
    WordEntry(level: 'C', rank: 18, en: 'Ubiquitous',  tr: 'Her yerde olan',     others: 'Yaygın',            ex: 'Smartphones are ubiquitous.',        desc: 'Present, found, or appearing everywhere.',                  descTr: 'Her yerde bulunan.'),
    WordEntry(level: 'C', rank: 19, en: 'Fortuitous',  tr: 'Şanslı tesadüf',     others: 'Talihli',           ex: 'A fortuitous meeting.',              desc: 'Happening by lucky chance.',                                descTr: 'Şans eseri olan.'),
    WordEntry(level: 'C', rank: 20, en: 'Scrutiny',    tr: 'Dikkatli inceleme',  others: 'Mercek altı',       ex: 'Under close scrutiny.',              desc: 'Close and careful examination.',                            descTr: 'Yakın ve dikkatli inceleme.'),

    // C250 (rank 21-40)
    WordEntry(level: 'C', rank: 21, en: 'Mitigate',    tr: 'Hafifletmek',        others: 'Yumuşatmak',        ex: 'Mitigate the damage.',               desc: 'To make something bad less severe.',                        descTr: 'Kötü bir şeyi daha az şiddetli kılmak.'),
    WordEntry(level: 'C', rank: 22, en: 'Exacerbate',  tr: 'Kötüleştirmek',      others: 'Şiddetlendirmek',   ex: 'Exacerbate the situation.',          desc: 'To make a bad situation worse.',                            descTr: 'Kötü durumu daha da kötü hâle getirmek.'),
    WordEntry(level: 'C', rank: 23, en: 'Alleviate',   tr: 'Dindirmek',          others: 'Hafifletmek',       ex: 'Alleviate the pain.',                desc: 'To reduce pain or difficulty.',                             descTr: 'Acıyı veya zorluğu azaltmak.'),
    WordEntry(level: 'C', rank: 24, en: 'Expedite',    tr: 'Hızlandırmak',       others: 'Çabuklaştırmak',    ex: 'Expedite the shipment.',             desc: 'To make a process happen faster.',                          descTr: 'Bir süreci daha hızlı yapmak.'),
    WordEntry(level: 'C', rank: 25, en: 'Articulate',  tr: 'Net ifade etmek',    others: 'Açıkça dile getirmek',ex: 'Articulate your point.',             desc: 'To express thoughts clearly in words.',                     descTr: 'Düşünceleri kelimelerle net belirtmek.'),
    WordEntry(level: 'C', rank: 26, en: 'Delineate',   tr: 'Belirginleştirmek',  others: 'Sınırlamak',        ex: 'Delineate the borders.',             desc: 'To describe or define precisely.',                          descTr: 'Kesin şekilde tanımlamak.'),
    WordEntry(level: 'C', rank: 27, en: 'Corroborate', tr: 'Doğrulamak',         others: 'Pekiştirmek',       ex: 'Witnesses corroborate the story.',   desc: 'To support a statement with evidence.',                     descTr: 'Bir ifadeyi kanıtla desteklemek.'),
    WordEntry(level: 'C', rank: 28, en: 'Perpetuate',  tr: 'Sürdürmek',          others: 'Devam ettirmek',    ex: 'Perpetuate the tradition.',          desc: 'To make something continue indefinitely.',                  descTr: 'Bir şeyi süresiz devam ettirmek.'),
    WordEntry(level: 'C', rank: 29, en: 'Reciprocate', tr: 'Karşılık vermek',    others: 'Mukabele etmek',    ex: 'Reciprocate the gesture.',           desc: 'To respond in kind to a gesture or feeling.',               descTr: 'Bir jest veya hisse aynıyla karşılık vermek.'),
    WordEntry(level: 'C', rank: 30, en: 'Scrutinize',  tr: 'Detaylı incelemek',  others: 'Didik didik etmek', ex: 'Scrutinize the report.',             desc: 'To examine something very carefully.',                      descTr: 'Bir şeyi çok dikkatle incelemek.'),
    WordEntry(level: 'C', rank: 31, en: 'Juxtapose',   tr: 'Yan yana koymak',    others: 'Karşılaştırmak',    ex: 'Juxtapose the two images.',          desc: 'To place things side by side for comparison.',              descTr: 'Karşılaştırma için yan yana yerleştirmek.'),
    WordEntry(level: 'C', rank: 32, en: 'Oscillate',   tr: 'Salınmak',           others: 'Sallanmak',         ex: 'Oscillate between options.',         desc: 'To move back and forth regularly.',                         descTr: 'İleri geri düzenli hareket etmek.'),
    WordEntry(level: 'C', rank: 33, en: 'Emanate',     tr: 'Yayılmak',           others: 'Saçmak',            ex: 'Light emanates from the lamp.',      desc: 'To flow out from a source.',                                descTr: 'Bir kaynaktan dışarı yayılmak.'),
    WordEntry(level: 'C', rank: 34, en: 'Fluctuate',   tr: 'Dalgalanmak',        others: 'Değişkenlik göstermek',ex: 'Prices fluctuate daily.',            desc: 'To change frequently in level or amount.',                  descTr: 'Düzeyi veya miktarı sık değişmek.'),
    WordEntry(level: 'C', rank: 35, en: 'Hypothesize', tr: 'Hipotez kurmak',     others: 'Varsaymak',         ex: 'Scientists hypothesize about it.',   desc: 'To suggest a possible explanation.',                        descTr: 'Olası bir açıklama önermek.'),
    WordEntry(level: 'C', rank: 36, en: 'Ameliorate',  tr: 'İyileştirmek',       others: 'Düzeltmek',         ex: 'Ameliorate the conditions.',         desc: 'To make a bad situation better.',                           descTr: 'Kötü durumu daha iyi hâle getirmek.'),
    WordEntry(level: 'C', rank: 37, en: 'Capitulate',  tr: 'Teslim olmak',       others: 'Pes etmek',         ex: 'Capitulate to demands.',             desc: 'To stop resisting and give in.',                            descTr: 'Direnmeyi bırakıp boyun eğmek.'),
    WordEntry(level: 'C', rank: 38, en: 'Deliberate',  tr: 'Kasıtlı',            others: 'Bilinçli',          ex: 'A deliberate choice.',               desc: 'Done on purpose, with full awareness.',                     descTr: 'Bilerek ve isteyerek yapılan.'),
    WordEntry(level: 'C', rank: 39, en: 'Equivocate',  tr: 'Kaçamak konuşmak',   others: 'Belirsiz konuşmak', ex: 'Stop equivocating.',                 desc: 'To speak unclearly to avoid commitment.',                   descTr: 'Bağlanmamak için net konuşmamak.'),
    WordEntry(level: 'C', rank: 40, en: 'Denigrate',   tr: 'Karalamak',          others: 'Aşağılamak',        ex: 'Do not denigrate others.',           desc: 'To criticize unfairly; to belittle.',                       descTr: 'Haksızca eleştirmek; küçümsemek.'),

    // C500 (rank 41-60)
    WordEntry(level: 'C', rank: 41, en: 'Quintessential',tr: 'Özünü temsil eden',others: 'Tam örneği',        ex: 'The quintessential gentleman.',      desc: 'Being a perfect example of a quality.',                     descTr: 'Bir özelliğin mükemmel örneği.'),
    WordEntry(level: 'C', rank: 42, en: 'Idiosyncratic',tr: 'Kendine özgü',      others: 'Tuhaf kendine has', ex: 'Idiosyncratic habits.',              desc: 'Unusual and unique to one person.',                         descTr: 'Bir kişiye özgü ve sıra dışı.'),
    WordEntry(level: 'C', rank: 43, en: 'Surreptitious',tr: 'Sinsi',             others: 'Gizlice yapılan',   ex: 'A surreptitious glance.',            desc: 'Done secretly to avoid being noticed.',                     descTr: 'Fark edilmemek için gizlice yapılan.'),
    WordEntry(level: 'C', rank: 44, en: 'Ostensible', tr: 'Görünürdeki',         others: 'Sözde',             ex: 'The ostensible reason.',             desc: 'Stated as true but possibly not the real reason.',          descTr: 'Doğru denilen ama gerçek olmayabilen.'),
    WordEntry(level: 'C', rank: 45, en: 'Vicarious',  tr: 'Dolaylı yaşanan',     others: 'Dolaylı',           ex: 'Vicarious joy.',                     desc: 'Experienced through another rather than directly.',         descTr: 'Doğrudan değil, başkası üzerinden hissedilen.'),
    WordEntry(level: 'C', rank: 46, en: 'Fastidious', tr: 'Müşkülpesent',        others: 'Titiz',             ex: 'Fastidious about cleanliness.',      desc: 'Very attentive to detail; hard to please.',                 descTr: 'Detaylara aşırı dikkat eden; zor memnun olan.'),
    WordEntry(level: 'C', rank: 47, en: 'Perfunctory',tr: 'Üstünkörü',           others: 'Yarım ağız',        ex: 'A perfunctory greeting.',            desc: 'Done with little care or interest.',                        descTr: 'Az özen veya ilgiyle yapılan.'),
    WordEntry(level: 'C', rank: 48, en: 'Recalcitrant',tr: 'Dik kafalı',         others: 'Söz dinlemez',      ex: 'A recalcitrant child.',              desc: 'Stubbornly refusing to obey.',                              descTr: 'İnatla itaat etmeyen.'),
    WordEntry(level: 'C', rank: 49, en: 'Vociferous', tr: 'Gürültücü',           others: 'Yüksek sesli',      ex: 'Vociferous protest.',                desc: 'Expressing opinions loudly and forcefully.',                descTr: 'Görüşleri yüksek sesle ifade eden.'),
    WordEntry(level: 'C', rank: 50, en: 'Parsimonious',tr: 'Cimri',              others: 'Eli sıkı',          ex: 'Parsimonious with words.',           desc: 'Very unwilling to spend money.',                            descTr: 'Para harcamaya çok isteksiz.'),
    WordEntry(level: 'C', rank: 51, en: 'Magnanimous',tr: 'Cömert ruhlu',        others: 'Yüce gönüllü',      ex: 'A magnanimous gesture.',             desc: 'Generous and forgiving, especially toward a rival.',        descTr: 'Özellikle rakibe karşı cömert ve bağışlayıcı.'),
    WordEntry(level: 'C', rank: 52, en: 'Taciturn',   tr: 'Az konuşan',          others: 'Ağzı sıkı',         ex: 'A taciturn man.',                    desc: 'Saying little; reserved in speech.',                        descTr: 'Az konuşan; ağzı sıkı.'),
    WordEntry(level: 'C', rank: 53, en: 'Trenchant',  tr: 'Keskin',              others: 'Sert',              ex: 'A trenchant critique.',              desc: 'Vigorous and effective in expression.',                     descTr: 'İfadede güçlü ve etkili.'),
    WordEntry(level: 'C', rank: 54, en: 'Mendacious', tr: 'Yalancı',             others: 'Sahtekar',          ex: 'A mendacious witness.',              desc: 'Not telling the truth; lying.',                             descTr: 'Doğruyu söylemeyen; yalan söyleyen.'),
    WordEntry(level: 'C', rank: 55, en: 'Indolent',   tr: 'Tembel',              others: 'Üşengeç',           ex: 'An indolent afternoon.',             desc: 'Avoiding work; lazy.',                                      descTr: 'Çalışmaktan kaçınan; tembel.'),
    WordEntry(level: 'C', rank: 56, en: 'Propitious', tr: 'Elverişli',           others: 'Uğurlu',            ex: 'A propitious moment.',               desc: 'Giving a good chance of success.',                          descTr: 'Başarı şansı sunan.'),
    WordEntry(level: 'C', rank: 57, en: 'Pernicious', tr: 'Zararlı',             others: 'Sinsi tehlikeli',   ex: 'A pernicious habit.',                desc: 'Having a harmful effect, often gradually.',                 descTr: 'Genelde yavaş zarar veren.'),
    WordEntry(level: 'C', rank: 58, en: 'Intransigent',tr: 'Uzlaşmaz',           others: 'Katı',              ex: 'An intransigent stance.',            desc: 'Refusing to change firm views or attitudes.',               descTr: 'Görüşlerini değiştirmek istemeyen.'),
    WordEntry(level: 'C', rank: 59, en: 'Ineffable',  tr: 'Tarif edilemez',      others: 'Anlatılmaz',        ex: 'Ineffable joy.',                     desc: 'Too great to be expressed in words.',                       descTr: 'Kelimelerle ifade edilemeyecek kadar büyük.'),
    WordEntry(level: 'C', rank: 60, en: 'Ephemeral',  tr: 'Kısa ömürlü',         others: 'Geçici',            ex: 'Fame is ephemeral.',                 desc: 'Lasting only for a short time.',                            descTr: 'Sadece kısa süre süren.'),

    // C1K (rank 61-80)
    WordEntry(level: 'C', rank: 61, en: 'Esoteric',    tr: 'Sırlı / az bilinen', others: 'Erişilmesi güç',    ex: 'Esoteric knowledge.',                desc: 'Understood by only a small group of experts.',              descTr: 'Sadece küçük bir uzman grubun anladığı.'),
    WordEntry(level: 'C', rank: 62, en: 'Mundane',     tr: 'Sıradan',            others: 'Bayağı',            ex: 'Mundane tasks.',                     desc: 'Lacking interest; ordinary.',                               descTr: 'İlginç olmayan; olağan.'),
    WordEntry(level: 'C', rank: 63, en: 'Sagacious',   tr: 'Bilge',              others: 'Akıllı',            ex: 'A sagacious leader.',                desc: 'Showing good judgment and wisdom.',                         descTr: 'İyi muhakeme ve bilgelik gösteren.'),
    WordEntry(level: 'C', rank: 64, en: 'Sanguine',    tr: 'İyimser',            others: 'Umutlu',            ex: 'Sanguine about the outcome.',        desc: 'Optimistic in a difficult situation.',                      descTr: 'Zor durumda iyimser kalan.'),
    WordEntry(level: 'C', rank: 65, en: 'Obstreperous',tr: 'Asi',                others: 'Yaramaz',           ex: 'Obstreperous children.',             desc: 'Noisy and difficult to control.',                           descTr: 'Gürültücü ve kontrolü zor.'),
    WordEntry(level: 'C', rank: 66, en: 'Pellucid',    tr: 'Şeffaf',             others: 'Saydam',            ex: 'Pellucid water.',                    desc: 'Translucently clear or easy to understand.',                descTr: 'Saydam veya anlaması kolay.'),
    WordEntry(level: 'C', rank: 67, en: 'Voluminous',  tr: 'Hacimli',            others: 'Geniş',             ex: 'A voluminous coat.',                 desc: 'Large in size or amount.',                                  descTr: 'Boyut veya miktar olarak büyük.'),
    WordEntry(level: 'C', rank: 68, en: 'Redoubtable', tr: 'Korkutucu',          others: 'Heybetli',          ex: 'A redoubtable foe.',                 desc: 'Causing fear or respect; formidable.',                      descTr: 'Korku veya saygı uyandıran.'),
    WordEntry(level: 'C', rank: 69, en: 'Impervious',  tr: 'Geçirimsiz',         others: 'Kayıtsız',          ex: 'Impervious to criticism.',           desc: 'Not affected by something.',                                descTr: 'Bir şeyden etkilenmeyen.'),
    WordEntry(level: 'C', rank: 70, en: 'Innocuous',   tr: 'Zararsız',           others: 'Masum',             ex: 'An innocuous comment.',              desc: 'Not harmful or offensive.',                                 descTr: 'Zararsız veya rahatsız etmeyen.'),
    WordEntry(level: 'C', rank: 71, en: 'Nefarious',   tr: 'Kötü niyetli',       others: 'Hain',              ex: 'Nefarious plans.',                   desc: 'Wicked or criminal in nature.',                             descTr: 'Kötü veya suç doğalı.'),
    WordEntry(level: 'C', rank: 72, en: 'Mellifluous', tr: 'Tatlı sesli',        others: 'Akıcı',             ex: 'A mellifluous voice.',               desc: 'Pleasing to hear; smooth and sweet.',                       descTr: 'Kulağa hoş gelen; pürüzsüz ve tatlı.'),
    WordEntry(level: 'C', rank: 73, en: 'Perfidious',  tr: 'Hain',               others: 'Sadakatsiz',        ex: 'A perfidious act.',                  desc: 'Deceitful and untrustworthy.',                              descTr: 'Aldatıcı ve güvenilmez.'),
    WordEntry(level: 'C', rank: 74, en: 'Quixotic',    tr: 'Hayalperest',        others: 'Boş hayaller peşinde',ex: 'A quixotic quest.',                  desc: 'Idealistic but unrealistic.',                               descTr: 'İdealist ama gerçekçi olmayan.'),
    WordEntry(level: 'C', rank: 75, en: 'Recondite',   tr: 'Anlaşılması zor',    others: 'Derin gizli',       ex: 'Recondite topics.',                  desc: 'Dealing with very obscure subject matter.',                 descTr: 'Çok karanlık konularla ilgilenen.'),
    WordEntry(level: 'C', rank: 76, en: 'Salubrious',  tr: 'Sağlığa yararlı',    others: 'Sağlıklı',          ex: 'A salubrious climate.',              desc: 'Health-giving; healthy.',                                   descTr: 'Sağlık veren; sağlıklı.'),
    WordEntry(level: 'C', rank: 77, en: 'Tenacious',   tr: 'Azimli',             others: 'Dirençli',          ex: 'A tenacious negotiator.',            desc: 'Holding firmly; not giving up.',                            descTr: 'Sımsıkı tutunan; pes etmeyen.'),
    WordEntry(level: 'C', rank: 78, en: 'Truculent',   tr: 'Kavgacı',            others: 'Saldırgan',         ex: 'A truculent attitude.',              desc: 'Eager or quick to argue or fight.',                         descTr: 'Tartışmaya veya kavgaya hevesli.'),
    WordEntry(level: 'C', rank: 79, en: 'Winsome',     tr: 'Cazibeli',           others: 'Sevimli',           ex: 'A winsome smile.',                   desc: 'Attractive in a charming, innocent way.',                   descTr: 'Çekici ve masum şekilde sevimli.'),
    WordEntry(level: 'C', rank: 80, en: 'Iconoclastic',tr: 'Kuralları yıkıcı',   others: 'Asi düşünür',       ex: 'Iconoclastic views.',                desc: 'Attacking traditional beliefs or institutions.',            descTr: 'Geleneksel inanç veya kurumlara saldıran.'),
  ];
  // dart format on
}
