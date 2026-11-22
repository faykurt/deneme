import 'package:aklimda/takvim/takvim_kaynagi.dart';
import 'package:aklimda/takvim/takvim_modeller.dart';

/// Testlerde telefon takvimi yerine kullanılan bellek içi sahte takvim.
class SahteTakvim implements TakvimKaynagi {
  bool izin;
  bool izinVerilir;
  bool hataFirlat = false;
  List<TakvimBilgi> cals;
  List<TEtkinlik> ev;
  int _n = 0;
  final List<String> gunluk = [];

  SahteTakvim({this.izin = false, this.izinVerilir = true, List<TakvimBilgi>? takvimler, List<TEtkinlik>? etkinlikler})
      : cals = takvimler ??
            const [
              TakvimBilgi(id: 'sam', ad: 'Samsung takvimim', hesap: 'ben@samsung'),
              TakvimBilgi(id: 'goog', ad: 'Google', hesap: 'ben@gmail.com'),
              TakvimBilgi(id: 'tatil', ad: 'Türkiye tatilleri', saltOkunur: true),
            ],
        ev = etkinlikler ?? [];

  void _kontrol() {
    if (hataFirlat) throw const TakvimHatasi('Sahte hata');
  }

  @override
  Future<bool> izinVar() async => izin;

  @override
  Future<bool> izinIste() async {
    gunluk.add('izinIste');
    if (izinVerilir) izin = true;
    return izin;
  }

  @override
  Future<List<TakvimBilgi>> takvimler() async {
    _kontrol();
    return cals;
  }

  @override
  Future<List<TEtkinlik>> etkinlikler(DateTime bas, DateTime bit, {List<String>? takvimIdler}) async {
    _kontrol();
    final l = ev.where((e) {
      if (takvimIdler != null && takvimIdler.isNotEmpty && !takvimIdler.contains(e.takvimId)) return false;
      return e.baslangic.isBefore(bit) && (e.bitis.isAfter(bas) || e.baslangic == e.bitis && !e.baslangic.isBefore(bas));
    }).toList();
    l.sort((a, b) => a.baslangic.compareTo(b.baslangic));
    return l;
  }

  @override
  Future<TEtkinlik?> getir(String id) async {
    _kontrol();
    final eventId = id.split('@').first;
    for (final e in ev) {
      if (e.eventId == eventId) return e;
    }
    return null;
  }

  @override
  Future<String> ekle(TEtkinlikTaslagi t) async {
    _kontrol();
    final id = 'ev${++_n}';
    gunluk.add('ekle:${t.baslik}');
    ev.add(_yap(id, t, tekrarli: t.tekrar != TekrarTuru.yok));
    return id;
  }

  TEtkinlik _yap(String id, TEtkinlikTaslagi t, {required bool tekrarli}) => TEtkinlik(
        instanceId: id,
        eventId: id,
        takvimId: t.takvimId ?? 'sam',
        baslik: t.baslik,
        baslangic: t.baslangic,
        bitis: t.bitis,
        tumGun: t.tumGun,
        meshgul: t.meshgul,
        tekrarli: tekrarli,
        tekrar: t.tekrar,
        tekrarBitis: t.tekrarBitis,
        aciklama: t.aciklama,
      );

  @override
  Future<void> guncelle(TEtkinlik eski, TEtkinlikTaslagi yeni, Kapsam kapsam) async {
    _kontrol();
    gunluk.add('guncelle:${kapsam.name}:${yeni.baslik}');
    final i = ev.indexWhere((e) => e.eventId == eski.eventId);
    if (i < 0) throw const TakvimHatasi('Etkinlik takvimde bulunamadı, silinmiş olabilir.');
    ev[i] = _yap(eski.eventId, yeni, tekrarli: yeni.tekrar != TekrarTuru.yok);
  }

  @override
  Future<void> sil(TEtkinlik e, Kapsam kapsam) async {
    _kontrol();
    gunluk.add('sil:${kapsam.name}:${e.baslik}');
    ev.removeWhere((x) => x.eventId == e.eventId);
  }

  /// Telefonun takviminde, uygulamanın dışında yapılan bir değişikliği taklit eder.
  void disaridanTasi(String eventId, DateTime bas, DateTime bit) {
    final i = ev.indexWhere((e) => e.eventId == eventId);
    final e = ev[i];
    ev[i] = TEtkinlik(
      instanceId: e.instanceId,
      eventId: e.eventId,
      takvimId: e.takvimId,
      baslik: e.baslik,
      baslangic: bas,
      bitis: bit,
      tumGun: e.tumGun,
      meshgul: e.meshgul,
    );
  }

  void disaridanSil(String eventId) => ev.removeWhere((e) => e.eventId == eventId);
}

TEtkinlik etk(String id, String baslik, DateTime b, DateTime s,
        {String takvim = 'sam', bool tumGun = false, bool meshgul = true, bool tekrarli = false}) =>
    TEtkinlik(
      instanceId: id,
      eventId: id,
      takvimId: takvim,
      baslik: baslik,
      baslangic: b,
      bitis: s,
      tumGun: tumGun,
      meshgul: meshgul,
      tekrarli: tekrarli,
      tekrar: tekrarli ? TekrarTuru.haftalik : TekrarTuru.yok,
    );
