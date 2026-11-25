
import 'package:material_ui/material_ui.dart';

import '../veri/depo.dart';
import '../veri/modeller.dart';
import '../kategori_gorunum.dart';
import '../ortak.dart';
import 'not_detay.dart';
import 'notlar_ekrani.dart';

/// Ana sayfanın kütüphanesi: her kategori bir kitap, kategorisiz notlar raftaki post-it kâğıtlar.
class Kutuphane extends StatelessWidget {
  const Kutuphane({super.key});

  static const _kagitRenkleri = [
    Color(0xFFE6D98F),
    Color(0xFFA9CDB6),
    Color(0xFFDDB3C0),
    Color(0xFFAFC3DD),
  ];
  static const _gecikme = 8;

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final agac = depo.agac;
        final aktif = depo.aktifNotlar;
        final kitaplar = agac.anaKategoriler;
        final kagitlar = aktif.where((n) => n.kategoriIdler.isEmpty).toList();
        return Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            color: Renk.koyu ? const Color(0xFF3B3129).withValues(alpha: 0.85) : const Color(0xFFEBD6B4),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Renk.koyu ? const Color(0xFF7A6652) : const Color(0xFFD7B27E), width: 7),
            boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: LayoutBuilder(builder: (context, c) {
            final satirlar = _satirlaraBol(kitaplar, c.maxWidth);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (kitaplar.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Henüz kitap yok. Ayarlar > Kategorileri düzenle ile ekleyebilirsin.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                ),
              for (final satir in satirlar) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final k in satir)
                    Padding(
                      padding: const EdgeInsets.only(right: _bosluk),
                      child: _Kitap(kategori: k, agac: agac, sayi: _sayi(agac, aktif, k.id)),
                    ),
                ]),
                _Tahta(),
                const SizedBox(height: 6),
              ],
              if (kagitlar.isNotEmpty) _Kagitlar(kagitlar: kagitlar),
            ]);
          }),
        );
      },
    );
  }

  static const _bosluk = 6.0;

  static double _kitapGenisligi(Kategori k) => 46.0 + (k.id % 3) * 6;

  static int _sayi(KategoriAgaci agac, List<Not> aktif, int id) {
    final ids = agac.kendisiVeAltlari(id);
    return aktif.where((n) => n.kategoriIdler.any(ids.contains)).length;
  }

  /// Kitapları raf genişliğine göre satırlara böler.
  static List<List<Kategori>> _satirlaraBol(List<Kategori> kitaplar, double genislik) {
    final sonuc = <List<Kategori>>[];
    var satir = <Kategori>[];
    var kullanilan = 0.0;
    for (final k in kitaplar) {
      final w = _kitapGenisligi(k) + _bosluk;
      if (satir.isNotEmpty && kullanilan + w > genislik) {
        sonuc.add(satir);
        satir = [];
        kullanilan = 0;
      }
      satir.add(k);
      kullanilan += w;
    }
    if (satir.isNotEmpty) sonuc.add(satir);
    return sonuc;
  }
}

class _Tahta extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(children: [
        Container(height: 6, color: Renk.koyu ? const Color(0xFF8C7660) : const Color(0xFFEDCF9C)),
        Container(height: 4, color: Renk.koyu ? const Color(0xFF5A4838) : const Color(0xFFC99F68)),
      ]);
}

class _Kitap extends StatelessWidget {
  final Kategori kategori;
  final KategoriAgaci agac;
  final int sayi;
  const _Kitap({required this.kategori, required this.agac, required this.sayi});

  @override
  Widget build(BuildContext context) {
    final renk = agac.renkOf(kategori.id);
    final koyu = Color.lerp(renk, Colors.black, 0.45)!;
    final w = Kutuphane._kitapGenisligi(kategori);
    final h = 100.0 + ((kategori.id * 37) % 5) * 10;
    return Semantics(
      button: true,
      label: '${kategori.ad}, $sayi not',
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KategoriSayfasi(kategori: kategori))),
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: renk,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            border: Border.all(color: koyu, width: 2),
          ),
          child: Stack(children: [
            // sırt rengi şeritleri
            Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: koyu.withValues(alpha: 0.5))),
            Positioned(left: 0, right: 0, top: 0, height: 4, child: ColoredBox(color: const Color(0xFFFBF1DA).withValues(alpha: 0.9))), // sayfa kenarı
            Positioned(left: 0, right: 0, top: 8, height: 2, child: ColoredBox(color: const Color(0xFFE8CF8A).withValues(alpha: 0.85))),
            Positioned(left: 0, right: 0, bottom: 8, height: 2, child: ColoredBox(color: const Color(0xFFE8CF8A).withValues(alpha: 0.85))),
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(child: kategoriSimgesi(agac, kategori.id, size: 16, renk: Colors.white.withValues(alpha: 0.9))),
            ),
            Positioned(
              top: 34,
              bottom: 16,
              left: 0,
              right: 0,
              child: RotatedBox(
                quarterTurns: 3,
                child: Center(
                  child: Text(kategori.ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                ),
              ),
            ),
            if (sayi > 0)
              Positioned(
                bottom: 14,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(color: koyu, borderRadius: BorderRadius.circular(6)),
                  child: Text('$sayi', style: const TextStyle(color: Colors.white, fontSize: 9)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Kategorisiz notlar: rafa yapıştırılmış, hafif eğik post-it kâğıtları.
class _Kagitlar extends StatelessWidget {
  final List<Not> kagitlar;
  const _Kagitlar({required this.kagitlar});

  @override
  Widget build(BuildContext context) {
    final gorunen = kagitlar.take(Kutuphane._gecikme).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (final n in gorunen) _Kagit(not: n),
        if (kagitlar.length > Kutuphane._gecikme)
          ActionChip(
            label: Text('Tümü (${kagitlar.length})'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ListeSayfasi(
                      baslik: 'Kategorisiz notlar',
                      kaynak: () => Depo.instance.aktifNotlar.where((n) => n.kategoriIdler.isEmpty).toList())),
            ),
          ),
      ]),
    );
  }
}

class _Kagit extends StatelessWidget {
  final Not not;
  const _Kagit({required this.not});

  @override
  Widget build(BuildContext context) {
    final h = not.id.hashCode;
    final renk = Kutuphane._kagitRenkleri[h.abs() % Kutuphane._kagitRenkleri.length];
    final aci = (((h.abs() % 9) - 4) * 0.018);
    return Transform.rotate(
      angle: aci,
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotDetay(notId: not.id))),
        child: Container(
          width: 76,
          height: 70,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
          decoration: BoxDecoration(
            color: renk,
            boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(1, 2))],
          ),
          child: Text(not.gorunenBaslik,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, height: 1.15, color: Color(0xFF2B2B2B))),
        ),
      ),
    );
  }
}
