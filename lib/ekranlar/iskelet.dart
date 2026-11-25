import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../ai/isleyici.dart';
import '../ortak.dart';
import '../takvim/takvim_deposu.dart';
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

class _IskeletState extends State<Iskelet> with WidgetsBindingObserver {
  int _sekme = 0;
  final List<StreamSubscription<Object?>> _abonelikler = [];
  Timer? _yenidenDene;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    sekmeSecici.addListener(_sekmeDegisti);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _disGirisleriDinle();
      AiIsleyici.instance.zamanlanmisIsle();
      _takvimiYokla();
    });
    // İnternet yokken kalan notlar için aralıklarla yeniden dener.
    _yenidenDene = Timer.periodic(const Duration(minutes: 2), (_) {
      final ai = AiIsleyici.instance;
      if (ai.bekleyenSayisi > 0 && (ai.sonHata?.otomatikDeneme ?? true)) ai.zamanlanmisIsle();
    });
  }

  /// Takvim iznini ve takvime bağlı notları (silinen/taşınan etkinlikler) günceller.
  Future<void> _takvimiYokla() async {
    final t = TakvimDeposu.instance;
    await t.baslat();
    await t.notlariSenkronla();
  }

  void _sekmeDegisti() {
    if (mounted && _sekme != sekmeSecici.value) setState(() => _sekme = sekmeSecici.value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState durum) {
    if (durum == AppLifecycleState.resumed) {
      AiIsleyici.instance.zamanlanmisIsle();
      _takvimiYokla();
    }
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
        sekmeSecici.value = 0;
        yaziliNotAc();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sekmeSecici.removeListener(_sekmeDegisti);
    _yenidenDene?.cancel();
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
        backgroundColor: Renk.vurgu,
        foregroundColor: Renk.vurguUstu,
        shape: CircleBorder(side: BorderSide(color: Renk.kart, width: 4)),
        child: const Icon(Icons.mic, size: 40),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Renk.kart,
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
        onTap: () => sekmeSecici.value = i,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
                message: ad,
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: secili ? Renk.vurgu.withValues(alpha: 0.22) : Colors.transparent,
                      ),
                      child: Icon(secili ? seciliIkon : ikon, size: 26, color: secili ? Renk.vurgu : Renk.yazi)))),
          ],
        ),
      ),
    );
  }
}
