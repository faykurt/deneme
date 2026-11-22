import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/ai_modeller.dart';
import '../ai/ai_harcama.dart';
import '../ai/ai_servisi.dart';
import '../ai/ai_zamanlama.dart';
import '../ai/isleyici.dart';
import '../ortak.dart';
import '../takvim/takvim_ayarlari.dart';
import 'onay_penceresi.dart';
import 'takvim_ayar_pencereleri.dart';
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
  bool _deniyor = false;

  Future<void> _anahtarDialogu() async {
    final c = TextEditingController();
    final sonuc = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yapay zeka anahtarı'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('console.anthropic.com adresinde oluşturduğun anahtarı yapıştır. '
              'Anahtar sadece bu telefonda, şifreli olarak saklanır.'),
          const SizedBox(height: 12),
          TextField(
            controller: c,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(hintText: 'sk-ant-…', border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          if (AiAyarlar.instance.anahtarVar)
            TextButton(onPressed: () => Navigator.pop(ctx, '__sil__'), child: const Text('Anahtarı sil')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Kaydet ve dene')),
        ],
      ),
    );
    if (sonuc == null || !mounted) return;
    if (sonuc == '__sil__') {
      await AiAyarlar.instance.sil();
      mesajGoster('Anahtar silindi');
      return;
    }
    final temiz = sonuc.replaceAll(RegExp(r'\s+'), '');
    if (temiz.isEmpty) return;
    if (!temiz.startsWith('sk-ant-')) {
      final yine = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Anahtar tuhaf görünüyor'),
          content: const Text('Anthropic anahtarları "sk-ant-" ile başlar. Yine de kaydedilsin mi?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yine de kaydet')),
          ],
        ),
      );
      if (yine != true) return;
    }
    await AiAyarlar.instance.kaydet(temiz);
    await _baglantiyiDene();
  }

  void _harcamaAyrinti(BuildContext context) {
    final h = AiHarcama.instance;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bu ayki kullanım'),
        content: Text('Tahmini harcama: ${h.dolarMetni}\n'
            'İstek sayısı: ${h.istek}\n'
            'Gönderilen: ${h.girdi} token\n'
            'Alınan: ${h.cikti} token\n\n'
            'Bu rakam, API\'nin bildirdiği token sayıları ve güncel fiyatlarla hesaplanan bir tahmindir. '
            'Kesin tutar için console.anthropic.com adresinde Usage sayfasına bak.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
      ),
    );
  }

  Future<void> _baglantiyiDene() async {
    final anahtar = AiAyarlar.instance.anahtar;
    if (anahtar == null || _deniyor) return;
    setState(() => _deniyor = true);
    try {
      await AiServisi.baglantiyiDene(anahtar);
      AiIsleyici.instance.hatayiTemizle();
      mesajGoster('Bağlantı başarılı ✓ Yapay zeka hazır.');
      AiIsleyici.instance.bekleyenleriIsle();
    } on AiHata catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bağlantı kurulamadı'),
          content: Text(e.mesaj),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
        ),
      );
    } finally {
      if (mounted) setState(() => _deniyor = false);
    }
  }

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
          ListenableBuilder(
            listenable: Listenable.merge(
                [AiAyarlar.instance, AiZamanlama.instance, AiHarcama.instance, AiIsleyici.instance, Depo.instance]),
            builder: (context, _) {
              final ai = AiAyarlar.instance;
              final isleyici = AiIsleyici.instance;
              return Column(children: [
                ListTile(
                  leading: _deniyor
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome, color: Renk.turuncu),
                  title: const Text('Yapay zeka anahtarı'),
                  subtitle: Text(ai.anahtarVar
                      ? 'Kayıtlı (${ai.maskeli})'
                      : 'Henüz eklenmedi. Notların kendiliğinden düzenlenmesi için gerekli.'),
                  onTap: _deniyor ? null : _anahtarDialogu,
                ),
                if (ai.anahtarVar)
                  ListTile(
                    leading: const Icon(Icons.network_check),
                    title: const Text('Bağlantıyı dene'),
                    onTap: _deniyor ? null : _baglantiyiDene,
                  ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Yapay zeka çalışma saatleri'),
                  subtitle: Text('${AiZamanlama.instance.ozet}. Notlar kaydedilince hemen değil, bu saatlerde işlenir '
                      '(maliyeti düşük tutmak için).'),
                  onTap: () => aiSaatleriDialogu(context),
                ),
                ListTile(
                  leading: isleyici.mesgul
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.play_circle_outline),
                  title: const Text('Şimdi işle'),
                  subtitle: Text(isleyici.bekleyenSayisi == 0
                      ? 'İşlenmeyi bekleyen not yok'
                      : '${isleyici.bekleyenSayisi} not işlenmeyi bekliyor'),
                  onTap: !ai.anahtarVar || isleyici.mesgul || isleyici.bekleyenSayisi == 0
                      ? null
                      : () async {
                          await isleyici.bekleyenleriIsle();
                          final h = isleyici.sonHata;
                          mesajGoster(h == null ? 'Notlar işlendi, onay bekleyenlere düştü.' : h.mesaj);
                        },
                ),
                ListTile(
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Bu ay yapay zeka harcaması'),
                  subtitle: Text('${AiHarcama.instance.ozet}  ·  tahminidir'),
                  onTap: () => _harcamaAyrinti(context),
                ),
                ListTile(
                  leading: const Icon(Icons.memory),
                  title: const Text('Modeller'),
                  subtitle: Text(aiModelBilgisi),
                ),
              ]);
            },
          ),
          const Divider(),
          ListenableBuilder(
            listenable: TakvimAyarlari.instance,
            builder: (context, _) {
              final t = TakvimAyarlari.instance;
              return Column(children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month_outlined, color: Renk.turuncu),
                  title: const Text('Kullanılan takvim'),
                  subtitle: Text(t.takvimAdi ?? 'Henüz seçilmedi'),
                  onTap: () async {
                    await t.takvimiSifirla();
                    sekmeSecici.value = 1;
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: const Text('Uyku saatleri'),
                  subtitle: Text(t.kurallar.uykuTanimli
                      ? 'Hafta içi ${t.uykuHaftaIci}  ·  Hafta sonu ${t.uykuHaftaSonu}'
                      : 'Henüz girilmedi'),
                  onTap: () => uykuAyarlaDialogu(context),
                ),
                ListTile(
                  leading: const Icon(Icons.work_outline),
                  title: const Text('İş bloğu kelimesi'),
                  subtitle: Text('Takvimde başlığında "${t.isKelimesi}" geçen etkinlik iş bloğu sayılır'),
                  onTap: () => isKelimesiDialogu(context),
                ),
                ListTile(
                  leading: const Icon(Icons.beach_access_outlined),
                  title: const Text('İzin günleri'),
                  subtitle: Text(t.izinGunleri.isEmpty ? 'Eklenmedi' : '${t.izinGunleri.length} gün'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IzinGunleriEkrani())),
                ),
              ]);
            },
          ),
          const Divider(),
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
