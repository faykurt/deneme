import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../takvim/takvim_ayarlari.dart';
import '../takvim/takvim_deposu.dart';
import '../takvim/takvim_modeller.dart';

/// Ayarlar > Görünen takvimler: telefondaki bütün hesapların (kişisel, iş) takvimlerinden hangileri
/// Aklımda'da görünsün, yeni etkinlikler hangisine yazılsın.
class GorunenTakvimlerEkrani extends StatelessWidget {
  const GorunenTakvimlerEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final depo = TakvimDeposu.instance;
    final ayar = TakvimAyarlari.instance;
    return Scaffold(
      appBar: AppBar(backgroundColor: Renk.zemin, title: const Text('Görünen takvimler')),
      body: ListenableBuilder(
        listenable: Listenable.merge([depo, ayar]),
        builder: (context, _) {
          final tumu = depo.takvimler;
          if (tumu.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Takvimler henüz yüklenmedi. Takvim sekmesinden takvim iznini ver.',
                    textAlign: TextAlign.center, style: TextStyle(color: Renk.yazi.withValues(alpha: 0.7))),
              ),
            );
          }
          final gorunen = ayar.gorunenTakvimler ?? tumu.map((t) => t.id).toSet();
          final hesaplar = <String, List<TakvimBilgi>>{};
          for (final t in tumu) {
            hesaplar.putIfAbsent(t.hesap?.isNotEmpty == true ? t.hesap! : 'Diğer', () => []).add(t);
          }
          final yazilabilir = tumu.where((t) => !t.saltOkunur).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  "İş ve kişisel hesapların hepsi telefonunun takviminde ekliyse burada görünür. "
                  "İşaretlediklerin Aklımda'da birlikte listelenir.",
                  style: TextStyle(color: Renk.yazi.withValues(alpha: 0.7), fontSize: 13),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar_outlined),
                title: const Text('Yeni etkinlikler şuraya yazılır'),
                subtitle: Text(ayar.takvimAdi ?? 'Seçilmedi'),
                onTap: () async {
                  final t = await showDialog<TakvimBilgi>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: const Text('Yeni etkinlikler hangi takvime yazılsın?'),
                      children: [
                        for (final t in yazilabilir)
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, t),
                            child: Text('${t.ad}${t.hesap == null ? '' : '  ·  ${t.hesap}'}'),
                          ),
                      ],
                    ),
                  );
                  if (t != null) await depo.takvimSec(t);
                },
              ),
              const Divider(),
              for (final e in hesaplar.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                  child: Text(e.key, style: TextStyle(color: Renk.vurgu, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                for (final t in e.value)
                  CheckboxListTile(
                    value: gorunen.contains(t.id),
                    secondary: CircleAvatar(radius: 10, backgroundColor: t.renk ?? Renk.vurgu),
                    title: Text(t.ad),
                    subtitle: t.saltOkunur ? const Text('Salt okunur') : null,
                    onChanged: (v) {
                      final yeni = {...gorunen};
                      if (v == true) {
                        yeni.add(t.id);
                      } else if (yeni.length > 1) {
                        yeni.remove(t.id);
                      }
                      depo.gorunenTakvimleriAyarla(yeni);
                    },
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
