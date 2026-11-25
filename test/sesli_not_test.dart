import 'package:aklimda/ekranlar/sesli_not.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Sessizlikte gelen boş nihai sonuç, bekleyen konuşmayı silmez', () {
    final m = SesMetni();
    m.sonuc('merhaba bugün market', nihai: false);
    m.sonuc('', nihai: true); // servis sessizlikte boş nihai sonuç gönderir
    expect(m.tum, 'merhaba bugün market');
    m.sonuc('sonra eve', nihai: false);
    m.sonuc('sonra eve gidecegim', nihai: false);
    m.durdu();
    expect(m.tum, 'merhaba bugün market sonra eve gidecegim');
  });

  test('Durma sonrası gelen aynı nihai sonuç metni ikiye katlamaz', () {
    final m = SesMetni();
    m.sonuc('bir iki', nihai: false);
    m.durdu();
    m.sonuc('bir iki', nihai: true);
    expect(m.tum, 'bir iki');
  });

  test('Yeni oturumun boş kısmı eski parçayı ezmez', () {
    final m = SesMetni();
    m.sonuc('eski konuşma', nihai: false);
    m.sonuc('', nihai: false);
    expect(m.tum, 'eski konuşma');
  });
}
