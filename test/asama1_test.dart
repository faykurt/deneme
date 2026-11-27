import 'dart:convert';
import 'dart:io';

import 'package:aklimda/ai/ai_ayarlar.dart';
import 'package:aklimda/ai/ai_servisi.dart';
import 'package:aklimda/ai/isleyici.dart';
import 'package:aklimda/kategori_gorunum.dart';
import 'package:aklimda/ekranlar/onay_bekleyenler.dart';
import 'package:aklimda/ekranlar/yazili_not.dart';
import 'package:aklimda/ekranlar/ana_sayfa.dart';
import 'package:aklimda/ekranlar/ayarlar.dart';
import 'package:aklimda/ekranlar/sesli_not.dart';
import 'package:aklimda/ekranlar/kutuphane.dart' show Kutuphane, kapakIndeksi;
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
import 'package:shared_preferences/shared_preferences.dart';
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
    Kutuphane.animasyon = false;
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

  http.Response listeYaniti(String baslik, List<String> maddeler) => http.Response.bytes(
      utf8.encode(jsonEncode({
        'stop_reason': 'end_turn',
        'content': [
          {'type': 'text', 'text': jsonEncode({'baslik': baslik, 'kategori_idler': <int>[], 'maddeler': maddeler})},
        ],
      })),
      200,
      headers: {'content-type': 'application/json'});

  test('Liste: yapay zeka metni maddelere böler, işaretli maddeler işaretli kalır, liste onay beklemez', () async {
    final n = await depo.notEkle(metin: 'market', kaynak: Kaynak.yazili, tur: NotTuru.liste, aiDisi: true);
    await depo.adimlariKaydet(n.id, [
      Adim(notId: n.id, sira: 0, metin: 'süt ekmek yumurta', durum: Durum.yapilacak),
      Adim(notId: n.id, sira: 1, metin: 'Peynir', durum: Durum.yapildi),
    ]);
    AiServisi.istemciUret = () => MockClient((r) async => listeYaniti('Market listesi', ['Süt', 'Ekmek', 'Yumurta', 'peynir']));
    final hata = await AiIsleyici.instance.notuGonder(depo.notlar.firstWhere((x) => x.id == n.id));
    expect(hata, isNull);
    final g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(g.metin, 'Market listesi');
    expect(g.adimlar.map((a) => a.metin), ['Süt', 'Ekmek', 'Yumurta', 'peynir']);
    expect(g.adimlar.where((a) => a.yapildi).map((a) => a.metin), ['peynir']);
    expect(g.onayBekliyor, isFalse);
    expect(g.liste, isTrue);
  });

  test('Sesle liste: konuşma maddelere bölünür; anahtar ya da bağlantı yoksa tek madde olur', () async {
    AiServisi.istemciUret = () => MockClient((r) async => listeYaniti('', ['Süt', 'Ekmek']));
    expect(await AiIsleyici.instance.metniMaddelereBol('süt ekmek'), ['Süt', 'Ekmek']);
    AiServisi.istemciUret = () => MockClient((r) async => http.Response('hata', 500));
    expect(await AiIsleyici.instance.metniMaddelereBol('süt ekmek'), ['süt ekmek']);
    await AiAyarlar.instance.sil();
    expect(await AiIsleyici.instance.metniMaddelereBol('süt ekmek'), ['süt ekmek']);
    await AiAyarlar.instance.kaydet('sk-ant-deneme');
  });

  testWidgets('Liste kipinde maddeler tek tek eklenir, yapay zeka kapalı kaydedilir; kütüphanede kitap ve kâğıt görünür', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => yaziliNotAc(liste: true), child: const Text('ac'))))));
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
    expect(find.text('Liste adı (ör. Market)'), findsOneWidget);
    final alanlar = find.byType(TextField);
    await tester.enterText(alanlar.first, 'Hafta sonu market');
    await tester.enterText(alanlar.last, 'Süt');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'Ekmek');
    await tester.tap(find.byTooltip('Maddeyi ekle'));
    await tester.pump();
    expect(find.text('Süt'), findsOneWidget);
    expect(find.text('Ekmek'), findsOneWidget);
    await tester.tap(find.text('Kaydet'));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
      if (depo.notlar.any((n) => n.metin == 'Hafta sonu market')) break;
    }
    await tester.pumpAndSettle();
    final n = depo.notlar.firstWhere((n) => n.metin == 'Hafta sonu market');
    expect(n.liste, isTrue);
    expect(n.aiDisi, isTrue); // başta yapay zeka açılmadı
    expect(n.adimlar.map((a) => a.metin), ['Süt', 'Ekmek']);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: const Kutuphane()))));
    await tester.pump();
    expect(find.text('Hafta sonu market'), findsOneWidget); // kategorisiz: post-it
    expect(find.bySemanticsLabel(RegExp('^Hobi, ')), findsOneWidget); // kitap
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  Future<void> bekleDb(WidgetTester t, bool Function() kosul) async {
    for (var i = 0; i < 100 && !kosul(); i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
      await t.pump(const Duration(milliseconds: 30));
    }
  }

  testWidgets('Sesli not kaydedilince yapay zeka penceresi çıkar; kapatılırsa not dışarıda kalır', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final n = (await tester.runAsync(() => depo.notEkle(metin: 'yarın market listesi hazırla', kaynak: Kaynak.sesli)))!;
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => sesliSonrasi(n), child: const Text('ac'))))));
    await tester.tap(find.text('ac'));
    await tester.pumpAndSettle();
    expect(find.text('Sesli not kaydedildi'), findsOneWidget);
    expect(find.text('yarın market listesi hazırla'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue); // genel anahtar açık
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Tamam'));
    await bekleDb(tester, () => depo.notlar.firstWhere((x) => x.id == n.id).aiDisi);
    await tester.pumpAndSettle(const Duration(seconds: 6));
    expect(depo.notlar.firstWhere((x) => x.id == n.id).aiDisi, isTrue);
  });

  testWidgets('Ana sayfada alanın içinde Not / Liste anahtarı var; seçili olana göre doğru arayüz açılır', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MaterialApp(navigatorKey: navigatorKey, home: const AnaSayfa()));
    await tester.pump();
    expect(find.text('Aklında ne var?'), findsOneWidget);
    expect(find.text('Sesli'), findsNothing); // sesli düğmesi kalktı, alttaki mikrofon var
    expect(find.byTooltip('Fotoğraflı not'), findsNothing); // kamera düğmesi kalktı
    // Not seçiliyken yazı arayüzü
    await tester.tap(find.text('Aklında ne var?'));
    await tester.pumpAndSettle();
    expect(find.text('Liste adı (ör. Market)'), findsNothing);
    expect(find.text('Aklında ne var?'), findsWidgets); // yazı kutusunun ipucu
    await tester.tapAt(const Offset(10, 10)); // pencereyi kapat
    await tester.pumpAndSettle();
    // Liste seçiliyken liste arayüzü
    await tester.tap(find.text('Liste').first);
    await tester.pump();
    await tester.tap(find.text('Aklında ne var?'));
    await tester.pumpAndSettle();
    expect(find.text('Liste adı (ör. Market)'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('Kategoriye dokununca düzenleme penceresi açılır, emoji ikon olur', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(navigatorKey: navigatorKey, home: const KategoriYonetimi()));
    await tester.pump();
    final ev = depo.agac.anaKategoriler.firstWhere((k) => k.ad == 'Ev');
    await tester.tap(find.text('Ev').first);
    await tester.pumpAndSettle();
    expect(find.text('Kategoriyi sil'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Ya da emoji'), '🏠');
    await bekleDb(tester, () => depo.agac.emojiOf(ev.id) != null);
    expect(depo.agac.emojiOf(ev.id), '🏠');
    await tester.pumpAndSettle();
  });

  test('Kapak seçimi: kategori rengine en yakın kitap kapağı', () {
    expect(kapakIndeksi(const Color(0xFFC0714F)), 0); // kiremit
    expect(kapakIndeksi(const Color(0xFF7A9E5C)), 1); // yeşil
    expect(kapakIndeksi(const Color(0xFF9B6FB5)), 2); // mor
    expect(kapakIndeksi(const Color(0xFF4FA3A0)), 3); // turkuaz
    expect(kapakIndeksi(const Color(0xFF5B8DB8)), 4); // mavi
    expect(kapakIndeksi(const Color(0xFFC9A23E)), 5); // hardal
  });

  testWidgets('Kitaba dokununca kitap açılır, içinde notlar ve kapat düğmesi görünür; kapatınca raf döner', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final hobi = depo.agac.anaKategoriler.firstWhere((k) => k.ad == 'Hobi');
    await tester.runAsync(() => depo.notEkle(metin: 'Dizi listesi yap', kaynak: Kaynak.yazili, kategoriIdler: [hobi.id]));
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: SingleChildScrollView(child: Kutuphane()))));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(RegExp('^Hobi, ')).first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byTooltip('Kitabı kapat'), findsOneWidget);
    expect(find.text('Dizi listesi yap'), findsWidgets);
    await tester.tap(find.byTooltip('Kitabı kapat'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.byTooltip('Kitabı kapat'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^Hobi, ')), findsWidgets);
  });
}
