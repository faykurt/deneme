import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../takvim/takvim_deposu.dart';
import '../takvim/takvim_kaynagi.dart';
import '../takvim/takvim_modeller.dart';

class EtkinlikSonucu {
  final String? etkinlikId;
  final DateTime baslangic;
  final DateTime bitis;
  final bool silindi;
  const EtkinlikSonucu({this.etkinlikId, required this.baslangic, required this.bitis, this.silindi = false});
}

/// Etkinlik ekleme/düzenleme ekranını açar. Kaydedilirse ya da silinirse sonucu döner, vazgeçilirse null.
Future<EtkinlikSonucu?> etkinlikDuzenleAc({
  TEtkinlik? mevcut,
  String baslik = '',
  DateTime? baslangic,
  int sureDk = 60,
  String? aciklama,
}) {
  final nav = navigatorKey.currentState;
  if (nav == null) return Future.value(null);
  return nav.push<EtkinlikSonucu>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => EtkinlikDuzenle(mevcut: mevcut, baslik: baslik, baslangic: baslangic, sureDk: sureDk, aciklama: aciklama),
  ));
}

String _isaretiSil(String b) => b.startsWith(uygulamaIsareti) ? b.substring(uygulamaIsareti.length).trimLeft() : b;

class EtkinlikDuzenle extends StatefulWidget {
  final TEtkinlik? mevcut;
  final String baslik;
  final DateTime? baslangic;
  final int sureDk;
  final String? aciklama;
  const EtkinlikDuzenle({super.key, this.mevcut, this.baslik = '', this.baslangic, this.sureDk = 60, this.aciklama});

  @override
  State<EtkinlikDuzenle> createState() => _EtkinlikDuzenleState();
}

class _EtkinlikDuzenleState extends State<EtkinlikDuzenle> {
  final _depo = TakvimDeposu.instance;
  late final TextEditingController _baslik;
  late final TextEditingController _aciklama;
  late bool _tumGun;
  late bool _meshgul;
  late DateTime _bas;
  late DateTime _bit; // saatli: gerçek bitiş. Tüm gün: son günün 00:00'ı (bitiş dahil)
  late TekrarTuru _tekrar;
  DateTime? _tekrarBitis;
  late final bool _uygulamaninMi;
  bool _kaydediliyor = false;

  bool get _yeni => widget.mevcut == null;

  @override
  void initState() {
    super.initState();
    final e = widget.mevcut;
    _uygulamaninMi = e == null || e.uygulamaninMi;
    _baslik = TextEditingController(text: _isaretiSil(e?.baslik ?? widget.baslik));
    _aciklama = TextEditingController(text: e?.aciklama ?? widget.aciklama ?? '');
    _tumGun = e?.tumGun ?? false;
    _meshgul = e?.meshgul ?? true;
    _tekrar = e?.tekrar ?? TekrarTuru.yok;
    _tekrarBitis = e?.tekrarBitis;
    if (e != null) {
      _bas = e.baslangic;
      _bit = e.tumGun ? _sonGun(e) : e.bitis;
    } else {
      final simdi = DateTime.now();
      final b = widget.baslangic ?? DateTime(simdi.year, simdi.month, simdi.day, simdi.hour + 1);
      _bas = b;
      _bit = b.add(Duration(minutes: widget.sureDk <= 0 ? 60 : widget.sureDk));
    }
  }

  DateTime _sonGun(TEtkinlik e) {
    final son = gunBasi(e.bitis);
    final bas = gunBasi(e.baslangic);
    return son.isAfter(bas) ? son.subtract(const Duration(days: 1)) : bas;
  }

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  Future<void> _tarihSec({required bool baslangicMi}) async {
    final eski = baslangicMi ? _bas : _bit;
    final gun = await showDatePicker(
      context: context,
      initialDate: eski,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (gun == null) return;
    setState(() {
      final yeni = DateTime(gun.year, gun.month, gun.day, eski.hour, eski.minute);
      if (baslangicMi) {
        final sure = _bit.difference(_bas);
        _bas = yeni;
        _bit = _bas.add(sure);
      } else {
        _bit = yeni;
        if (_bit.isBefore(_bas)) _bas = _tumGun ? gunBasi(_bit) : _bit.subtract(const Duration(hours: 1));
      }
    });
  }

  Future<void> _saatSec({required bool baslangicMi}) async {
    final eski = baslangicMi ? _bas : _bit;
    final saat = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(eski));
    if (saat == null) return;
    setState(() {
      final yeni = DateTime(eski.year, eski.month, eski.day, saat.hour, saat.minute);
      if (baslangicMi) {
        final sure = _bit.difference(_bas);
        _bas = yeni;
        _bit = _bas.add(sure);
      } else {
        _bit = yeni;
        if (!_bit.isAfter(_bas)) _bit = _bas.add(const Duration(minutes: 30));
      }
    });
  }

  Future<Kapsam?> _kapsamSor(String eylem) {
    return showDialog<Kapsam>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Bu tekrarlı bir etkinlik. $eylem?'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, Kapsam.sadeceBu), child: const Text('Sadece bu etkinlik')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, Kapsam.buVeSonrakiler), child: const Text('Bu ve sonraki tekrarlar')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, Kapsam.hepsi), child: const Text('Tüm tekrarlar')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        ],
      ),
    );
  }

  TEtkinlikTaslagi _taslak() {
    var baslik = _baslik.text.trim();
    if (_uygulamaninMi) baslik = '$uygulamaIsareti $baslik';
    final bitis = _tumGun ? gunBasi(_bit).add(const Duration(days: 1)) : _bit;
    return TEtkinlikTaslagi(
      takvimId: widget.mevcut?.takvimId,
      baslik: baslik,
      baslangic: _tumGun ? gunBasi(_bas) : _bas,
      bitis: bitis,
      tumGun: _tumGun,
      meshgul: _tumGun ? _meshgul : (widget.mevcut?.meshgul ?? true),
      tekrar: _tekrar,
      tekrarBitis: _tekrar == TekrarTuru.yok ? null : _tekrarBitis,
      aciklama: _aciklama.text.trim().isEmpty ? null : _aciklama.text.trim(),
    );
  }

  Future<void> _kaydet() async {
    if (_baslik.text.trim().isEmpty) {
      mesajGoster('Etkinliğe bir başlık yaz.');
      return;
    }
    final e = widget.mevcut;
    Kapsam kapsam = Kapsam.hepsi;
    if (e != null && e.tekrarli) {
      final k = await _kapsamSor('Değişiklik hangisine uygulansın');
      if (k == null || !mounted) return;
      kapsam = k;
    }
    setState(() => _kaydediliyor = true);
    try {
      final t = _taslak();
      String? id = e?.eventId;
      if (e == null) {
        id = await _depo.ekle(t);
      } else {
        await _depo.guncelle(e, t, kapsam);
      }
      if (!mounted) return;
      Navigator.pop(context, EtkinlikSonucu(etkinlikId: id, baslangic: t.baslangic, bitis: t.bitis));
    } on TakvimHatasi catch (h) {
      _hataGoster(h.mesaj);
    } catch (h) {
      _hataGoster('Beklenmeyen bir sorun oldu: $h');
    }
  }

  void _hataGoster(String mesaj) {
    if (!mounted) return;
    setState(() => _kaydediliyor = false);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydedilemedi'),
        content: Text(mesaj),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
      ),
    );
  }

  Future<void> _sil() async {
    final e = widget.mevcut;
    if (e == null) return;
    Kapsam kapsam = Kapsam.hepsi;
    if (e.tekrarli) {
      final k = await _kapsamSor('Hangisi silinsin');
      if (k == null || !mounted) return;
      kapsam = k;
    } else {
      final evet = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Etkinlik silinsin mi?'),
          content: const Text('Etkinlik telefonunun takviminden de silinir.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
          ],
        ),
      );
      if (evet != true || !mounted) return;
    }
    setState(() => _kaydediliyor = true);
    try {
      await _depo.sil(e, kapsam);
      if (!mounted) return;
      Navigator.pop(context, EtkinlikSonucu(etkinlikId: e.eventId, baslangic: e.baslangic, bitis: e.bitis, silindi: true));
    } on TakvimHatasi catch (h) {
      _hataGoster(h.mesaj);
    } catch (h) {
      _hataGoster('Beklenmeyen bir sorun oldu: $h');
    }
  }

  String _gun(DateTime d) => DateFormat('d MMM y, EEE', 'tr').format(d);
  String _saat(DateTime d) => DateFormat('HH:mm').format(d);

  Widget _satir(String etiket, DateTime d, {required bool baslangicMi}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 62, child: Text(etiket, style: const TextStyle(color: Renk.kahve))),
        Expanded(
          flex: 3,
          child: OutlinedButton(
            onPressed: () => _tarihSec(baslangicMi: baslangicMi),
            child: Text(_gun(d), overflow: TextOverflow.ellipsis, maxLines: 1),
          ),
        ),
        if (!_tumGun) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: () => _saatSec(baslangicMi: baslangicMi),
              child: Text(_saat(d)),
            ),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ozel = _tekrar == TekrarTuru.ozel;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Renk.krem,
        title: Text(_yeni ? 'Yeni etkinlik' : 'Etkinlik'),
        actions: [
          if (!_yeni)
            IconButton(tooltip: 'Sil', icon: const Icon(Icons.delete_outline), onPressed: _kaydediliyor ? null : _sil),
          TextButton(onPressed: _kaydediliyor ? null : _kaydet, child: const Text('Kaydet')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          TextField(
            controller: _baslik,
            autofocus: _yeni && _baslik.text.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Başlık',
              prefixText: _uygulamaninMi ? '$uygulamaIsareti ' : null,
              filled: true,
              fillColor: Renk.acikKrem,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tüm gün'),
            value: _tumGun,
            onChanged: (v) => setState(() {
              _tumGun = v;
              if (v) {
                _bas = gunBasi(_bas);
                _bit = gunBasi(_bit.isBefore(_bas) ? _bas : _bit);
              } else {
                _bas = DateTime(_bas.year, _bas.month, _bas.day, 9);
                _bit = DateTime(_bit.year, _bit.month, _bit.day, 10);
                if (!_bit.isAfter(_bas)) _bit = _bas.add(const Duration(hours: 1));
              }
            }),
          ),
          if (_tumGun)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Günü dolu say'),
              subtitle: const Text('Açıksa o gün öneri yapılmaz. Tatil, doğum günü gibi şeylerde kapalı bırak.'),
              value: _meshgul,
              onChanged: (v) => setState(() => _meshgul = v),
            ),
          _satir('Başlangıç', _bas, baslangicMi: true),
          _satir('Bitiş', _bit, baslangicMi: false),
          const SizedBox(height: 4),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Tekrar',
              filled: true,
              fillColor: Renk.acikKrem,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TekrarTuru>(
                value: _tekrar,
                isExpanded: true,
                items: [
                  for (final t in TekrarTuru.values)
                    if (t != TekrarTuru.ozel || ozel) DropdownMenuItem(value: t, child: Text(t.ad)),
                ],
                onChanged: ozel ? null : (v) => setState(() => _tekrar = v ?? TekrarTuru.yok),
              ),
            ),
          ),
          if (ozel)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Bu etkinliğin tekrarı özel olduğu için burada değiştirilemez.',
                  style: TextStyle(color: Renk.kahve.withValues(alpha: 0.7), fontSize: 12)),
            ),
          if (_tekrar != TekrarTuru.yok && !ozel)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event_busy_outlined),
                    label: Text(
                      _tekrarBitis == null ? 'Tekrar bitiş tarihi (yok)' : 'Tekrar ${_gun(_tekrarBitis!)} tarihine kadar',
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () async {
                      final g = await showDatePicker(
                        context: context,
                        initialDate: _tekrarBitis ?? _bas.add(const Duration(days: 30)),
                        firstDate: _bas,
                        lastDate: DateTime(2100),
                      );
                      if (g != null) setState(() => _tekrarBitis = g);
                    },
                  ),
                ),
                if (_tekrarBitis != null)
                  IconButton(
                      tooltip: 'Bitiş tarihini kaldır',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _tekrarBitis = null)),
              ]),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _aciklama,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Açıklama (isteğe bağlı)',
              filled: true,
              fillColor: Renk.acikKrem,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          if (_kaydediliyor) const Padding(padding: EdgeInsets.only(top: 20), child: LinearProgressIndicator()),
        ],
      ),
    );
  }
}
