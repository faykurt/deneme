import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Ana sayfanın karşılama selamı: saate göre, her açılışta farklı. Bazen imza selamı çıkar.
class Selam {
  Selam._();
  static final Selam instance = Selam._();

  static const imza = 'Tam da aklımdaydın.';

  static const sabah = ['Günaydın, güneş böreğim.', 'Günaydın, kahve kuşum.', 'Selam, ballı kruvasanım.'];
  static const ogle = ['Selam, öğlen şekerim.', 'Merhaba, limonlu kekim.', 'Selam, çilekli tartım.'];
  static const aksamustu = ['Selam, çay kurabiyem.', 'Hoş geldin, tarçınlı çöreğim.', 'Selam, akşam çayım.'];
  static const aksam = ['Selam, battaniye rulom.', 'Hoş geldin, sıcak çikolatam.', 'Selam, akşam çayı yanı kurabiyesi.'];
  static const gece = ['Selam, ay çöreğim.', 'Hoş geldin, gece kurabiyem.', 'Selam, yıldız şekerim.'];

  /// Saat dilimleri: sabah 05:00-10:59, öğle 11:00-14:59, akşamüstü 15:00-17:59, akşam 18:00-21:59, gece 22:00-04:59.
  static List<String> liste(DateTime t) {
    final s = t.hour;
    if (s >= 5 && s < 11) return sabah;
    if (s >= 11 && s < 15) return ogle;
    if (s >= 15 && s < 18) return aksamustu;
    if (s >= 18 && s < 22) return aksam;
    return gece;
  }

  static const _sayacAnahtari = 'selam_sayac';
  static const _esikAnahtari = 'selam_esik';
  static const _sonAnahtari = 'selam_son';

  Random _rastgele = Random();
  int _sayac = 0;
  int _esik = 5;
  String? _son;
  String? _bu;
  String? _buListe;

  /// Testlerde sabit rastgelelik için.
  void tohumla(Random r) => _rastgele = r;

  int _yeniEsik() => 4 + _rastgele.nextInt(3); // 4, 5 ya da 6

  Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      _sayac = p.getInt(_sayacAnahtari) ?? 0;
      _esik = p.getInt(_esikAnahtari) ?? _yeniEsik();
      _son = p.getString(_sonAnahtari);
    } catch (_) {
      _esik = _yeniEsik();
    }
  }

  Future<void> _yaz() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_sayacAnahtari, _sayac);
      await p.setInt(_esikAnahtari, _esik);
      if (_son != null) await p.setString(_sonAnahtari, _son!);
    } catch (_) {}
  }

  /// Yeni bir uygulama açılışı: sayaç artar, selam seçilir (art arda aynısı gelmez).
  Future<String> acilis(DateTime t) async {
    _sayac++;
    String secim;
    if (_sayac >= _esik) {
      secim = imza;
      _sayac = 0;
      _esik = _yeniEsik();
    } else {
      secim = _sec(t);
    }
    _bu = secim;
    _buListe = _listeAnahtari(t);
    _son = secim;
    await _yaz();
    return secim;
  }

  String _listeAnahtari(DateTime t) => liste(t).first;

  String _sec(DateTime t) {
    final l = liste(t);
    final adaylar = l.where((e) => e != _son).toList();
    return adaylar[_rastgele.nextInt(adaylar.length)];
  }

  /// Ekranda gösterilen selam. Açılıştan sonra saat dilimi değiştiyse (imza değilse) yeni dilimden seçilir.
  String simdi(DateTime t) {
    if (_bu == null) return liste(t).first;
    if (_bu != imza && _buListe != _listeAnahtari(t)) {
      _bu = _sec(t);
      _buListe = _listeAnahtari(t);
      _son = _bu;
    }
    return _bu!;
  }
}
