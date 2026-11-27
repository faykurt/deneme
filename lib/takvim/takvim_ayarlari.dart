import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'takvim_modeller.dart';

/// Uyku aralığı, günün dakikası olarak (0-1439). Başlangıç bitişten büyükse gece yarısını aşar (23:00-07:00).
class UykuAraligi {
  final int baslangicDk;
  final int bitisDk;
  const UykuAraligi(this.baslangicDk, this.bitisDk);

  bool get geceyiAsar => baslangicDk > bitisDk;

  static String saat(int dk) =>
      '${(dk ~/ 60).toString().padLeft(2, '0')}:${(dk % 60).toString().padLeft(2, '0')}';

  @override
  String toString() => '${saat(baslangicDk)} - ${saat(bitisDk)}';

  @override
  bool operator ==(Object other) =>
      other is UykuAraligi && other.baslangicDk == baslangicDk && other.bitisDk == bitisDk;
  @override
  int get hashCode => Object.hash(baslangicDk, bitisDk);
}

/// Zaman kuralları: boş zaman hesabı için gereken, kullanıcının tanımladığı bilgiler.
class ZamanKurallari {
  final UykuAraligi? uykuHaftaIci;
  final UykuAraligi? uykuHaftaSonu;
  final Set<String> izinGunleri;
  final String isKelimesi;

  const ZamanKurallari({
    this.uykuHaftaIci,
    this.uykuHaftaSonu,
    this.izinGunleri = const {},
    this.isKelimesi = 'İş',
  });

  bool get uykuTanimli => uykuHaftaIci != null && uykuHaftaSonu != null;

  /// Hafta sonu ya da kullanıcının izin günü olarak işaretlediği gün.
  bool haftaSonuGibi(DateTime gun) =>
      gun.weekday >= DateTime.saturday || izinGunleri.contains(gunAnahtari(gun));

  UykuAraligi? _uykuTuru(DateTime gun) => haftaSonuGibi(gun) ? uykuHaftaSonu : uykuHaftaIci;

  /// [bas, bit) aralığına değen uyku aralıkları. Gecenin gece yarısını aşan kısmı doğru gün ayarıyla birleştirilir:
  /// yatış o günün türüne, kalkış kalkılan günün türüne göre belirlenir.
  List<(DateTime, DateTime)> uykular(DateTime bas, DateTime bit) {
    if (!uykuTanimli) return const [];
    final sonuc = <(DateTime, DateTime)>[];
    for (var g = gunBasi(bas).subtract(const Duration(days: 1)); g.isBefore(bit); g = sonrakiGun(g)) {
      final u = _uykuTuru(g)!;
      final yatis = DateTime(g.year, g.month, g.day, u.baslangicDk ~/ 60, u.baslangicDk % 60);
      DateTime kalkis;
      if (u.geceyiAsar) {
        final yarin = sonrakiGun(g);
        final k = _uykuTuru(yarin)!;
        kalkis = DateTime(yarin.year, yarin.month, yarin.day, k.bitisDk ~/ 60, k.bitisDk % 60);
      } else {
        kalkis = DateTime(g.year, g.month, g.day, u.bitisDk ~/ 60, u.bitisDk % 60);
      }
      if (kalkis.isAfter(bas) && yatis.isBefore(bit)) sonuc.add((yatis, kalkis));
    }
    return sonuc;
  }
}

/// Takvim ve zaman ayarlarının telefonda saklandığı yer.
class TakvimAyarlari extends ChangeNotifier {
  TakvimAyarlari._();
  static final TakvimAyarlari instance = TakvimAyarlari._();

  SharedPreferences? _p;
  String? takvimId;

  /// Aklımda'da görünen takvimler (telefondaki bütün hesaplardan). null: gizli olmayan hepsi.
  Set<String>? gorunenTakvimler;
  String? takvimAdi;
  UykuAraligi? uykuHaftaIci;
  UykuAraligi? uykuHaftaSonu;
  String isKelimesi = 'İş';
  Set<String> izinGunleri = {};

  ZamanKurallari get kurallar => ZamanKurallari(
        uykuHaftaIci: uykuHaftaIci,
        uykuHaftaSonu: uykuHaftaSonu,
        izinGunleri: izinGunleri,
        isKelimesi: isKelimesi,
      );

  Future<void> yukle() async {
    try {
      final p = _p = await SharedPreferences.getInstance();
      takvimId = p.getString('takvim_id');
      gorunenTakvimler = p.getStringList('gorunen_takvimler')?.toSet();
      takvimAdi = p.getString('takvim_adi');
      uykuHaftaIci = _oku(p, 'uyku_hafta_ici');
      uykuHaftaSonu = _oku(p, 'uyku_hafta_sonu');
      isKelimesi = p.getString('is_kelimesi') ?? 'İş';
      izinGunleri = (p.getStringList('izin_gunleri') ?? []).toSet();
    } catch (_) {
      // Ayarlar okunamazsa varsayılanlarla devam edilir.
    }
    notifyListeners();
  }

  UykuAraligi? _oku(SharedPreferences p, String anahtar) {
    final v = p.getStringList(anahtar);
    if (v == null || v.length != 2) return null;
    final a = int.tryParse(v[0]);
    final b = int.tryParse(v[1]);
    return a == null || b == null ? null : UykuAraligi(a, b);
  }

  Future<void> takvimSec(String id, String ad) async {
    takvimId = id;
    takvimAdi = ad;
    await _p?.setString('takvim_id', id);
    await _p?.setString('takvim_adi', ad);
    notifyListeners();
  }

  Future<void> gorunenAyarla(Set<String>? ids) async {
    gorunenTakvimler = ids;
    if (ids == null) {
      await _p?.remove('gorunen_takvimler');
    } else {
      await _p?.setStringList('gorunen_takvimler', ids.toList()..sort());
    }
    notifyListeners();
  }

  Future<void> takvimiSifirla() async {
    takvimId = null;
    takvimAdi = null;
    await _p?.remove('takvim_id');
    await _p?.remove('takvim_adi');
    notifyListeners();
  }

  Future<void> uykuAyarla({UykuAraligi? haftaIci, UykuAraligi? haftaSonu}) async {
    if (haftaIci != null) {
      uykuHaftaIci = haftaIci;
      await _p?.setStringList('uyku_hafta_ici', ['${haftaIci.baslangicDk}', '${haftaIci.bitisDk}']);
    }
    if (haftaSonu != null) {
      uykuHaftaSonu = haftaSonu;
      await _p?.setStringList('uyku_hafta_sonu', ['${haftaSonu.baslangicDk}', '${haftaSonu.bitisDk}']);
    }
    notifyListeners();
  }

  Future<void> isKelimesiAyarla(String kelime) async {
    isKelimesi = kelime.trim().isEmpty ? 'İş' : kelime.trim();
    await _p?.setString('is_kelimesi', isKelimesi);
    notifyListeners();
  }

  Future<void> izinGunuEkle(DateTime gun) async {
    izinGunleri = {...izinGunleri, gunAnahtari(gun)};
    await _p?.setStringList('izin_gunleri', izinGunleri.toList()..sort());
    notifyListeners();
  }

  Future<void> izinGunuKaldir(String anahtar) async {
    izinGunleri = {...izinGunleri}..remove(anahtar);
    await _p?.setStringList('izin_gunleri', izinGunleri.toList()..sort());
    notifyListeners();
  }
}
