import 'dart:io';

import 'package:aklimda/ai/ai_ayarlar.dart';
import 'package:aklimda/ai/ai_harcama.dart';
import 'package:aklimda/ai/ai_servisi.dart';
import 'package:aklimda/ai/ai_zamanlama.dart';
import 'package:aklimda/ai/isleyici.dart';
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

void main() {
  late Directory gecici;
  final depo = Depo.instance;
  final z = AiZamanlama.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr');
    gecici = await Directory.systemTemp.createTemp('aklimda_zamanlama');
    PathProviderPlatform.instance = _SahtePathProvider(gecici.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(gecici.path);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await depo.ac();
    await AiAyarlar.instance.kaydet('sk-ant-deneme');
  });
  tearDownAll(() => gecici.delete(recursive: true));
  tearDown(() => AiServisi.istemciUret = http.Client.new);

  group('Çalışma saatleri', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await z.yukle();
      await z.saatleriAyarla([13 * 60, 21 * 60]);
    });

    test('Varsayılan saatler 13:00 ve 21:00', () async {
      SharedPreferences.setMockInitialValues({});
      await z.yukle();
      expect(z.saatler.map(AiZamanlama.saatMetni), ['13:00', '21:00']);
      expect(z.ozet, '13:00 ve 21:00');
    });

    test('Son saat: sabah dünkü 21:00, öğleden sonra 13:00, geceyarısından önce 21:00', () {
      expect(z.sonSlot(DateTime(2026, 11, 24, 9)), DateTime(2026, 11, 23, 21));
      expect(z.sonSlot(DateTime(2026, 11, 24, 13)), DateTime(2026, 11, 24, 13));
      expect(z.sonSlot(DateTime(2026, 11, 24, 20, 59)), DateTime(2026, 11, 24, 13));
      expect(z.sonSlot(DateTime(2026, 11, 24, 23, 59)), DateTime(2026, 11, 24, 21));
      expect(z.sonSlot(DateTime(2026, 12, 1, 0, 30)), DateTime(2026, 11, 30, 21), reason: 'ay sınırı');
    });

    test('Sonraki saat ve okunur metin', () {
      expect(z.sonrakiSlot(DateTime(2026, 11, 24, 9)), DateTime(2026, 11, 24, 13));
      expect(z.sonrakiSlot(DateTime(2026, 11, 24, 13)), DateTime(2026, 11, 24, 21));
      expect(z.sonrakiSlot(DateTime(2026, 11, 24, 22)), DateTime(2026, 11, 25, 13));
      expect(z.sonrakiMetni(DateTime(2026, 11, 24, 9)), 'bugün 13:00');
      expect(z.sonrakiMetni(DateTime(2026, 11, 24, 22)), 'yarın 13:00');
    });

    test('Aynı iki saat seçilirse günde bir kez çalışır; ayar telefonda saklanır', () async {
      await z.saatleriAyarla([20 * 60 + 30, 20 * 60 + 30]);
      expect(z.saatler, [20 * 60 + 30]);
      expect(z.sonrakiMetni(DateTime(2026, 11, 24, 9)), 'bugün 20:30');
      await z.yukle();
      expect(z.saatler, [20 * 60 + 30]);
    });

    test('Boş saat listesi kabul edilmez', () async {
      await z.saatleriAyarla([]);
      expect(z.saatler, isNotEmpty);
    });
  });

  group('Zamanlanmış işleme', () {
    String? sonModel;
    var cagri = 0;

    http.Response ok(String model) => http.Response.bytes(
        [
          ...'{"model":"$model","usage":{"input_tokens":1000,"output_tokens":200},'
              '"stop_reason":"end_turn","content":[{"type":"text","text":"{\\"fikirler\\":[{\\"metin\\":\\"x\\",\\"baslik\\":\\"B\\",\\"kategori_idler\\":[],\\"yeni_kategori_ad\\":\\"\\",\\"yeni_kategori_ust_id\\":0,\\"sure_dk\\":10,\\"tarih\\":\\"\\",\\"tarih_saatli\\":false,\\"yapilabilir_is\\":false,\\"adimlar\\":[]}]}"}]}'
              .codeUnits
        ],
        200,
        headers: {'content-type': 'application/json'});

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await z.yukle();
      await z.saatleriAyarla([13 * 60, 21 * 60]);
      cagri = 0;
      AiServisi.istemciUret = () => MockClient((r) async {
            cagri++;
            sonModel = (r.body.contains('"claude-haiku-5-5"')) ? 'haiku' : 'sonnet';
            return ok(sonModel == 'haiku' ? 'claude-haiku-5-5' : 'claude-sonnet-5-5');
          });
    });

    Future<Not> notAt(String metin, DateTime zaman) async {
      final n = await depo.notEkle(metin: metin, kaynak: Kaynak.yazili);
      n.olusturma = zaman.millisecondsSinceEpoch;
      await depo.notGuncelle(n);
      return n;
    }

    Not guncel(Not n) => depo.notlar.firstWhere((x) => x.id == n.id);

    test('Saatten önce kaydedilen not o saat geçince işlenir, sonra kaydedilen bir sonrakini bekler', () async {
      // Önceki testlerden kalan işlenmemiş notları sıfırla
      for (final n in depo.notlar.where((n) => !n.islendi)) {
        n.islendi = true;
        await depo.notGuncelle(n);
      }
      final once = await notAt('Öğleden önce yazdım', DateTime(2026, 11, 24, 11));
      final sonra = await notAt('Öğleden sonra yazdım', DateTime(2026, 11, 24, 14));

      // 13:30: 13:00 saati geçti → sadece 11:00'deki işlenir
      await AiIsleyici.instance.zamanlanmisIsle(simdi: DateTime(2026, 11, 24, 13, 30));
      expect(guncel(once).islendi, isTrue);
      expect(guncel(sonra).islendi, isFalse);
      expect(cagri, 1);

      // 14:30: yeni saat gelmedi → ağa hiç çıkmaz
      await AiIsleyici.instance.zamanlanmisIsle(simdi: DateTime(2026, 11, 24, 14, 30));
      expect(cagri, 1, reason: 'işlenecek bir şey yokken istek atılmamalı');

      // 21:05: 21:00 saati geçti → 14:00'deki işlenir
      await AiIsleyici.instance.zamanlanmisIsle(simdi: DateTime(2026, 11, 24, 21, 5));
      expect(guncel(sonra).islendi, isTrue);
      expect(cagri, 2);
    });

    test('"Şimdi işle" saati beklemeden hepsini işler', () async {
      for (final n in depo.notlar.where((n) => !n.islendi)) {
        n.islendi = true;
        await depo.notGuncelle(n);
      }
      final a = await depo.notEkle(metin: 'Hemen işlensin', kaynak: Kaynak.yazili);
      expect(AiIsleyici.instance.bekleyenSayisi, 1);
      await AiIsleyici.instance.bekleyenleriIsle();
      expect(guncel(a).islendi, isTrue);
      expect(AiIsleyici.instance.bekleyenSayisi, 0);
    });

    test('Kullanım harcama sayacına işlenir ve ay değişince sıfırlanır', () async {
      SharedPreferences.setMockInitialValues({});
      final h = AiHarcama.instance;
      await h.yukle(simdi: DateTime(2026, 11, 10));
      AiServisi.kullanimDinleyici = (m, g, c) => h.kaydet(m, g, c, simdi: DateTime(2026, 11, 10));
      addTearDown(() => AiServisi.kullanimDinleyici = null);
      for (final n in depo.notlar.where((n) => !n.islendi)) {
        n.islendi = true;
        await depo.notGuncelle(n);
      }
      final a = await depo.notEkle(metin: 'Sayaç denemesi', kaynak: Kaynak.yazili);
      await AiIsleyici.instance.hemenIsle(a);
      expect(h.istek, 1);
      expect(h.girdi, 1000);
      expect(h.cikti, 200);
      expect(h.dolar, closeTo(1000 * 0.10 / 1e6 + 200 * 0.50 / 1e6, 1e-12));
      expect(h.dolarMetni, '1 sentten az');
      // yeniden yükle: değerler saklanmış olmalı
      await h.yukle(simdi: DateTime(2026, 11, 20));
      expect(h.istek, 1);
      // ay değişince sıfırlanır
      await h.yukle(simdi: DateTime(2026, 12, 1));
      expect(h.istek, 0);
      expect(h.dolarMetni, '0 \$');
    });

    test('Harcama metni: sent ve dolar biçimleri', () async {
      final h = AiHarcama.instance;
      SharedPreferences.setMockInitialValues({});
      await h.yukle(simdi: DateTime(2026, 11, 10));
      await h.kaydet('claude-sonnet-5-5', 1000000, 150000, simdi: DateTime(2026, 11, 10));
      // 2.0 + 1.5 = 3.5
      expect(h.dolarMetni, 'yaklaşık 3,50 \$');
      expect(h.ozet, contains('1 istek'));
    });
  });
}
