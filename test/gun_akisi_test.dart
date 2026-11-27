import 'dart:io';

import 'package:aklimda/ekranlar/gun_akisi.dart';
import 'package:aklimda/ekranlar/hafta_ozeti.dart';
import 'package:aklimda/takvim/etkinlik_ikonlari.dart';
import 'package:aklimda/takvim/etkinlik_simgesi.dart';
import 'package:aklimda/takvim/takvim_ayarlari.dart';
import 'package:aklimda/takvim/takvim_deposu.dart';
import 'package:aklimda/takvim/takvim_modeller.dart';
import 'package:aklimda/veri/depo.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'sahte_takvim.dart';

class _SahtePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String yol;
  _SahtePathProvider(this.yol);
  @override
  Future<String?> getApplicationDocumentsPath() async => yol;
}

void main() {
  late Directory gecici;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr');
    gecici = await Directory.systemTemp.createTemp('aklimda_akis');
    PathProviderPlatform.instance = _SahtePathProvider(gecici.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(gecici.path);
    FlutterSecureStorage.setMockInitialValues({});
    await Depo.instance.ac();
  });
  tearDownAll(() => gecici.delete(recursive: true));

  test('Etkinlik başlığından tür: kelimeye göre ikon ve renk, baştaki emoji ve işaret ayıklanır', () {
    expect(EtkinlikSimgesi.turBul('Market alışverişi')!.ikon, Icons.shopping_basket);
    expect(EtkinlikSimgesi.turBul('Akşam yemeği')!.ikon, Icons.restaurant);
    expect(EtkinlikSimgesi.turBul('Tez toplantısı')!.ikon, Icons.groups); // toplantı, tezden önce
    expect(EtkinlikSimgesi.turBul('Yoga dersi')!.ikon, Icons.directions_run);
    expect(EtkinlikSimgesi.turBul('Xyz'), isNull);
    expect(EtkinlikSimgesi.bastakiEmoji('$uygulamaIsareti 🏋️ Spor'), '🏋️');
    expect(EtkinlikSimgesi.bastakiEmoji('Spor'), isNull);
    expect(EtkinlikSimgesi.temizBaslik('$uygulamaIsareti 🏋️ Spor'), 'Spor');
    expect(EtkinlikSimgesi.temizBaslik('$uygulamaIsareti Dolabı düzenle'), 'Dolabı düzenle');
  });

  testWidgets('Günlük akış: etkinlikler süreyle, "şimdi" işareti, boşluk ve günü kapat kartı görünür', (t) async {
    t.view.physicalSize = const Size(1080, 3000);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final ayar = TakvimAyarlari.instance;
    await ayar.yukle();
    await ayar.takvimSec('sam', 'S');
    final simdi = DateTime.now();
    final g = DateTime(simdi.year, simdi.month, simdi.day);
    final sahte = SahteTakvim(izin: true, etkinlikler: [
      etk('a', 'Tez toplantısı', g.add(const Duration(hours: 1)), g.add(const Duration(hours: 2, minutes: 30))),
      etk('b', 'Market', g.add(const Duration(hours: 23)), g.add(const Duration(hours: 23, minutes: 30))),
    ]);
    final td = TakvimDeposu.instance = TakvimDeposu(sahte, ayar);
    await t.runAsync(() async {
      await td.baslat();
      await td.yukle(g.subtract(const Duration(days: 2)), g.add(const Duration(days: 2)));
    });
    var eklendi = false;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: GunAkisi(gun: g, onAc: (_) {}, onEkle: ({baslik, baslangic}) async => eklendi = true))));
    await t.pump();
    expect(find.text('Tez toplantısı'), findsOneWidget);
    expect(find.textContaining('1 sa 30 dk'), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);
    expect(find.byIcon(Icons.groups), findsOneWidget); // türe göre ikon
    expect(find.byIcon(Icons.shopping_basket), findsOneWidget);
    expect(find.textContaining('Şimdi · '), findsOneWidget);
    expect(find.text('Günü kapatalım mı?'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Ekle'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Ekle'));
    expect(eklendi, isTrue);
  });

  test('Emoji başlığa yazılır, işaret korunur; kendi seçtiğin ikon saklanır', () async {
    expect(EtkinlikSimgesi.baslikEmojiyle('$uygulamaIsareti Spor', '🏋️'), '$uygulamaIsareti 🏋️ Spor');
    expect(EtkinlikSimgesi.baslikEmojiyle('🏋️ Spor', '🎯'), '🎯 Spor');
    expect(EtkinlikSimgesi.baslikEmojiyle('🏋️ Spor', null), 'Spor');
    SharedPreferences.setMockInitialValues({});
    final ik = EtkinlikIkonlari.instance;
    await ik.ata('ev1', 'kahve');
    expect(ik.ikonOf('ev1'), Icons.local_cafe);
    await ik.ata('ev1', null);
    expect(ik.ikonOf('ev1'), isNull);
  });

  testWidgets('Hafta özeti: yedi gün alt alta, etkinlikler ikonlu satırlar, güne dokununca günlük görünüm istenir', (t) async {
    t.view.physicalSize = const Size(1080, 3400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    SharedPreferences.setMockInitialValues({});
    final ayar = TakvimAyarlari.instance;
    await ayar.yukle();
    await ayar.takvimSec('sam', 'S');
    final simdi = DateTime.now();
    final g = DateTime(simdi.year, simdi.month, simdi.day);
    final sahte = SahteTakvim(izin: true, etkinlikler: [
      etk('h1', 'Market alışverişi', g.add(const Duration(hours: 10)), g.add(const Duration(hours: 11))),
    ]);
    final td = TakvimDeposu.instance = TakvimDeposu(sahte, ayar);
    await t.runAsync(() async {
      await td.baslat();
      await td.yukle(g.subtract(const Duration(days: 8)), g.add(const Duration(days: 8)));
    });
    DateTime? secilen;
    await t.pumpWidget(MaterialApp(home: Scaffold(body: HaftaOzeti(odak: g, onGun: (d) => secilen = d, onAc: (_) {}))));
    await t.pump();
    for (final ad in ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar']) {
      expect(find.text(ad), findsOneWidget);
    }
    expect(find.text('Market alışverişi'), findsOneWidget);
    expect(find.byIcon(Icons.shopping_basket), findsOneWidget);
    await t.tap(find.text('Salı'));
    expect(secilen, isNotNull);
    expect(secilen!.weekday, DateTime.tuesday);
  });
}
