import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/isleyici.dart';
import '../ortak.dart';
import 'sesli_not.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'kayit_sonrasi.dart';

/// Yazılı not penceresini açar. [kameraIleBasla] true ise önce kamera açılır.
Future<void> yaziliNotAc({bool kameraIleBasla = false, bool liste = false, int? kategoriId}) async {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  final not = await showModalBottomSheet<Not>(
    context: ctx,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Renk.zemin,
    builder: (_) => _YaziliNotPenceresi(kameraIleBasla: kameraIleBasla, liste: liste, kategoriId: kategoriId),
  );
  if (not == null) return;
  if (not.liste && not.aiDisi) {
    mesajGoster('Liste kaydedildi');
  } else {
    await kayitSonrasi(not, kayitMesaji: not.liste ? 'Liste kaydedildi' : 'Not kaydedildi');
  }
}

/// Kameradan ya da galeriden fotoğraf seçtirir, dosya yollarını döner.
Future<List<String>> fotografSec({required bool kamera}) async {
  final secici = ImagePicker();
  if (kamera) {
    final f = await secici.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2000);
    return f == null ? [] : [f.path];
  }
  final liste = await secici.pickMultiImage(imageQuality: 85, maxWidth: 2000);
  return liste.map((f) => f.path).toList();
}

class _YaziliNotPenceresi extends StatefulWidget {
  final bool kameraIleBasla;
  final bool liste;
  final int? kategoriId;
  const _YaziliNotPenceresi({required this.kameraIleBasla, this.liste = false, this.kategoriId});

  @override
  State<_YaziliNotPenceresi> createState() => _YaziliNotPenceresiState();
}

class _YaziliNotPenceresiState extends State<_YaziliNotPenceresi> {
  final _metin = TextEditingController();
  final List<String> _fotograflar = [];
  bool _kaydediliyor = false;

  // Liste kipi
  late bool _listeKipi = widget.liste;
  final _madde = TextEditingController();
  final List<String> _maddeler = [];
  bool _aiAcik = false;
  bool _sesBoluyor = false;

  @override
  void dispose() {
    _metin.dispose();
    _madde.dispose();
    super.dispose();
  }

  void _maddeEkle() {
    final t = _madde.text.trim();
    if (t.isEmpty) return;
    setState(() => _maddeler.add(t));
    _madde.clear();
  }

  Future<void> _sesleMadde() async {
    final metin = await sesliMetinAl();
    if (metin == null || metin.trim().isEmpty || !mounted) return;
    setState(() => _sesBoluyor = true);
    final liste = await AiIsleyici.instance.metniMaddelereBol(metin);
    if (!mounted) return;
    setState(() {
      _maddeler.addAll(liste);
      _sesBoluyor = false;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.kameraIleBasla) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fotoEkle(kamera: true));
    }
  }

  Future<void> _fotoEkle({required bool kamera}) async {
    final yollar = await fotografSec(kamera: kamera);
    if (mounted && yollar.isNotEmpty) setState(() => _fotograflar.addAll(yollar));
  }

  Future<void> _listeyiKaydet() async {
    if (_madde.text.trim().isNotEmpty) _maddeEkle();
    if (_metin.text.trim().isEmpty && _maddeler.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _kaydediliyor = true);
    final depo = Depo.instance;
    final not = await depo.notEkle(
      metin: _metin.text,
      kaynak: Kaynak.yazili,
      tur: NotTuru.liste,
      aiDisi: !_aiAcik,
      kategoriIdler: [?widget.kategoriId],
    );
    await depo.adimlariKaydet(not.id, [
      for (final m in _maddeler) Adim(notId: not.id, sira: 0, metin: m),
    ]);
    if (mounted) Navigator.pop(context, depo.notlar.firstWhere((n) => n.id == not.id));
  }

  Future<void> _kaydet() async {
    if (_listeKipi) return _listeyiKaydet();
    if (_metin.text.trim().isEmpty && _fotograflar.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _kaydediliyor = true);
    final not = await Depo.instance.notEkle(
      metin: _metin.text,
      kaynak: Kaynak.yazili,
      fotografYollari: _fotograflar,
      kategoriIdler: [?widget.kategoriId],
    );
    if (mounted) Navigator.pop(context, not);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, icon: Icon(Icons.notes), label: Text('Not')),
              ButtonSegment(value: true, icon: Icon(Icons.checklist), label: Text('Liste')),
            ],
            selected: {_listeKipi},
            onSelectionChanged: (v) => setState(() => _listeKipi = v.first),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _metin,
            autofocus: !widget.kameraIleBasla,
            minLines: _listeKipi ? 1 : 3,
            maxLines: _listeKipi ? 2 : 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _listeKipi ? 'Liste adı (ör. Market)' : 'Aklında ne var?',
              filled: true,
              fillColor: Renk.kart,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          if (_listeKipi) ...[
            const SizedBox(height: 8),
            for (var i = 0; i < _maddeler.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_box_outline_blank, size: 20),
                title: Text(_maddeler[i]),
                trailing: IconButton(
                  tooltip: 'Maddeyi kaldır',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _maddeler.removeAt(i)),
                ),
              ),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _madde,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _maddeEkle(),
                  decoration: const InputDecoration(hintText: 'Madde ekle', isDense: true),
                ),
              ),
              IconButton(
                  tooltip: 'Sesle ekle (yapay zeka maddelere böler)',
                  icon: _sesBoluyor
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.mic_none),
                  onPressed: _sesBoluyor ? null : _sesleMadde),
              IconButton(tooltip: 'Maddeyi ekle', icon: const Icon(Icons.add_circle_outline), onPressed: _maddeEkle),
            ]),
            if (AiAyarlar.instance.anahtarVar)
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Yapay zeka düzenlesin'),
                subtitle: const Text('Açarsan liste ad ve kategori alır, yazdığın metin maddelere bölünür.'),
                value: _aiAcik,
                onChanged: (v) => setState(() => _aiAcik = v),
              ),
          ],
          if (!_listeKipi && _fotograflar.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final yol in _fotograflar)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(yol), width: 72, height: 72, fit: BoxFit.cover, cacheWidth: 216),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _fotograflar.remove(yol)),
                            child: const CircleAvatar(
                                radius: 11,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close, size: 14, color: Colors.white)),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (!_listeKipi) ...[
                IconButton(
                    onPressed: () => _fotoEkle(kamera: true),
                    icon: const Icon(Icons.photo_camera_outlined),
                    tooltip: 'Fotoğraf çek'),
                IconButton(
                    onPressed: () => _fotoEkle(kamera: false),
                    icon: const Icon(Icons.photo_library_outlined),
                    tooltip: 'Galeriden seç'),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: _kaydediliyor ? null : _kaydet,
                icon: const Icon(Icons.check),
                label: const Text('Kaydet'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
