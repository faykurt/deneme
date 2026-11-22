import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/ai_modeller.dart';
import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'onay_penceresi.dart';
import 'yazili_not.dart';

/// Bir notun ayrıntısı: metni, fotoğrafları, kategorileri ve durumu düzenlenir.
class NotDetay extends StatefulWidget {
  final String notId;
  const NotDetay({super.key, required this.notId});

  @override
  State<NotDetay> createState() => _NotDetayState();
}

class _NotDetayState extends State<NotDetay> {
  final _depo = Depo.instance;
  late final TextEditingController _metin;
  late final TextEditingController _yorum;
  Timer? _kayitZamanlayici;

  Not? get _not {
    for (final n in _depo.notlar) {
      if (n.id == widget.notId) return n;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _metin = TextEditingController(text: _not?.metin ?? '');
    _yorum = TextEditingController(text: _not?.yorum ?? '');
  }

  void _yaziDegisti() {
    _kayitZamanlayici?.cancel();
    _kayitZamanlayici = Timer(const Duration(milliseconds: 700), _yaziyiKaydet);
  }

  Future<void> _yaziyiKaydet() async {
    final n = _not;
    if (n == null) return;
    final yorum = _yorum.text.trim().isEmpty ? null : _yorum.text.trim();
    if (n.metin == _metin.text && n.yorum == yorum) return;
    n.metin = _metin.text;
    n.yorum = yorum;
    await _depo.notGuncelle(n);
  }

  @override
  void dispose() {
    _kayitZamanlayici?.cancel();
    _yaziyiKaydet();
    _metin.dispose();
    _yorum.dispose();
    super.dispose();
  }

  Future<void> _fotoEkle(bool kamera) async {
    final yollar = await fotografSec(kamera: kamera);
    for (final y in yollar) {
      await _depo.fotografEkle(widget.notId, y);
    }
  }

  Future<void> _kategoriEkle() async {
    final n = _not;
    if (n == null) return;
    final k = await kategoriSec(context, baslik: 'Kategori ekle');
    if (k != null) {
      await _depo.kategorileriAyarla(n.id, [...n.kategoriIdler, k]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _depo,
      builder: (context, _) {
        final n = _not;
        if (n == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Bu not artık yok.')),
          );
        }
        final agac = _depo.agac;
        final yazi = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Renk.krem,
            title: Text(n.arsiv ? 'Not (arşivde)' : 'Not'),
            actions: [
              IconButton(
                tooltip: n.arsiv ? 'Arşivden çıkar' : 'Arşivle',
                icon: Icon(
                  n.arsiv ? Icons.unarchive_outlined : Icons.archive_outlined,
                ),
                onPressed: () => arsivleVeGeriAlGoster([n.id], !n.arsiv),
              ),
              IconButton(
                tooltip: 'Sil',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  _kayitZamanlayici?.cancel();
                  Navigator.pop(context);
                  await silVeGeriAlGoster([n.id]);
                },
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${tarihYazisi(n.olusturma)} · ${switch (n.kaynak) {
                  Kaynak.sesli => 'sesli not',
                  Kaynak.paylasim => 'paylaşımdan',
                  _ => 'yazılı not',
                }}',
                style: yazi.labelMedium?.copyWith(
                  color: Renk.kahve.withValues(alpha: 0.6),
                ),
              ),
              if (n.onayBekliyor) ...[
                const SizedBox(height: 10),
                Material(
                  color: Renk.turuncu.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                  child: ListTile(
                    leading: const Icon(
                      Icons.auto_awesome,
                      color: Renk.turuncu,
                    ),
                    title: const Text('Yapay zeka bu notu düzenledi'),
                    subtitle: const Text(
                      'Önerileri kontrol edip onaylayabilirsin.',
                    ),
                    trailing: FilledButton(
                      onPressed: () => onayPenceresiAc(n.id),
                      child: const Text('İncele'),
                    ),
                  ),
                ),
              ] else if (!n.islendi && AiAyarlar.instance.anahtarVar) ...[
                const SizedBox(height: 6),
                Text(
                  '⏳ Yapay zeka sırada, bağlantı olunca düzenleyecek.',
                  style: yazi.bodySmall?.copyWith(
                    color: Renk.kahve.withValues(alpha: 0.7),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _metin,
                onChanged: (_) => _yaziDegisti(),
                minLines: 4,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Not',
                  filled: true,
                  fillColor: Renk.acikKrem,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (n.link != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: Text(
                    n.link!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text('Kopyalamak için dokun'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: n.link!));
                    mesajGoster('Link kopyalandı');
                  },
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    label: Text(
                      n.sureDk == null ? 'Süre ekle' : '${n.sureDk} dk',
                    ),
                    onPressed: () => _sureDuzenle(n),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.event, size: 18),
                    label: Text(
                      n.tarih == null
                          ? 'Tarih ekle'
                          : DateFormat(
                              n.tarihSaatli ? 'd MMMM, HH:mm' : 'd MMMM',
                              'tr',
                            ).format(
                              DateTime.fromMillisecondsSinceEpoch(n.tarih!),
                            ),
                    ),
                    onPressed: () => _tarihDuzenle(n),
                  ),
                  if (n.tarih != null)
                    ActionChip(
                      avatar: const Icon(Icons.close, size: 16),
                      label: const Text('Tarihi kaldır'),
                      onPressed: () {
                        n.tarih = null;
                        _depo.notGuncelle(n);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ..._adimBolumu(n, yazi),
              Text('Fotoğraflar', style: yazi.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final f in n.fotograflar)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _fotografGoster(f),
                          onLongPress: () => _fotografSilSor(n.id, f),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(f),
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              cacheWidth: 288,
                            ),
                          ),
                        ),
                      ),
                    _KareButon(
                      icon: Icons.photo_camera_outlined,
                      onTap: () => _fotoEkle(true),
                    ),
                    _KareButon(
                      icon: Icons.photo_library_outlined,
                      onTap: () => _fotoEkle(false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Kategoriler', style: yazi.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in n.kategoriIdler)
                    InputChip(
                      label: Text(agac.tamAd(k)),
                      onDeleted: () => _depo.kategorileriAyarla(
                        n.id,
                        n.kategoriIdler.where((x) => x != k),
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Kategori ekle'),
                    onPressed: _kategoriEkle,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Durum', style: yazi.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in Durum.hepsi)
                    ChoiceChip(
                      label: Text(Durum.ad(d)),
                      selected: n.durum == d,
                      onSelected: (_) {
                        n.durum = d;
                        _depo.notGuncelle(n);
                      },
                    ),
                ],
              ),
              if (n.kaynak == Kaynak.paylasim || n.yorum != null) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _yorum,
                  onChanged: (_) => _yaziDegisti(),
                  decoration: InputDecoration(
                    labelText: 'Yorum',
                    filled: true,
                    fillColor: Renk.acikKrem,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _sureDuzenle(Not n) async {
    final c = TextEditingController(text: n.sureDk?.toString() ?? '');
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tahmini süre (dakika)'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (tamam != true) return;
    n.sureDk = int.tryParse(c.text.trim());
    await _depo.notGuncelle(n);
  }

  Future<void> _tarihDuzenle(Not n) async {
    final simdi = DateTime.now();
    final eski = n.tarih == null
        ? simdi
        : DateTime.fromMillisecondsSinceEpoch(n.tarih!);
    final gun = await showDatePicker(
      context: context,
      initialDate: eski,
      firstDate: DateTime(simdi.year - 1),
      lastDate: DateTime(simdi.year + 5),
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: n.tarihSaatli
          ? TimeOfDay.fromDateTime(eski)
          : const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Saat de eklemek ister misin? (Vazgeç: sadece gün)',
    );
    n.tarihSaatli = saat != null;
    n.tarih = DateTime(
      gun.year,
      gun.month,
      gun.day,
      saat?.hour ?? 0,
      saat?.minute ?? 0,
    ).millisecondsSinceEpoch;
    await _depo.notGuncelle(n);
  }

  /// Adımlar: sıralı liste. Sıradaki (ilk yapılmamış) adım vurgulanır.
  List<Widget> _adimBolumu(Not n, TextTheme yazi) {
    final siradaki = n.adimlar.indexWhere((a) => !a.yapildi);
    final oneri = AiSonuc.coz(n.aiJson);
    final oneriVar =
        n.adimlar.isEmpty &&
        oneri != null &&
        oneri.fikirler.length == 1 &&
        oneri.fikirler.first.yapilabilirIs &&
        oneri.fikirler.first.adimlar.isNotEmpty;
    return [
      Row(
        children: [
          Text('Adımlar', style: yazi.titleSmall),
          const Spacer(),
          if (oneriVar)
            TextButton.icon(
              onPressed: () => onayPenceresiAc(n.id),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Adım önerisini gör'),
            ),
        ],
      ),
      for (var i = 0; i < n.adimlar.length; i++)
        _adimSatiri(n, n.adimlar[i], i == siradaki),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _adimDuzenle(n, null),
          icon: const Icon(Icons.add),
          label: const Text('Adım ekle'),
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  Widget _adimSatiri(Not n, Adim a, bool siradaki) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: siradaki
            ? Renk.turuncu.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 4, right: 4),
          leading: Checkbox(
            value: a.yapildi,
            onChanged: (v) => _adimIsaretle(n, a, v == true),
          ),
          title: Text(
            a.metin,
            style: TextStyle(
              decoration: a.yapildi ? TextDecoration.lineThrough : null,
              color: a.yapildi ? Renk.kahve.withValues(alpha: 0.5) : Renk.kahve,
            ),
          ),
          subtitle: Text(
            [
              if (siradaki) 'Sıradaki',
              if (a.sureDk != null) '${a.sureDk} dk',
              if (a.bekleme) 'bekleme',
            ].join(' · '),
          ),
          onTap: () => _adimDuzenle(n, a),
          trailing: IconButton(
            tooltip: 'Adımı sil',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _depo.adimlariKaydet(
              n.id,
              n.adimlar.where((x) => x.id != a.id).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _adimIsaretle(Not n, Adim a, bool yapildi) async {
    await _depo.adimDurumu(a.id!, yapildi ? Durum.yapildi : Durum.yapilacak);
    final guncel = _not;
    if (!mounted || guncel == null || !yapildi) return;
    if (guncel.adimlar.isNotEmpty &&
        guncel.adimlar.every((x) => x.yapildi) &&
        !guncel.arsiv) {
      final evet = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Tüm adımlar bitti 🎉'),
          content: const Text('Not tamamlanmış olarak arşive gitsin mi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kalsın'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Arşive taşı'),
            ),
          ],
        ),
      );
      if (evet == true) {
        guncel.durum = Durum.yapildi;
        await _depo.notGuncelle(guncel);
        await arsivleVeGeriAlGoster([guncel.id], true);
      }
    }
  }

  Future<void> _adimDuzenle(Not n, Adim? a) async {
    final metin = TextEditingController(text: a?.metin ?? '');
    final sure = TextEditingController(text: a?.sureDk?.toString() ?? '');
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(a == null ? 'Adım ekle' : 'Adımı düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: metin,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: sure,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Süre (dk)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (tamam != true || metin.text.trim().isEmpty) return;
    final liste = [...n.adimlar];
    final sureDk = int.tryParse(sure.text.trim());
    if (a == null) {
      liste.add(
        Adim(
          notId: n.id,
          sira: liste.length,
          metin: metin.text.trim(),
          sureDk: sureDk,
        ),
      );
    } else {
      final i = liste.indexWhere((x) => x.id == a.id);
      if (i >= 0) {
        liste[i].metin = metin.text.trim();
        liste[i].sureDk = sureDk;
      }
    }
    await _depo.adimlariKaydet(n.id, liste);
  }

  void _fotografGoster(String yol) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          body: Center(child: InteractiveViewer(child: Image.file(File(yol)))),
        ),
      ),
    );
  }

  Future<void> _fotografSilSor(String notId, String yol) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fotoğraf silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (evet == true) await _depo.fotografSil(notId, yol);
  }
}

class _KareButon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _KareButon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: Renk.acikKrem,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x33000000)),
        ),
        child: Icon(icon, color: Renk.kahve),
      ),
    ),
  );
}
