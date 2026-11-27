import 'dart:math' as math;
import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../ses.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'kutuphane.dart';
import 'notlar_ekrani.dart';
import 'yazili_not.dart';

/// Kitaba dokununca: kitap raftan öne gelip büyür, arka plan kararır, kapak sırttan açılır ve içinde notlar görünür.
Route<void> kitapAcilisiRotasi(Kategori k) => PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondary) => KitapSayfasi(kategori: k),
      transitionsBuilder: (context, animation, secondary, child) => FadeTransition(opacity: animation, child: child),
    );

class KitapSayfasi extends StatefulWidget {
  final Kategori kategori;
  const KitapSayfasi({super.key, required this.kategori});

  @override
  State<KitapSayfasi> createState() => _KitapSayfasiState();
}

class _KitapSayfasiState extends State<KitapSayfasi> with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  bool _kapaniyor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rota = ModalRoute.of(context);
      final anim = rota?.animation;
      void ac() {
        if (!mounted) return;
        _ac.forward();
      }

      if (anim == null || anim.isCompleted) {
        ac();
      } else {
        late final AnimationStatusListener dinle;
        dinle = (s) {
          if (s == AnimationStatus.completed) {
            anim.removeStatusListener(dinle);
            ac();
          }
        };
        anim.addStatusListener(dinle);
      }
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _kapat() async {
    if (_kapaniyor) return;
    _kapaniyor = true;
    Ses.instance.sayfa();
    await _ac.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kategori;
    final boyut = MediaQuery.sizeOf(context);
    final w = math.min(boyut.width - 32, 360.0);
    final h = math.min(w / KitapKapagi.oran, boyut.height * 0.74);
    final agac = Depo.instance.agac;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _kapat();
      },
      child: Material(
        type: MaterialType.transparency,
        child: Stack(children: [
          // karartma
          Positioned.fill(
            child: GestureDetector(
              onTap: _kapat,
              child: AnimatedBuilder(
                animation: _ac,
                builder: (context, _) => BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6 * _ac.value, sigmaY: 6 * _ac.value),
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: w,
              height: h,
              child: AnimatedBuilder(
                animation: _ac,
                builder: (context, _) {
                  final ilerleme = Curves.easeInOutCubic.transform(_ac.value);
                  final aci = ilerleme * 2.75; // ~158°
                  final kapakGorunur = aci < math.pi / 2;
                  return Stack(clipBehavior: Clip.none, children: [
                    // sayfa
                    Positioned.fill(
                      child: Opacity(
                        opacity: (ilerleme * 1.6 - 0.35).clamp(0.0, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12), left: Radius.circular(3)),
                            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 8))],
                          ),
                          child: Material(
                          color: Renk.kart,
                          shape: RoundedRectangleBorder(
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12), left: Radius.circular(3)),
                            side: BorderSide(color: Renk.sinir),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 4, 0),
                              child: Row(children: [
                                Expanded(
                                  child: Text(agac.tamAd(k.id),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Renk.yazi, fontWeight: FontWeight.w800, fontSize: 19)),
                                ),
                                IconButton(
                                    tooltip: 'Liste ekle',
                                    icon: const Icon(Icons.checklist),
                                    onPressed: () => yaziliNotAc(liste: true, kategoriId: k.id)),
                                IconButton(
                                    tooltip: 'Not ekle',
                                    icon: const Icon(Icons.note_add_outlined),
                                    onPressed: () => yaziliNotAc(kategoriId: k.id)),
                                IconButton(tooltip: 'Kitabı kapat', icon: const Icon(Icons.close), onPressed: _kapat),
                              ]),
                            ),
                            const Divider(height: 1),
                            Expanded(child: KategoriGovdesi(kategori: k)),
                          ]),
                          ),
                        ),
                      ),
                    ),
                    // kapak (sırttan menteşeli)
                    Positioned.fill(
                      child: Transform(
                        alignment: Alignment.centerLeft,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0014)
                          ..rotateY(-aci),
                        child: kapakGorunur
                            ? Hero(
                                tag: 'kitap_${k.id}',
                                child: KitapKapagi(kategori: k, agac: agac, sayi: 0, genislik: w),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFE2C6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Renk.sinir),
                                ),
                              ),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
