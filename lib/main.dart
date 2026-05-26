import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/app_colors.dart';
import 'screens/home_screen.dart';
import 'services/app_settings.dart';
import 'services/ownership_db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.init();
  await OwnershipDb.init();
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
