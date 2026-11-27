import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'not_detay.dart';
import 'onay_bekleyenler.dart';
import 'yazili_not.dart';

/// Notlar sekmesi: klasör görünümü (varsayılan) ve liste görünümü.
class NotlarEkrani extends StatefulWidget {
  const NotlarEkrani({super.key});

  @override
  State<NotlarEkrani> createState() => _NotlarEkraniState();
}

class _NotlarEkraniState extends State<NotlarEkrani> {
  bool _klasor = false; // varsayılan: tüm notların listesi

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Renk.zemin,
        title: const Text('Notlar'),
        actions: [
          IconButton(
            tooltip: _klasor ? 'Liste görünümü' : 'Klasör görünümü',
            icon: Icon(_klasor ? Icons.view_agenda_outlined : Icons.folder_outlined),
            onPressed: () => setState(() => _klasor = !_klasor),
          ),
        ],
      ),
      body: Column(children: [
        const OnayBandi(),
        const IslenecekBandi(),
        Expanded(
          child: _klasor
              ? const _KlasorGorunumu()
              : NotListesi(kaynak: () => Depo.instance.aktifNotlar, aramaVar: true),
        ),
      ]),
    );
  }
}

class _KlasorGorunumu extends StatelessWidget {
  const _KlasorGorunumu();

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final agac = depo.agac;
        final aktif = depo.aktifNotlar;
        int sayi(int katId) {
          final ids = agac.kendisiVeAltlari(katId);
          return aktif.where((n) => n.kategoriIdler.any(ids.contains)).length;
        }

        final kategorisiz = aktif.where((n) => n.kategoriIdler.isEmpty).length;
        return ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            for (final k in agac.anaKategoriler)
              _KlasorSatiri(
                ad: k.ad,
                sayi: sayi(k.id),
                onTap: () => _klasorAc(context, k),
              ),
            _KlasorSatiri(
              ad: 'Kategorisiz',
              ikon: Icons.inbox_outlined,
              sayi: kategorisiz,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ListeSayfasi(
                    baslik: 'Kategorisiz',
                    kaynak: () => Depo.instance.aktifNotlar.where((n) => n.kategoriIdler.isEmpty).toList(),
                  ),
                ),
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            _KlasorSatiri(
              ad: 'Arşiv',
              ikon: Icons.archive_outlined,
              sayi: depo.arsivNotlari.length,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ListeSayfasi(
                    baslik: 'Arşiv',
                    arsivMi: true,
                    kaynak: () => Depo.instance.arsivNotlari,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _klasorAc(BuildContext context, Kategori k) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => KategoriSayfasi(kategori: k)));
  }
}

class _KlasorSatiri extends StatelessWidget {
  final String ad;
  final int sayi;
  final IconData ikon;
  final VoidCallback onTap;
  const _KlasorSatiri({required this.ad, required this.sayi, required this.onTap, this.ikon = Icons.folder_outlined});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(ikon, color: Renk.vurgu),
        title: Text(ad, style: TextStyle(color: Renk.yazi, fontWeight: FontWeight.w500)),
        trailing: Text('$sayi', style: TextStyle(color: Renk.yazi.withValues(alpha: 0.6))),
        onTap: onTap,
      );
}

/// Bir kategorinin içeriği: alt klasörler ve doğrudan bu kategorideki notlar (başlıksız, sayfa içinde kullanılır).
class KategoriGovdesi extends StatelessWidget {
  final Kategori kategori;
  const KategoriGovdesi({super.key, required this.kategori});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final altlar = depo.agac.altlari(kategori.id);
        return NotListesi(
          kaynak: () => depo.aktifNotlar.where((n) => n.kategoriIdler.contains(kategori.id)).toList(),
          klasorKategoriId: kategori.id,
          ustKisim: [
            for (final alt in altlar)
              _KlasorSatiri(
                ad: alt.ad,
                sayi: depo.aktifNotlar.where((n) => n.kategoriIdler.contains(alt.id)).length,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => KategoriSayfasi(kategori: alt))),
              ),
            if (altlar.isNotEmpty) const Divider(indent: 16, endIndent: 16),
          ],
        );
      },
    );
  }
}

/// Bir kategorinin sayfası (alt kategoriler için).
class KategoriSayfasi extends StatelessWidget {
  final Kategori kategori;
  const KategoriSayfasi({super.key, required this.kategori});

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return Scaffold(
      appBar: AppBar(backgroundColor: Renk.zemin, title: Text(depo.agac.tamAd(kategori.id)), actions: [
        IconButton(
            tooltip: 'Liste ekle',
            icon: const Icon(Icons.checklist),
            onPressed: () => yaziliNotAc(liste: true, kategoriId: kategori.id)),
        IconButton(
            tooltip: 'Not ekle',
            icon: const Icon(Icons.note_add_outlined),
            onPressed: () => yaziliNotAc(kategoriId: kategori.id)),
      ]),
      body: KategoriGovdesi(kategori: kategori),
    );
  }
}

class ListeSayfasi extends StatelessWidget {
  final String baslik;
  final List<Not> Function() kaynak;
  final bool arsivMi;
  const ListeSayfasi({super.key, required this.baslik, required this.kaynak, this.arsivMi = false});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: Renk.zemin, title: Text(baslik)),
        body: NotListesi(kaynak: kaynak, arsivMi: arsivMi),
      );
}

/// Not listesi: arama, sıralama, uzun basınca toplu seçim (Taşı, Kopyala, Arşivle, Sil).
class NotListesi extends StatefulWidget {
  final List<Not> Function() kaynak;
  final bool aramaVar;
  final bool arsivMi;
  final int? klasorKategoriId;
  final List<Widget> ustKisim;

  const NotListesi({
    super.key,
    required this.kaynak,
    this.aramaVar = false,
    this.arsivMi = false,
    this.klasorKategoriId,
    this.ustKisim = const [],
  });

  @override
  State<NotListesi> createState() => _NotListesiState();
}

class _NotListesiState extends State<NotListesi> {
  String _arama = '';
  bool _yeniOnce = true;
  final Set<String> _secili = {};

  bool get _secimModu => _secili.isNotEmpty;

  List<Not> _filtrele(List<Not> liste) {
    final q = _arama.trim().toLowerCase();
    var sonuc = q.isEmpty
        ? liste
        : liste.where((n) {
            final hepsi = [n.metin, n.baslik ?? '', n.yorum ?? '', n.link ?? ''].join(' ').toLowerCase();
            return hepsi.contains(q);
          }).toList();
    sonuc = [...sonuc]..sort((a, b) =>
        _yeniOnce ? b.olusturma.compareTo(a.olusturma) : a.olusturma.compareTo(b.olusturma));
    return sonuc;
  }

  Future<void> _tasiVeyaKopyala({required bool tasi}) async {
    final hedef = await kategoriSec(context, baslik: tasi ? 'Nereye taşınsın?' : 'Nereye kopyalansın?');
    if (hedef == null) return;
    final idler = _secili.toList();
    if (tasi) {
      await Depo.instance.tasi(idler, hedef, eskiKategori: widget.klasorKategoriId);
    } else {
      await Depo.instance.kopyala(idler, hedef);
    }
    setState(_secili.clear);
    mesajGoster(tasi ? 'Taşındı' : 'Kopyalandı');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.instance,
      builder: (context, _) {
        final notlar = _filtrele(widget.kaynak());
        _secili.removeWhere((id) => !notlar.any((n) => n.id == id));
        return Column(
          children: [
            if (_secimModu)
              Material(
                color: Renk.vurgu.withValues(alpha: 0.18),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_secili.clear)),
                  Text('${_secili.length} seçili'),
                  const Spacer(),
                  if (!widget.arsivMi) ...[
                    IconButton(
                        tooltip: 'Taşı',
                        icon: const Icon(Icons.drive_file_move_outline),
                        onPressed: () => _tasiVeyaKopyala(tasi: true)),
                    IconButton(
                        tooltip: 'Kopyala',
                        icon: const Icon(Icons.copy_all_outlined),
                        onPressed: () => _tasiVeyaKopyala(tasi: false)),
                  ],
                  IconButton(
                    tooltip: widget.arsivMi ? 'Arşivden çıkar' : 'Arşivle',
                    icon: Icon(widget.arsivMi ? Icons.unarchive_outlined : Icons.archive_outlined),
                    onPressed: () async {
                      final idler = _secili.toList();
                      setState(_secili.clear);
                      await arsivleVeGeriAlGoster(idler, !widget.arsivMi);
                    },
                  ),
                  IconButton(
                    tooltip: 'Sil',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final idler = _secili.toList();
                      setState(_secili.clear);
                      await silVeGeriAlGoster(idler);
                    },
                  ),
                ]),
              ),
            if (widget.aramaVar && !_secimModu)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => _arama = v),
                      decoration: InputDecoration(
                        hintText: 'Notlarda ara',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        filled: true,
                        fillColor: Renk.kart,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                    ),
                  ),
                  PopupMenuButton<bool>(
                    tooltip: 'Sırala',
                    icon: const Icon(Icons.sort),
                    initialValue: _yeniOnce,
                    onSelected: (v) => setState(() => _yeniOnce = v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: true, child: Text('Önce en yeni')),
                      PopupMenuItem(value: false, child: Text('Önce en eski')),
                    ],
                  ),
                ]),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 100),
                children: [
                  ...widget.ustKisim,
                  if (notlar.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        _arama.isEmpty ? 'Burada henüz not yok.' : 'Aramaya uyan not bulunamadı.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Renk.yazi.withValues(alpha: 0.6)),
                      ),
                    ),
                  for (final n in notlar)
                    NotKarti(
                      not: n,
                      secili: _secili.contains(n.id),
                      onTap: () {
                        if (_secimModu) {
                          setState(() => _secili.contains(n.id) ? _secili.remove(n.id) : _secili.add(n.id));
                        } else {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => NotDetay(notId: n.id)));
                        }
                      },
                      onLongPress: () => setState(() => _secili.add(n.id)),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
