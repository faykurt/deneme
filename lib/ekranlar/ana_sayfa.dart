import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/isleyici.dart';
import '../ortak.dart';
import '../selam.dart';
import '../veri/depo.dart';
import '../ses.dart';
import 'kutuphane.dart';
import 'oneri_kartlari.dart';
import '../oneri/oneri_deposu.dart';
import 'sahne_arka_plan.dart';
import 'onay_bekleyenler.dart';
import 'yaptin_mi.dart';
import 'yazili_not.dart';

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> with WidgetsBindingObserver {
  bool _liste = false;

  static const _modAnahtari = 'ana_liste_modu';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => OneriDeposu.instance.yenile());
    _modYukle();
  }

  Future<void> _modYukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (mounted) setState(() => _liste = p.getBool(_modAnahtari) ?? false);
    } catch (_) {}
  }

  Future<void> _modDegistir(bool liste) async {
    Ses.instance.tik();
    setState(() => _liste = liste);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_modAnahtari, liste);
    } catch (_) {}
  }

  void _ac() => yaziliNotAc(liste: _liste);

  bool get _koyuZemin => Renk.koyu || SahneIsigi.simdi() == SahneIsigi.gece;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Uygulamaya dönülünce gün bölümü (sabah/öğle/akşam) değişmiş olabilir.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      OneriDeposu.instance.yenile();
    }
  }

  String get _selam => Selam.instance.simdi(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final yazi = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: SahneArkaPlan(isik: SahneIsigi.simdi())),
        SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Text(_selam,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontVariations: const [FontVariation('wght', 700)],
                    fontSize: 44,
                    height: 1.0,
                    color: _koyuZemin ? const Color(0xFFFFF4E0) : const Color(0xFF2B1F18),
                    shadows: _koyuZemin
                        ? const [Shadow(color: Color(0x99000000), blurRadius: 8)]
                        : const [Shadow(color: Color(0x88FFFFFF), blurRadius: 10)],
                  )),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              decoration: BoxDecoration(
                color: Renk.kart.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Renk.vurgu.withValues(alpha: 0.5)),
              ),
              child: Row(children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: _ac,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                      child: Row(children: [
                        Icon(_liste ? Icons.checklist : Icons.edit_note, color: Renk.vurgu),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Aklında ne var?',
                              style: TextStyle(fontSize: 16, color: Renk.yazi.withValues(alpha: 0.7))),
                        ),
                      ]),
                    ),
                  ),
                ),
                _ModAnahtari(liste: _liste, degisti: _modDegistir),
              ]),
            ),
            const Kutuphane(),
            const OneriKartlari(),
            const YaptinMiKartlari(),
            const OnayBandi(),
            const IslenecekBandi(),
            ListenableBuilder(
              listenable: Listenable.merge([AiAyarlar.instance, AiIsleyici.instance]),
              builder: (context, _) {
                final ai = AiAyarlar.instance;
                final hata = AiIsleyici.instance.sonHata;
                if (!ai.anahtarVar) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                    child: Card(
                      elevation: 0,
                      color: Renk.kart,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Renk.vurgu.withValues(alpha: 0.4))),
                      child: ListTile(
                        leading: Icon(Icons.key, color: Renk.vurgu),
                        title: const Text('Yapay zekayı aç'),
                        subtitle: const Text('Notların kendiliğinden düzenlenmesi için anahtarını ekle.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => sekmeSecici.value = 3,
                      ),
                    ),
                  );
                }
                if (hata != null) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(hata.mesaj,
                        style: TextStyle(color: Renk.hata, fontSize: 13)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: Depo.instance,
              builder: (context, _) {
                final sayi = Depo.instance.aktifNotlar.length;
                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Renk.kart.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      sayi == 0 ? 'Henüz notun yok.' : 'Aklımda\'da $sayi notun var.',
                      style: yazi.bodySmall?.copyWith(color: Renk.yazi.withValues(alpha: 0.75)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        ),
      ]),
    );
  }
}

/// Alanın içindeki Not / Liste anahtarı: ikisinden biri seçili.
class _ModAnahtari extends StatelessWidget {
  final bool liste;
  final void Function(bool) degisti;
  const _ModAnahtari({required this.liste, required this.degisti});

  @override
  Widget build(BuildContext context) {
    Widget parca(bool listeMi, IconData ikon, String ad) {
      final secili = liste == listeMi;
      return Semantics(
        button: true,
        selected: secili,
        label: ad,
        child: GestureDetector(
          onTap: () => degisti(listeMi),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: secili ? Renk.vurgu : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ikon, size: 17, color: secili ? Renk.vurguUstu : Renk.yazi.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Text(ad,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: secili ? Renk.vurguUstu : Renk.yazi.withValues(alpha: 0.7))),
            ]),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Renk.yazi.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(22)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        parca(false, Icons.edit_note, 'Not'),
        parca(true, Icons.checklist, 'Liste'),
      ]),
    );
  }
}
