import 'package:material_ui/material_ui.dart';

import '../ortak.dart';

/// Ana sayfanın arka plan ışığı: gün boyu üç ton. Saatler `SahneIsigi.simdi` içinde ayarlanır.
enum SahneIsigi {
  gun, // sarı-yeşil, aydınlık
  aksamUstu, // şeftali
  gece; // mor

  /// Varsayılan saatler: gün 06-16, akşamüstü 16-19, gece 19-06.
  static SahneIsigi simdi([DateTime? an]) {
    final s = (an ?? DateTime.now()).hour;
    if (s >= 6 && s < 16) return gun;
    if (s >= 16 && s < 19) return aksamUstu;
    return gece;
  }
}

/// Geçici arka plan: ışığa göre yumuşak renk geçişi (sonra hazır resimle değiştirilecek).
/// Koyu temada her zaman gece tonu kullanılır.
class SahneArkaPlan extends StatelessWidget {
  final SahneIsigi isik;
  const SahneArkaPlan({super.key, required this.isik});

  static List<Color> renkler(SahneIsigi isik, bool koyu) {
    if (koyu) return const [Color(0xFF1B1A24), Color(0xFF2A2735), Color(0xFF14131B)];
    return switch (isik) {
      SahneIsigi.gun => const [Color(0xFFF1EAC4), Color(0xFFDCE6C0), Color(0xFFB9CFA6)],
      SahneIsigi.aksamUstu => const [Color(0xFFF7D9B8), Color(0xFFF0B995), Color(0xFFD99A7E)],
      SahneIsigi.gece => const [Color(0xFFC9B8D8), Color(0xFF9C88B8), Color(0xFF6E5F94)],
    };
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: renkler(isik, Renk.koyu),
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
