import 'dart:io';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'ai/ai_ayarlar.dart';
import 'ai/isleyici.dart';
import 'takvim/takvim_deposu.dart';
import 'takvim/takvim_modeller.dart';
import 'veri/depo.dart';
import 'veri/modeller.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Alt menüde hangi sekmenin açık olduğu (başka ekranlardan sekme değiştirmek için).
final ValueNotifier<int> sekmeSecici = ValueNotifier<int>(0);

/// Uygulamanın renkleri: nötr gri zemin, tek yeşil vurgu. Koyu ve açık tema.
class Renk {
  /// Tema değişince [TemaAyari] günceller.
  static bool koyu = true;

  static Color get vurgu => koyu ? const Color(0xFF5CC38A) : const Color(0xFF2F8F5B);
  static Color get vurguUstu => koyu ? const Color(0xFF0C1F15) : Colors.white;
  static Color get zemin => koyu ? const Color(0xFF131514) : const Color(0xFFECEDEC);
  static Color get kart => koyu ? const Color(0xFF212423) : const Color(0xFFFAFAF9);
  static Color get yazi => koyu ? const Color(0xFFE7E9E7) : const Color(0xFF232625);
  static Color get hata => koyu ? const Color(0xFFEF9A9A) : const Color(0xFFC62828);
  /// Yarı saydam görünmesin diye karta karıştırılmış vurgu zemini.
  static Color vurguKart([double a = 0.16]) => Color.alphaBlend(vurgu.withValues(alpha: a), kart);
  static Color get sinir => koyu ? const Color(0x33FFFFFF) : const Color(0x22000000);
}

String tarihYazisi(int ms) {
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  final simdi = DateTime.now();
  final bugun = DateTime(simdi.year, simdi.month, simdi.day);
  final gun = DateTime(t.year, t.month, t.day);
  final fark = bugun.difference(gun).inDays;
  final saat = DateFormat('HH:mm', 'tr').format(t);
  if (fark == 0) return 'Bugün $saat';
  if (fark == 1) return 'Dün $saat';
  if (t.year == simdi.year) return DateFormat('d MMMM', 'tr').format(t);
  return DateFormat('d MMMM y', 'tr').format(t);
}

void mesajGoster(String metin, {String? eylem, VoidCallback? eylemFn, int saniye = 4}) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  ScaffoldMessenger.of(ctx)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(metin),
      // Yüzen bildirim: sesli not butonunu ve alt menüyü yerinden oynatmaz.
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      duration: Duration(seconds: saniye),
      action: eylem == null ? null : SnackBarAction(label: eylem, onPressed: eylemFn ?? () {}),
    ));
}

/// Notları silip 5 saniye "Geri al" gösterir.
Future<void> silVeGeriAlGoster(List<String> idler) async {
  final bagli = Depo.instance.notlar
      .where((n) => idler.contains(n.id) && n.takvimEtkinlikId != null)
      .toList();
  var etkinlikleriSil = false;
  final ctx = navigatorKey.currentContext;
  if (bagli.isNotEmpty && ctx != null) {
    final secim = await showDialog<String>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Takvimdeki etkinlik de silinsin mi?'),
        content: Text(bagli.length == 1
            ? 'Bu not takvime eklenmişti.'
            : '${bagli.length} not takvime eklenmişti.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, 'sadece'), child: const Text('Sadece notu sil')),
          FilledButton(onPressed: () => Navigator.pop(c, 'ikisi'), child: const Text('İkisini de sil')),
        ],
      ),
    );
    if (secim == null) return;
    etkinlikleriSil = secim == 'ikisi';
  }
  await Depo.instance.sil(idler);
  if (bagli.isNotEmpty) {
    final takvim = TakvimDeposu.instance;
    for (final n in bagli) {
      if (etkinlikleriSil) {
        try {
          final e = await takvim.getir(n.takvimEtkinlikId!);
          if (e != null) await takvim.sil(e, Kapsam.hepsi);
        } catch (_) {
          // Etkinlik silinemediyse not yine silinir.
        }
      }
      // Silme geri alınırsa not takvim bağlantısı olmadan geri gelir.
      if (etkinlikleriSil) await takvim.baglantiyiKaldir(n);
    }
  }
  mesajGoster(idler.length == 1 ? 'Not silindi' : '${idler.length} not silindi',
      eylem: 'Geri al', eylemFn: () => Depo.instance.silmeyiGeriAl(idler), saniye: 5);
}

/// Notları arşive alır (ya da arşivden çıkarır) ve 5 saniye "Geri al" gösterir.
Future<void> arsivleVeGeriAlGoster(List<String> idler, bool arsiv) async {
  await Depo.instance.arsivle(idler, arsiv);
  final tek = idler.length == 1;
  mesajGoster(
    arsiv
        ? (tek ? 'Arşivlendi' : '${idler.length} not arşivlendi')
        : (tek ? 'Arşivden çıkarıldı' : '${idler.length} not arşivden çıkarıldı'),
    eylem: 'Geri al',
    eylemFn: () => Depo.instance.arsivle(idler, !arsiv),
    saniye: 5,
  );
}

/// Tek kategori seçtirir (Taşı/Kopyala için). İptal ederse null.
Future<int?> kategoriSec(BuildContext context, {required String baslik}) {
  final agac = Depo.instance.agac;
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(baslik, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final ana in agac.anaKategoriler) ...[
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(ana.ad),
                onTap: () => Navigator.pop(ctx, ana.id),
              ),
              for (final alt in agac.altlari(ana.id))
                ListTile(
                  contentPadding: const EdgeInsets.only(left: 56, right: 16),
                  leading: const Icon(Icons.subdirectory_arrow_right, size: 18),
                  title: Text(alt.ad),
                  onTap: () => Navigator.pop(ctx, alt.id),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Bir notun liste/klasör görünümündeki kartı.
class NotKarti extends StatelessWidget {
  final Not not;
  final bool secili;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Verilirse kartın köşesinde küçük bir çöp kutusu çıkar.
  final VoidCallback? silFn;

  const NotKarti({
    super.key,
    required this.not,
    required this.onTap,
    this.onLongPress,
    this.silFn,
    this.secili = false,
  });

  @override
  Widget build(BuildContext context) {
    final agac = Depo.instance.agac;
    final yazi = Theme.of(context).textTheme;
    final metinOnizleme = not.metin.trim().split('\n').skip(not.baslik == null ? 1 : 0).join(' ').trim();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: secili ? Renk.vurgu.withValues(alpha: 0.25) : Renk.kart,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: secili ? Renk.vurgu : Renk.sinir),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (not.liste)
                        Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.checklist, size: 18, color: Renk.vurgu)),
                      if (not.kaynak == Kaynak.sesli && !not.liste)
                        Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.mic, size: 16, color: Renk.vurgu)),
                      if (not.kaynak == Kaynak.paylasim)
                        Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.share, size: 16, color: Renk.vurgu)),
                      Expanded(
                        child: Text(not.gorunenBaslik,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: yazi.titleSmall?.copyWith(
                              color: Renk.yazi,
                              fontWeight: FontWeight.w600,
                              decoration: not.durum == Durum.yapildi ? TextDecoration.lineThrough : null,
                            )),
                      ),
                    ]),
                    if (metinOnizleme.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(metinOnizleme,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: yazi.bodySmall?.copyWith(color: Renk.yazi.withValues(alpha: 0.75))),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(tarihYazisi(not.olusturma),
                            style: yazi.labelSmall?.copyWith(color: Renk.yazi.withValues(alpha: 0.6))),
                        if (not.liste && not.adimlar.isNotEmpty)
                          _Etiket('${not.adimlar.where((a) => a.yapildi).length}/${not.adimlar.length} madde'),
                        if (not.durum != Durum.yapilacak) _Etiket(Durum.ad(not.durum)),
                        if (!not.islendi && !not.aiDisi && AiAyarlar.instance.anahtarVar) const _Etiket('⏳ işlenecek'),
                        if (not.onayBekliyor) const _Etiket('onay bekliyor'),
                        for (final k in not.kategoriIdler) _Etiket(agac.tamAd(k)),
                      ],
                    ),
                    if (not.aiDisi && !not.islendi && AiAyarlar.instance.anahtarVar) _AiGonderBaglantisi(not: not),
                  ],
                ),
              ),
              if (silFn != null)
                InkWell(
                  onTap: silFn,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(Icons.delete_outline, size: 20, color: Renk.yazi.withValues(alpha: 0.6)),
                  ),
                ),
              if (not.fotograflar.isNotEmpty) ...[
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(not.fotograflar.first),
                      width: 56, height: 56, fit: BoxFit.cover, cacheWidth: 168,
                      errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiket extends StatelessWidget {
  final String yazi;
  const _Etiket(this.yazi);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Renk.vurgu.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(yazi, style: TextStyle(fontSize: 11, color: Renk.yazi)),
      );
}

/// Yapay zeka dışı bırakılmış notta, göze batmayan küçük "Yapay zekaya gönder" bağlantısı.
class _AiGonderBaglantisi extends StatelessWidget {
  final Not not;
  const _AiGonderBaglantisi({required this.not});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: InkWell(
          onTap: () async {
            final hata = await AiIsleyici.instance.notuGonder(not);
            mesajGoster(hata == null ? 'Yapay zeka düzenledi, onay bekleyenlere düştü.' : hata.mesaj);
          },
          child: Text('Yapay zekaya gönder',
              style: TextStyle(fontSize: 11, color: Renk.yazi.withValues(alpha: 0.5), decoration: TextDecoration.underline)),
        ),
      );
}
