import 'dart:convert';
import 'dart:io';

import 'package:aklimda/ai/ai_ayarlar.dart';
import 'package:aklimda/ai/ai_servisi.dart';
import 'package:aklimda/oneri/bildirim_servisi.dart';
import 'package:aklimda/oneri/oneri_deposu.dart';
import 'package:aklimda/oneri/oneri_modeller.dart';
import 'package:aklimda/veri/depo.dart';
import 'package:aklimda/veri/modeller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
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

http.Response oneriYaniti(List<Map<String, Object?>> oneriler, {List<String> ogle = const [], List<String> aksam = const []}) =>
    http.Response.bytes(
        utf8.encode(jsonEncode({
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'text', 'text': jsonEncode({'oneriler': oneriler, 'hafta_sonu': {'ogle': ogle, 'aksam': aksam}})},
          ],
        })),
        200,
        headers: {'content-type': 'application/json'});

void main() {
  late Directory gecici;
  final depo = Depo.instance;
  final oneri = OneriDeposu.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr');
    gecici = await Directory.systemTemp.createTemp('aklimda_oneri');
    PathProviderPlatform.instance = _SahtePathProvider(gecici.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(gecici.path);
    FlutterSecureStorage.setMockInitialValues({});
    await depo.ac();
    await AiAyarlar.instance.kaydet('sk-ant-deneme');
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await oneri.yukle();
    oneri.paket = null;
    oneri.ertelenen = {};
    oneri.acik = true;
    oneri.bildirimSiniri = 3;
  });
  tearDown(() => AiServisi.istemciUret = http.Client.new);
  tearDownAll(() => gecici.delete(recursive: true));

  test('Hafta sonu planı hedefi: Cuma 22:00 Cumartesi\'ye, Cumartesi 22:00 Pazar\'a döner', () {
    // 2026-11-27 Cuma
    expect(OneriDeposu.planHedefi(DateTime(2026, 11, 27, 10)), 'genel');
    expect(OneriDeposu.planHedefi(DateTime(2026, 11, 27, 22)), 'cumartesi');
    expect(OneriDeposu.planHedefi(DateTime(2026, 11, 28, 15)), 'cumartesi');
    expect(OneriDeposu.planHedefi(DateTime(2026, 11, 28, 23)), 'pazar');
    expect(OneriDeposu.planHedefi(DateTime(2026, 11, 29, 9)), 'pazar');
    expect(OneriDeposu.planHedefi(DateTime(2026, 11, 25, 9)), isNull); // Çarşamba
    expect(OneriDeposu.bolumAdi(DateTime(2026, 11, 25, 8)), 'sabah');
    expect(OneriDeposu.bolumAdi(DateTime(2026, 11, 25, 12)), 'ogle');
    expect(OneriDeposu.bolumAdi(DateTime(2026, 11, 25, 20)), 'aksam');
  });

  test('Öneri paketi yapay zekadan alınır, geçersiz not kimlikleri ayıklanır, saat bildirimi sınıra göre kurulur', () async {
    final a = await depo.notEkle(metin: 'Dolabı düzenle', kaynak: Kaynak.yazili);
    final b = await depo.notEkle(metin: 'Kitabı bitir', kaynak: Kaynak.yazili);
    final simdi = DateTime(2026, 11, 25, 8, 0); // Çarşamba sabah
    AiServisi.istemciUret = () => MockClient((r) async => oneriYaniti([
          {'not_id': a.id, 'neden': '20 dk boşsun, 2 haftadır bekliyor', 'bildirim_saati': '19:30'},
          {'not_id': 'yok-boyle-bir-not', 'neden': 'uydurma', 'bildirim_saati': ''},
          {'not_id': b.id, 'neden': 'Kısa bir iş', 'bildirim_saati': ''},
        ]));
    await oneri.yenile(simdi: simdi);
    expect(oneri.sonHata, isNull);
    final p = oneri.paket!;
    expect(p.oneriler.map((o) => o.notId), [a.id, b.id]);
    expect(p.bolum, 'sabah');
    expect(p.plan, isNull); // Çarşamba: hafta sonu planı yok
    expect(oneri.paketGuncelMi(simdi), isTrue);
    expect(oneri.paketGuncelMi(DateTime(2026, 11, 25, 12)), isFalse); // öğle bölümü: yenilenmeli
    expect(oneri.gosterilecekler(simdi).length, 2);
    // Paket telefonda saklanır
    final yeni = OneriPaketi.coz(p.toJsonMetni())!;
    expect(yeni.oneriler.first.bildirimSaati, '19:30');
    expect(await BildirimServisi.instance.bugunkuSayi(simdi), 1);
  });

  test('Günlük bildirim sınırı: atılanlar sayılır, kalan hak kadar zamanlanır', () async {
    SharedPreferences.setMockInitialValues({});
    final simdi = DateTime(2026, 11, 25, 15, 0);
    final liste = [
      for (var i = 0; i < 4; i++) (notId: 'n$i', baslik: 'B$i', metin: 'M$i', zaman: DateTime(2026, 11, 25, 16 + i, 0)),
    ];
    final b = BildirimServisi.instance;
    expect(await b.oneriBildirimleriniKur(bildirimler: liste, sinir: 3, simdi: simdi), 3);
    expect(await b.bugunkuSayi(simdi), 3);
    // 17:30'da: ilk ikisi atılmış sayılır, yalnızca 1 hak kalır
    expect(await b.oneriBildirimleriniKur(bildirimler: liste, sinir: 3, simdi: DateTime(2026, 11, 25, 17, 30)), 1);
    expect(await b.oneriBildirimleriniKur(bildirimler: liste, sinir: 0, simdi: DateTime(2026, 11, 25, 17, 30)), 0);
  });

  test('Hafta sonu planı: Cuma günü yapay zekadan istenir ve plan notları döner', () async {
    final a = await depo.notEkle(metin: 'Parka git', kaynak: Kaynak.yazili);
    final b = await depo.notEkle(metin: 'Film izle', kaynak: Kaynak.yazili);
    final simdi = DateTime(2026, 11, 27, 11, 0); // Cuma öğle
    AiServisi.istemciUret = () => MockClient((r) async => oneriYaniti([], ogle: [a.id], aksam: [b.id, 'uydurma']));
    await oneri.yenile(simdi: simdi);
    final plan = oneri.haftaSonuPlani(simdi)!;
    expect(plan.gun, 'genel');
    expect(plan.ogle.map((n) => n.id), [a.id]);
    expect(plan.aksam.map((n) => n.id), [b.id]);
    expect(oneri.haftaSonuPlani(DateTime(2026, 11, 27, 23)), isNull); // 22'den sonra hedef değişti, plan yenilenmeli
  });

  test('Eylemler: adımlı notta sıradaki adım tamamlanır, sonra hatırlat yarına bırakır, öneriden çıkarır', () async {
    final n = await depo.notEkle(metin: 'Tabloyu as', kaynak: Kaynak.yazili);
    await depo.adimlariKaydet(n.id, [Adim(notId: n.id, sira: 0, metin: 'Ölç'), Adim(notId: n.id, sira: 1, metin: 'Çivile')]);
    var g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(await oneri.sonrakiAdimiTamamla(g), isTrue);
    g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(g.adimlar.where((a) => a.yapildi).length, 1);
    expect(await oneri.sonrakiAdimiTamamla(g), isTrue);
    g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(await oneri.sonrakiAdimiTamamla(g), isFalse); // adım kalmadı

    final simdi = DateTime(2026, 11, 25, 10);
    oneri.paket = OneriPaketi(
        olusturma: simdi.millisecondsSinceEpoch, bolum: 'sabah', gun: '2026-11-25', oneriler: [Oneri(notId: n.id, neden: 'x')]);
    expect(oneri.gosterilecekler(simdi), hasLength(1));
    await oneri.yarinaBirak(g, simdi: simdi);
    expect(oneri.gosterilecekler(simdi), isEmpty);
    expect(oneri.gosterilecekler(DateTime(2026, 11, 26, 10)), hasLength(1)); // ertesi gün yine girer
    expect(depo.notlar.firstWhere((x) => x.id == n.id).ertelemeSayisi, 1);
    expect(oneri.adaylar(simdi).any((x) => x.id == n.id), isFalse);
  });

  test('Şu an ne yapabilirim: süreye uyanlar gelir, eski dokunulmayan önce', () async {
    final kisa = await depo.notEkle(metin: 'Kısa iş (10dk)', kaynak: Kaynak.yazili);
    final uzun = await depo.notEkle(metin: 'Uzun iş (3 saat)', kaynak: Kaynak.yazili);
    kisa.sureDk = 10;
    uzun.sureDk = 180;
    await depo.notGuncelle(kisa);
    await depo.notGuncelle(uzun);
    final l15 = oneri.suAnNeYapabilirim(15, simdi: DateTime(2026, 11, 25, 20));
    expect(l15.map((n) => n.id), contains(kisa.id));
    expect(l15.map((n) => n.id), isNot(contains(uzun.id)));
    expect(oneri.suAnNeYapabilirim(240, simdi: DateTime(2026, 11, 25, 20)).length, lessThanOrEqualTo(3));
  });
}
