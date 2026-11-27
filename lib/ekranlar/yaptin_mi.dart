import 'not_ac.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';

/// Takvime eklenen bir etkinlik bittikten 5 dakika sonra "yaptın mı?" diye sorar.
/// Bildirim değildir, uygulama açılınca ana sayfada görünür.
class YaptinMiKartlari extends StatefulWidget {
  const YaptinMiKartlari({super.key});

  /// Bitişinden en az 5 dk geçmiş, henüz cevaplanmamış, tamamlanmamış notlar.
  static List<Not> sorulacaklar(Iterable<Not> notlar, DateTime simdi) {
    final liste = notlar.where((n) {
      final bitis = n.takvimBitis;
      if (bitis == null || n.yaptinCevap || n.arsiv || n.durum == Durum.yapildi) return false;
      return simdi.millisecondsSinceEpoch >= bitis + const Duration(minutes: 5).inMilliseconds;
    }).toList();
    liste.sort((a, b) => a.takvimBitis!.compareTo(b.takvimBitis!));
    return liste;
  }

  @override
  State<YaptinMiKartlari> createState() => _YaptinMiKartlariState();
}

class _YaptinMiKartlariState extends State<YaptinMiKartlari> {
  Timer? _zamanlayici;

  @override
  void initState() {
    super.initState();
    // Sorunun zamanı gelince kart kendiliğinden belirsin.
    _zamanlayici = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _zamanlayici?.cancel();
    super.dispose();
  }

  Future<void> _cevapla(Not n, String durum) async {
    n.yaptinCevap = true;
    n.durum = durum;
    await Depo.instance.notGuncelle(n);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.instance,
      builder: (context, _) {
        final liste = YaptinMiKartlari.sorulacaklar(Depo.instance.notlar, DateTime.now()).take(2).toList();
        if (liste.isEmpty) return const SizedBox.shrink();
        return Column(children: [
          for (final n in liste)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Card(
                elevation: 0,
                color: Renk.kart,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Renk.vurgu.withValues(alpha: 0.4)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Yaptın mı?', style: TextStyle(color: Renk.vurgu, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => notuAc(context, n),
                      child: Text(n.gorunenBaslik,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Renk.yazi, fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      FilledButton(onPressed: () => _cevapla(n, Durum.yapildi), child: const Text('Yaptım')),
                      OutlinedButton(onPressed: () => _cevapla(n, Durum.yapiliyor), child: const Text('Yapıyorum')),
                      TextButton(onPressed: () => _cevapla(n, n.durum), child: const Text('Olmadı')),
                    ]),
                  ]),
                ),
              ),
            ),
        ]);
      },
    );
  }
}
