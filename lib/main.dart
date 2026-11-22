import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const AklimdaApp());
}

/// Uygulamanın sıcak renk paleti.
class AklimdaColors {
  static const turuncu = Color(0xFFE8833A);
  static const krem = Color(0xFFFFF4E0);
  static const kahve = Color(0xFF4A2C1D);
}

class AklimdaApp extends StatelessWidget {
  const AklimdaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aklımda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AklimdaColors.turuncu,
          surface: AklimdaColors.krem,
        ),
        scaffoldBackgroundColor: AklimdaColors.krem,
        useMaterial3: true,
      ),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    final yazi = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('💭', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                Text(
                  'Aklımda',
                  style: yazi.displaySmall?.copyWith(
                    color: AklimdaColors.kahve,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Kurulum tamam!\nBir sonraki sürümde buraya not alabileceksin.',
                  textAlign: TextAlign.center,
                  style: yazi.titleMedium?.copyWith(color: AklimdaColors.kahve),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
