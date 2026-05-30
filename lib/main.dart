import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_colors.dart';
import 'game/word_rarity.dart';
import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'services/database_helper.dart';
import 'services/nakama_service.dart';
import 'services/ownership_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.init();
  await OwnershipDb.init();
  DatabaseHelper.init();            // kelime DB'sini arka planda aç/kopyala
  AppSettings.sesPreload();         // fire-and-forget; arka planda yüklenir
  // Faz 0: backend'e bağlan + anonim cihaz kimliğiyle oturum aç.
  // Fire-and-forget — sunucu kapalıysa oyun offline çalışmaya devam eder.
  NakamaService.instance.baglanVeGiris().then((_) {
    if (NakamaService.instance.girisYapildi) {
      NakamaService.instance.profilYukle();
    }
  });
  // Enderlik SVG'lerini ilk frame'den ÖNCE cache'e ısıt → açılışta pop yok.
  // 6 küçük SVG (~10KB) olduğundan startup gecikmesi ihmal edilebilir.
  await RarityIcon.precacheAll();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(const YabanciDilUygulamam());
}

class YabanciDilUygulamam extends StatelessWidget {
  const YabanciDilUygulamam({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.arkaPlan,
        useMaterial3: true,
      ),
      home: const AnaKontrolMerkezi(),
    );
  }
}
