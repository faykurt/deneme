import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../ses.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'kitap_acilisi.dart';
import 'not_detay.dart';
import 'notlar_ekrani.dart';

const _gorsel = 'assets/gorsel';

/// Altı kapak resminin ton açıları (derece): kiremit, yeşil, mor, turkuaz, mavi, hardal.
const _kapakTonlari = <double>[11, 69, 340, 150, 214, 41];

/// Kategori rengine ton olarak en yakın kapağın sırası.
int kapakIndeksi(Color renk) {
  final h = HSLColor.fromColor(renk).hue;
  var en = 0;
  var enUzak = double.infinity;
  for (var i = 0; i < _kapakTonlari.length; i++) {
    var d = (h - _kapakTonlari[i]).abs();
    if (d > 180) d = 360 - d;
    if (d < enUzak) {
      enUzak = d;
      en = i;
    }
  }
  return en;
}

/// Bir kategorinin kitap kapağı (önden bakış): kapak resmi, ortada simge / emoji / kendi resmin, altta ad.
/// Genişliğe göre ölçeklenir, hem rafta hem açılış sayfasında aynı görünür.
class KitapKapagi extends StatelessWidget {
  final Kategori kategori;
  final KategoriAgaci agac;
  final int sayi;
  final double genislik;
  const KitapKapagi({super.key, required this.kategori, required this.agac, required this.sayi, required this.genislik});

  static const oran = 0.81; // genişlik / yükseklik

  @override
  Widget build(BuildContext context) {
    final w = genislik;
    final h = w / oran;
    final cream = const Color(0xFFFBF1DA);
    final resim = kategori.kapakResmi;
    final resimVar = resim != null && File(resim).existsSync();
    final emoji = agac.emojiOf(kategori.id);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(children: [
        Positioned.fill(
          child: Image.asset('$_gorsel/kapak_${kapakIndeksi(agac.renkOf(kategori.id))}.webp',
              fit: BoxFit.fill, filterQuality: FilterQuality.medium, gaplessPlayback: true),
        ),
        // simge / emoji / resim
        Positioned(
          left: w * 0.2,
          right: w * 0.1,
          top: h * 0.12,
          height: h * 0.46,
          child: Center(
            child: resimVar
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(w * 0.04),
                    child: Image.file(File(resim), fit: BoxFit.cover, width: double.infinity, height: double.infinity, cacheWidth: 360),
                  )
                : emoji != null
                    ? FittedBox(child: Text(emoji, style: const TextStyle(fontSize: 100)))
                    : Icon(agac.ikonOf(kategori.id), size: w * 0.36, color: cream.withValues(alpha: 0.92)),
          ),
        ),
        // ad
        Positioned(
          left: w * 0.18,
          right: w * 0.08,
          top: h * 0.64,
          child: Text(kategori.ad,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: cream,
                fontWeight: FontWeight.w800,
                fontSize: math.max(8, w * 0.15),
                height: 1.05,
                shadows: const [Shadow(color: Color(0x66000000), blurRadius: 2)],
              )),
        ),
        if (sayi > 0)
          Positioned(
            right: w * 0.07,
            bottom: h * 0.06,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: w * 0.06, vertical: w * 0.01),
              decoration: BoxDecoration(color: const Color(0xCC3A2B20), borderRadius: BorderRadius.circular(w)),
              child: Text('$sayi', style: TextStyle(color: cream, fontSize: math.max(7.5, w * 0.12), fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

/// Ana sayfanın kütüphanesi: yana kaydırmalı iki katlı raf; her kategori bir kitap, kategorisiz notlar
/// rafa yapıştırılmış kâğıtlar. Rafın üstünde mum (yanıp söner), saksı ve asma (hafifçe sallanır).
class Kutuphane extends StatefulWidget {
  const Kutuphane({super.key});

  /// Testlerde sonsuz animasyonu kapatmak için (pumpAndSettle bitebilsin).
  static bool animasyon = true;

  @override
  State<Kutuphane> createState() => _KutuphaneState();
}

class _KutuphaneState extends State<Kutuphane> with SingleTickerProviderStateMixin {
  // Ölçüler (mantıksal px). Raf görseli 548 birimlik yüksekliğe göre: zemin çizgileri sabit oranlarda.
  static const double _rafYuksekligi = 270;
  static const double _ustBosluk = 100; // rafın üstündeki süs bölgesi
  static const double _kapak = 62; // kitap genişliği
  static const double _aralik = 6;
  static const double _solPay = 30;
  static const double _zemin1 = 0.467 * _rafYuksekligi;
  static const double _zemin2 = 0.905 * _rafYuksekligi;
  static const double _kagitMax = 6;

  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 7));

  @override
  void initState() {
    super.initState();
    if (Kutuphane.animasyon) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _kagitRenkleri = [Color(0xFFE6D98F), Color(0xFFA9CDB6), Color(0xFFDDB3C0), Color(0xFFAFC3DD)];

  @override
  Widget build(BuildContext context) {
    final azHareket = MediaQuery.disableAnimationsOf(context) || !Kutuphane.animasyon;
    if (azHareket && _c.isAnimating) _c.stop();
    if (!azHareket && !_c.isAnimating) _c.repeat();
    final depo = Depo.instance;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final agac = depo.agac;
        final aktif = depo.aktifNotlar;
        final kitaplar = agac.anaKategoriler;
        final kagitlar = aktif.where((n) => n.kategoriIdler.isEmpty).toList();
        final gorunenKagit = kagitlar.take(_kagitMax.toInt()).toList();
        final ogeSayisi = kitaplar.length + gorunenKagit.length + (kagitlar.length > _kagitMax ? 1 : 0);
        final sutun = (ogeSayisi / 2).ceil();
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: LayoutBuilder(builder: (context, c) {
            final genislik = c.maxWidth;
            final icGenislik = math.max(genislik, _solPay * 2 + sutun * (_kapak + _aralik));
            return SizedBox(
              height: _ustBosluk + _rafYuksekligi,
              child: Stack(clipBehavior: Clip.none, children: [
                // raf (yana kaydırılır)
                Positioned(
                  top: _ustBosluk,
                  left: 0,
                  right: 0,
                  height: _rafYuksekligi,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: icGenislik,
                      height: _rafYuksekligi,
                      child: Stack(children: [
                        _RafArkaPlani(genislik: icGenislik),
                        for (var i = 0; i < kitaplar.length; i++)
                          _yerles(i, _kitap(context, agac, aktif, kitaplar[i])),
                        for (var j = 0; j < gorunenKagit.length; j++)
                          _yerles(kitaplar.length + j, _kagit(context, gorunenKagit[j]), kucuk: true),
                        if (kagitlar.length > _kagitMax)
                          _yerles(kitaplar.length + gorunenKagit.length, _tumu(context, kagitlar.length), kucuk: true),
                      ]),
                    ),
                  ),
                ),
                // süsler (sabit, raf kaysa da yerinde)
                Positioned.fill(child: IgnorePointer(child: _Susler(denetleyici: _c, genislik: genislik))),
              ]),
            );
          }),
        );
      },
    );
  }

  /// Öğeyi sütun-satır düzenine göre rafa koyar: tek sayılar alt rafa, çiftler üst rafa, sütun sütun ilerler.
  Widget _yerles(int indeks, Widget oge, {bool kucuk = false}) {
    final sutun = indeks ~/ 2;
    final satir = indeks % 2;
    final zemin = satir == 0 ? _zemin1 : _zemin2;
    final h = kucuk ? 52.0 : _kapak / KitapKapagi.oran;
    final w = kucuk ? 52.0 : _kapak;
    return Positioned(
      left: _solPay + sutun * (_kapak + _aralik) + (_kapak - w) / 2,
      top: zemin - h + 2,
      width: w,
      height: h,
      child: oge,
    );
  }

  Widget _kitap(BuildContext context, KategoriAgaci agac, List<Not> aktif, Kategori k) {
    final ids = agac.kendisiVeAltlari(k.id);
    final sayi = aktif.where((n) => n.kategoriIdler.any(ids.contains)).length;
    return Semantics(
      button: true,
      label: '${k.ad}, $sayi not',
      child: GestureDetector(
        onTap: () {
          Ses.instance.sayfa();
          Navigator.of(context).push(kitapAcilisiRotasi(k));
        },
        child: Hero(
          tag: 'kitap_${k.id}',
          child: KitapKapagi(kategori: k, agac: agac, sayi: sayi, genislik: _kapak),
        ),
      ),
    );
  }

  Widget _kagit(BuildContext context, Not n) {
    final h = n.id.hashCode;
    final renk = _kagitRenkleri[h.abs() % _kagitRenkleri.length];
    final aci = (((h.abs() % 9) - 4) * 0.02);
    return Transform.rotate(
      angle: aci,
      child: GestureDetector(
        onTap: () {
          Ses.instance.tik();
          Navigator.push(context, MaterialPageRoute(builder: (_) => NotDetay(notId: n.id)));
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 7, 5, 3),
          decoration: BoxDecoration(
            color: renk,
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(1, 2))],
          ),
          child: Text(n.gorunenBaslik,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, height: 1.15, color: Color(0xFF2B2B2B))),
        ),
      ),
    );
  }

  Widget _tumu(BuildContext context, int sayi) => GestureDetector(
        onTap: () {
          Ses.instance.tik();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ListeSayfasi(
                  baslik: 'Kategorisiz notlar',
                  kaynak: () => Depo.instance.aktifNotlar.where((n) => n.kategoriIdler.isEmpty).toList()),
            ),
          );
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF2E6CC),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(1, 2))],
          ),
          child: Text('Tümü\n($sayi)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF2B2B2B))),
        ),
      );
}

/// Raf görseli: sol uç, tekrarlanan orta parça, sağ uç.
class _RafArkaPlani extends StatelessWidget {
  final double genislik;
  const _RafArkaPlani({required this.genislik});

  @override
  Widget build(BuildContext context) {
    const capW = 64.0;
    return Row(children: [
      Image.asset('$_gorsel/raf_sol.webp', width: capW, height: _KutuphaneState._rafYuksekligi, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
      Expanded(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('$_gorsel/raf_orta.webp'),
              repeat: ImageRepeat.repeatX,
              fit: BoxFit.fitHeight,
              alignment: Alignment.centerLeft,
              filterQuality: FilterQuality.medium,
            ),
          ),
          child: const SizedBox(height: _KutuphaneState._rafYuksekligi),
        ),
      ),
      Image.asset('$_gorsel/raf_sag.webp', width: capW, height: _KutuphaneState._rafYuksekligi, fit: BoxFit.fill, filterQuality: FilterQuality.medium),
    ]);
  }
}

/// Rafın üstündeki süsler: mum, saksı, asma. Hepsi tek denetleyiciyle hafifçe hareket eder.
class _Susler extends StatelessWidget {
  final AnimationController denetleyici;
  final double genislik;
  const _Susler({required this.denetleyici, required this.genislik});

  @override
  Widget build(BuildContext context) {
    const rafUstu = _KutuphaneState._ustBosluk + 6;
    return AnimatedBuilder(
      animation: denetleyici,
      builder: (context, _) {
        final t = denetleyici.value;
        double dalga(double katsayi, [double faz = 0]) => math.sin(2 * math.pi * (t * katsayi + faz));
        // mum
        const mumW = 54.0, mumH = 54.0 * 234 / 300;
        const mumSol = 74.0;
        final mumUst = rafUstu - mumH;
        const alevW = 14.0, alevH = 14.0 * 273 / 160;
        final alevOlcek = 1 + 0.07 * dalga(9) + 0.05 * dalga(23, .3);
        final alevDonus = 0.06 * dalga(5) + 0.03 * dalga(13, .2);
        final isik = (0.28 + 0.08 * dalga(9) + 0.05 * dalga(23, .3)).clamp(0.12, 0.45);
        // bitki
        const saksiW = 48.0, saksiH = 48.0 * 256 / 300;
        const yaprakW = 80.0, yaprakH = 80.0 * 335 / 380;
        final saksiSag = 26.0;
        final saksiLeft = genislik - saksiSag - saksiW;
        final yaprakDonus = 0.035 * dalga(1, .4) + 0.012 * dalga(3);
        final asmaDonus = 0.05 * dalga(2, .1) + 0.015 * dalga(5);
        return Stack(clipBehavior: Clip.none, children: [
          // mum ışığı
          Positioned(
            left: mumSol + mumW / 2 - 50,
            top: mumUst - alevH * 0.5 - 38,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [const Color(0xFFFFB347).withValues(alpha: isik), const Color(0xFFFFB347).withValues(alpha: 0)]),
              ),
            ),
          ),
          Positioned(left: mumSol, top: mumUst, width: mumW, height: mumH, child: Image.asset('$_gorsel/mum.webp', fit: BoxFit.fill, filterQuality: FilterQuality.medium)),
          Positioned(
            left: mumSol + mumW / 2 - alevW / 2,
            top: mumUst - alevH + 5,
            width: alevW,
            height: alevH,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..rotateZ(alevDonus)
                ..scaleByDouble(1 - 0.04 * dalga(11), alevOlcek, 1, 1),
              child: Image.asset('$_gorsel/alev.webp', fit: BoxFit.fill, filterQuality: FilterQuality.medium),
            ),
          ),
          // saksı + yaprak
          Positioned(
            left: saksiLeft - (yaprakW - saksiW) / 2,
            top: rafUstu - saksiH - yaprakH + 12,
            width: yaprakW,
            height: yaprakH,
            child: Transform.rotate(
              alignment: Alignment.bottomCenter,
              angle: yaprakDonus,
              child: Image.asset('$_gorsel/yaprak.webp', fit: BoxFit.fill, filterQuality: FilterQuality.medium),
            ),
          ),
          Positioned(left: saksiLeft, top: rafUstu - saksiH, width: saksiW, height: saksiH, child: Image.asset('$_gorsel/saksi.webp', fit: BoxFit.fill, filterQuality: FilterQuality.medium)),
          // asma (sol üst köşeden sarkar)
          Positioned(
            left: 4,
            top: rafUstu - 8,
            width: 22,
            height: 22 * 700 / 106,
            child: Transform.rotate(
              alignment: Alignment.topCenter,
              angle: asmaDonus,
              child: Image.asset('$_gorsel/asma.webp', fit: BoxFit.fill, filterQuality: FilterQuality.medium),
            ),
          ),
        ]);
      },
    );
  }
}
