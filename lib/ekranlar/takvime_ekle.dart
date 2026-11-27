import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../takvim/takvim_ayarlari.dart';
import '../takvim/takvim_deposu.dart';
import '../takvim/takvim_kaynagi.dart';
import '../takvim/takvim_modeller.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'etkinlik_duzenle.dart';
import 'takvim_ayar_pencereleri.dart';

bool notIsMi(Not not) {
  final agac = Depo.instance.agac;
  for (final k in not.kategoriIdler) {
    final kat = agac.bul(k);
    if (kat == null) continue;
    final ana = kat.ustId == null ? kat : agac.bul(kat.ustId!) ?? kat;
    if (isKategorisiMi(ana.ad)) return true;
  }
  return false;
}

Future<bool> _hazirMi(BuildContext context) async {
  final depo = TakvimDeposu.instance;
  if (!depo.izinSorgulandi) await depo.baslat();
  if (!depo.izinVar) {
    final ok = await depo.izinIste();
    if (!ok) {
      mesajGoster('Takvime eklemek için takvim izni gerekiyor.',
          eylem: 'Takvim', eylemFn: () => sekmeSecici.value = 1);
      return false;
    }
  }
  if (!depo.takvimSecili) {
    mesajGoster('Önce hangi takvimi kullanacağını seç.', eylem: 'Seç', eylemFn: () => sekmeSecici.value = 1);
    sekmeSecici.value = 1;
    return false;
  }
  return true;
}

/// Notu takvime ekler: "Kendim seçeyim" (düzenleme ekranı) ya da "Otomatik öner" (boş zamanı uygulama bulur).
Future<void> takvimeEkle(BuildContext context, Not not) async {
  if (!await _hazirMi(context) || !context.mounted) return;
  final secim = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Renk.zemin,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: Icon(Icons.edit_calendar, color: Renk.vurgu),
          title: const Text('Kendim seçeyim'),
          subtitle: const Text('Takvim ekranı açılır, günü ve saati sen belirlersin.'),
          onTap: () => Navigator.pop(ctx, 'kendim'),
        ),
        ListTile(
          leading: Icon(Icons.auto_awesome, color: Renk.vurgu),
          title: const Text('Otomatik öner'),
          subtitle: const Text('Uygun boş bir zamanı uygulama bulur, sonra değiştirebilirsin.'),
          onTap: () => Navigator.pop(ctx, 'otomatik'),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (secim == null || !context.mounted) return;
  if (secim == 'kendim') {
    await _kendimSec(not);
  } else {
    await _otomatikEkle(context, not);
  }
}

Future<void> _kendimSec(Not not) async {
  final depo = TakvimDeposu.instance;
  DateTime? bas;
  if (not.tarih != null) {
    final t = DateTime.fromMillisecondsSinceEpoch(not.tarih!);
    bas = not.tarihSaatli ? t : DateTime(t.year, t.month, t.day, 9);
  }
  final sonuc = await etkinlikDuzenleAc(
    baslik: not.gorunenBaslik,
    baslangic: bas,
    sureDk: not.sureDk ?? 60,
    aciklama: not.link,
  );
  if (sonuc == null || sonuc.silindi || sonuc.etkinlikId == null) return;
  await depo.notuBagla(not, sonuc.etkinlikId!, sonuc.baslangic, sonuc.bitis);
  mesajGoster('Takvime eklendi: ${zamanMetni(sonuc.baslangic)}');
}

Future<void> _otomatikEkle(BuildContext context, Not not) async {
  final depo = TakvimDeposu.instance;
  final ayar = TakvimAyarlari.instance;
  if (!ayar.kurallar.uykuTanimli) {
    final ok = await uykuAyarlaDialogu(context);
    if (!ok || !context.mounted) return;
  }
  final isNotu = notIsMi(not);
  final sure = not.sureDk ?? 30;
  try {
    final zaman = await depo.bosZamanBul(sureDk: sure, isNotu: isNotu);
    if (zaman == null) {
      mesajGoster(isNotu
          ? 'İş notu için uygun yer bulamadım. Takvimde başlığında "${ayar.isKelimesi}" geçen bir etkinlik (iş bloğu) olmalı.'
          : 'Önümüzdeki 2 haftada uygun boş zaman bulamadım.');
      return;
    }
    final bitis = zaman.add(Duration(minutes: sure <= 0 ? 30 : sure));
    final id = await depo.ekle(TEtkinlikTaslagi(
      baslik: '$uygulamaIsareti ${not.gorunenBaslik}',
      baslangic: zaman,
      bitis: bitis,
      aciklama: not.link,
    ));
    await depo.notuBagla(not, id, zaman, bitis);
    mesajGoster(
      '${zamanMetni(zaman)} için eklendi',
      eylem: 'Değiştir',
      eylemFn: () async {
        final e = await depo.getir(id);
        if (e == null) return;
        final s = await etkinlikDuzenleAc(mevcut: e);
        if (s != null && !s.silindi) {
          await depo.notuBagla(not, id, s.baslangic, s.bitis);
        } else if (s != null && s.silindi) {
          await depo.baglantiyiKaldir(not);
        }
      },
      saniye: 7,
    );
  } on TakvimHatasi catch (e) {
    mesajGoster(e.mesaj);
  }
}

/// Bağlı etkinliği açıp düzenletir.
Future<void> bagliEtkinligiAc(Not not) async {
  final depo = TakvimDeposu.instance;
  final id = not.takvimEtkinlikId;
  if (id == null) return;
  final e = await depo.getir(id);
  if (e == null) {
    await depo.baglantiyiKaldir(not);
    mesajGoster('Etkinlik takvimde bulunamadı, bağlantı kaldırıldı.');
    return;
  }
  final s = await etkinlikDuzenleAc(mevcut: e);
  if (s == null) return;
  if (s.silindi) {
    await depo.baglantiyiKaldir(not);
  } else {
    await depo.notuBagla(not, id, s.baslangic, s.bitis);
  }
}

/// Notun takvimdeki etkinliğini siler ve bağlantıyı kaldırır.
Future<void> bagliEtkinligiSil(Not not) async {
  final depo = TakvimDeposu.instance;
  final id = not.takvimEtkinlikId;
  if (id == null) return;
  try {
    final e = await depo.getir(id);
    if (e != null) await depo.sil(e, Kapsam.hepsi);
  } on TakvimHatasi catch (h) {
    mesajGoster(h.mesaj);
    return;
  }
  await depo.baglantiyiKaldir(not);
  mesajGoster('Etkinlik takvimden silindi');
}
