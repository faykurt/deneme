import 'dart:convert';
import 'dart:io';

import 'package:aklimda/ai/ai_ayarlar.dart';
import 'package:aklimda/ai/ai_servisi.dart';
import 'package:aklimda/ai/isleyici.dart';
import 'package:aklimda/ekranlar/ana_sayfa.dart';
import 'package:aklimda/ekranlar/ayarlar.dart';
import 'package:aklimda/ekranlar/not_detay.dart';
import 'package:aklimda/ekranlar/notlar_ekrani.dart';
import 'package:aklimda/ekranlar/onay_bekleyenler.dart';
import 'package:aklimda/ekranlar/onay_penceresi.dart';
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

Widget _sar(Widget w) => MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('tr'),
      theme: ThemeData(scaffoldBackgroundColor: Renk.krem),
      home: w,
    );

void main() {
  late Directory gecici;
  final depo = Depo.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr');
    gecici = await Directory.systemTemp.createTemp('aklimda_ekran');
    PathProviderPlatform.instance = _SahtePathProvider(gecici.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(gecici.path);
    FlutterSecureStorage.setMockInitialValues({});
    await depo.ac();
    await AiAyarlar.instance.kaydet('sk-ant-deneme');
  });
  tearDown(() => AiServisi.istemciUret = http.Client.new);
  tearDownAll(() => gecici.delete(recursive: true));

  testWidgets('Onay penceresi adım önerisini ve alanları gösterir, onaylayınca not onaylanır', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final not = (await tester.runAsync(() async {
      final n = await depo.notEkle(metin: 'Salona tablo asacağım', kaynak: Kaynak.sesli);
      AiServisi.istemciUret = () => MockClient((r) async => _ok([_fikir('Salona tablo asmak', is_: true, yeniKat: 'Sanat')]));
      await AiIsleyici.instance.hemenIsle(n);
      return depo.notlar.firstWhere((x) => x.id == n.id);
    }))!;

    await tester.pumpWidget(_sar(Scaffold(body: OnayPenceresi(notId: not.id, canli: false))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Yapay zekanın önerisi'), findsOneWidget);
    expect(find.text('Salona tablo asmak'), findsWidgets);
    expect(find.text('Adımları ekle'), findsOneWidget);
    expect(find.text('Duvarı ölç'), findsOneWidget);
    expect(find.text('Yeni kategori: Sanat'), findsOneWidget);
    expect(find.text('Onayla'), findsOneWidget);
    expect(find.text('Sonra onaylarım'), findsOneWidget);

    // Onayla'ya basınca adımlar kaydolur, not onaylanır (Navigator.pop için gerçek rota gerekir)
    await tester.pumpWidget(_sar(Builder(
        builder: (ctx) => Scaffold(
            body: Center(
                child: FilledButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: ctx, isScrollControlled: true, builder: (_) => OnayPenceresi(notId: not.id, canli: false)),
                    child: const Text('ac')))))));
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    final g = depo.notlar.firstWhere((x) => x.id == not.id);
    expect(g.onayli, isTrue);
    expect(g.adimlar.map((a) => a.metin), ['Duvarı ölç', 'Tabloyu sipariş ver', 'Kargoyu bekle']);
    expect(g.adimlar.last.bekleme, isTrue);
  });

  testWidgets('Çoklu fikir penceresi bölme seçeneği sunar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final not = (await tester.runAsync(() async {
      final n = await depo.notEkle(metin: 'Kargo gönder ve dizi kaydet', kaynak: Kaynak.sesli);
      AiServisi.istemciUret = () => MockClient((r) async => _ok([_fikir('Kargo gönder'), _fikir('Dizi kaydet')]));
      await AiIsleyici.instance.hemenIsle(n);
      return depo.notlar.firstWhere((x) => x.id == n.id);
    }))!;
    await tester.pumpWidget(_sar(Scaffold(body: OnayPenceresi(notId: not.id, canli: false))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Bu kayıtta 2 ayrı fikir var'), findsOneWidget);
    expect(find.text('Ayrı notlara böl'), findsOneWidget);
    expect(find.text('Tek not kalsın'), findsOneWidget);
  });

  testWidgets('Canlı akışta işlenirken bekleme, bitince öneri gösterilir', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final n = (await tester.runAsync(() => depo.notEkle(metin: 'Hemen işlensin', kaynak: Kaynak.yazili)))!;
    AiServisi.istemciUret = () => MockClient((r) async => _ok([_fikir('Hemen işlendi')]));
    await tester.pumpWidget(_sar(Scaffold(body: OnayPenceresi(notId: n.id, canli: true))));
    await tester.pump();
    expect(find.text('Yapay zeka düzenliyor…'), findsOneWidget);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Yapay zekanın önerisi'), findsOneWidget);
  });

  testWidgets('İnternet yokken pencere hata ve güvence mesajı gösterir', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final n = (await tester.runAsync(() => depo.notEkle(metin: 'Çevrimdışı', kaynak: Kaynak.yazili)))!;
    AiServisi.istemciUret = () => MockClient((r) async => throw const SocketException('yok'));
    await tester.pumpWidget(_sar(Scaffold(body: OnayPenceresi(notId: n.id, canli: true))));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Not kaydedildi'), findsOneWidget);
    expect(find.textContaining('İnternet bağlantısı yok'), findsOneWidget);
    expect(find.text('Tamam'), findsOneWidget);
  });

  testWidgets('Not ayrıntısı adımları gösterir ve son adım bitince arşiv sorar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final n = (await tester.runAsync(() async {
      final n = await depo.notEkle(metin: 'Adımlı not', kaynak: Kaynak.yazili);
      await depo.adimlariKaydet(n.id, [Adim(notId: n.id, sira: 0, metin: 'Tek adım', sureDk: 3)]);
      return n;
    }))!;
    await tester.pumpWidget(_sar(NotDetay(notId: n.id)));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Adımlar'), findsOneWidget);
    expect(find.text('Tek adım'), findsOneWidget);
    expect(find.textContaining('Sıradaki'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    expect(find.text('Tüm adımlar bitti 🎉'), findsOneWidget);
  });

  testWidgets('Ana sayfa, Notlar, Onay bekleyenler ve Ayarlar ekranları çökmeden açılır', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    for (final w in <Widget>[
      const AnaSayfa(),
      const NotlarEkrani(),
      const OnayBekleyenlerEkrani(),
      const AyarlarEkrani(),
    ]) {
      await tester.pumpWidget(_sar(w));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '${w.runtimeType}');
    }
    await tester.pumpWidget(_sar(const AyarlarEkrani()));
    await tester.pump();
    expect(find.text('Yapay zeka anahtarı'), findsOneWidget);
    expect(find.textContaining('sk-ant'), findsOneWidget);
    expect(find.text('Bağlantıyı dene'), findsOneWidget);
  });
}
