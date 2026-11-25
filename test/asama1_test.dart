import 'dart:convert';
import 'dart:io';

import 'package:aklimda/ai/ai_ayarlar.dart';
import 'package:aklimda/ai/ai_servisi.dart';
import 'package:aklimda/ai/isleyici.dart';
import 'package:aklimda/kategori_gorunum.dart';
import 'package:aklimda/ekranlar/onay_bekleyenler.dart';
import 'package:aklimda/ortak.dart';
import 'package:aklimda/veri/depo.dart';
import 'package:aklimda/veri/modeller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SahtePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String yol;
  _SahtePathProvider(this.yol);
  @override
  Future<String?> getApplicationDocumentsPath() async => yol;
}

Map<String, dynamic> _fikir(String baslik, {bool is_ = false, String yeniKat = ''}) => {
      'metin': baslik,
      'baslik': baslik,
      'kategori_idler': <int>[],
      'yeni_kategori_ad': yeniKat,
      'yeni_kategori_ust_id': 0,
      'sure_dk': 25,
      'tarih': '2026-12-19',
      'tarih_saatli': false,
      'yapilabilir_is': is_,
      'adimlar': is_
          ? [
              {'metin': 'Duvarı ölç', 'sure_dk': 5, 'bekleme': false},
              {'metin': 'Tabloyu sipariş ver', 'sure_dk': 10, 'bekleme': false},
              {'metin': 'Kargoyu bekle', 'sure_dk': 0, 'bekleme': true},
            ]
          : [],
    };

http.Response _ok(List<Map<String, dynamic>> fikirler) => http.Response.bytes(
    utf8.encode(jsonEncode({
      'stop_reason': 'end_turn',
      'content': [
        {'type': 'text', 'text': jsonEncode({'fikirler': fikirler})},
      ],
    })),
    200,
    headers: {'content-type': 'application/json'});

void main() {
  late Directory gecici;
  final depo = Depo.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr');
    gecici = await Directory.systemTemp.createTemp('aklimda_asama1');
    PathProviderPlatform.instance = _SahtePathProvider(gecici.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(gecici.path);
    FlutterSecureStorage.setMockInitialValues({});
    await depo.ac();
    await AiAyarlar.instance.kaydet('sk-ant-deneme');
  });
  tearDown(() {
    AiServisi.istemciUret = http.Client.new;
    Depo.yeniNotAiDisi = () => false;
  });
  tearDownAll(() => gecici.delete(recursive: true));

  testWidgets('Yapay zeka kapalıyken yeni not dışarıda kalır, zamanlı işlemede atlanır, "gönder" ile işlenir', (tester) async {
    var istek = 0;
    AiServisi.istemciUret = () => MockClient((r) async {
          istek++;
          return _ok([_fikir('Market listesi')]);
        });
    Depo.yeniNotAiDisi = () => true;
    await tester.runAsync(() async {
      final n = await depo.notEkle(metin: 'süt ekmek', kaynak: Kaynak.yazili);
      expect(n.aiDisi, isTrue);
      expect(AiIsleyici.instance.bekleyenSayisi, 0);
      await AiIsleyici.instance.bekleyenleriIsle();
      expect(istek, 0);
      final hata = await AiIsleyici.instance.notuGonder(n);
      expect(hata, isNull);
      expect(istek, 1);
      final g = depo.notlar.firstWhere((x) => x.id == n.id);
      expect(g.aiDisi, isFalse);
      expect(g.islendi, isTrue);
    });
  });

  testWidgets('Onay bekleyenler ekranından not silinebilir', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final n = (await tester.runAsync(() async {
      final n = await depo.notEkle(metin: 'Silinecek not', kaynak: Kaynak.yazili);
      AiServisi.istemciUret = () => MockClient((r) async => _ok([_fikir('Silinecek not')]));
      await AiIsleyici.instance.hemenIsle(n);
      return depo.notlar.firstWhere((x) => x.id == n.id);
    }))!;
    expect(n.onayBekliyor, isTrue);
    await tester.pumpWidget(MaterialApp(navigatorKey: navigatorKey, home: const OnayBekleyenlerEkrani()));
    await tester.pump();
    expect(find.text('Silinecek not'), findsWidgets);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(depo.notlar.where((x) => x.id == n.id), isEmpty);
    expect(find.text('Silinecek not'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  test('Kategori rengi ve ikonu: varsayılan, kendi seçimi ve üst kategoriden miras', () async {
    final agac = depo.agac;
    final hobi = agac.anaKategoriler.firstWhere((k) => k.ad == 'Hobi');
    final dizi = agac.altlari(hobi.id).firstWhere((k) => k.ad == 'Dizi');
    expect(agac.renkOf(hobi.id), KategoriGorunum.varsayilanRenk(hobi.id));
    expect(agac.renkOf(dizi.id), agac.renkOf(hobi.id)); // alt, üstten alır
    await depo.kategoriGorunumu(hobi.id, renk: 0xFF112233, ikon: 'film');
    expect(depo.agac.renkOf(dizi.id).toARGB32(), 0xFF112233);
    expect(depo.agac.ikonOf(dizi.id), KategoriGorunum.ikonlar['film']);
    await depo.kategoriGorunumu(hobi.id, renkiTemizle: true);
    expect(depo.agac.renkOf(hobi.id), KategoriGorunum.varsayilanRenk(hobi.id));
  });
}
