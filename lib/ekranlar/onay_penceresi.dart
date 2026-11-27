import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/ai_modeller.dart';
import '../ai/isleyici.dart';
import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';

/// Yapay zekanın hazırladığı önerileri gösteren pencere.
/// [canli] true ise (not az önce kaydedildi) önce yapay zekanın bitirmesini bekler.
Future<void> onayPenceresiAc(String notId, {bool canli = false, bool gonder = false}) async {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Renk.zemin,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(ctx).size.height * 0.92,
    ),
    builder: (_) => OnayPenceresi(notId: notId, canli: canli, gonder: gonder),
  );
}

class OnayPenceresi extends StatefulWidget {
  final String notId;
  final bool canli;

  /// true ise not yapay zeka dışıydı, açılırken yapay zekaya gönderilir.
  final bool gonder;
  const OnayPenceresi({super.key, required this.notId, required this.canli, this.gonder = false});

  @override
  State<OnayPenceresi> createState() => _OnayPenceresiState();
}

class _OnayPenceresiState extends State<OnayPenceresi> {
  final _depo = Depo.instance;
  final _isleyici = AiIsleyici.instance;
  final _baslik = TextEditingController();
  final _sure = TextEditingController();

  AiHata? _hata;
  bool _dolduruldu = false;
  bool _adimlariEkle = true;
  List<AiAdim> _adimlar = [];
  int? _tarih;
  bool _tarihSaatli = false;

  Not? get _not {
    for (final n in _depo.notlar) {
      if (n.id == widget.notId) return n;
    }
    return null;
  }

  AiSonuc? get _sonuc => AiSonuc.coz(_not?.aiJson);

  @override
  void initState() {
    super.initState();
    final n = _not;
    if (n == null) return;
    if (!n.islendi && (widget.canli || widget.gonder)) {
      (widget.gonder ? _isleyici.notuGonder(n) : _isleyici.hemenIsle(n)).then((hata) {
        if (!mounted) return;
        setState(() => _hata = hata);
        _alanlariDoldur();
      });
    } else {
      _alanlariDoldur();
    }
  }

  /// Not işlendiğinde (ya da pencere açıldığında) form alanlarını notun güncel haliyle doldurur.
  void _alanlariDoldur() {
    final n = _not;
    if (n == null || _dolduruldu || !n.islendi) return;
    _dolduruldu = true;
    _baslik.text = n.baslik ?? '';
    _sure.text = n.sureDk?.toString() ?? '';
    _tarih = n.tarih;
    _tarihSaatli = n.tarihSaatli;
    final fikirler = _sonuc?.fikirler ?? [];
    if (fikirler.length == 1 &&
        fikirler.first.yapilabilirIs &&
        n.adimlar.isEmpty) {
      _adimlar = [...fikirler.first.adimlar];
    }
  }

  @override
  void dispose() {
    _baslik.dispose();
    _sure.dispose();
    super.dispose();
  }

  Future<void> _tarihSec() async {
    final simdi = DateTime.now();
    final eski = _tarih == null
        ? simdi
        : DateTime.fromMillisecondsSinceEpoch(_tarih!);
    final gun = await showDatePicker(
      context: context,
      initialDate: eski,
      firstDate: DateTime(simdi.year - 1),
      lastDate: DateTime(simdi.year + 5),
    );
    if (gun == null || !mounted) return;
    final saat = await showTimePicker(
      context: context,
      initialTime: _tarihSaatli
          ? TimeOfDay.fromDateTime(eski)
          : const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Saat de eklemek ister misin? (Vazgeç: sadece gün)',
    );
    setState(() {
      _tarihSaatli = saat != null;
      _tarih = DateTime(
        gun.year,
        gun.month,
        gun.day,
        saat?.hour ?? 0,
        saat?.minute ?? 0,
      ).millisecondsSinceEpoch;
    });
  }

  Future<void> _kategoriEkle() async {
    final n = _not;
    if (n == null) return;
    final k = await kategoriSec(context, baslik: 'Kategori ekle');
    if (k != null) {
      await _depo.kategorileriAyarla(n.id, [...n.kategoriIdler, k]);
    }
  }

  Future<void> _yeniKategoriOlustur(AiFikir f) async {
    final n = _not;
    if (n == null) return;
    final ust =
        f.yeniKategoriUstId != 0 && _depo.agac.bul(f.yeniKategoriUstId) != null
        ? f.yeniKategoriUstId
        : null;
    final id = await _depo.kategoriEkle(f.yeniKategoriAd, ustId: ust);
    await _depo.kategorileriAyarla(n.id, [...n.kategoriIdler, id]);
    f.yeniKategoriAd = '';
    // Öneriyi bir daha göstermemek için kayıtlı öneriden de çıkar.
    final s = _sonuc;
    if (s != null) {
      n.aiJson = null;
      await _depo.notGuncelle(n, dokunma: false);
    }
    if (mounted) setState(() {});
  }

  Future<void> _kaydet({required bool onayla}) async {
    final n = _not;
    if (n == null) {
      Navigator.pop(context);
      return;
    }
    final baslik = _baslik.text.trim();
    n.baslik = baslik.isEmpty ? null : baslik;
    n.sureDk = int.tryParse(_sure.text.trim());
    n.tarih = _tarih;
    n.tarihSaatli = _tarihSaatli;
    await _depo.notGuncelle(n);
    if (_adimlariEkle && _adimlar.isNotEmpty && n.adimlar.isEmpty) {
      await _depo.adimlariKaydet(n.id, [
        for (final a in _adimlar)
          Adim(
            notId: n.id,
            sira: 0,
            metin: a.metin,
            sureDk: a.sureDk > 0 ? a.sureDk : null,
            bekleme: a.bekleme,
          ),
      ]);
    }
    if (onayla) await _depo.onayla([n.id]);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _ayir(List<AiFikir> fikirler) async {
    final n = _not;
    if (n == null) return;
    await _isleyici.bol(n, fikirler);
    if (!mounted) return;
    Navigator.pop(context);
    mesajGoster(
      '${fikirler.length} ayrı not oluşturuldu. Onay bekleyenlerde görebilirsin.',
    );
  }

  Future<void> _tekNotKalsin() async {
    final n = _not;
    if (n == null) return;
    n.aiJson = null;
    await _depo.notGuncelle(n, dokunma: false);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_depo, _isleyici]),
      builder: (context, _) {
        final n = _not;
        if (n == null) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Bu not artık yok.')),
          );
        }
        if (!n.islendi) return _bekleniyor(n);
        _alanlariDoldur();
        return _form(n);
      },
    );
  }

  Widget _bekleniyor(Not n) {
    final calisiyor = _isleyici.notIsleniyor(n.id);
    final yazi = Theme.of(context).textTheme;
    final hata = _hata;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                hata == null ? Icons.check_circle : Icons.cloud_off,
                color: Renk.vurgu,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                'Not kaydedildi',
                style: yazi.titleLarge?.copyWith(
                  color: Renk.yazi,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Renk.kart,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              n.metin.isEmpty ? '(fotoğraflı not)' : n.metin,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Renk.yazi),
            ),
          ),
          const SizedBox(height: 16),
          if (calisiyor)
            const Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Yapay zeka düzenliyor…')),
              ],
            )
          else
            Text(
              hata != null
                  ? '${hata.mesaj}\nNot güvende, işlenince burada onayını bekleyecek.'
                  : 'Yapay zeka sırada, biraz sonra düzenleyecek.',
              style: TextStyle(
                color: hata != null ? Renk.hata : Renk.yazi,
              ),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(calisiyor ? 'Sonra bakarım' : 'Tamam'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _form(Not n) {
    final yazi = Theme.of(context).textTheme;
    final s = _sonuc;
    final fikirler = s?.fikirler ?? [];
    final coklu = fikirler.length > 1;
    final fikir = fikirler.length == 1 ? fikirler.first : null;
    final agac = _depo.agac;
    final govde = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Renk.vurgu),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  n.onayli ? 'Notun' : 'Yapay zekanın önerisi',
                  style: yazi.titleLarge?.copyWith(
                    color: Renk.yazi,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Renk.kart,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              n.metin.isEmpty ? '(fotoğraflı not)' : n.metin,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Renk.yazi),
            ),
          ),
          if (coklu) ...[
            const SizedBox(height: 14),
            Card(
              elevation: 0,
              color: Renk.vurgu.withValues(alpha: 0.14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bu kayıtta ${fikirler.length} ayrı fikir var',
                      style: yazi.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    for (final f in fikirler)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '• ${f.baslik.isEmpty ? f.metin : f.baslik}',
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _ayir(fikirler),
                            child: const Text('Ayrı notlara böl'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _tekNotKalsin,
                          child: const Text('Tek not kalsın'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            TextField(
              controller: _baslik,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Başlık',
                filled: true,
                fillColor: Renk.kart,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
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
                  label: const Text('Kategori'),
                  onPressed: _kategoriEkle,
                ),
                if (fikir != null && fikir.yeniKategoriAd.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 18,
                    ),
                    label: Text('Yeni kategori: ${fikir.yeniKategoriAd}'),
                    onPressed: () => _yeniKategoriOlustur(fikir),
                  ),
              ],
            ),
            if (n.kategoriIdler.isEmpty &&
                fikir != null &&
                fikir.yeniKategoriAd.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Uygun bir kategori bulunamadı, istersen sen seç.',
                  style: yazi.bodySmall?.copyWith(
                    color: Renk.yazi.withValues(alpha: 0.7),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _sure,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Tahmini süre (dakika)',
                filled: true,
                fillColor: Renk.kart,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _tarihSec,
                    icon: const Icon(Icons.event),
                    label: Text(
                      _tarih == null
                          ? 'Tarih ekle'
                          : _tarihYazisi(_tarih!, _tarihSaatli),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_tarih != null)
                  IconButton(
                    tooltip: 'Tarihi kaldır',
                    onPressed: () => setState(() => _tarih = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            if (_adimlar.isNotEmpty && n.adimlar.isEmpty) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: Renk.vurgu.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bu yapılabilir bir iş gibi görünüyor. Adımlara bölelim mi?',
                        style: yazi.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('Adımları ekle'),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('Adımsız kalsın'),
                          ),
                        ],
                        selected: {_adimlariEkle},
                        onSelectionChanged: (v) =>
                            setState(() => _adimlariEkle = v.first),
                      ),
                      if (_adimlariEkle) ...[
                        const SizedBox(height: 8),
                        for (var i = 0; i < _adimlar.length; i++)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 12,
                              backgroundColor: Renk.vurgu,
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                  color: Renk.vurguUstu,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(_adimlar[i].metin),
                            subtitle: Text(
                              [
                                if (_adimlar[i].sureDk > 0)
                                  '${_adimlar[i].sureDk} dk',
                                if (_adimlar[i].bekleme) 'bekleme',
                              ].join(' · '),
                            ),
                            onTap: () => _adimDuzenle(i),
                            trailing: IconButton(
                              tooltip: 'Adımı kaldır',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _adimlar.removeAt(i)),
                            ),
                          ),
                        TextButton.icon(
                          onPressed: () => _adimDuzenle(null),
                          icon: const Icon(Icons.add),
                          label: const Text('Adım ekle'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
    final aksiyonlar = coklu
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 20, 16),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Notu sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _sil,
                ),
                Flexible(
                  child: TextButton(
                    onPressed: () => _kaydet(onayla: false),
                    child: const Text(
                      'Sonra onaylarım',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: n.onayli
                      ? FilledButton(
                          onPressed: () => _kaydet(onayla: false),
                          child: const Text('Kaydet'),
                        )
                      : FilledButton.icon(
                          onPressed: () => _kaydet(onayla: true),
                          icon: const Icon(Icons.check),
                          label: const Text(
                            'Onayla',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
              ],
            ),
          );
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(child: govde),
          ?aksiyonlar,
        ],
      ),
    );
  }

  Future<void> _sil() async {
    final id = widget.notId;
    Navigator.pop(context);
    await silVeGeriAlGoster([id]);
  }

  Future<void> _adimDuzenle(int? i) async {
    final metin = TextEditingController(
      text: i == null ? '' : _adimlar[i].metin,
    );
    final sure = TextEditingController(
      text: i == null || _adimlar[i].sureDk == 0 ? '' : '${_adimlar[i].sureDk}',
    );
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i == null ? 'Adım ekle' : 'Adımı düzenle'),
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
    setState(() {
      final sureDk = int.tryParse(sure.text.trim()) ?? 0;
      if (i == null) {
        _adimlar.add(AiAdim(metin: metin.text.trim(), sureDk: sureDk));
      } else {
        _adimlar[i].metin = metin.text.trim();
        _adimlar[i].sureDk = sureDk;
      }
    });
  }
}

String _tarihYazisi(int ms, bool saatli) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return DateFormat(saatli ? 'd MMMM, HH:mm' : 'd MMMM', 'tr').format(t);
}

/// Model bilgisi (Ayarlar'da gösterilir).
String get aiModelBilgisi => 'Basit notlar: Claude Haiku 5.5  ·  Fotoğraflı ve uzun notlar: Claude Sonnet 5.5  ·  efor düşük';

/// Anahtar yoksa kısa bir hatırlatma gösterir.
bool get aiHazir => AiAyarlar.instance.anahtarVar;
