import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../ortak.dart';
import 'ana_sayfa.dart';
import 'ayarlar.dart';
import 'notlar_ekrani.dart';
import 'paylasim.dart';
import 'sesli_not.dart';
import 'takvim.dart';
import 'yazili_not.dart';

/// Alt menü (Ana sayfa, Takvim, Notlar, Ayarlar) ve ortadaki sesli not butonu.
class Iskelet extends StatefulWidget {
  const Iskelet({super.key});

  @override
  State<Iskelet> createState() => _IskeletState();
}

class _IskeletState extends State<Iskelet> {
  int _sekme = 0;
  final List<StreamSubscription<Object?>> _abonelikler = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _disGirisleriDinle());
  }

  void _disGirisleriDinle() {
    // Paylaş menüsünden gelenler
    final paylasim = ReceiveSharingIntent.instance;
    paylasim.getInitialMedia().then((liste) {
      if (liste.isNotEmpty) {
        paylasimiIsle(liste);
        paylasim.reset();
      }
    });
    _abonelikler.add(paylasim.getMediaStream().listen((liste) {
      if (liste.isNotEmpty) {
        paylasimiIsle(liste);
        paylasim.reset();
      }
    }));
    // Ana ekran widget'ından gelenler
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_widgetten);
    _abonelikler.add(HomeWidget.widgetClicked.listen(_widgetten));
  }

  void _widgetten(Uri? uri) {
    switch (uri?.host) {
      case 'sesli':
        sesliNotAc();
      case 'yazili':
        setState(() => _sekme = 0);
        yaziliNotAc();
    }
  }

  @override
  void dispose() {
    for (final a in _abonelikler) {
      a.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _sekme,
        children: const [AnaSayfa(), TakvimEkrani(), NotlarEkrani(), AyarlarEkrani()],
      ),
      floatingActionButton: FloatingActionButton.large(
        onPressed: sesliNotAc,
        tooltip: 'Sesli not',
        backgroundColor: Renk.turuncu,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.mic, size: 40),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Renk.acikKrem,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            _sekmeButonu(0, Icons.home_outlined, Icons.home, 'Ana sayfa'),
            _sekmeButonu(1, Icons.calendar_month_outlined, Icons.calendar_month, 'Takvim'),
            const SizedBox(width: 96),
            _sekmeButonu(2, Icons.sticky_note_2_outlined, Icons.sticky_note_2, 'Notlar'),
            _sekmeButonu(3, Icons.settings_outlined, Icons.settings, 'Ayarlar'),
          ],
        ),
      ),
    );
  }

  Widget _sekmeButonu(int i, IconData ikon, IconData seciliIkon, String ad) {
    final secili = _sekme == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _sekme = i),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(secili ? seciliIkon : ikon, color: secili ? Renk.turuncu : Renk.kahve),
            Text(ad,
                style: TextStyle(
                  fontSize: 11,
                  color: secili ? Renk.turuncu : Renk.kahve,
                  fontWeight: secili ? FontWeight.w600 : FontWeight.normal,
                )),
          ],
        ),
      ),
    );
  }
}
