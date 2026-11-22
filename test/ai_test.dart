import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:aklimda/ai/ai_modeller.dart';
import 'package:aklimda/ai/ai_servisi.dart';
import 'package:aklimda/veri/modeller.dart';

Map<String, dynamic> _fikir({String baslik = 'Salona tablo asmak', bool yapilabilir = true}) => {
      'metin': 'Salona tablo asacağım',
      'baslik': baslik,
      'kategori_idler': [3],
      'yeni_kategori_ad': '',
      'yeni_kategori_ust_id': 0,
      'sure_dk': 45,
      'tarih': '2026-12-19',
      'tarih_saatli': false,
      'yapilabilir_is': yapilabilir,
      'adimlar': [
        {'metin': 'Duvarın ölçüsünü al', 'sure_dk': 5, 'bekleme': false},
        {'metin': 'Tabloyu sipariş ver', 'sure_dk': 10, 'bekleme': false},
        {'metin': 'Kargonun gelmesini bekle', 'sure_dk': 0, 'bekleme': true},
      ],
    };

http.Response _yanit(Map<String, dynamic> govde, [int kod = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(govde)), kod, headers: {'content-type': 'application/json'});

Map<String, dynamic> _basarili(List<Map<String, dynamic>> fikirler) => {
      'stop_reason': 'end_turn',
      'content': [
        {'type': 'thinking', 'thinking': ''},
        {'type': 'text', 'text': jsonEncode({'fikirler': fikirler})},
      ],
    };

final _agac = KategoriAgaci([
  Kategori(id: 1, ad: 'Ev'),
  Kategori(id: 3, ad: 'Dekorasyon', ustId: 1),
]);

Not _not([String metin = 'Salona tablo asacağım']) => Not(
    id: 'a', metin: metin, kaynak: Kaynak.sesli, olusturma: 0, guncelleme: 0, sonDokunma: 0);

Future<AiSonuc> _isle() =>
    AiServisi.notuIsle(apiKey: 'sk-ant-test', not: _not(), agac: _agac, resimlerBase64: const []);

void main() {
  setUpAll(() => initializeDateFormatting('tr'));
  tearDown(() => AiServisi.istemciUret = http.Client.new);

  test('İstek doğru biçimde hazırlanır ve cevap okunur', () async {
    late http.Request alinan;
    AiServisi.istemciUret = () => MockClient((r) async {
          alinan = r;
          return _yanit(_basarili([_fikir()]));
        });
    final sonuc = await _isle();

    expect(alinan.headers['x-api-key'], 'sk-ant-test');
    expect(alinan.headers['anthropic-version'], '2026-10-21');
    final g = jsonDecode(alinan.body) as Map<String, dynamic>;
    expect(g['model'], 'claude-sonnet-5-5');
    expect(g['output_config']['effort'], 'medium');
    expect(g['output_config']['format']['type'], 'json_schema');
    expect(g.containsKey('temperature'), isFalse);
    expect(g.containsKey('thinking'), isFalse);
    final icerik = (g['messages'][0]['content'] as List).last['text'] as String;
    expect(icerik, contains('Salona tablo asacağım'));
    expect(icerik, contains('3: Ev › Dekorasyon'));

    expect(sonuc.fikirler, hasLength(1));
    final f = sonuc.fikirler.first;
    expect(f.baslik, 'Salona tablo asmak');
    expect(f.kategoriIdler, [3]);
    expect(f.sureDk, 45);
    expect(f.adimlar, hasLength(3));
    expect(f.adimlar.last.bekleme, isTrue);
    expect(f.tarihDt, DateTime(2026, 12, 19));
    expect(f.saatVar, isFalse);
  });

  test('Şema her nesnede additionalProperties:false ve tüm alanları zorunlu kılar', () async {
    late Map<String, dynamic> govde;
    AiServisi.istemciUret = () => MockClient((r) async {
          govde = jsonDecode(r.body) as Map<String, dynamic>;
          return _yanit(_basarili([_fikir()]));
        });
    await _isle();
    void kontrol(dynamic s) {
      if (s is Map<String, dynamic>) {
        if (s['type'] == 'object') {
          expect(s['additionalProperties'], false);
          expect((s['required'] as List).toSet(), (s['properties'] as Map).keys.toSet());
        }
        s.values.forEach(kontrol);
      } else if (s is List) {
        s.forEach(kontrol);
      }
    }

    kontrol(govde['output_config']['format']['schema']);
  });

  test('Yedek model özelliği reddedilirse onsuz yeniden dener', () async {
    final istekler = <http.Request>[];
    AiServisi.istemciUret = () => MockClient((r) async {
          istekler.add(r);
          if (istekler.length == 1) {
            return _yanit({'type': 'error', 'error': {'type': 'invalid_request_error', 'message': 'fallbacks is not supported'}}, 400);
          }
          return _yanit(_basarili([_fikir()]));
        });
    final sonuc = await _isle();
    expect(istekler, hasLength(2));
    expect(istekler[0].headers['anthropic-beta'], contains('fallback'));
    expect(istekler[1].headers.containsKey('anthropic-beta'), isFalse);
    expect(jsonDecode(istekler[1].body).containsKey('fallbacks'), isFalse);
    expect(sonuc.fikirler, hasLength(1));
  });

  test('Birden fazla fikir ayrı ayrı döner', () async {
    AiServisi.istemciUret = () => MockClient((r) async => _yanit(_basarili([
          _fikir(),
          _fikir(baslik: 'Diziyi kaydet', yapilabilir: false),
        ])));
    final sonuc = await _isle();
    expect(sonuc.fikirler.map((f) => f.baslik), ['Salona tablo asmak', 'Diziyi kaydet']);
  });

  test('Güvenlik reddinde boş sonuç döner, hata fırlatmaz', () async {
    AiServisi.istemciUret = () => MockClient((r) async => _yanit({'stop_reason': 'refusal', 'content': []}));
    expect((await _isle()).fikirler, isEmpty);
  });

  Future<AiHata> hataAl(http.Response Function() cevap) async {
    AiServisi.istemciUret = () => MockClient((r) async => cevap());
    try {
      await _isle();
    } on AiHata catch (e) {
      return e;
    }
    fail('Hata bekleniyordu');
  }

  test('Hata türleri doğru eşlenir', () async {
    expect((await hataAl(() => _yanit({'error': {'message': 'invalid x-api-key'}}, 401))).tur, AiHataTuru.anahtarGecersiz);
    expect((await hataAl(() => _yanit({'error': {'message': 'Your credit balance is too low'}}, 400))).tur, AiHataTuru.kredi);
    expect((await hataAl(() => _yanit({'error': {'message': 'rate'}}, 429))).tur, AiHataTuru.gecici);
    expect((await hataAl(() => _yanit({'error': {'message': 'overloaded'}}, 529))).tur, AiHataTuru.gecici);
    expect((await hataAl(() => _yanit({'error': {'message': 'bad'}}, 400))).tur, AiHataTuru.diger);
  });

  test('İnternet yoksa çevrimdışı hatası verir ve otomatik yeniden denenebilir', () async {
    AiServisi.istemciUret = () => MockClient((r) async => throw const SocketException('yok'));
    try {
      await _isle();
      fail('Hata bekleniyordu');
    } on AiHata catch (e) {
      expect(e.tur, AiHataTuru.cevrimdisi);
      expect(e.otomatikDeneme, isTrue);
    }
  });

  test('Anahtar hatası kullanıcı bir şey yapmadan yeniden denenmez', () {
    expect(const AiHata('x', AiHataTuru.anahtarGecersiz).otomatikDeneme, isFalse);
    expect(const AiHata('x', AiHataTuru.kredi).otomatikDeneme, isTrue);
  });

  test('Saatli tarih doğru çözülür, bozuk tarih null olur', () {
    expect(AiFikir(tarih: '2026-12-19T14:30', tarihSaatli: true).tarihDt, DateTime(2026, 12, 19, 14, 30));
    expect(AiFikir(tarih: '2026-12-19T14:30', tarihSaatli: true).saatVar, isTrue);
    expect(AiFikir(tarih: 'cuma').tarihDt, isNull);
    expect(AiFikir().tarihDt, isNull);
  });

  test('Kayıtlı öneri JSON olarak gidip gelir', () {
    final s = AiSonuc([AiFikir.fromJson(_fikir())]);
    final geri = AiSonuc.coz(jsonEncode(s.toJson()))!;
    expect(geri.fikirler.single.adimlar.map((a) => a.metin), ['Duvarın ölçüsünü al', 'Tabloyu sipariş ver', 'Kargonun gelmesini bekle']);
    expect(AiSonuc.coz('bozuk'), isNull);
    expect(AiSonuc.coz(null), isNull);
  });
}
