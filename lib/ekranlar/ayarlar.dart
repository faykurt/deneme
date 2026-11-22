import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';

const uygulamaSurumu = String.fromEnvironment('SURUM', defaultValue: 'geliştirme');

class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key});

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  bool _yedekleniyor = false;

  /// Tüm notları ve fotoğrafları tek bir zip dosyasına koyup paylaşım menüsünü açar
  /// (Drive'a ya da telefona kaydetmek için).
  Future<void> _yedekAl() async {
    setState(() => _yedekleniyor = true);
    try {
      final depo = Depo.instance;
      await depo.yedekIcinHazirla();
      final gecici = await getTemporaryDirectory();
      final ad = 'aklimda-yedek-${DateFormat('yyyy-MM-dd-HHmm').format(DateTime.now())}.zip';
      final yol = p.join(gecici.path, ad);
      final zip = ZipFileEncoder()..create(yol);
      await zip.addFile(File(depo.veritabaniYolu), 'aklimda.db');
      await zip.addDirectory(depo.fotografKlasoru);
      await zip.close();
      await SharePlus.instance.share(ShareParams(files: [XFile(yol)], text: 'Aklımda yedeği'));
    } catch (e) {
      mesajGoster('Yedek alınamadı: $e');
    } finally {
      if (mounted) setState(() => _yedekleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Renk.krem, title: const Text('Ayarlar')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Kategorileri düzenle'),
            subtitle: const Text('Ekle, yeniden adlandır, sil'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KategoriYonetimi())),
          ),
          ListTile(
            leading: _yedekleniyor
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.backup_outlined),
            title: const Text('Yedek al'),
            subtitle: const Text('Tüm notları ve fotoğrafları tek dosyada Drive\'a ya da telefona kaydet'),
            onTap: _yedekleniyor ? null : _yedekAl,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sürüm'),
            subtitle: const Text(uygulamaSurumu),
          ),
        ],
      ),
    );
  }
}

class KategoriYonetimi extends StatelessWidget {
  const KategoriYonetimi({super.key});

  Future<String?> _adSor(BuildContext context, {required String baslik, String ilk = ''}) {
    final c = TextEditingController(text: ilk);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(baslik),
        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? null : c.text.trim()),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _silSor(BuildContext context, Kategori k, bool altlariVar) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${k.ad}" silinsin mi?'),
        content: Text(altlariVar
            ? 'Alt kategorileri de silinir. Notların silinmez, kategorisi kalmayanlar "Kategorisiz"e düşer.'
            : 'Notların silinmez, kategorisi kalmayanlar "Kategorisiz"e düşer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (evet == true) await Depo.instance.kategoriSil(k.id);
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return Scaffold(
      appBar: AppBar(backgroundColor: Renk.krem, title: const Text('Kategoriler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ad = await _adSor(context, baslik: 'Yeni kategori');
          if (ad != null) await depo.kategoriEkle(ad);
        },
        icon: const Icon(Icons.add),
        label: const Text('Kategori'),
      ),
      body: ListenableBuilder(
        listenable: depo,
        builder: (context, _) {
          final agac = depo.agac;
          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              for (final ana in agac.anaKategoriler) ...[
                ListTile(
                  leading: const Icon(Icons.folder_outlined, color: Renk.turuncu),
                  title: Text(ana.ad),
                  onTap: () async {
                    final ad = await _adSor(context, baslik: 'Yeniden adlandır', ilk: ana.ad);
                    if (ad != null) await depo.kategoriAdlandir(ana.id, ad);
                  },
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Alt kategori ekle',
                      icon: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () async {
                        final ad = await _adSor(context, baslik: '${ana.ad} içine alt kategori');
                        if (ad != null) await depo.kategoriEkle(ad, ustId: ana.id);
                      },
                    ),
                    IconButton(
                      tooltip: 'Sil',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _silSor(context, ana, agac.altlari(ana.id).isNotEmpty),
                    ),
                  ]),
                ),
                for (final alt in agac.altlari(ana.id))
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 56, right: 16),
                    title: Text(alt.ad),
                    onTap: () async {
                      final ad = await _adSor(context, baslik: 'Yeniden adlandır', ilk: alt.ad);
                      if (ad != null) await depo.kategoriAdlandir(alt.id, ad);
                    },
                    trailing: IconButton(
                      tooltip: 'Sil',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _silSor(context, alt, false),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
