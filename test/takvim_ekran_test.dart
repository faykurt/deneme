import 'dart:io';

import 'package:aklimda/ekranlar/ana_sayfa.dart';
import 'package:aklimda/ekranlar/not_detay.dart';
import 'package:aklimda/ekranlar/takvim.dart';
import 'package:aklimda/ortak.dart';
import 'package:aklimda/takvim/takvim_ayarlari.dart';
import 'package:aklimda/takvim/takvim_deposu.dart';
import 'package:aklimda/takvim/takvim_modeller.dart';
import 'package:aklimda/veri/depo.dart';
import 'package:aklimda/veri/modeller.dart';
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

Widget _sar(Widget w) => MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('tr'),
      theme: ThemeData(scaffoldBackgroundColor: Renk.krem),
      home: w,
    );

void main() {
  late Directory gecici;
  final depo = Depo.instance;
  final ayar = TakvimAyarlari.instance;
  late SahteTakvim sahte;
  final simdi = DateTime.now();
  final bugun14 = DateTime(simdi.year, simdi.month, simdi.day, 14);

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr');
    gecici = await Directory.systemTemp.createTemp('aklimda_takvim_ekran');
    PathProviderPlatform.instance = _SahtePathProvider(gecici.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(gecici.path);
    FlutterSecureStorage.setMockInitialValues({});
    await depo.ac();
  });
  tearDownAll(() => gecici.delete(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ayar.yukle();
    await ayar.takvimiSifirla();
  });

  void ekranBoyu(WidgetTester t) {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
  }

  Future<void> bekle(WidgetTester t, {int ms = 250}) async {
    await t.runAsync(() => Future.delayed(Duration(milliseconds: ms)));
    await t.pumpAndSettle();
  }

  void kur({bool izin = false, bool izinVerilir = true, List<TEtkinlik>? etkinlikler, bool takvimSec = false}) {
    sahte = SahteTakvim(
      izin: izin,
      izinVerilir: izinVerilir,
      etkinlikler: etkinlikler ?? [etk('t1', 'Bugünkü toplantı', bugun14, bugun14.add(const Duration(hours: 1)))],
    );
    TakvimDeposu.instance = TakvimDeposu(sahte, ayar);
    if (takvimSec) {
      // sahte ayarlar zaten hazır
    }
  }

  testWidgets('İzin yokken açıklama kartı çıkar, izin verilince takvim seçimi gelir', (t) async {
    ekranBoyu(t);
    kur();
    await t.pumpWidget(_sar(const TakvimEkrani()));
    await t.pump();
    await t.pump();
    expect(find.text('Takvimini bağlayalım'), findsOneWidget);
    await t.tap(find.text('Takvim iznini ver'));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(tester(t), isNull);
    expect(find.text('Hangi takvimi kullanalım?'), findsOneWidget);
    expect(find.text('Samsung takvimim'), findsOneWidget);
    expect(find.textContaining('1 etkinlik'), findsWidgets);
    expect(find.textContaining('sadece okunur'), findsOneWidget);
  });

  testWidgets('İzin reddedilirse yönlendirme yazısı çıkar', (t) async {
    ekranBoyu(t);
    kur(izinVerilir: false);
    await t.pumpWidget(_sar(const TakvimEkrani()));
    await t.pump();
    await t.tap(find.text('Takvim iznini ver'));
    await t.pump();
    await t.pump();
    expect(find.textContaining('İzin verilmedi'), findsOneWidget);
  });

  testWidgets('Takvim seçilince ay görünümü etkinliği gösterir, hafta ve gün görünümü açılır', (t) async {
    ekranBoyu(t);
    kur();
    await t.pumpWidget(_sar(const TakvimEkrani()));
    await t.pump();
    await t.tap(find.text('Takvim iznini ver'));
    await t.pump();
    await t.pump();
    await t.pump();
    await t.tap(find.text('Samsung takvimim'));
    await t.pump();
    await bekle(t);
    expect(tester(t), isNull);
    expect(find.text('Pzt'), findsOneWidget);
    expect(find.text('Bugünkü toplantı'), findsOneWidget);
    expect(ayar.takvimAdi, 'Samsung takvimim');

    await t.tap(find.byIcon(Icons.calendar_view_month));
    await t.pumpAndSettle();
    await t.tap(find.text('Hafta'));
    await t.pumpAndSettle();
    expect(tester(t), isNull);
    expect(find.text('Bugünkü toplantı'), findsOneWidget);

    await t.tap(find.byIcon(Icons.calendar_view_week));
    await t.pumpAndSettle();
    await t.tap(find.text('Gün'));
    await t.pumpAndSettle();
    expect(tester(t), isNull);
    expect(find.textContaining('Bugünkü toplantı'), findsOneWidget);
    expect(find.text('14:00'), findsOneWidget);
  });

  testWidgets('Yeni etkinlik eklenir ve başına 💭 işareti konur', (t) async {
    ekranBoyu(t);
    kur(izin: true);
    await ayar.takvimSec('sam', 'Samsung takvimim');
    await t.pumpWidget(_sar(const TakvimEkrani()));
    await t.pump();
    await bekle(t);
    await t.tap(find.byIcon(Icons.add));
    await t.pumpAndSettle();
    expect(find.text('Yeni etkinlik'), findsOneWidget);
    // başlık boşken kaydedilmez
    await t.tap(find.text('Kaydet'));
    await t.pump();
    expect(find.text('Etkinliğe bir başlık yaz.'), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 5));
    await t.enterText(find.byType(TextField).first, 'Dişçi randevusu');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(sahte.gunluk, contains('ekle:💭 Dişçi randevusu'));
    expect(sahte.ev.last.takvimId, 'sam');
    expect(tester(t), isNull);
  });

  testWidgets('Tüm gün etkinlikte "Günü dolu say" kapatılırsa müsait yazılır, bitiş ertesi gün olur', (t) async {
    ekranBoyu(t);
    kur(izin: true);
    await ayar.takvimSec('sam', 'S');
    await t.pumpWidget(_sar(const TakvimEkrani()));
    await bekle(t);
    await t.tap(find.byIcon(Icons.add));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Doğum günüm');
    await t.tap(find.widgetWithText(SwitchListTile, 'Tüm gün'));
    await t.pumpAndSettle();
    expect(find.text('Günü dolu say'), findsOneWidget);
    // varsayılan açık; kapat
    await t.tap(find.widgetWithText(SwitchListTile, 'Günü dolu say'));
    await t.pumpAndSettle();
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    final e = sahte.ev.last;
    expect(e.baslik, '💭 Doğum günüm');
    expect(e.tumGun, isTrue);
    expect(e.meshgul, isFalse);
    expect(e.bitis.difference(e.baslangic), const Duration(days: 1));
  });

  testWidgets('Tüm gün etkinlikte "Günü dolu say" açık bırakılırsa meşgul yazılır', (t) async {
    ekranBoyu(t);
    kur(izin: true);
    await ayar.takvimSec('sam', 'S');
    await t.pumpWidget(_sar(const TakvimEkrani()));
    await bekle(t);
    await t.tap(find.byIcon(Icons.add));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Seminer');
    await t.tap(find.widgetWithText(SwitchListTile, 'Tüm gün'));
    await t.pumpAndSettle();
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(sahte.ev.last.meshgul, isTrue);
  });

  testWidgets('Mevcut etkinliği silme: onay sorar ve takvimden siler', (t) async {
    ekranBoyu(t);
    kur(izin: true);
    await ayar.takvimSec('sam', 'S');
    await t.pumpWidget(_sar(const TakvimEkrani()));
    await bekle(t);
    await t.tap(find.text('Bugünkü toplantı'));
    await t.pumpAndSettle();
    expect(find.text('Etkinlik'), findsOneWidget);
    await t.tap(find.byIcon(Icons.delete_outline));
    await t.pumpAndSettle();
    expect(find.text('Etkinlik silinsin mi?'), findsOneWidget);
    await t.tap(find.text('Sil'));
    await t.pumpAndSettle();
    expect(sahte.ev.where((e) => e.eventId == 't1'), isEmpty);
    expect(sahte.gunluk, contains('sil:hepsi:Bugünkü toplantı'));
  });

  testWidgets('Tekrarlı etkinlikte düzenleme ve silme kapsam sorar', (t) async {
    ekranBoyu(t);
    kur(izin: true, etkinlikler: [
      etk('r1', 'Haftalık toplantı', bugun14, bugun14.add(const Duration(hours: 1)), tekrarli: true),
    ]);
    await ayar.takvimSec('sam', 'S');
    await t.pumpWidget(_sar(const TakvimEkrani()));
    await bekle(t);
    await t.tap(find.text('Haftalık toplantı'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Haftalık toplantı (yeni)');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(find.textContaining('Bu tekrarlı bir etkinlik'), findsOneWidget);
    await t.tap(find.text('Bu ve sonraki tekrarlar'));
    await t.pumpAndSettle();
    expect(sahte.gunluk, contains('guncelle:buVeSonrakiler:Haftalık toplantı (yeni)'));

    await t.tap(find.text('Haftalık toplantı (yeni)'));
    await t.pumpAndSettle();
    await t.tap(find.byIcon(Icons.delete_outline));
    await t.pumpAndSettle();
    expect(find.textContaining('Hangisi silinsin'), findsOneWidget);
    await t.tap(find.text('Tüm tekrarlar'));
    await t.pumpAndSettle();
    expect(sahte.gunluk.any((g) => g.startsWith('sil:hepsi')), isTrue);
  });

  testWidgets('Takvim hata verirse düzenleme ekranı açık kalır ve mesaj gösterir', (t) async {
    ekranBoyu(t);
    kur(izin: true);
    await ayar.takvimSec('sam', 'S');
    await t.pumpWidget(_sar(const TakvimEkrani()));
    await bekle(t);
    await t.tap(find.byIcon(Icons.add));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Hata deneyi');
    sahte.hataFirlat = true;
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    expect(find.text('Kaydedilemedi'), findsOneWidget);
    expect(find.text('Sahte hata'), findsOneWidget);
    await t.tap(find.text('Tamam'));
    await t.pumpAndSettle();
    expect(find.text('Yeni etkinlik'), findsOneWidget, reason: 'ekran kapanmamalı, kullanıcı tekrar deneyebilmeli');
  });

  testWidgets('Notu takvime "Kendim seçeyim" ile ekle: ekran dolu gelir, kayıtla not bağlanır', (t) async {
    ekranBoyu(t);
    kur(izin: true, etkinlikler: []);
    await ayar.takvimSec('sam', 'S');
    final not = (await t.runAsync(() async {
      final n = await depo.notEkle(metin: 'Salona tablo asmak', kaynak: Kaynak.yazili);
      n.sureDk = 45;
      await depo.notGuncelle(n);
      return n;
    }))!;
    await t.pumpWidget(_sar(NotDetay(notId: not.id)));
    await t.pump();
    await t.tap(find.text('Takvime ekle'));
    await t.pumpAndSettle();
    expect(find.text('Kendim seçeyim'), findsOneWidget);
    expect(find.text('Otomatik öner'), findsOneWidget);
    await t.tap(find.text('Kendim seçeyim'));
    await t.pumpAndSettle();
    expect(find.text('Yeni etkinlik'), findsOneWidget);
    expect(find.text('Salona tablo asmak'), findsOneWidget, reason: 'başlık nottan gelmeli');
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    await bekle(t);
    final e = sahte.ev.single;
    expect(e.baslik, '💭 Salona tablo asmak');
    expect(e.bitis.difference(e.baslangic), const Duration(minutes: 45), reason: 'süre nottan gelmeli');
    final g = depo.notlar.firstWhere((n) => n.id == not.id);
    expect(g.takvimEtkinlikId, e.eventId);
    expect(find.text('Takvimde'), findsOneWidget);
  });

  testWidgets('Notu "Otomatik öner" ile ekle: uyku saatlerini sorar, boş zaman bulup yazar', (t) async {
    ekranBoyu(t);
    kur(izin: true, etkinlikler: []);
    await ayar.takvimSec('sam', 'S');
    expect(ayar.kurallar.uykuTanimli, isFalse);
    final not = (await t.runAsync(() => depo.notEkle(metin: 'Kitap oku', kaynak: Kaynak.yazili)))!;
    await t.pumpWidget(_sar(NotDetay(notId: not.id)));
    await t.pump();
    await t.tap(find.text('Takvime ekle'));
    await t.pumpAndSettle();
    await t.tap(find.text('Otomatik öner'));
    await t.pumpAndSettle();
    expect(find.text('Uyku saatlerin'), findsOneWidget);
    await t.tap(find.text('Kaydet'));
    await t.pumpAndSettle();
    await bekle(t);
    expect(ayar.kurallar.uykuTanimli, isTrue);
    final e = sahte.ev.single;
    expect(e.baslik, '💭 Kitap oku');
    expect(e.baslangic.isAfter(DateTime.now()), isTrue);
    final g = depo.notlar.firstWhere((n) => n.id == not.id);
    expect(g.takvimEtkinlikId, e.eventId);
    expect(find.textContaining('için eklendi'), findsOneWidget);
    // sahte takvimde "Değiştir" ile düzenleme açılabilir
    await t.tap(find.text('Değiştir'));
    await t.pumpAndSettle();
    expect(find.text('Etkinlik'), findsOneWidget);
  });

  testWidgets('İş notu için iş bloğu yoksa açıklayıcı mesaj verir', (t) async {
    ekranBoyu(t);
    kur(izin: true, etkinlikler: []);
    await ayar.takvimSec('sam', 'S');
    await ayar.uykuAyarla(haftaIci: const UykuAraligi(23 * 60, 7 * 60), haftaSonu: const UykuAraligi(0, 9 * 60));
    final isId = depo.kategoriler.firstWhere((k) => k.ad == 'İş').id;
    final not = (await t.runAsync(() => depo.notEkle(metin: 'Rapor hazırla', kaynak: Kaynak.yazili, kategoriIdler: [isId])))!;
    await t.pumpWidget(_sar(NotDetay(notId: not.id)));
    await t.pump();
    await t.tap(find.text('Takvime ekle'));
    await t.pumpAndSettle();
    await t.tap(find.text('Otomatik öner'));
    await t.pumpAndSettle();
    await bekle(t);
    expect(find.textContaining('iş bloğu'), findsOneWidget);
    expect(sahte.ev, isEmpty);
  });

  testWidgets('Takvime bağlı notu silerken etkinliğin de silinip silinmeyeceği sorulur', (t) async {
    ekranBoyu(t);
    kur(izin: true);
    await ayar.takvimSec('sam', 'S');
    await t.pumpWidget(_sar(const Scaffold(body: SizedBox())));

    Future<Not> bagliNot(String metin) async => (await t.runAsync(() async {
          final n = await depo.notEkle(metin: metin, kaynak: Kaynak.yazili);
          await TakvimDeposu.instance.notuBagla(n, 't1', bugun14, bugun14.add(const Duration(hours: 1)));
          return n;
        }))!;

    /// Silme akışını başlatır, pencerede [dugme]ye basar, veritabanı işleri bitene kadar bekler.
    Future<void> sil(Not n, String dugme) async {
      var bitti = false;
      silVeGeriAlGoster([n.id]).then((_) => bitti = true);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('Takvimdeki etkinlik de silinsin mi?'), findsOneWidget);
      await t.tap(find.text(dugme));
      for (var i = 0; i < 60 && !bitti; i++) {
        await t.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
        await t.pump();
      }
      expect(bitti, isTrue, reason: 'silme akışı bitmeli');
      await bekle(t);
    }

    final n1 = await bagliNot('İkisini de sil');
    await sil(n1, 'İkisini de sil');
    expect(sahte.ev.where((e) => e.eventId == 't1'), isEmpty);
    expect(depo.notlar.where((n) => n.id == n1.id), isEmpty);

    // "Sadece notu sil" etkinliği korur
    kur(izin: true);
    final n2 = await bagliNot('Sadece notu sil');
    await sil(n2, 'Sadece notu sil');
    expect(sahte.ev.where((e) => e.eventId == 't1'), hasLength(1));
    expect(depo.notlar.where((n) => n.id == n2.id), isEmpty);

    // "Vazgeç" hiçbir şeyi silmez
    final n3 = await bagliNot('Vazgeç denemesi');
    await sil(n3, 'Vazgeç');
    expect(depo.notlar.where((n) => n.id == n3.id), hasLength(1));
    expect(sahte.ev.where((e) => e.eventId == 't1'), hasLength(1));
  });

  testWidgets('Ana sayfada biten etkinliğin notu için "Yaptın mı?" sorulur', (t) async {
    ekranBoyu(t);
    kur(izin: true);
    final bitis = DateTime.now().subtract(const Duration(minutes: 10));
    await t.runAsync(() async {
      final n = await depo.notEkle(metin: 'Akşam yürüyüşü', kaynak: Kaynak.yazili);
      await TakvimDeposu.instance.notuBagla(n, 't1', bitis.subtract(const Duration(hours: 1)), bitis);
    });
    await t.pumpWidget(_sar(const AnaSayfa()));
    await t.pump();
    expect(tester(t), isNull);
    expect(find.text('Yaptın mı?'), findsWidgets);
    expect(find.text('Akşam yürüyüşü'), findsOneWidget);
    await t.tap(find.text('Yaptım').first);
    await bekle(t);
    final g = depo.notlar.firstWhere((n) => n.metin == 'Akşam yürüyüşü');
    expect(g.durum, Durum.yapildi);
    expect(g.yaptinCevap, isTrue);
    expect(find.text('Akşam yürüyüşü'), findsNothing);
  });
}

Object? tester(WidgetTester t) => t.takeException();
