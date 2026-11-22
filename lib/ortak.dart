import 'dart:io';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'veri/depo.dart';
import 'veri/modeller.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Uygulamanın sıcak renk paleti.
class Renk {
  static const turuncu = Color(0xFFE8833A);
  static const krem = Color(0xFFFFF4E0);
  static const kahve = Color(0xFF4A2C1D);
  static const acikKrem = Color(0xFFFFFAF0);
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
      duration: Duration(seconds: saniye),
      action: eylem == null ? null : SnackBarAction(label: eylem, onPressed: eylemFn ?? () {}),
    ));
}

/// Notları silip 5 saniye "Geri al" gösterir.
Future<void> silVeGeriAlGoster(List<String> idler) async {
  await Depo.instance.sil(idler);
  mesajGoster(idler.length == 1 ? 'Not silindi' : '${idler.length} not silindi',
      eylem: 'Geri al', eylemFn: () => Depo.instance.silmeyiGeriAl(idler), saniye: 5);
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

  const NotKarti({
    super.key,
    required this.not,
    required this.onTap,
    this.onLongPress,
    this.secili = false,
  });

  @override
  Widget build(BuildContext context) {
    final agac = Depo.instance.agac;
    final yazi = Theme.of(context).textTheme;
    final metinOnizleme = not.metin.trim().split('\n').skip(not.baslik == null ? 1 : 0).join(' ').trim();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: secili ? Renk.turuncu.withValues(alpha: 0.25) : Renk.acikKrem,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: secili ? Renk.turuncu : const Color(0x22000000)),
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
                      if (not.kaynak == Kaynak.sesli)
                        const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.mic, size: 16, color: Renk.turuncu)),
                      if (not.kaynak == Kaynak.paylasim)
                        const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.share, size: 16, color: Renk.turuncu)),
                      Expanded(
                        child: Text(not.gorunenBaslik,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: yazi.titleSmall?.copyWith(
                              color: Renk.kahve,
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
                          style: yazi.bodySmall?.copyWith(color: Renk.kahve.withValues(alpha: 0.75))),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(tarihYazisi(not.olusturma),
                            style: yazi.labelSmall?.copyWith(color: Renk.kahve.withValues(alpha: 0.6))),
                        if (not.durum != Durum.yapilacak) _Etiket(Durum.ad(not.durum)),
                        for (final k in not.kategoriIdler) _Etiket(agac.tamAd(k)),
                      ],
                    ),
                  ],
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
          color: Renk.turuncu.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(yazi, style: const TextStyle(fontSize: 11, color: Renk.kahve)),
      );
}
