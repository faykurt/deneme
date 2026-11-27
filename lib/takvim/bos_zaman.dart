import 'takvim_ayarlari.dart';
import 'takvim_modeller.dart';

/// Takvimde bir not için uygun boş zamanı bulur.
///
/// Kurallar:
/// - Uyku saatlerine ve takvimdeki dolu etkinliklere denk gelmez.
/// - İş bloğu (başlığında iş kelimesi geçen etkinlik) dolu sayılır, iş dışı notlar içine yerleşmez.
/// - İş notları sadece iş bloğunun içine yerleşir, hafta sonu ve izin günlerinde hiç yerleşmez.
class BosZamanBulucu {
  static bool isBlogu(TEtkinlik e, String kelime) =>
      !e.tumGun && e.baslik.toLowerCase().contains(kelime.toLowerCase());

  static DateTime? bul({
    required DateTime simdi,
    required int sureDk,
    required bool isNotu,
    required List<TEtkinlik> etkinlikler,
    required ZamanKurallari kurallar,
    int gunSayisi = 14,
    int adimDk = 15,
    int enAzBeklemeDk = 30,
  }) {
    final sure = Duration(minutes: sureDk <= 0 ? 30 : sureDk.clamp(5, 12 * 60));
    final adim = Duration(minutes: adimDk);
    final bas = simdi.add(Duration(minutes: enAzBeklemeDk));
    final son = gunBasi(simdi).add(Duration(days: gunSayisi));

    // Dolu aralıklar
    final dolu = <(DateTime, DateTime)>[];
    final bloklar = <(DateTime, DateTime)>[];
    for (final e in etkinlikler) {
      final (b, s) = _aralik(e);
      if (isBlogu(e, kurallar.isKelimesi)) {
        bloklar.add((b, s));
      } else if (e.meshgul) {
        dolu.add((b, s));
      }
    }
    dolu.addAll(kurallar.uykular(gunBasi(simdi), son));
    if (!isNotu) dolu.addAll(bloklar);

    // İlk aday: bugün/şimdi + bekleme, adım sınırına yuvarlanmış
    var t = _yukariYuvarla(bas, adimDk);
    while (t.add(sure).isBefore(son) || t.add(sure).isAtSameMomentAs(son)) {
      final bitis = t.add(sure);
      if (_uygun(t, bitis, dolu, bloklar, isNotu, kurallar)) return t;
      t = t.add(adim);
    }
    return null;
  }

  static bool _uygun(
    DateTime b,
    DateTime s,
    List<(DateTime, DateTime)> dolu,
    List<(DateTime, DateTime)> bloklar,
    bool isNotu,
    ZamanKurallari k,
  ) {
    for (final (db, ds) in dolu) {
      if (b.isBefore(ds) && s.isAfter(db)) return false;
    }
    if (!isNotu) return true;
    // İş notu: hafta sonu/izin günü olmaz, bir iş bloğunun tamamen içinde olmalı
    if (k.haftaSonuGibi(b) || k.haftaSonuGibi(s.subtract(const Duration(minutes: 1)))) return false;
    for (final (bb, bs) in bloklar) {
      if (!b.isBefore(bb) && !s.isAfter(bs)) return true;
    }
    return false;
  }

  static (DateTime, DateTime) _aralik(TEtkinlik e) {
    if (e.tumGun) {
      final b = gunBasi(e.baslangic);
      var s = gunBasi(e.bitis);
      if (!s.isAfter(b)) s = sonrakiGun(b);
      return (b, s);
    }
    final s = e.bitis.isAfter(e.baslangic) ? e.bitis : e.baslangic.add(const Duration(minutes: 1));
    return (e.baslangic, s);
  }

  static DateTime _yukariYuvarla(DateTime t, int adimDk) {
    final gunDk = t.hour * 60 + t.minute + (t.second > 0 || t.millisecond > 0 ? 1 : 0);
    final yuvarlak = ((gunDk + adimDk - 1) ~/ adimDk) * adimDk;
    return gunBasi(t).add(Duration(minutes: yuvarlak));
  }
}
