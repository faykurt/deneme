import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../takvim/takvim_ayarlari.dart';

/// Hafta içi ve hafta sonu uyku saatlerini soran pencere. Kaydedilirse true döner.
/// Daha önce girilmemişse önerilen saatler dolu gelir, ama kullanıcı "Kaydet" demeden uygulanmaz.
Future<bool> uykuAyarlaDialogu(BuildContext context) async {
  final ayar = TakvimAyarlari.instance;
  var haftaIci = ayar.uykuHaftaIci ?? const UykuAraligi(23 * 60, 7 * 60);
  var haftaSonu = ayar.uykuHaftaSonu ?? const UykuAraligi(0, 9 * 60);
  final sonuc = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Future<void> sec(bool ici, bool yatis) async {
          final a = ici ? haftaIci : haftaSonu;
          final dk = yatis ? a.baslangicDk : a.bitisDk;
          final t = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: dk ~/ 60, minute: dk % 60));
          if (t == null) return;
          final yeniDk = t.hour * 60 + t.minute;
          final yeni = yatis ? UykuAraligi(yeniDk, a.bitisDk) : UykuAraligi(a.baslangicDk, yeniDk);
          setState(() {
            if (ici) {
              haftaIci = yeni;
            } else {
              haftaSonu = yeni;
            }
          });
        }

        Widget satir(String baslik, UykuAraligi a, bool ici) => Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => sec(ici, true), child: Text('Yatış ${UykuAraligi.saat(a.baslangicDk)}')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => sec(ici, false), child: Text('Kalkış ${UykuAraligi.saat(a.bitisDk)}')),
                  ),
                ]),
              ]),
            );

        return AlertDialog(
          title: const Text('Uyku saatlerin'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Bu saatlerde sana öneri yapılmaz ve notlar bu saatlere yerleştirilmez. '
                  'Değerler önerilen saatlerdir, kendine göre değiştir.'),
              satir('Hafta içi (izin günleri hariç)', haftaIci, true),
              satir('Hafta sonu ve izin günleri', haftaSonu, false),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        );
      },
    ),
  );
  if (sonuc != true) return false;
  await ayar.uykuAyarla(haftaIci: haftaIci, haftaSonu: haftaSonu);
  return true;
}

Future<void> isKelimesiDialogu(BuildContext context) async {
  final ayar = TakvimAyarlari.instance;
  final c = TextEditingController(text: ayar.isKelimesi);
  final sonuc = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('İş bloğu kelimesi'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Takvimde başlığında bu kelime geçen etkinlik "iş bloğu" sayılır. '
            'İş notları sadece bu bloğun içinde önerilir.'),
        const SizedBox(height: 12),
        TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.sentences),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Kaydet')),
      ],
    ),
  );
  if (sonuc != null) await ayar.isKelimesiAyarla(sonuc);
}

/// Kullanıcının izin günü olarak işaretlediği günler (hafta sonu gibi sayılır).
class IzinGunleriEkrani extends StatelessWidget {
  const IzinGunleriEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    final ayar = TakvimAyarlari.instance;
    return ListenableBuilder(
      listenable: ayar,
      builder: (context, _) {
        final gunler = ayar.izinGunleri.toList()..sort();
        return Scaffold(
          appBar: AppBar(backgroundColor: Renk.krem, title: const Text('İzin günleri')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final simdi = DateTime.now();
              final g = await showDatePicker(
                context: context,
                initialDate: simdi,
                firstDate: DateTime(simdi.year - 1),
                lastDate: DateTime(simdi.year + 3),
                helpText: 'İzin günü ekle',
              );
              if (g != null) await ayar.izinGunuEkle(g);
            },
            icon: const Icon(Icons.add),
            label: const Text('İzin günü'),
          ),
          body: gunler.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Henüz izin günü eklemedin.\nİzin günleri hafta sonu gibi sayılır: iş notu önerilmez.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Renk.kahve.withValues(alpha: 0.7)),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    for (final k in gunler)
                      ListTile(
                        leading: const Icon(Icons.beach_access_outlined),
                        title: Text(DateFormat('d MMMM y, EEEE', 'tr').format(DateTime.parse(k))),
                        trailing: IconButton(
                          tooltip: 'Kaldır',
                          icon: const Icon(Icons.close),
                          onPressed: () => ayar.izinGunuKaldir(k),
                        ),
                      ),
                  ],
                ),
        );
      },
    );
  }
}

/// Bu kategori "iş" kategorisi mi? (Ayarlardaki iş kelimesiyle aynı adlı ana kategori.)
bool isKategorisiMi(String anaKategoriAdi) =>
    anaKategoriAdi.toLowerCase() == TakvimAyarlari.instance.isKelimesi.toLowerCase();

/// "Cuma 14:00" gibi kısa zaman yazısı.
String zamanMetni(DateTime d) => DateFormat('d MMMM, EEEE HH:mm', 'tr').format(d);

