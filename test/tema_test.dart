import 'package:aklimda/ekranlar/piksel_sahne.dart';
import 'package:aklimda/ekranlar/sahne_arka_plan.dart';
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

  test('Tema varsayılan açık (krem); seçim kaydedilir ve renkler değişir', () async {
    SharedPreferences.setMockInitialValues({});
    await TemaAyari.instance.yukle();
    expect(TemaAyari.instance.koyu, isFalse);
    final acikZemin = Renk.zemin;
    await TemaAyari.instance.ayarla(true);
    expect(Renk.koyu, isTrue);
    expect(Renk.zemin, isNot(acikZemin));
    await TemaAyari.instance.ayarla(false);
    expect(Renk.koyu, isFalse);
    SharedPreferences.setMockInitialValues({'tema_koyu': true});
    await TemaAyari.instance.yukle();
    expect(TemaAyari.instance.koyu, isTrue); // kaydedilen seçim geri yüklenir
  });

  test('Arka plan ışığı: gün 06-16, akşamüstü 16-19, gece 19-06', () {
    SahneIsigi i(int s) => SahneIsigi.simdi(DateTime(2026, 11, 25, s));
    expect(i(5), SahneIsigi.gece);
    expect(i(6), SahneIsigi.gun);
    expect(i(15), SahneIsigi.gun);
    expect(i(16), SahneIsigi.aksamUstu);
    expect(i(18), SahneIsigi.aksamUstu);
    expect(i(19), SahneIsigi.gece);
  });
}
