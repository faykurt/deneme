import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'ai/ai_ayarlar.dart';
import 'ai/ai_harcama.dart';
import 'ai/ai_servisi.dart';
import 'ai/ai_zamanlama.dart';
import 'takvim/takvim_ayarlari.dart';
import 'ekranlar/iskelet.dart';
import 'ortak.dart';
import 'tema.dart';
import 'veri/depo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  await Depo.instance.ac();
  await AiAyarlar.instance.yukle();
  await AiZamanlama.instance.yukle();
  await AiHarcama.instance.yukle();
  AiServisi.kullanimDinleyici = (model, girdi, cikti) => AiHarcama.instance.kaydet(model, girdi, cikti);
  await TakvimAyarlari.instance.yukle();
  await TemaAyari.instance.yukle();
  runApp(const AklimdaApp());
}

class AklimdaApp extends StatelessWidget {
  const AklimdaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TemaAyari.instance,
      builder: (context, _) => MaterialApp(
        title: 'Aklımda',
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        theme: TemaAyari.instance.tema,
        home: const Iskelet(),
      ),
    );
  }
}
