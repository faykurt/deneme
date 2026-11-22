import 'dart:convert';
import 'dart:io';

import 'package:aklimda/ai/ai_ayarlar.dart';
import 'package:aklimda/ai/ai_modeller.dart';
import 'package:aklimda/ai/ai_servisi.dart';
import 'package:aklimda/ai/isleyici.dart';
import 'package:aklimda/veri/depo.dart';
import 'package:aklimda/veri/modeller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SahtePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String yol;
  _SahtePathProvider(this.yol);
  @override
  Future<String?> getApplicationDocumentsPath() async => yol;
}

/// Uygulamanın 1. sürümündeki (0.2.x) veritabanı şeması.
const _v1 = [
  '''CREATE TABLE notlar (
    id TEXT PRIMARY KEY, metin TEXT NOT NULL DEFAULT '', baslik TEXT, kaynak TEXT NOT NULL,
    olusturma INTEGER NOT NULL, guncelleme INTEGER NOT NULL, durum TEXT NOT NULL DEFAULT 'yapilacak',
    arsiv INTEGER NOT NULL DEFAULT 0, silindi INTEGER NOT NULL DEFAULT 0, onayli INTEGER NOT NULL DEFAULT 0,
    islendi INTEGER NOT NULL DEFAULT 0, sure_dk INTEGER, tarih INTEGER, tarih_saatli INTEGER NOT NULL DEFAULT 0,
    hatirlatma INTEGER, link TEXT, yorum TEXT, son_dokunma INTEGER NOT NULL,
    erteleme_sayisi INTEGER NOT NULL DEFAULT 0, gormezden_sayisi INTEGER NOT NULL DEFAULT 0, takvim_etkinlik_id TEXT)''',
  '''CREATE TABLE kategoriler (id INTEGER PRIMARY KEY AUTOINCREMENT, ad TEXT NOT NULL,
    ust_id INTEGER REFERENCES kategoriler(id) ON DELETE CASCADE, sira INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE not_kategori (not_id TEXT NOT NULL REFERENCES notlar(id) ON DELETE CASCADE,
    kategori_id INTEGER NOT NULL REFERENCES kategoriler(id) ON DELETE CASCADE, PRIMARY KEY (not_id, kategori_id))''',
  '''CREATE TABLE fotograflar (id INTEGER PRIMARY KEY AUTOINCREMENT,
    not_id TEXT NOT NULL REFERENCES notlar(id) ON DELETE CASCADE, dosya TEXT NOT NULL, sira INTEGER NOT NULL DEFAULT 0)''',
  '''CREATE TABLE adimlar (id INTEGER PRIMARY KEY AUTOINCREMENT,
    not_id TEXT NOT NULL REFERENCES notlar(id) ON DELETE CASCADE, sira INTEGER NOT NULL, metin TEXT NOT NULL,
    sure_dk INTEGER, durum TEXT NOT NULL DEFAULT 'yapilacak')''',
];

Map<String, dynamic> _fikir(String baslik, {List<int> kat = const [], int sure = 30, bool is_ = false}) => {
      'metin': baslik,
      'baslik': baslik,
      'kategori_idler': kat,
      'yeni_kategori_ad': '',
      'yeni_kategori_ust_id': 0,
      'sure_dk': sure,
      'tarih': '2026-12-19T14:30',
      'tarih_saatli': true,
      'yapilabilir_is': is_,
      'adimlar': is_
          ? [
              {'metin': 'Ölç', 'sure_dk': 5, 'bekleme': false},
              {'metin': 'Sipariş ver', 'sure_dk': 10, 'bekleme': false},
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
  late int hobiId;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr');
    gecici = await Directory.systemTemp.createTemp('aklimda_test');
    PathProviderPlatform.instance = _SahtePathProvider(gecici.path);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(gecici.path);

    // 1. sürüm bir veritabanı hazırla: bir kategori ve iki not (biri arşivde).
    final eski = await databaseFactoryFfi.openDatabase(p.join(gecici.path, 'aklimda.db'),
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              for (final s in _v1) {
                await db.execute(s);
              }
              await db.insert('kategoriler', {'ad': 'Hobi'});
              await db.insert('notlar', {
                'id': 'eski1', 'metin': 'Eski bir not', 'kaynak': 'yazili',
                'olusturma': 1, 'guncelleme': 1, 'son_dokunma': 1,
              });
              await db.insert('notlar', {
                'id': 'eski2', 'metin': 'Arşivdeki not', 'kaynak': 'sesli',
                'olusturma': 2, 'guncelleme': 2, 'son_dokunma': 2, 'arsiv': 1,
              });
              await db.insert('not_kategori', {'not_id': 'eski1', 'kategori_id': 1});
            }));
    await eski.close();

    FlutterSecureStorage.setMockInitialValues({});
    await depo.ac();
    hobiId = depo.kategoriler.first.id;
  });

  tearDown(() => AiServisi.istemciUret = http.Client.new);
  tearDownAll(() => gecici.delete(recursive: true));

  test('Eski veritabanı güncellenir, notlar ve kategoriler korunur', () {
    expect(depo.notlar.map((n) => n.id), containsAll(['eski1', 'eski2']));
    final n = depo.notlar.firstWhere((n) => n.id == 'eski1');
    expect(n.metin, 'Eski bir not');
    expect(n.kategoriIdler, [hobiId]);
    expect(n.onayli, isTrue, reason: 'eski notlar "onay bekleyen" yığını oluşturmamalı');
    expect(n.islendi, isFalse);
    expect(n.aiJson, isNull);
    expect(depo.arsivNotlari.single.id, 'eski2');
    expect(depo.onayBekleyenler, isEmpty);
  });

  test('Adımlar kaydedilir, işaretlenir, silinir ve notla birlikte yüklenir', () async {
    final n = await depo.notEkle(metin: 'Tablo asılacak', kaynak: Kaynak.yazili);
    await depo.adimlariKaydet(n.id, [
      Adim(notId: n.id, sira: 0, metin: 'Ölç', sureDk: 5),
      Adim(notId: n.id, sira: 1, metin: 'Sipariş ver', sureDk: 10),
      Adim(notId: n.id, sira: 2, metin: 'Kargo bekle', bekleme: true),
    ]);
    var g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(g.adimlar.map((a) => a.metin), ['Ölç', 'Sipariş ver', 'Kargo bekle']);
    expect(g.adimlar.last.bekleme, isTrue);
    await depo.adimDurumu(g.adimlar.first.id!, Durum.yapildi);
    g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(g.adimlar.first.yapildi, isTrue);
    expect(g.adimlar.where((a) => !a.yapildi), hasLength(2));
    // Ortadaki adımı sil: kalanlar sırasını korur
    await depo.adimlariKaydet(n.id, g.adimlar.where((a) => a.metin != 'Sipariş ver').toList());
    g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(g.adimlar.map((a) => a.metin), ['Ölç', 'Kargo bekle']);
    expect(g.adimlar.first.yapildi, isTrue);
    await depo.sil([n.id]);
  });

  test('Yapay zeka bekleyen notları işler: başlık, süre, tarih, kategori yazılır, onay bekler', () async {
    await AiAyarlar.instance.kaydet(' sk-ant-deneme\n');
    expect(AiAyarlar.instance.anahtar, 'sk-ant-deneme', reason: 'boşluk ve satır sonu temizlenmeli');

    final istekler = <Map<String, dynamic>>[];
    AiServisi.istemciUret = () => MockClient((r) async {
          istekler.add(jsonDecode(r.body) as Map<String, dynamic>);
          return _ok([_fikir('Eski not başlığı', kat: [hobiId, 99999], sure: 20)]);
        });
    await AiIsleyici.instance.bekleyenleriIsle();

    // eski1 ve eski2 işlenmemişti → ikisi de işlendi
    expect(istekler.length, greaterThanOrEqualTo(2));
    final n = depo.notlar.firstWhere((x) => x.id == 'eski1');
    expect(n.islendi, isTrue);
    expect(n.baslik, 'Eski not başlığı');
    expect(n.sureDk, 20);
    expect(n.tarih, DateTime(2026, 12, 19, 14, 30).millisecondsSinceEpoch);
    expect(n.tarihSaatli, isTrue);
    expect(n.kategoriIdler, [hobiId], reason: 'notta kategori vardı, yapay zeka üzerine yazmamalı');
    expect(n.onayli, isTrue, reason: 'eski notlar zaten onaylı');
    expect(AiIsleyici.instance.sonHata, isNull);
  });

  test('Yeni not işlenince onay bekleyenlere düşer, geçersiz kategori yok sayılır', () async {
    final n = await depo.notEkle(metin: 'Yarın doktora git', kaynak: Kaynak.sesli);
    expect(n.islendi, isFalse);
    expect(depo.onayBekleyenler, isEmpty, reason: 'işlenmeden onay beklemez');
    AiServisi.istemciUret = () => MockClient((r) async => _ok([_fikir('Doktora git', kat: [99999])]));
    final hata = await AiIsleyici.instance.hemenIsle(n);
    expect(hata, isNull);
    final g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(g.islendi, isTrue);
    expect(g.baslik, 'Doktora git');
    expect(g.kategoriIdler, isEmpty);
    expect(g.onayBekliyor, isTrue);
    expect(depo.onayBekleyenler.map((x) => x.id), contains(n.id));
    await depo.onayla([n.id]);
    expect(depo.onayBekleyenler.map((x) => x.id), isNot(contains(n.id)));
  });

  test('İnternet yokken not bekler, bağlantı gelince işlenir', () async {
    final n = await depo.notEkle(metin: 'Çevrimdışı not', kaynak: Kaynak.yazili);
    AiServisi.istemciUret = () => MockClient((r) async => throw const SocketException('yok'));
    await AiIsleyici.instance.bekleyenleriIsle();
    expect(AiIsleyici.instance.sonHata?.tur, AiHataTuru.cevrimdisi);
    var g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(g.islendi, isFalse);
    expect(g.baslik, isNull);
    expect(depo.onayBekleyenler.map((x) => x.id), isNot(contains(n.id)));

    AiServisi.istemciUret = () => MockClient((r) async => _ok([_fikir('Çevrimdışı not düzenlendi')]));
    await AiIsleyici.instance.bekleyenleriIsle();
    g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(g.islendi, isTrue);
    expect(g.baslik, 'Çevrimdışı not düzenlendi');
    expect(g.onayBekliyor, isTrue);
    expect(AiIsleyici.instance.sonHata, isNull);
  });

  test('Boş not yapay zekaya gönderilmez', () async {
    final n = await depo.notEkle(metin: '   ', kaynak: Kaynak.yazili);
    var cagri = 0;
    AiServisi.istemciUret = () => MockClient((r) async {
          cagri++;
          return _ok([_fikir('x')]);
        });
    expect(await AiIsleyici.instance.hemenIsle(n), isNull);
    expect(cagri, 0);
    expect(depo.notlar.firstWhere((x) => x.id == n.id).islendi, isTrue);
  });

  test('Birden fazla fikir ayrı notlara bölünür', () async {
    final n = await depo.notEkle(metin: 'Kargoyu gönder, bir de Ayşe\'nin önerdiği diziyi kaydet', kaynak: Kaynak.sesli);
    final fikirler = [
      AiFikir.fromJson(_fikir('Kargoyu gönder', kat: [], sure: 15)),
      AiFikir.fromJson(_fikir('Ayşe\'nin önerdiği dizi', kat: [hobiId], sure: 45)),
    ]..[0].metin = 'Kargoyu gönder';
    fikirler[1].metin = 'Ayşe\'nin önerdiği diziyi kaydet';
    final once = depo.notlar.length;
    await AiIsleyici.instance.bol(depo.notlar.firstWhere((x) => x.id == n.id), fikirler);
    expect(depo.notlar.length, once + 1);
    final ilk = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(ilk.metin, 'Kargoyu gönder');
    expect(ilk.baslik, 'Kargoyu gönder');
    final yeni = depo.notlar.firstWhere((x) => x.metin == 'Ayşe\'nin önerdiği diziyi kaydet');
    expect(yeni.kategoriIdler, [hobiId]);
    expect(yeni.islendi, isTrue);
    expect(yeni.onayBekliyor, isTrue);
    expect(yeni.kaynak, Kaynak.sesli);
  });

  test('Çoklu fikirde nota hiçbir alan yazılmaz, öneri kayıtlı kalır', () async {
    final n = await depo.notEkle(metin: 'İki şey var', kaynak: Kaynak.sesli);
    AiServisi.istemciUret = () => MockClient((r) async => _ok([_fikir('Birinci'), _fikir('İkinci')]));
    await AiIsleyici.instance.hemenIsle(n);
    final g = depo.notlar.firstWhere((x) => x.id == n.id);
    expect(g.islendi, isTrue);
    expect(g.baslik, isNull, reason: 'bölme kararı kullanıcıda');
    expect(AiSonuc.coz(g.aiJson)!.fikirler, hasLength(2));
  });

  test('Kategori ekleme id döndürür, silme notları Kategorisiz bırakır', () async {
    final n = await depo.notEkle(metin: 'Spor notu', kaynak: Kaynak.yazili);
    final id = await depo.kategoriEkle('Spor');
    expect(id, greaterThan(0));
    await depo.kategorileriAyarla(n.id, [id]);
    expect(depo.notlar.firstWhere((x) => x.id == n.id).kategoriIdler, [id]);
    await depo.kategoriSil(id);
    expect(depo.notlar.firstWhere((x) => x.id == n.id).kategoriIdler, isEmpty);
  });

  test('Arşivle, geri al ve sil/geri al çalışır', () async {
    final n = await depo.notEkle(metin: 'Arşiv denemesi', kaynak: Kaynak.yazili);
    await depo.arsivle([n.id], true);
    expect(depo.arsivNotlari.map((x) => x.id), contains(n.id));
    await depo.arsivle([n.id], false);
    expect(depo.aktifNotlar.map((x) => x.id), contains(n.id));
    await depo.sil([n.id]);
    expect(depo.notlar.map((x) => x.id), isNot(contains(n.id)));
    await depo.silmeyiGeriAl([n.id]);
    expect(depo.notlar.map((x) => x.id), contains(n.id));
  });
}
