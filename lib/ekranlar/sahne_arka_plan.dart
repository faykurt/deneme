import 'package:material_ui/material_ui.dart';

import '../ortak.dart';

/// Ana sayfanın arka plan ışığı: gün boyu beş resim. Saatler karşılama selamlarıyla aynı.
enum SahneIsigi {
  sabah, // 05:00-10:59 açık adaçayı yeşili
  ogle, // 11:00-14:59 sıcak krem
  aksamUstu, // 15:00-17:59 pastel şeftali
  aksam, // 18:00-21:59 yumuşak lavanta
  gece; // 22:00-04:59 puslu mavi

  static SahneIsigi simdi([DateTime? an]) {
    final s = (an ?? DateTime.now()).hour;
    if (s >= 5 && s < 11) return sabah;
    if (s >= 11 && s < 15) return ogle;
    if (s >= 15 && s < 18) return aksamUstu;
    if (s >= 18 && s < 22) return aksam;
    return gece;
  }

  String get dosya => switch (this) {
        sabah => 'assets/sahne/sabah.jpg',
        ogle => 'assets/sahne/ogle.jpg',
        aksamUstu => 'assets/sahne/aksamustu.jpg',
        aksam => 'assets/sahne/aksam.jpg',
        gece => 'assets/sahne/gece.jpg',
      };

  /// Resim yüklenemezse kullanılacak düz ton.
  Color get yedekRenk => switch (this) {
        sabah => const Color(0xFFD6D7B4),
        ogle => const Color(0xFFEBDEBD),
        aksamUstu => const Color(0xFFEBB88B),
        aksam => const Color(0xFFA997A0),
        gece => const Color(0xFF566770),
      };
}

/// Ana sayfa arka planı: saate göre resim, değişirken yumuşak geçiş.
/// Koyu temada her zaman gece resmi kullanılır.
class SahneArkaPlan extends StatelessWidget {
  final SahneIsigi isik;
  const SahneArkaPlan({super.key, required this.isik});

  @override
  Widget build(BuildContext context) {
    final kullanilan = Renk.koyu ? SahneIsigi.gece : isik;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: SizedBox.expand(
        key: ValueKey(kullanilan),
        child: Image.asset(
          kullanilan.dosya,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => ColoredBox(color: kullanilan.yedekRenk),
        ),
      ),
    );
  }
}
