import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../takvim/takvim_ayarlari.dart';
import '../takvim/takvim_deposu.dart';
import '../takvim/takvim_modeller.dart';
import 'etkinlik_duzenle.dart';

enum Gorunum { ay, hafta, gun }

const _gunKisa = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

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

  Future<void> _ekle() async {
    final simdi = DateTime.now();
    final g = gunBasi(_odak) == gunBasi(simdi)
        ? DateTime(simdi.year, simdi.month, simdi.day, simdi.hour + 1)
        : DateTime(_odak.year, _odak.month, _odak.day, 9);
    await etkinlikDuzenleAc(baslangic: g);
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
            title: Text(hazir ? _baslikMetni : 'Takvim'),
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
                IconButton(tooltip: 'Etkinlik ekle', icon: const Icon(Icons.add), onPressed: _ekle),
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
      _gezinti(),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () async {
            await _depo.yenile();
            await _depo.notlariSenkronla();
          },
          child: switch (_gorunum) {
            Gorunum.ay => _AyGorunumu(odak: _odak, onGunSec: (g) => setState(() => _odak = gunBasi(g)), onAc: _ac),
            Gorunum.hafta => _HaftaGorunumu(odak: _odak, onAc: _ac),
            Gorunum.gun => _GunGorunumu(gun: _odak, onAc: _ac),
          },
        ),
      ),
    ]);
  }

  Widget _gezinti() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _git(-1)),
          Expanded(
            child: Text(
              switch (_gorunum) {
                Gorunum.ay => _depo.ayarlar.takvimAdi ?? '',
                Gorunum.hafta => _haftaMetni(),
                Gorunum.gun => _depo.ayarlar.takvimAdi ?? '',
              },
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Renk.kahve.withValues(alpha: 0.7), fontSize: 13),
            ),
          ),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _git(1)),
        ]),
      );

  String _haftaMetni() {
    final b = haftaBasi(_odak);
    final s = b.add(const Duration(days: 6));
    final f = DateFormat('d MMM', 'tr');
    return '${f.format(b)} – ${f.format(s)}';
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

class _AyGorunumu extends StatelessWidget {
  final DateTime odak;
  final void Function(DateTime) onGunSec;
  final void Function(TEtkinlik) onAc;
  const _AyGorunumu({required this.odak, required this.onGunSec, required this.onAc});

  @override
  Widget build(BuildContext context) {
    final depo = TakvimDeposu.instance;
    final ilk = DateTime(odak.year, odak.month, 1);
    final baslangic = haftaBasi(ilk);
    final bugun = gunBasi(DateTime.now());
    final haftaSayisi = ((ilk.difference(baslangic).inDays + DateTime(odak.year, odak.month + 1, 0).day) / 7).ceil();
    final secili = depo.gununEtkinlikleri(odak);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            for (final g in _gunKisa)
              Expanded(
                child: Center(
                  child: Text(g, style: TextStyle(color: Renk.kahve.withValues(alpha: 0.6), fontSize: 12)),
                ),
              ),
          ]),
        ),
        for (var h = 0; h < haftaSayisi; h++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              for (var i = 0; i < 7; i++)
                Expanded(child: _gunHucresi(depo, baslangic.add(Duration(days: h * 7 + i)), bugun)),
            ]),
          ),
        const Divider(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            DateFormat('d MMMM, EEEE', 'tr').format(odak),
            style: const TextStyle(color: Renk.kahve, fontWeight: FontWeight.w600),
          ),
        ),
        if (secili.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Bu gün için etkinlik yok.',
                textAlign: TextAlign.center, style: TextStyle(color: Renk.kahve.withValues(alpha: 0.6))),
          ),
        for (final e in secili) _EtkinlikKarti(e: e, gun: odak, onAc: onAc),
      ],
    );
  }

  Widget _gunHucresi(TakvimDeposu depo, DateTime g, DateTime bugun) {
    final buAy = g.month == odak.month;
    final secili = gunBasi(g) == gunBasi(odak);
    final bugunMu = g == bugun;
    final etkinlikler = depo.gununEtkinlikleri(g);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => onGunSec(g),
      child: Container(
        height: 54,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: secili ? Renk.turuncu.withValues(alpha: 0.22) : null,
          borderRadius: BorderRadius.circular(12),
          border: bugunMu ? Border.all(color: Renk.turuncu, width: 1.5) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${g.day}',
              style: TextStyle(
                color: buAy ? Renk.kahve : Renk.kahve.withValues(alpha: 0.35),
                fontWeight: bugunMu || secili ? FontWeight.bold : FontWeight.normal,
              )),
          const SizedBox(height: 3),
          SizedBox(
            height: 6,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final e in etkinlikler.take(3))
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: e.uygulamaninMi ? Renk.turuncu : Renk.kahve,
                    shape: BoxShape.circle,
                  ),
                ),
            ]),
          ),
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
