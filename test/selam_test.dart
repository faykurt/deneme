import 'dart:math';

import 'package:aklimda/selam.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Saat dilimleri: sabah 05-11, öğle 11-15, akşamüstü 15-18, akşam 18-22, gece 22-05', () {
    List<String> l(int s) => Selam.liste(DateTime(2026, 11, 25, s));
    expect(l(5), Selam.sabah);
    expect(l(10), Selam.sabah);
    expect(l(11), Selam.ogle);
    expect(l(14), Selam.ogle);
    expect(l(15), Selam.aksamustu);
    expect(l(17), Selam.aksamustu);
    expect(l(18), Selam.aksam);
    expect(l(21), Selam.aksam);
    expect(l(22), Selam.gece);
    expect(l(4), Selam.gece);
  });

  test('Her açılışta farklı selam gelir, art arda aynısı gelmez; imza 4-6 açılışta bir çıkar', () async {
    SharedPreferences.setMockInitialValues({});
    final s = Selam.instance..tohumla(Random(3));
    await s.yukle();
    final t = DateTime(2026, 11, 25, 20);
    String? onceki;
    var imzaAcilislari = <int>[];
    var sonImza = 0;
    for (var i = 1; i <= 60; i++) {
      final g = await s.acilis(t);
      if (g == Selam.imza) {
        imzaAcilislari.add(i - sonImza);
        sonImza = i;
      } else {
        expect(Selam.aksam, contains(g));
      }
      expect(g == onceki && g != Selam.imza, isFalse, reason: 'Art arda aynı selam: $g');
      onceki = g;
    }
    expect(imzaAcilislari, isNotEmpty);
    for (final aralik in imzaAcilislari) {
      expect(aralik, inInclusiveRange(4, 6));
    }
    expect(imzaAcilislari.toSet().length, greaterThan(1)); // sayı değişiyor (hep aynı değil)
  });

  test('Açılıştan sonra saat dilimi değişirse yeni dilimden selam gelir, imza değişmez', () async {
    SharedPreferences.setMockInitialValues({});
    final s = Selam.instance..tohumla(Random(1));
    await s.yukle();
    final g = await s.acilis(DateTime(2026, 11, 25, 9));
    if (g != Selam.imza) {
      expect(Selam.sabah, contains(s.simdi(DateTime(2026, 11, 25, 9, 30))));
      expect(Selam.ogle, contains(s.simdi(DateTime(2026, 11, 25, 12))));
    }
  });
}
