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
import '../kategori_gorunum.dart';
import '../ortak.dart';
import '../ses.dart';
import '../tema.dart';
import '../takvim/takvim_ayarlari.dart';
import '../oneri/bildirim_servisi.dart';
import '../oneri/oneri_deposu.dart';
import 'fikir_kutusu.dart';
import 'gorunen_takvimler.dart';
import 'yazili_not.dart' show fotografSec;
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
      appBar: AppBar(backgroundColor: Renk.zemin, title: const Text('Ayarlar')),
      body: ListView(
        children: [
          ListenableBuilder(
            listenable: Ses.instance,
            builder: (context, _) => SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: const Text('Ses efektleri'),
              subtitle: const Text('Düğmelerde yumuşak tık, kitaplarda sayfa hışırtısı.'),
              value: Ses.instance.acik,
              onChanged: (v) {
                Ses.instance.acikAyarla(v);
                if (v) Ses.instance.tik();
              },
            ),
          ),
          ListenableBuilder(
            listenable: TemaAyari.instance,
            builder: (context, _) => SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined),
              title: const Text('Koyu tema'),
              subtitle: Text(TemaAyari.instance.koyu ? 'Koyu' : 'Açık (krem)'),
              value: TemaAyari.instance.koyu,
              onChanged: (v) => TemaAyari.instance.ayarla(v),
            ),
          ),
          const Divider(),
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
                      : Icon(Icons.auto_awesome, color: Renk.vurgu),
                  title: const Text('Yapay zeka anahtarı'),
                  subtitle: Text(ai.anahtarVar
                      ? 'Kayıtlı (${ai.maskeli})'
                      : 'Henüz eklenmedi. Notların kendiliğinden düzenlenmesi için gerekli.'),
                  onTap: _deniyor ? null : _anahtarDialogu,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.auto_fix_high_outlined),
                  title: const Text('Notları yapay zeka düzenlesin'),
                  subtitle: Text(ai.otomatik
                      ? 'Açık: yeni notlar çalışma saatlerinde kendiliğinden işlenir.'
                      : 'Kapalı: notlar olduğu gibi kalır, istediğin notu kartından yapay zekaya gönderirsin.'),
                  value: ai.otomatik,
                  onChanged: (v) => ai.otomatikAyarla(v),
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
            listenable: OneriDeposu.instance,
            builder: (context, _) {
              final o = OneriDeposu.instance;
              return Column(children: [
                SwitchListTile(
                  secondary: const Icon(Icons.lightbulb_outline),
                  title: const Text('Öneriler'),
                  subtitle: const Text('Ana sayfada günün saatine ve takvimine göre ne yapabileceğini önerir.'),
                  value: o.acik,
                  onChanged: (v) => o.acikAyarla(v),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Günlük bildirim sayısı'),
                  subtitle: Text(o.bildirimSiniri == 0 ? 'Bildirim yok' : 'Günde en fazla ${o.bildirimSiniri} öneri bildirimi'),
                  onTap: () async {
                    final n = await showDialog<int>(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Günde kaç bildirim?'),
                        children: [
                          for (final s in [0, 1, 2, 3])
                            SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, s),
                              child: Text(s == 0 ? 'Hiç (sadece uygulamada göster)' : '$s'),
                            ),
                        ],
                      ),
                    );
                    if (n != null) await o.sinirAyarla(n);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notification_add_outlined),
                  title: const Text('Bildirimi dene'),
                  subtitle: const Text('Bildirimlerin geldiğini kontrol et. Gelmezse Samsung pil ayarında Aklımda\'yı "Sınırsız" yap.'),
                  onTap: () async {
                    final b = BildirimServisi.instance;
                    if (!await b.izinVarMi()) await b.izinIste();
                    final tamam = await b.denemeGoster();
                    mesajGoster(tamam ? 'Deneme bildirimi gönderildi.' : 'Bildirim gösterilemedi. Telefon ayarlarından izin ver.');
                  },
                ),
                ListTile(
                  leading: o.yenileniyor
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  title: const Text('Önerileri şimdi yenile'),
                  subtitle: Text(o.sonHata?.mesaj ?? (o.paket == null ? 'Henüz öneri hazırlanmadı' : 'Son hazırlanan: ${tarihYazisi(o.paket!.olusturma)}')),
                  onTap: o.yenileniyor || !AiAyarlar.instance.anahtarVar ? null : () => o.yenile(zorla: true),
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
                  leading: Icon(Icons.calendar_month_outlined, color: Renk.vurgu),
                  title: const Text('Yeni etkinliklerin takvimi'),
                  subtitle: Text(t.takvimAdi ?? 'Henüz seçilmedi'),
                  onTap: () async {
                    await t.takvimiSifirla();
                    sekmeSecici.value = 1;
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_repeat_outlined),
                  title: const Text('Görünen takvimler'),
                  subtitle: Text(t.gorunenTakvimler == null
                      ? 'Telefondaki hepsi (iş ve kişisel hesaplar)'
                      : '${t.gorunenTakvimler!.length} takvim seçili'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GorunenTakvimlerEkrani())),
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
            leading: const Icon(Icons.tips_and_updates_outlined),
            title: const Text('Fikir kutusu'),
            subtitle: const Text('Uygulama için aklına gelenleri yaz, bana gönder'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FikirKutusuEkrani())),
          ),
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

  /// Kategoriye dokununca açılan pencere: ad, renk, ikon / emoji ve sil bir arada.
  Future<void> _duzenle(BuildContext context, Kategori k) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Renk.zemin,
      isScrollControlled: true,
      builder: (ctx) => _KategoriDuzenle(
        kategori: k,
        sil: () async {
          Navigator.pop(ctx);
          await _silSor(context, k, Depo.instance.agac.altlari(k.id).isNotEmpty);
        },
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
      appBar: AppBar(backgroundColor: Renk.zemin, title: const Text('Kategoriler')),
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
                  leading: _Yuvarlak(agac: agac, id: ana.id),
                  title: Text(ana.ad),
                  subtitle: const Text('Ad, renk ve ikon için dokun'),
                  onTap: () => _duzenle(context, ana),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Alt kategori ekle',
                      icon: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () async {
                        final ad = await _adSor(context, baslik: '${ana.ad} içine alt kategori');
                        if (ad != null) await depo.kategoriEkle(ad, ustId: ana.id);
                      },
                    ),
                  ]),
                ),
                for (final alt in agac.altlari(ana.id))
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 40, right: 16),
                    leading: _Yuvarlak(agac: agac, id: alt.id, kucuk: true),
                    title: Text(alt.ad),
                    onTap: () => _duzenle(context, alt),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Kategorinin rengiyle dolu yuvarlak içinde simgesi.
class _Yuvarlak extends StatelessWidget {
  final KategoriAgaci agac;
  final int id;
  final bool kucuk;
  const _Yuvarlak({required this.agac, required this.id, this.kucuk = false});

  @override
  Widget build(BuildContext context) {
    final r = kucuk ? 15.0 : 19.0;
    return CircleAvatar(
      radius: r,
      backgroundColor: agac.renkOf(id),
      child: kategoriSimgesi(agac, id, size: r, renk: Colors.white),
    );
  }
}

/// Kategori düzenleme penceresi.
class _KategoriDuzenle extends StatefulWidget {
  final Kategori kategori;
  final VoidCallback sil;
  const _KategoriDuzenle({required this.kategori, required this.sil});

  @override
  State<_KategoriDuzenle> createState() => _KategoriDuzenleState();
}

class _KategoriDuzenleState extends State<_KategoriDuzenle> {
  late final _ad = TextEditingController(text: widget.kategori.ad);
  final _emoji = TextEditingController();

  @override
  void dispose() {
    _ad.dispose();
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _adKaydet() async {
    final t = _ad.text.trim();
    if (t.isNotEmpty && t != widget.kategori.ad) await Depo.instance.kategoriAdlandir(widget.kategori.id, t);
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kategori;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Depo.instance,
          builder: (context, _) {
            final agac = Depo.instance.agac;
            final guncel = agac.bul(k.id) ?? k;
            final renk = agac.renkOf(k.id);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _Yuvarlak(agac: agac, id: k.id),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ad,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Ad'),
                      onSubmitted: (_) => _adKaydet(),
                      onEditingComplete: _adKaydet,
                      onTapOutside: (_) => _adKaydet(),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                Text('Kitap kapağı', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(children: [
                  if (guncel.kapakResmi != null && File(guncel.kapakResmi!).existsSync())
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(guncel.kapakResmi!), width: 52, height: 64, fit: BoxFit.cover, cacheWidth: 200),
                      ),
                    ),
                  Expanded(
                    child: Wrap(spacing: 8, children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final yollar = await fotografSec(kamera: false);
                          if (yollar.isNotEmpty) await Depo.instance.kategoriKapakResmi(k.id, yollar.first);
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(guncel.kapakResmi == null ? 'Kapağa resim koy' : 'Resmi değiştir'),
                      ),
                      if (guncel.kapakResmi != null)
                        TextButton(onPressed: () => Depo.instance.kategoriKapakResmi(k.id, null), child: const Text('Kaldır')),
                    ]),
                  ),
                ]),
                const SizedBox(height: 18),
                Text('Renk', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final c in KategoriGorunum.renkler)
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Depo.instance.kategoriGorunumu(k.id, renk: c.toARGB32()),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: c,
                        child: renk.toARGB32() == c.toARGB32() ? const Icon(Icons.check, color: Colors.white) : null,
                      ),
                    ),
                  if (guncel.renkDegeri != null)
                    TextButton(
                        onPressed: () => Depo.instance.kategoriGorunumu(k.id, renkiTemizle: true),
                        child: const Text('Varsayılan renk')),
                ]),
                const SizedBox(height: 18),
                Text('İkon', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final e in KategoriGorunum.ikonlar.entries)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Depo.instance.kategoriGorunumu(k.id, ikon: e.key),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: guncel.ikonAnahtari == e.key ? renk.withValues(alpha: 0.3) : Renk.kart,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: guncel.ikonAnahtari == e.key ? renk : Renk.sinir),
                        ),
                        child: Icon(e.value, color: Renk.yazi),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _emoji,
                      decoration: const InputDecoration(
                        labelText: 'Ya da emoji',
                        hintText: 'Klavyenin emoji düğmesiyle seç',
                      ),
                      onChanged: (v) {
                        final e = KategoriGorunum.ilkEmoji(v);
                        if (e != null) Depo.instance.kategoriGorunumu(k.id, ikon: e);
                      },
                    ),
                  ),
                  if (KategoriGorunum.emojiMi(guncel.ikonAnahtari))
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(guncel.ikonAnahtari!, style: const TextStyle(fontSize: 28)),
                    ),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Flexible(
                    child: TextButton.icon(
                      onPressed: widget.sil,
                      icon: Icon(Icons.delete_outline, color: Renk.hata),
                      label: Text('Kategoriyi sil', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Renk.hata)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      await _adKaydet();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Tamam'),
                  ),
                ]),
              ]),
            );
          },
        ),
      ),
    );
  }
}
