import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
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
    if (k != null) await _depo.kategorileriAyarla(n.id, [...n.kategoriIdler, k]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _depo,
      builder: (context, _) {
        final n = _not;
        if (n == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Bu not artık yok.')));
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
                icon: Icon(n.arsiv ? Icons.unarchive_outlined : Icons.archive_outlined),
                onPressed: () async {
                  await _depo.arsivle([n.id], !n.arsiv);
                  mesajGoster(n.arsiv ? 'Arşivden çıkarıldı' : 'Arşivlendi');
                },
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
              Text('${tarihYazisi(n.olusturma)} · ${switch (n.kaynak) {
                Kaynak.sesli => 'sesli not',
                Kaynak.paylasim => 'paylaşımdan',
                _ => 'yazılı not',
              }}', style: yazi.labelMedium?.copyWith(color: Renk.kahve.withValues(alpha: 0.6))),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              if (n.link != null) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link),
                  title: Text(n.link!, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: const Text('Kopyalamak için dokun'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: n.link!));
                    mesajGoster('Link kopyalandı');
                  },
                ),
              ],
              const SizedBox(height: 16),
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
                            child: Image.file(File(f), width: 96, height: 96, fit: BoxFit.cover, cacheWidth: 288),
                          ),
                        ),
                      ),
                    _KareButon(icon: Icons.photo_camera_outlined, onTap: () => _fotoEkle(true)),
                    _KareButon(icon: Icons.photo_library_outlined, onTap: () => _fotoEkle(false)),
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
                      onDeleted: () => _depo.kategorileriAyarla(n.id, n.kategoriIdler.where((x) => x != k)),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _fotografGoster(String yol) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
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
