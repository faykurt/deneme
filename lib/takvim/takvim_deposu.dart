import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'bos_zaman.dart';
import 'takvim_ayarlari.dart';
import 'takvim_kaynagi.dart';
import 'takvim_modeller.dart';

/// Takvim ekranının ve notlarla takvimin bağlantısının merkezi.
class TakvimDeposu extends ChangeNotifier {
  TakvimDeposu(this.kaynak, this.ayarlar);

  /// Uygulamadaki tek örnek. Testlerde sahte kaynakla değiştirilir.
  static TakvimDeposu instance = TakvimDeposu(CihazTakvimi(), TakvimAyarlari.instance);

  final TakvimKaynagi kaynak;
  final TakvimAyarlari ayarlar;

  bool izinVar = false;
  bool izinSorgulandi = false;
  List<TakvimBilgi> takvimler = [];
  List<TEtkinlik> etkinlikler = [];
  DateTime? _bas;
  DateTime? _bit;
  String? hata;

  bool get yuklendi => _bas != null;
  bool get takvimSecili => ayarlar.takvimId != null;
  bool get hazir => izinVar && takvimSecili;

  List<String>? get _secili => ayarlar.takvimId == null ? null : [ayarlar.takvimId!];

  Future<void> baslat() async {
    try {
      izinVar = await kaynak.izinVar();
    } catch (_) {
      izinVar = false;
    }
    izinSorgulandi = true;
    if (izinVar) await takvimleriYukle();
    notifyListeners();
  }

  Future<bool> izinIste() async {
    try {
      izinVar = await kaynak.izinIste();
    } catch (_) {
      izinVar = false;
    }
    izinSorgulandi = true;
    if (izinVar) await takvimleriYukle();
    notifyListeners();
    return izinVar;
  }

  Future<void> takvimleriYukle() async {
    try {
      takvimler = (await kaynak.takvimler()).where((t) => !t.gizli).toList();
      hata = null;
      // Seçili takvim artık yoksa seçimi sıfırla
      if (ayarlar.takvimId != null && !takvimler.any((t) => t.id == ayarlar.takvimId)) {
        await ayarlar.takvimiSifirla();
      }
    } on TakvimHatasi catch (e) {
      hata = e.mesaj;
      if (e.izinYok) izinVar = false;
    }
    notifyListeners();
  }

  /// Her takvimde son/gelecek 3 ayda kaç etkinlik olduğu (takvim seçerken gösterilir).
  Future<Map<String, int>> etkinlikSayilari() async {
    final simdi = DateTime.now();
    final sonuc = <String, int>{};
    try {
      final liste = await kaynak.etkinlikler(
          simdi.subtract(const Duration(days: 90)), simdi.add(const Duration(days: 90)));
      for (final e in liste) {
        sonuc[e.takvimId] = (sonuc[e.takvimId] ?? 0) + 1;
      }
    } on TakvimHatasi catch (_) {}
    return sonuc;
  }

  Future<void> takvimSec(TakvimBilgi t) async {
    await ayarlar.takvimSec(t.id, t.ad);
    etkinlikler = [];
    _bas = _bit = null;
    notifyListeners();
  }

  /// [bas, bit) aralığındaki etkinlikleri yükler. Aynı aralık yeniden istenirse (zorla değilse) atlanır.
  Future<void> yukle(DateTime bas, DateTime bit, {bool zorla = false}) async {
    if (!hazir) return;
    if (!zorla && _bas != null && _bit != null && !bas.isBefore(_bas!) && !bit.isAfter(_bit!)) return;
    try {
      etkinlikler = await kaynak.etkinlikler(bas, bit, takvimIdler: _secili);
      _bas = bas;
      _bit = bit;
      hata = null;
    } on TakvimHatasi catch (e) {
      hata = e.mesaj;
    }
    notifyListeners();
  }

  Future<void> yenile() async {
    if (_bas != null && _bit != null) await yukle(_bas!, _bit!, zorla: true);
  }

  /// Etkinliğin rengi: kendi rengi yoksa takviminin rengi.
  Color? renkOf(TEtkinlik e) {
    if (e.renk != null) return e.renk;
    for (final t in takvimler) {
      if (t.id == e.takvimId) return t.renk;
    }
    return null;
  }

  List<TEtkinlik> gununEtkinlikleri(DateTime gun) {
    final l = etkinlikler.where((e) => e.gunuKapsar(gun)).toList();
    l.sort((a, b) {
      if (a.tumGun != b.tumGun) return a.tumGun ? -1 : 1;
      return a.baslangic.compareTo(b.baslangic);
    });
    return l;
  }

  // ---- Yazma işlemleri (hata olursa TakvimHatasi fırlatır)

  Future<String> ekle(TEtkinlikTaslagi t) async {
    t.takvimId ??= ayarlar.takvimId;
    final id = await kaynak.ekle(t);
    await yenile();
    return id;
  }

  Future<void> guncelle(TEtkinlik eski, TEtkinlikTaslagi yeni, Kapsam kapsam) async {
    yeni.takvimId ??= eski.takvimId;
    await kaynak.guncelle(eski, yeni, kapsam);
    await yenile();
    await notlariSenkronla();
  }

  Future<void> sil(TEtkinlik e, Kapsam kapsam) async {
    await kaynak.sil(e, kapsam);
    await yenile();
    await notlariSenkronla();
  }

  /// Kimliğine göre etkinliği (silinmişse null) getirir.
  Future<TEtkinlik?> getir(String id) async {
    try {
      return await kaynak.getir(id);
    } on TakvimHatasi catch (_) {
      return null;
    }
  }

  /// Bir notu takvime bağlar (not ↔ etkinlik).
  Future<void> notuBagla(Not not, String etkinlikId, DateTime bas, DateTime bit) async {
    not.takvimEtkinlikId = etkinlikId;
    not.takvimBaslangic = bas.millisecondsSinceEpoch;
    not.takvimBitis = bit.millisecondsSinceEpoch;
    not.yaptinCevap = false;
    await Depo.instance.notGuncelle(not, dokunma: false);
  }

  Future<void> baglantiyiKaldir(Not not) async {
    not.takvimEtkinlikId = null;
    not.takvimBaslangic = null;
    not.takvimBitis = null;
    not.yaptinCevap = false;
    await Depo.instance.notGuncelle(not, dokunma: false);
  }

  /// Takvime bağlı notları takvimdeki gerçek duruma getirir: etkinlik silinmişse bağlantı kalkar, saat değişmişse güncellenir.
  Future<void> notlariSenkronla() async {
    if (!izinVar) return;
    final depo = Depo.instance;
    for (final n in List.of(depo.notlar.where((n) => n.takvimEtkinlikId != null))) {
      try {
        final e = await kaynak.getir(n.takvimEtkinlikId!);
        if (e == null) {
          await baglantiyiKaldir(n);
        } else if (e.baslangic.millisecondsSinceEpoch != n.takvimBaslangic ||
            e.bitis.millisecondsSinceEpoch != n.takvimBitis) {
          n.takvimBaslangic = e.baslangic.millisecondsSinceEpoch;
          n.takvimBitis = e.bitis.millisecondsSinceEpoch;
          n.yaptinCevap = false;
          await depo.notGuncelle(n, dokunma: false);
        }
      } on TakvimHatasi catch (_) {
        // Okunamadıysa dokunma, bir sonraki senkronda tekrar denenir.
      }
    }
  }

  /// Bir not için takvimde uygun boş zamanı bulur (hiç yoksa null).
  Future<DateTime?> bosZamanBul({
    required int sureDk,
    required bool isNotu,
    DateTime? simdi,
  }) async {
    final s = simdi ?? DateTime.now();
    final gun = gunBasi(s);
    final liste = await kaynak.etkinlikler(gun, gun.add(const Duration(days: 16)), takvimIdler: _secili);
    return BosZamanBulucu.bul(
      simdi: s,
      sureDk: sureDk,
      isNotu: isNotu,
      etkinlikler: liste,
      kurallar: ayarlar.kurallar,
    );
  }
}
