import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../takvim/takvim_ayarlari.dart';
import '../takvim/takvim_deposu.dart';
import '../takvim/takvim_modeller.dart';
import 'etkinlik_duzenle.dart';

enum Gorunum { ay, hafta, gun }

const _gunKisa = ['PZT', 'SAL', 'ÇAR', 'PER', 'CUM', 'CMT', 'PZR'];

DateTime haftaBasi(DateTime d) => gunBasi(d).subtract(Duration(days: d.weekday - 1));

String etkinlikSaati(TEtkinlik e, {DateTime? gun}) {
  if (e.tumGun) return 'Tüm gün';
  final f = DateFormat('HH:mm');
  final g = gun == null ? null : gunBasi(gun);
  final basGunu = g != null && gunBasi(e.baslangic).isBefore(g) ? '…' : f.format(e.baslangic);
  final bitGunu = g != null && e.bitis.isAfter(sonrakiGun(g)) ? '…' : f.format(e.bitis);
  return '$basGunu–$bitGunu';
}

class TakvimEkrani extends StatefulWidget {
  const TakvimEkrani({super.key});

  @override
  State<TakvimEkrani> createState() => _TakvimEkraniState();
}

class _TakvimEkraniState extends State<TakvimEkrani> {
  final _depo = TakvimDeposu.instance;
  Gorunum _gorunum = Gorunum.ay;
  DateTime _odak = gunBasi(DateTime.now());
  bool _izinIstendi = false;
  Map<String, int> _sayilar = {};

  @override
  void initState() {
    super.initState();
    sekmeSecici.addListener(_sekmeDegisti);
    _depo.addListener(_depoDegisti);
    _baslat();
  }

  @override
  void dispose() {
    sekmeSecici.removeListener(_sekmeDegisti);
    _depo.removeListener(_depoDegisti);
    super.dispose();
  }

  Future<void> _baslat() async {
    await _depo.baslat();
    await _yukle();
    await _depo.notlariSenkronla();
  }

  void _sekmeDegisti() {
    if (sekmeSecici.value == 1 && _depo.hazir) {
      _depo.yenile();
      _depo.notlariSenkronla();
    }
  }

  bool _yukleniyor = false;
  bool _sayilarIstendi = false;
  void _depoDegisti() {
    // Takvim seçilince ilk yükleme (bir kez)
    if (_depo.hazir && !_depo.yuklendi && !_yukleniyor) _yukle();
  }

  (DateTime, DateTime) get _aralik {
    switch (_gorunum) {
      case Gorunum.ay:
        final ilk = DateTime(_odak.year, _odak.month, 1);
        final son = DateTime(_odak.year, _odak.month + 1, 1);
        return (haftaBasi(ilk).subtract(const Duration(days: 7)), son.add(const Duration(days: 14)));
      case Gorunum.hafta:
        final b = haftaBasi(_odak);
        return (b.subtract(const Duration(days: 7)), b.add(const Duration(days: 14)));
      case Gorunum.gun:
        return (_odak.subtract(const Duration(days: 7)), _odak.add(const Duration(days: 8)));
    }
  }

  Future<void> _yukle() async {
    if (!_depo.hazir || _yukleniyor) return;
    _yukleniyor = true;
    try {
      final (b, s) = _aralik;
      await _depo.yukle(b, s);
    } finally {
      _yukleniyor = false;
    }
  }

  void _odakDegistir(DateTime yeni) {
    setState(() => _odak = gunBasi(yeni));
    _yukle();
  }

  void _git(int yon) {
    switch (_gorunum) {
      case Gorunum.ay:
        _odakDegistir(DateTime(_odak.year, _odak.month + yon, math.min(_odak.day, 28)));
      case Gorunum.hafta:
        _odakDegistir(_odak.add(Duration(days: 7 * yon)));
      case Gorunum.gun:
        _odakDegistir(_odak.add(Duration(days: yon)));
    }
  }

  Future<void> _izinIste() async {
    final ok = await _depo.izinIste();
    if (mounted) setState(() => _izinIstendi = true);
    if (ok) await _takvimSayilariniYukle();
  }

  Future<void> _takvimSayilariniYukle() async {
    final s = await _depo.etkinlikSayilari();
    if (mounted) setState(() => _sayilar = s);
  }

  Future<void> _ekleGune(DateTime gun) async {
    final simdi = DateTime.now();
    final g = gunBasi(gun) == gunBasi(simdi)
        ? DateTime(simdi.year, simdi.month, simdi.day, simdi.hour + 1)
        : DateTime(gun.year, gun.month, gun.day, 9);
    await etkinlikDuzenleAc(baslangic: g);
  }

  Future<void> _gunPenceresi(DateTime gun) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _GunPenceresi(
        gun: gun,
        onEtkinlik: (e) {
          Navigator.pop(ctx);
          _ac(e);
        },
        onEkle: () {
          Navigator.pop(ctx);
          _ekleGune(gun);
        },
      ),
    );
  }

  Future<void> _ac(TEtkinlik e) async {
    await etkinlikDuzenleAc(mevcut: e);
  }

  String get _baslikMetni {
    final f = _gorunum == Gorunum.gun ? DateFormat('d MMMM, EEEE', 'tr') : DateFormat('LLLL y', 'tr');
    final s = f.format(_odak);
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_depo, TakvimAyarlari.instance]),
      builder: (context, _) {
        final hazir = _depo.hazir;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Renk.krem,
            title: hazir
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        tooltip: 'Önceki',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _git(-1)),
                    Flexible(child: Text(_baslikMetni, overflow: TextOverflow.ellipsis)),
                    IconButton(
                        tooltip: 'Sonraki',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _git(1)),
                  ])
                : const Text('Takvim'),
            centerTitle: true,
            actions: [
              if (hazir) ...[
                IconButton(
                    tooltip: 'Bugün',
                    icon: const Icon(Icons.today),
                    onPressed: () => _odakDegistir(DateTime.now())),
                PopupMenuButton<Gorunum>(
                  tooltip: 'Görünüm',
                  icon: Icon(switch (_gorunum) {
                    Gorunum.ay => Icons.calendar_view_month,
                    Gorunum.hafta => Icons.calendar_view_week,
                    Gorunum.gun => Icons.calendar_view_day,
                  }),
                  onSelected: (g) {
                    setState(() => _gorunum = g);
                    _yukle();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: Gorunum.ay, child: Text('Ay')),
                    PopupMenuItem(value: Gorunum.hafta, child: Text('Hafta')),
                    PopupMenuItem(value: Gorunum.gun, child: Text('Gün')),
                  ],
                ),
                IconButton(tooltip: 'Etkinlik ekle', icon: const Icon(Icons.add), onPressed: () => _ekleGune(_odak)),
              ],
            ],
          ),
          body: _govde(),
        );
      },
    );
  }

  Widget _govde() {
    if (!_depo.izinSorgulandi) return const Center(child: CircularProgressIndicator());
    if (!_depo.izinVar) return _izinKarti();
    if (!_depo.takvimSecili) return _takvimSecimi();
    return Column(children: [
      if (_depo.hata != null)
        Container(
          width: double.infinity,
          color: Colors.red.shade50,
          padding: const EdgeInsets.all(10),
          child: Text(_depo.hata!, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
        ),
      Expanded(
        child: switch (_gorunum) {
          Gorunum.ay => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -250) _git(1);
                if (v > 250) _git(-1);
              },
              child: _AyGorunumu(odak: _odak, onGunTikla: _gunPenceresi),
            ),
          Gorunum.hafta => RefreshIndicator(
              onRefresh: _yenile,
              child: _HaftaGorunumu(odak: _odak, onAc: _ac),
            ),
          Gorunum.gun => RefreshIndicator(
              onRefresh: _yenile,
              child: _GunGorunumu(gun: _odak, onAc: _ac),
            ),
        },
      ),
    ]);
  }

  Future<void> _yenile() async {
    await _depo.yenile();
    await _depo.notlariSenkronla();
  }

  Widget _izinKarti() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📅', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text('Takvimini bağlayalım',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Renk.kahve, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text(
            'Aklımda, telefonundaki Samsung Takvim\'i okuyup yazabilmek için takvim iznine ihtiyaç duyar. '
            'Böylece planlarını burada görür, notlarını takvime ekleyebilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Renk.kahve),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _izinIste,
            icon: const Icon(Icons.lock_open),
            label: const Text('Takvim iznini ver'),
          ),
          if (_izinIstendi) ...[
            const SizedBox(height: 16),
            Text(
              'İzin verilmedi. Telefonun Ayarlar → Uygulamalar → Aklımda → İzinler → Takvim bölümünden '
              '"İzin ver"i seçebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade800, fontSize: 13),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _takvimSecimi() {
    if (!_sayilarIstendi && _depo.takvimler.isNotEmpty) {
      _sayilarIstendi = true;
      _takvimSayilariniYukle();
    }
    final liste = [..._depo.takvimler];
    liste.sort((a, b) => (_sayilar[b.id] ?? 0).compareTo(_sayilar[a.id] ?? 0));
    final onerilen = liste.isNotEmpty && (_sayilar[liste.first.id] ?? 0) > 0 ? liste.first.id : null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Hangi takvimi kullanalım?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Renk.kahve, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text(
          'Planlarını yazdığın takvimi seç. Aklımda sadece bu takvimdeki etkinlikleri okur ve yeni etkinlikleri buraya yazar. '
          'Etkinlik sayıları son ve gelecek 3 ayı gösterir.',
          style: TextStyle(color: Renk.kahve),
        ),
        const SizedBox(height: 12),
        if (liste.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Telefonunda takvim bulunamadı.', textAlign: TextAlign.center),
          ),
        for (final t in liste)
          Card(
            elevation: 0,
            color: Renk.acikKrem,
            child: ListTile(
              leading: CircleAvatar(backgroundColor: t.renk ?? Renk.turuncu, radius: 10),
              title: Text(t.ad),
              subtitle: Text([
                if (t.hesap != null && t.hesap!.isNotEmpty) t.hesap!,
                '${_sayilar[t.id] ?? 0} etkinlik',
                if (t.saltOkunur) 'sadece okunur',
                if (t.id == onerilen) 'en çok etkinlik burada',
              ].join(' · ')),
              enabled: !t.saltOkunur,
              onTap: t.saltOkunur
                  ? null
                  : () async {
                      _sayilarIstendi = false;
                      await _depo.takvimSec(t);
                      await _yukle();
                      await _depo.notlariSenkronla();
                    },
            ),
          ),
      ],
    );
  }
}

class _EtkinlikKarti extends StatelessWidget {
  final TEtkinlik e;
  final DateTime gun;
  final void Function(TEtkinlik) onAc;
  const _EtkinlikKarti({required this.e, required this.gun, required this.onAc});

  @override
  Widget build(BuildContext context) {
    final renk = e.uygulamaninMi ? Renk.turuncu : Renk.kahve;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      elevation: 0,
      color: renk.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onAc(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Container(width: 4, height: 34, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.baslik, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Renk.kahve, fontWeight: FontWeight.w600)),
                Text(etkinlikSaati(e, gun: gun), style: TextStyle(color: Renk.kahve.withValues(alpha: 0.7), fontSize: 12)),
              ]),
            ),
            if (e.tekrarli) const Icon(Icons.repeat, size: 16, color: Renk.kahve),
            if (!e.meshgul) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.event_available, size: 16, color: Renk.kahve)),
          ]),
        ),
      ),
    );
  }
}

/// Ay görünümü: tüm sayfayı kaplar, her günün etkinlik başlıkları hücrede görünür.
/// Güne dokununca o günün etkinlikleri pencerede açılır.
class _AyGorunumu extends StatelessWidget {
  final DateTime odak;
  final void Function(DateTime) onGunTikla;
  const _AyGorunumu({required this.odak, required this.onGunTikla});

  static const _baslikYuksekligi = 28.0;
  static const _chipYuksekligi = 26.0;
  static const _gunNoYuksekligi = 24.0;
  static const _fazlaYazisiYuksekligi = 14.0;

  @override
  Widget build(BuildContext context) {
    final depo = TakvimDeposu.instance;
    final ilk = DateTime(odak.year, odak.month, 1);
    final baslangic = haftaBasi(ilk);
    final gunSayisi = DateTime(odak.year, odak.month + 1, 0).day;
    final haftaSayisi = ((ilk.weekday - 1 + gunSayisi) / 7).ceil();
    final bugun = gunBasi(DateTime.now());
    return LayoutBuilder(builder: (context, c) {
      final hucreH = (c.maxHeight - _baslikYuksekligi) / haftaSayisi;
      return Column(children: [
        SizedBox(
          height: _baslikYuksekligi,
          child: Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(_gunKisa[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: i >= 5 ? Colors.red.shade400 : Renk.kahve.withValues(alpha: 0.7),
                      )),
                ),
              ),
          ]),
        ),
        for (var h = 0; h < haftaSayisi; h++)
          SizedBox(
            height: hucreH,
            child: Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(child: _hucre(depo, baslangic.add(Duration(days: h * 7 + i)), bugun, hucreH)),
            ]),
          ),
      ]);
    });
  }

  Widget _hucre(TakvimDeposu depo, DateTime g, DateTime bugun, double yukseklik) {
    final buAy = g.month == odak.month;
    final bugunMu = g == bugun;
    final hafta = g.weekday >= 6;
    final etkinlikler = depo.gununEtkinlikleri(g);
    final alan = yukseklik - _gunNoYuksekligi - 2;
    var sigan = (alan / _chipYuksekligi).floor();
    if (sigan < 0) sigan = 0;
    var gosterilecek = etkinlikler.length;
    var fazla = 0;
    if (etkinlikler.length > sigan) {
      gosterilecek = ((alan - _fazlaYazisiYuksekligi) / _chipYuksekligi).floor().clamp(0, etkinlikler.length);
      fazla = etkinlikler.length - gosterilecek;
    }
    final solukluk = buAy ? 1.0 : 0.38;
    return InkWell(
      onTap: () => onGunTikla(g),
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Renk.kahve.withValues(alpha: 0.12)))),
        padding: const EdgeInsets.fromLTRB(1, 2, 1, 0),
        child: Opacity(
          opacity: solukluk,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: _gunNoYuksekligi - 2,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: bugunMu
                      ? BoxDecoration(color: Renk.turuncu, borderRadius: BorderRadius.circular(8))
                      : null,
                  child: Text('${g.day}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: bugunMu ? FontWeight.bold : FontWeight.w500,
                        color: bugunMu ? Colors.white : (hafta ? Colors.red.shade400 : Renk.kahve),
                      )),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: ClipRect(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final e in etkinlikler.take(gosterilecek)) _chip(depo, e),
                  if (fazla > 0)
                    SizedBox(
                      height: _fazlaYazisiYuksekligi,
                      child: Center(
                        child: Text('+$fazla',
                            style: TextStyle(fontSize: 10, color: Renk.kahve.withValues(alpha: 0.7))),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _chip(TakvimDeposu depo, TEtkinlik e) {
    final renk = depo.renkOf(e) ?? (e.uygulamaninMi ? Renk.turuncu : Renk.kahve);
    final metin = Text(
      e.baslik,
      maxLines: 2,
      overflow: TextOverflow.clip,
      style: TextStyle(fontSize: 9, height: 1.1, color: e.tumGun ? Colors.white : Renk.kahve),
    );
    return Container(
      height: _chipYuksekligi - 2,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: e.tumGun ? renk.withValues(alpha: 0.85) : renk.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(3),
        border: e.tumGun ? null : Border(left: BorderSide(color: renk, width: 2.5)),
      ),
      alignment: Alignment.centerLeft,
      child: metin,
    );
  }
}

/// Güne dokununca açılan pencere: o günün etkinlikleri ve hızlı "ekle".
class _GunPenceresi extends StatelessWidget {
  final DateTime gun;
  final void Function(TEtkinlik) onEtkinlik;
  final VoidCallback onEkle;
  const _GunPenceresi({required this.gun, required this.onEtkinlik, required this.onEkle});

  @override
  Widget build(BuildContext context) {
    final depo = TakvimDeposu.instance;
    final yazi = Theme.of(context).textTheme;
    final ekranH = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: Renk.acikKrem,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: ekranH * 0.78),
        child: ListenableBuilder(
          listenable: depo,
          builder: (context, _) {
            final liste = depo.gununEtkinlikleri(gun);
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Renk.turuncu, borderRadius: BorderRadius.circular(12)),
                    child: Text('${gun.day}',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(DateFormat('EEEE', 'tr').format(gun),
                        style: yazi.titleLarge?.copyWith(color: Renk.kahve, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                      tooltip: 'Kapat', icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ]),
                const Divider(height: 24),
                Flexible(
                  child: liste.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text('Bu gün için etkinlik yok.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Renk.kahve.withValues(alpha: 0.6))),
                        )
                      : ListView(shrinkWrap: true, children: [
                          for (final e in liste) _satir(context, depo, e),
                        ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: onEkle,
                      child: Container(
                        height: 48,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: Renk.kahve.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: Renk.kahve.withValues(alpha: 0.2)),
                        ),
                        child: Text('${DateFormat('d MMM', 'tr').format(gun)} için ekle',
                            style: TextStyle(color: Renk.kahve.withValues(alpha: 0.75))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Etkinlik ekle',
                    onPressed: onEkle,
                    icon: const Icon(Icons.add),
                  ),
                ]),
              ]),
            );
          },
        ),
      ),
    );
  }

  Widget _satir(BuildContext context, TakvimDeposu depo, TEtkinlik e) {
    final renk = depo.renkOf(e) ?? (e.uygulamaninMi ? Renk.turuncu : Renk.kahve);
    final f = DateFormat('HH:mm');
    final alt = e.tumGun ? 'Gün boyu' : '${f.format(e.baslangic)} - ${f.format(e.bitis)}';
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onEtkinlik(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 52,
            child: e.tumGun
                ? const Icon(Icons.calendar_today_outlined, size: 20, color: Renk.kahve)
                : Text(f.format(e.baslangic),
                    style: const TextStyle(color: Renk.kahve, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Container(width: 4, height: 40, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.baslik,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Renk.kahve, fontSize: 17, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(alt, style: TextStyle(color: Renk.kahve.withValues(alpha: 0.6), fontSize: 14)),
            ]),
          ),
          if (e.tekrarli) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.repeat, size: 16, color: Renk.kahve)),
        ]),
      ),
    );
  }
}

class _HaftaGorunumu extends StatelessWidget {
  final DateTime odak;
  final void Function(TEtkinlik) onAc;
  const _HaftaGorunumu({required this.odak, required this.onAc});

  @override
  Widget build(BuildContext context) {
    final depo = TakvimDeposu.instance;
    final bas = haftaBasi(odak);
    final bugun = gunBasi(DateTime.now());
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        for (var i = 0; i < 7; i++) ...[
          Builder(builder: (context) {
            final g = bas.add(Duration(days: i));
            final liste = depo.gununEtkinlikleri(g);
            final bugunMu = g == bugun;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  DateFormat('d MMMM, EEEE', 'tr').format(g),
                  style: TextStyle(
                    color: bugunMu ? Renk.turuncu : Renk.kahve,
                    fontWeight: bugunMu ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ),
              if (liste.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text('—', style: TextStyle(color: Renk.kahve.withValues(alpha: 0.4))),
                ),
              for (final e in liste) _EtkinlikKarti(e: e, gun: g, onAc: onAc),
            ]);
          }),
        ],
      ],
    );
  }
}

class _GunGorunumu extends StatelessWidget {
  final DateTime gun;
  final void Function(TEtkinlik) onAc;
  const _GunGorunumu({required this.gun, required this.onAc});

  static const _saatYuksekligi = 56.0;
  static const _solBosluk = 48.0;

  @override
  Widget build(BuildContext context) {
    final depo = TakvimDeposu.instance;
    final liste = depo.gununEtkinlikleri(gun);
    final tumGun = liste.where((e) => e.tumGun).toList();
    final saatli = liste.where((e) => !e.tumGun).toList();
    final g0 = gunBasi(gun);
    final g1 = sonrakiGun(g0);
    final yerlesim = _yerlestir(saatli, g0, g1);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        for (final e in tumGun) _EtkinlikKarti(e: e, gun: gun, onAc: onAc),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, c) {
          final genislik = c.maxWidth - _solBosluk - 12;
          return SizedBox(
            height: 24 * _saatYuksekligi,
            child: Stack(children: [
              for (var s = 0; s < 24; s++)
                Positioned(
                  top: s * _saatYuksekligi,
                  left: 0,
                  right: 0,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: _solBosluk,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text('${s.toString().padLeft(2, '0')}:00',
                            style: TextStyle(fontSize: 11, color: Renk.kahve.withValues(alpha: 0.5))),
                      ),
                    ),
                    Expanded(child: Divider(height: 8, color: Renk.kahve.withValues(alpha: 0.12))),
                  ]),
                ),
              for (final y in yerlesim)
                Positioned(
                  top: y.ustDk / 60 * _saatYuksekligi + 6,
                  left: _solBosluk + y.sutun * genislik / y.sutunSayisi,
                  width: genislik / y.sutunSayisi - 3,
                  height: math.max(26, y.sureDk / 60 * _saatYuksekligi - 2),
                  child: GestureDetector(
                    onTap: () => onAc(y.e),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: (y.e.uygulamaninMi ? Renk.turuncu : Renk.kahve).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(left: BorderSide(color: y.e.uygulamaninMi ? Renk.turuncu : Renk.kahve, width: 3)),
                      ),
                      child: Text('${y.e.baslik}\n${etkinlikSaati(y.e, gun: gun)}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Renk.kahve)),
                    ),
                  ),
                ),
            ]),
          );
        }),
      ],
    );
  }

  /// Çakışan etkinlikleri yan yana sütunlara dağıtır.
  List<_Yerlesim> _yerlestir(List<TEtkinlik> liste, DateTime g0, DateTime g1) {
    final sonuc = <_Yerlesim>[];
    final sirali = [...liste]..sort((a, b) => a.baslangic.compareTo(b.baslangic));
    var grup = <_Yerlesim>[];
    DateTime? grupBitis;
    void grubuKapat() {
      final n = grup.fold<int>(0, (m, y) => math.max(m, y.sutun + 1));
      for (final y in grup) {
        y.sutunSayisi = n;
      }
      sonuc.addAll(grup);
      grup = [];
      grupBitis = null;
    }

    for (final e in sirali) {
      final b = e.baslangic.isBefore(g0) ? g0 : e.baslangic;
      var s = e.bitis.isAfter(g1) ? g1 : e.bitis;
      if (!s.isAfter(b)) s = b.add(const Duration(minutes: 30));
      if (grupBitis != null && !b.isBefore(grupBitis!)) grubuKapat();
      var sutun = 0;
      while (grup.any((y) => y.sutun == sutun && y.bitis.isAfter(b))) {
        sutun++;
      }
      grup.add(_Yerlesim(e, b, s, sutun, b.difference(g0).inMinutes, s.difference(b).inMinutes));
      grupBitis = grupBitis == null || s.isAfter(grupBitis!) ? s : grupBitis;
    }
    if (grup.isNotEmpty) grubuKapat();
    return sonuc;
  }
}

class _Yerlesim {
  final TEtkinlik e;
  final DateTime bas;
  final DateTime bitis;
  final int sutun;
  final int ustDk;
  final int sureDk;
  int sutunSayisi = 1;
  _Yerlesim(this.e, this.bas, this.bitis, this.sutun, this.ustDk, this.sureDk);
}
