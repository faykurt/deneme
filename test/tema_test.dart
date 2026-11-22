import 'package:aklimda/ekranlar/piksel_sahne.dart';
import 'package:aklimda/ortak.dart';
import 'package:aklimda/tema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Gün bölümü sınırları: sabah 06-11, öğle 11-17, akşam 17-06', () {
    SahneBolumu b(int s) => SahneBolumu.simdi(DateTime(2026, 11, 22, s));
    expect(b(5), SahneBolumu.aksam);
    expect(b(6), SahneBolumu.sabah);
    expect(b(10), SahneBolumu.sabah);
    expect(b(11), SahneBolumu.ogle);
    expect(b(16), SahneBolumu.ogle);
    expect(b(17), SahneBolumu.aksam);
    expect(b(23), SahneBolumu.aksam);
  });

  test('Tema varsayılan koyu; seçim kaydedilir ve renkler değişir', () async {
    SharedPreferences.setMockInitialValues({});
    await TemaAyari.instance.yukle();
    expect(TemaAyari.instance.koyu, isTrue);
    final koyuZemin = Renk.zemin;
    await TemaAyari.instance.ayarla(false);
    expect(Renk.koyu, isFalse);
    expect(Renk.zemin, isNot(koyuZemin));
    SharedPreferences.setMockInitialValues({'tema_koyu': false});
    await TemaAyari.instance.ayarla(true); // önce koyuya al
    await TemaAyari.instance.yukle();
    expect(TemaAyari.instance.koyu, isTrue);
  });
}
