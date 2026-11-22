import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'ai/ai_ayarlar.dart';
import 'takvim/takvim_ayarlari.dart';
import 'ekranlar/iskelet.dart';
import 'ortak.dart';
import 'veri/depo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  await Depo.instance.ac();
  await AiAyarlar.instance.yukle();
  await TakvimAyarlari.instance.yukle();
  runApp(const AklimdaApp());
}

class AklimdaApp extends StatelessWidget {
  const AklimdaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aklımda',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Renk.turuncu, surface: Renk.krem),
        scaffoldBackgroundColor: Renk.krem,
        useMaterial3: true,
      ),
      home: const Iskelet(),
    );
  }
}
