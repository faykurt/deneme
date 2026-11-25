import 'dart:ui' show Color;

/// Uygulamanın takvime yazdığı etkinliklerin başındaki işaret.
const uygulamaIsareti = '💭';

enum TekrarTuru { yok, gunluk, haftaIci, haftalik, aylik, yillik, ozel }

extension TekrarTuruAd on TekrarTuru {
  String get ad => switch (this) {
        TekrarTuru.yok => 'Tekrar yok',
        TekrarTuru.gunluk => 'Her gün',
        TekrarTuru.haftaIci => 'Hafta içi her gün',
        TekrarTuru.haftalik => 'Her hafta',
        TekrarTuru.aylik => 'Her ay',
        TekrarTuru.yillik => 'Her yıl',
        TekrarTuru.ozel => 'Özel tekrar',
      };
}

/// Etkinlik silerken ya da değiştirirken tekrarlı etkinliklerde kapsam.
enum Kapsam { sadeceBu, buVeSonrakiler, hepsi }

DateTime gunBasi(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime sonrakiGun(DateTime d) => DateTime(d.year, d.month, d.day + 1);
String gunAnahtari(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class TakvimBilgi {
  final String id;
  final String ad;
  final String? hesap;
  final String? hesapTuru;
  final bool saltOkunur;
  final bool gizli;
  final Color? renk;

  const TakvimBilgi({
    required this.id,
    required this.ad,
    this.hesap,
    this.hesapTuru,
    this.saltOkunur = false,
    this.gizli = false,
    this.renk,
  });
}

/// Takvimdeki bir etkinlik (tekrarlı etkinliklerin her tekrarı ayrı bir nesnedir).
class TEtkinlik {
  final String instanceId;
  final String eventId;
  final String takvimId;
  final String baslik;
  final DateTime baslangic;
  final DateTime bitis; // tüm gün etkinliklerde bitiş günü dahil değildir (ertesi gün 00:00)
  final bool tumGun;
  final bool meshgul;
  final bool tekrarli;
  final TekrarTuru tekrar;
  final DateTime? tekrarBitis;
  final String? aciklama;
  final Color? renk;

  const TEtkinlik({
    required this.instanceId,
    required this.eventId,
    required this.takvimId,
    required this.baslik,
    required this.baslangic,
    required this.bitis,
    this.tumGun = false,
    this.meshgul = true,
    this.tekrarli = false,
    this.tekrar = TekrarTuru.yok,
    this.tekrarBitis,
    this.aciklama,
    this.renk,
  });

  bool get uygulamaninMi => baslik.startsWith(uygulamaIsareti);

  /// Aynı etkinlik, verilen (etkinliğe özel) renkle.
  TEtkinlik renkli(Color? yeni) => TEtkinlik(
        instanceId: instanceId,
        eventId: eventId,
        takvimId: takvimId,
        baslik: baslik,
        baslangic: baslangic,
        bitis: bitis,
        tumGun: tumGun,
        meshgul: meshgul,
        tekrarli: tekrarli,
        tekrar: tekrar,
        tekrarBitis: tekrarBitis,
        aciklama: aciklama,
        renk: yeni,
      );

  /// Etkinlik verilen günün herhangi bir kısmını kapsıyor mu?
  bool gunuKapsar(DateTime gun) {
    final g = gunBasi(gun);
    final ertesi = sonrakiGun(g);
    if (tumGun) {
      final bas = gunBasi(baslangic);
      var son = gunBasi(bitis);
      if (!son.isAfter(bas)) son = sonrakiGun(bas);
      return !g.isBefore(bas) && g.isBefore(son);
    }
    if (bitis.isAfter(baslangic)) return baslangic.isBefore(ertesi) && bitis.isAfter(g);
    return !baslangic.isBefore(g) && baslangic.isBefore(ertesi);
  }

  /// Çok günlü bir etkinliğin hangi gün aralığını kapsadığı (bitiş dahil değil).
  DateTime get ilkGun => gunBasi(baslangic);
}

/// Yeni etkinlik ya da değişiklik için taslak.
class TEtkinlikTaslagi {
  String? takvimId;
  String baslik;
  DateTime baslangic;
  DateTime bitis;
  bool tumGun;
  bool meshgul;
  TekrarTuru tekrar;
  DateTime? tekrarBitis;
  String? aciklama;

  /// Etkinliğe özel renk ve değişip değişmediği (null + değişti = rengi kaldır).
  Color? renk;
  bool renkDegisti;

  TEtkinlikTaslagi({
    this.takvimId,
    required this.baslik,
    required this.baslangic,
    required this.bitis,
    this.tumGun = false,
    this.meshgul = true,
    this.tekrar = TekrarTuru.yok,
    this.tekrarBitis,
    this.aciklama,
    this.renk,
    this.renkDegisti = false,
  });

  factory TEtkinlikTaslagi.dan(TEtkinlik e) => TEtkinlikTaslagi(
        takvimId: e.takvimId,
        baslik: e.baslik,
        baslangic: e.baslangic,
        bitis: e.bitis,
        tumGun: e.tumGun,
        meshgul: e.meshgul,
        tekrar: e.tekrar,
        tekrarBitis: e.tekrarBitis,
        aciklama: e.aciklama,
        renk: e.renk,
      );
}
