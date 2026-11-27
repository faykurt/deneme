import 'dart:convert';
import 'dart:io';

import 'package:aklimda/ai/ai_ayarlar.dart';
import 'package:aklimda/ai/ai_servisi.dart';
import 'package:aklimda/ekranlar/tarif_sayfasi.dart';
import 'package:material_ui/material_ui.dart';
import 'package:aklimda/tarif/tarif_ayristirici.dart';
import 'package:aklimda/tarif/tarif_ice_aktar.dart';
import 'package:aklimda/tarif/tarif_modeli.dart';
import 'package:aklimda/veri/depo.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SahtePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String yol;
  _SahtePathProvider(this.yol);
  @override
  Future<String?> getApplicationDocumentsPath() async => yol;
}

// 1x1 şeffaf PNG
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

const _sayfa = '''
<html><head><meta property="og:image" content="/img/og.jpg">
<script type="application/ld+json">
{"@context":"https://schema.org","@graph":[{"@type":"WebSite","name":"Site"},
{"@type":"Recipe","name":"Fırında Sütlaç &amp; Kaymak","image":["/img/sutlac.jpg"],
 "description":"<p>Kremamsı bir tatlı.</p>","prepTime":"PT15M","cookTime":"PT1H20M","totalTime":"PT1H35M","recipeYield":["6","6 kişilik"],
 "recipeCategory":"Tatlılar","recipeIngredient":["1 litre süt","1 çay bardağı pirinç"," 3 yemek kaşığı şeker"],
 "recipeInstructions":[{"@type":"HowToStep","text":"Pirinci haşla.","image":"/img/adim1.jpg"},
  {"@type":"HowToSection","itemListElement":[{"@type":"HowToStep","text":"Sütü ekle ve pişir."}]},"Fırında kızart."]}]}
</script></head><body>x</body></html>
''';

void main() {
  late Directory gecici;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr');
    gecici = await Directory.systemTemp.createTemp('aklimda_tarif');
    PathProviderPlatform.instance = _SahtePathProvider(gecici.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(gecici.path);
    FlutterSecureStorage.setMockInitialValues({});
    await Depo.instance.ac();
  });
  tearDown(() {
    TarifIceAktar.istemciUret = http.Client.new;
    AiServisi.istemciUret = http.Client.new;
  });
  tearDownAll(() => gecici.delete(recursive: true));

  test('Sayfadaki düzenli tarif verisi okunur: süre, kişi, malzeme, adımlar, kategori', () {
    final r = TarifAyristirici.recipeBul(_sayfa)!;
    final c = TarifAyristirici.tarifCikar(r, kaynakUrl: 'https://site.com/sutlac')!;
    expect(c.tarif.baslik, 'Fırında Sütlaç & Kaymak');
    expect(c.tarif.aciklama, 'Kremamsı bir tatlı.');
    expect(c.tarif.hazirlikDk, 15);
    expect(c.tarif.pisirmeDk, 80);
    expect(c.tarif.toplamDk, 95);
    expect(c.tarif.sure, 95);
    expect(c.tarif.kisi, '6 kişilik');
    expect(c.tarif.kategori, 'Tatlılar');
    expect(c.tarif.malzemeler, ['1 litre süt', '1 çay bardağı pirinç', '3 yemek kaşığı şeker']);
    expect(c.tarif.adimlar.map((a) => a.metin), ['Pirinci haşla.', 'Sütü ekle ve pişir.', 'Fırında kızart.']);
    expect(c.kapakUrl, '/img/sutlac.jpg');
    expect(c.adimResimUrlleri, ['/img/adim1.jpg', null, null]);
    expect(TarifAyristirici.sureDk('PT1H'), 60);
    expect(TarifAyristirici.sureDk('PT45M'), 45);
    expect(Tarif.sureMetni(95), '1 sa 35 dk');
  });

  test('Kategori bulma: site kategorisi ya da başlıktan', () {
    expect(TarifKategorileri.bul('Ana Yemekler', 'Tavuk sote'), 'Ana yemekler');
    expect(TarifKategorileri.bul(null, 'Mercimek çorbası'), 'Çorbalar');
    expect(TarifKategorileri.bul('', 'Cheesecake'), 'Tatlılar');
    expect(TarifKategorileri.bul('', 'Peynirli börek'), 'Hamur işleri');
    expect(TarifKategorileri.bul('', 'Bilinmeyen'), 'Diğer tarifler');
  });

  test('Bağlantıdan tarif alınır, resimler indirilir ve yemek kitabında bölümüne kaydedilir', () async {
    TarifIceAktar.istemciUret = () => MockClient((r) async {
          if (r.url.path.endsWith('.jpg')) return http.Response.bytes(_png, 200);
          return http.Response.bytes(utf8.encode(_sayfa), 200);
        });
    final sonuc = await TarifIceAktar.urlden('https://site.com/tarif/sutlac');
    expect(sonuc.tarif.baslik, 'Fırında Sütlaç & Kaymak');
    expect(sonuc.kapakDosya, isNotNull);
    expect(File(sonuc.kapakDosya!).existsSync(), isTrue);
    expect(sonuc.adimDosyalari.first, isNotNull);

    final not = await Depo.instance.tarifEkle(sonuc.tarif, kapakDosya: sonuc.kapakDosya, adimDosyalari: sonuc.adimDosyalari);
    expect(not.tarifMi, isTrue);
    expect(not.fotograflar.length, 2); // kapak + ilk adımın resmi
    final t = not.tarif!;
    expect(t.adimlar.first.resim, not.fotograflar[1]);
    expect(t.kaynakUrl, 'https://site.com/tarif/sutlac');
    final agac = Depo.instance.agac;
    final yemek = agac.anaKategoriler.firstWhere((k) => k.ad == 'Yemek');
    final bolum = agac.altlari(yemek.id).firstWhere((k) => k.ad == 'Tatlılar');
    expect(not.kategoriIdler, [bolum.id]);
    // aynı bölüm ikinci tarifte yeniden kullanılır
    final ikinci = await Depo.instance.tarifEkle(const Tarif(baslik: 'Kek', kategori: 'Tatlılar', malzemeler: ['un']));
    expect(ikinci.kategoriIdler, [bolum.id]);
  });

  test('Instagram bağlantısı okunamaz, açıklayıcı mesaj verir; paylaşılan metinden bağlantı bulunur', () async {
    await expectLater(TarifIceAktar.urlden('https://www.instagram.com/reel/abc/'), throwsA(isA<TarifHatasi>()));
    expect(TarifIceAktar.baglantiBul('Bak şu tarife https://site.com/t?x=1 harika'), 'https://site.com/t?x=1');
    expect(TarifIceAktar.baglantiBul('bağlantı yok'), isNull);
  });

  test('Düzenli veri yoksa yapay zeka sayfa metninden tarifi çıkarır', () async {
    await AiAyarlar.instance.kaydet('sk-ant-deneme');
    TarifIceAktar.istemciUret = () => MockClient((r) async => http.Response.bytes(utf8.encode('<html><body><h1>Kek</h1><p>2 yumurta, 1 bardak un. Karıştır ve fırınla.</p></body></html>'), 200));
    AiServisi.istemciUret = () => MockClient((r) async => http.Response.bytes(
        utf8.encode(jsonEncode({
          'stop_reason': 'end_turn',
          'content': [
            {
              'type': 'text',
              'text': jsonEncode({
                'baslik': 'Basit Kek',
                'kategori': 'Tatlılar',
                'hazirlik_dk': 10,
                'pisirme_dk': 35,
                'toplam_dk': 45,
                'kisi': '8 kişilik',
                'aciklama': '',
                'malzemeler': ['2 yumurta', '1 bardak un'],
                'adimlar': ['Karıştır.', 'Fırınla.'],
              })
            },
          ],
        })),
        200,
        headers: {'content-type': 'application/json'}));
    final s = await TarifIceAktar.urlden('https://site.com/kek');
    expect(s.tarif.baslik, 'Basit Kek');
    expect(s.tarif.sure, 45);
    expect(s.tarif.adimlar.length, 2);
    expect(s.tarif.kategori, 'Tatlılar');
  });

  testWidgets('Tarif sayfası süreyi, malzemeleri ve adımları gösterir; malzeme işareti kalıcıdır', (t) async {
    late String id;
    await t.runAsync(() async {
      final n = await Depo.instance.tarifEkle(const Tarif(
          baslik: 'Sayfa Kek', kategori: 'Tatlılar', toplamDk: 50, kisi: '4 kişilik', malzemeler: ['2 yumurta', '1 bardak un'],
          adimlar: [TarifAdimi('Karıştır.'), TarifAdimi('Fırınla.')], kaynakUrl: 'https://site.com/kek'));
      id = n.id;
    });
    await t.pumpWidget(MaterialApp(home: TarifSayfasi(notId: id)));
    await t.pump();
    expect(find.text('Sayfa Kek'), findsOneWidget);
    expect(find.text('50 dk'), findsOneWidget);
    expect(find.text('4 kişilik'), findsOneWidget);
    expect(find.text('2 yumurta'), findsOneWidget);
    expect(find.text('Karıştır.'), findsOneWidget);
    expect(find.text('Kaynağı aç'), findsOneWidget);
    await t.tap(find.text('2 yumurta'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump();
    final n = Depo.instance.notlar.firstWhere((x) => x.id == id);
    expect(n.tarif!.isaretli, [0]);
  });
}
