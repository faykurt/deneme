import 'package:material_ui/material_ui.dart';

import '../ai/ai_ayarlar.dart';
import '../oneri/oneri_deposu.dart';
import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'not_detay.dart';
import 'takvime_ekle.dart';

/// Ana sayfadaki öneri kartları, hafta sonu planı ve "Şu an ne yapabilirim?" düğmesi.
class OneriKartlari extends StatelessWidget {
  const OneriKartlari({super.key});

  @override
  Widget build(BuildContext context) {
    final oneri = OneriDeposu.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([oneri, Depo.instance, AiAyarlar.instance]),
      builder: (context, _) {
        final liste = oneri.gosterilecekler();
        final plan = oneri.haftaSonuPlani();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (oneri.acik && AiAyarlar.instance.anahtarVar && (liste.isNotEmpty || oneri.yenileniyor)) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
              child: Row(children: [
                _Baslik('Sana öneriler'),
                const Spacer(),
                if (oneri.yenileniyor)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
            ),
            for (final o in liste) _OneriKarti(not: o.not, neden: o.oneri.neden),
          ],
          if (oneri.acik && AiAyarlar.instance.anahtarVar && liste.isEmpty && !oneri.yenileniyor && oneri.adaylar(DateTime.now()).isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Renk.kart.withValues(alpha: 0.93), borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  Icon(Icons.notifications_none, color: Renk.vurgu),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Öneri ve hatırlatma almak istediğin notlarda "Bana hatırlat / öner" anahtarını aç.',
                        style: TextStyle(color: Renk.yazi.withValues(alpha: 0.8), fontSize: 13)),
                  ),
                ]),
              ),
            ),
          if (plan != null) _HaftaSonuKarti(plan: plan),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Material(
              color: Renk.vurguKart(0.2),
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => _suAnPenceresi(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(children: [
                    Icon(Icons.bolt, color: Renk.vurgu),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Şu an ne yapabilirim?', style: TextStyle(color: Renk.yazi, fontWeight: FontWeight.w600))),
                    Icon(Icons.chevron_right, color: Renk.yazi),
                  ]),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

class _Baslik extends StatelessWidget {
  final String metin;
  const _Baslik(this.metin);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Renk.kart.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
        child: Text(metin, style: TextStyle(color: Renk.yazi, fontWeight: FontWeight.w600)),
      );
}

class _OneriKarti extends StatelessWidget {
  final Not not;
  final String neden;
  const _OneriKarti({required this.not, required this.neden});

  Future<void> _yaptim(BuildContext context) async {
    final o = OneriDeposu.instance;
    if (await o.sonrakiAdimiTamamla(not)) {
      mesajGoster('Adım tamamlandı.');
      return;
    }
    if (!context.mounted) return;
    final secim = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Tamamen bitti mi?'),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'tam'), child: const Text('Tamamen bitti, arşive git')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx, 'bugun'), child: const Text('Bugünlük yaptım, sonra yine öner')),
          SimpleDialogOption(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        ],
      ),
    );
    if (secim == 'tam') {
      await o.tamamenBitti(not);
      mesajGoster('Tamamlandı, arşive taşındı.');
    } else if (secim == 'bugun') {
      await o.yarinaBirak(not, ertelemeSay: false);
      mesajGoster('Güzel! Yarın yine hatırlatırım.');
    }
  }

  Future<void> _sil() async {
    final adim = not.adimlar.where((a) => !a.yapildi).firstOrNull;
    if (adim == null) {
      await silVeGeriAlGoster([not.id]);
      return;
    }
    // Adımlı notta yalnızca sıradaki adım silinir.
    final eski = [...not.adimlar];
    await Depo.instance.adimlariKaydet(not.id, eski.where((a) => a.id != adim.id).toList());
    mesajGoster('Adım silindi', eylem: 'Geri al', eylemFn: () => Depo.instance.adimlariKaydet(not.id, eski), saniye: 5);
  }

  @override
  Widget build(BuildContext context) {
    final yazi = Theme.of(context).textTheme;
    final sonrakiAdim = not.adimlar.where((a) => !a.yapildi).firstOrNull;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      color: Renk.kart.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Renk.vurgu.withValues(alpha: 0.4))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotDetay(notId: not.id))),
            child: Text(not.gorunenBaslik, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: yazi.titleSmall?.copyWith(color: Renk.yazi, fontWeight: FontWeight.w600)),
          ),
          if (sonrakiAdim != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Sıradaki adım: ${sonrakiAdim.metin}', style: yazi.bodySmall?.copyWith(color: Renk.vurgu)),
            ),
          const SizedBox(height: 2),
          Text(neden, style: yazi.bodySmall?.copyWith(color: Renk.yazi.withValues(alpha: 0.8))),
          Wrap(spacing: 0, children: [
            TextButton.icon(onPressed: () => _yaptim(context), icon: const Icon(Icons.check, size: 18), label: const Text('Yaptım')),
            TextButton.icon(
                onPressed: () async {
                  await OneriDeposu.instance.yarinaBirak(not);
                  mesajGoster('Yarın yine önereceğim.');
                },
                icon: const Icon(Icons.schedule, size: 18),
                label: const Text('Sonra hatırlat')),
            TextButton.icon(onPressed: () => takvimeEkle(context, not), icon: const Icon(Icons.event_available, size: 18), label: const Text('Takvime ekle')),
            TextButton.icon(
                onPressed: _sil,
                icon: Icon(Icons.delete_outline, size: 18, color: Renk.hata),
                label: Text('Sil', style: TextStyle(color: Renk.hata))),
          ]),
        ]),
      ),
    );
  }
}

class _HaftaSonuKarti extends StatelessWidget {
  final ({String gun, List<Not> ogle, List<Not> aksam}) plan;
  const _HaftaSonuKarti({required this.plan});

  @override
  Widget build(BuildContext context) {
    final baslik = switch (plan.gun) {
      'cumartesi' => 'Cumartesi planı',
      'pazar' => 'Pazar planı',
      _ => 'Hafta sonu fikirleri',
    };
    Widget bolum(String ad, List<Not> notlar) => notlar.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(ad, style: TextStyle(color: Renk.vurgu, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            for (final n in notlar)
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NotDetay(notId: n.id))),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(Icons.circle, size: 6, color: Renk.yazi.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(n.gorunenBaslik, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Renk.yazi))),
                  ]),
                ),
              ),
          ]);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      color: Renk.kart.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.weekend_outlined, color: Renk.vurgu),
            const SizedBox(width: 8),
            Text(baslik, style: TextStyle(color: Renk.yazi, fontWeight: FontWeight.w600, fontSize: 16)),
          ]),
          bolum('Öğle (12:00-18:00)', plan.ogle),
          bolum('Akşam (18:00-24:00)', plan.aksam),
        ]),
      ),
    );
  }
}

/// "Şu an ne yapabilirim?": süre seçilir, o süreye uyan 2-3 not gösterilir (yapay zeka çağrılmaz).
Future<void> _suAnPenceresi(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Renk.zemin,
    isScrollControlled: true,
    builder: (ctx) => const _SuAnPenceresi(),
  );
}

class _SuAnPenceresi extends StatefulWidget {
  const _SuAnPenceresi();
  @override
  State<_SuAnPenceresi> createState() => _SuAnPenceresiState();
}

class _SuAnPenceresiState extends State<_SuAnPenceresi> {
  int? _dk;
  List<Not> _sonuc = [];

  Future<void> _sec(int dk) async {
    final iste = await OneriDeposu.instance.isBlogundaMi();
    if (!mounted) return;
    setState(() {
      _dk = dk;
      _sonuc = OneriDeposu.instance.suAnNeYapabilirim(dk, isBlogundayim: iste);
    });
  }

  @override
  Widget build(BuildContext context) {
    const secenekler = [(15, '15 dk'), (30, '30 dk'), (60, '1 saat'), (180, 'Bütün akşam')];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Ne kadar vaktin var?', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final s in secenekler)
              ChoiceChip(label: Text(s.$2), selected: _dk == s.$1, onSelected: (_) => _sec(s.$1)),
          ]),
          const SizedBox(height: 12),
          if (_dk != null && _sonuc.isEmpty)
            Text('Bu süreye uyan bir not bulamadım.', style: TextStyle(color: Renk.yazi.withValues(alpha: 0.7))),
          for (final n in _sonuc)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.arrow_circle_right_outlined, color: Renk.vurgu),
              title: Text(n.gorunenBaslik, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text('${n.sureDk ?? 30} dk'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => NotDetay(notId: n.id)));
              },
            ),
        ]),
      ),
    );
  }
}
