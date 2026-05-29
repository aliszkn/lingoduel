import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Enderlik (rarity) seviyeleri — sıradandan mistiğe.
///
/// Kullanım:
/// ```dart
/// EnderlikIcon(Enderlik.efsanevi, size: 40)            // sadece ikon
/// EnderlikBadge(Enderlik.destansi)                     // ikon + isim rozeti
/// Text('Ender', style: TextStyle(color: Enderlik.ender.color))
/// ```
///
/// Kurulum — pubspec.yaml:
/// ```yaml
/// dependencies:
///   flutter_svg: ^2.0.10
/// flutter:
///   assets:
///     - assets/enderlik/
/// ```
enum Enderlik {
  siradan(
    seviye: 1,
    ad: 'Sıradan',
    adEn: 'Common',
    renk: Color(0xFF9BA2AD),
    glow: Color(0x009BA2AD),
  ),
  siradisi(
    seviye: 2,
    ad: 'Sıradışı',
    adEn: 'Uncommon',
    renk: Color(0xFF4ADE80),
    glow: Color(0x4234D058),
  ),
  ender(
    seviye: 3,
    ad: 'Ender',
    adEn: 'Rare',
    renk: Color(0xFF5B9BFF),
    glow: Color(0x4D3B82F6),
  ),
  destansi(
    seviye: 4,
    ad: 'Destansı',
    adEn: 'Epic',
    renk: Color(0xFFC18BFF),
    glow: Color(0x57A855F7),
  ),
  efsanevi(
    seviye: 5,
    ad: 'Efsanevi',
    adEn: 'Legendary',
    renk: Color(0xFFFCD34D),
    glow: Color(0x6BFBA316),
  ),
  mistik(
    seviye: 6,
    ad: 'Mistik',
    adEn: 'Mythic',
    renk: Color(0xFFFF7088),
    glow: Color(0x80FF3D63),
  );

  const Enderlik({
    required this.seviye,
    required this.ad,
    required this.adEn,
    required this.renk,
    required this.glow,
  });

  /// 1 (sıradan) … 6 (mistik)
  final int seviye;

  /// Türkçe görünen ad.
  final String ad;

  /// İngilizce karşılık.
  final String adEn;

  /// Seviyenin ana rengi (metin / vurgu için).
  final Color renk;

  /// İkonun yaydığı ışık rengi (alfa dahil). Sıradan için saydam.
  final Color glow;

  /// SVG asset yolu.
  String get assetPath => 'assets/enderlik/enderlik_$name.svg';
}

/// Tek başına enderlik ikonu (SVG).
class EnderlikIcon extends StatelessWidget {
  const EnderlikIcon(this.enderlik, {super.key, this.size = 32});

  final Enderlik enderlik;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      enderlik.assetPath,
      width: size,
      height: size,
    );
  }
}

/// İkon + enderlik adını yan yana gösteren küçük rozet.
class EnderlikBadge extends StatelessWidget {
  const EnderlikBadge(
    this.enderlik, {
    super.key,
    this.iconSize = 22,
    this.showText = true,
  });

  final Enderlik enderlik;
  final double iconSize;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 5, showText ? 12 : 8, 5),
      decoration: BoxDecoration(
        color: enderlik.renk.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: enderlik.renk.withOpacity(0.35), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          EnderlikIcon(enderlik, size: iconSize),
          if (showText) ...[
            const SizedBox(width: 7),
            Text(
              enderlik.ad,
              style: TextStyle(
                color: enderlik.renk,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
