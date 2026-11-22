import 'dart:io';

import 'package:aklimda/ekranlar/yaptin_mi.dart';
import 'package:aklimda/takvim/takvim_ayarlari.dart';
import 'package:aklimda/takvim/takvim_deposu.dart';
import 'package:aklimda/takvim/takvim_modeller.dart';
import 'package:aklimda/veri/depo.dart';
import 'package:aklimda/veri/modeller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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
  final depo = Depo.instance;
  final ayar = TakvimAyarlari.instance;
  late SahteTakvim sahte;
  late TakvimDeposu td;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('tr');
    gecici = await Directory.systemTemp.createTemp('aklimda_takvim');
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
    sahte = SahteTakvim(etkinlikler: [
      etk('a', 'Toplantı', DateTime(2026, 11, 24, 10), DateTime(2026, 11, 24, 11), takvim: 'sam'),
      etk('b', 'Google etkinliği', DateTime(2026, 11, 24, 12), DateTime(2026, 11, 24, 13), takvim: 'goog'),
      etk('c', 'Haftalık', DateTime(2026, 11, 25, 9), DateTime(2026, 11, 25, 10), takvim: 'sam', tekrarli: true),
    ]);
    td = TakvimDeposu(sahte, ayar);
  });

  test('İzin yokken hazır değildir, izin verilince takvimler gelir', () async {
    await td.baslat();
    expect(td.izinVar, isFalse);
    expect(td.hazir, isFalse);
    expect(await td.izinIste(), isTrue);
    expect(td.takvimler.map((t) => t.id), containsAll(['sam', 'goog', 'tatil']));
  });

  test('İzin reddedilirse izinVar false kalır', () async {
    sahte.izinVerilir = false;
    await td.baslat();
    expect(await td.izinIste(), isFalse);
    expect(td.takvimler, isEmpty);
  });

  test('Etkinlik sayıları takvim başına hesaplanır', () async {
    sahte.izin = true;
    await td.baslat();
    // Tarihten bağımsız olsun diye etkinlikleri şu ana göre koy
    final simdi = DateTime.now();
    sahte.ev = [
      etk('x', 'Bugün', simdi, simdi.add(const Duration(hours: 1)), takvim: 'goog'),
      etk('y', 'Bugün de', simdi, simdi.add(const Duration(hours: 1)), takvim: 'goog'),
      etk('z', 'Çok uzak', simdi.add(const Duration(days: 200)), simdi.add(const Duration(days: 200, hours: 1)), takvim: 'sam'),
    ];
    final s = await td.etkinlikSayilari();
    expect(s['goog'], 2);
    expect(s['sam'], isNull, reason: '3 aylık pencerenin dışındaki etkinlik sayılmaz');
  });

  test('Sadece seçili takvimin etkinlikleri yüklenir', () async {
    sahte.izin = true;
    await td.baslat();
    await td.takvimSec(td.takvimler.firstWhere((t) => t.id == 'sam'));
    expect(ayar.takvimId, 'sam');
    expect(ayar.takvimAdi, 'Samsung takvimim');
    await td.yukle(DateTime(2026, 11, 1), DateTime(2026, 12, 1));
    expect(td.etkinlikler.map((e) => e.baslik), ['Toplantı', 'Haftalık']);
    expect(td.gununEtkinlikleri(DateTime(2026, 11, 24)).single.baslik, 'Toplantı');
  });

  test('Seçilen takvim telefonda kalmamışsa seçim sıfırlanır', () async {
    sahte.izin = true;
    await ayar.takvimSec('yok-boyle', 'Silinmiş takvim');
    await td.baslat();
    expect(ayar.takvimId, isNull);
  });

  test('Takvim hatası uygulamayı çökertmez, mesaj olarak tutulur', () async {
    sahte.izin = true;
    await td.baslat();
    await ayar.takvimSec('sam', 'S');
    sahte.hataFirlat = true;
    await td.yukle(DateTime(2026, 11, 1), DateTime(2026, 12, 1));
    expect(td.hata, 'Sahte hata');
  });

  test('Gün etkinlikleri sıralanır: tüm gün önce, sonra saate göre', () async {
    sahte.izin = true;
    sahte.ev.addAll([
      etk('t', 'Tüm gün', DateTime(2026, 11, 24), DateTime(2026, 11, 25), tumGun: true),
      etk('e', 'Erken', DateTime(2026, 11, 24, 8), DateTime(2026, 11, 24, 9)),
    ]);
    await td.baslat();
    await ayar.takvimSec('sam', 'S');
    await td.yukle(DateTime(2026, 11, 1), DateTime(2026, 12, 1));
    expect(td.gununEtkinlikleri(DateTime(2026, 11, 24)).map((e) => e.baslik), ['Tüm gün', 'Erken', 'Toplantı']);
  });

  test('Ekle, güncelle, sil: liste yenilenir ve takvime yazılır', () async {
    sahte.izin = true;
    await td.baslat();
    await ayar.takvimSec('sam', 'S');
    await td.yukle(DateTime(2026, 11, 1), DateTime(2026, 12, 1));
    final id = await td.ekle(TEtkinlikTaslagi(
        baslik: '💭 Tablo', baslangic: DateTime(2026, 11, 26, 18), bitis: DateTime(2026, 11, 26, 18, 30)));
    expect(td.etkinlikler.any((e) => e.eventId == id && e.uygulamaninMi && e.takvimId == 'sam'), isTrue);
    final e = td.etkinlikler.firstWhere((e) => e.eventId == id);
    await td.guncelle(e, TEtkinlikTaslagi(baslik: '💭 Tablo asmak', baslangic: e.baslangic, bitis: e.bitis), Kapsam.hepsi);
    expect(td.etkinlikler.firstWhere((x) => x.eventId == id).baslik, '💭 Tablo asmak');
    await td.sil(td.etkinlikler.firstWhere((x) => x.eventId == id), Kapsam.hepsi);
    expect(td.etkinlikler.any((x) => x.eventId == id), isFalse);
    expect(sahte.gunluk.where((g) => g.startsWith('sil:hepsi')), isNotEmpty);
  });

  test('Notu bağla, takvimde taşınırsa saatler güncellenir ve "yaptın mı" sıfırlanır', () async {
    sahte.izin = true;
    await td.baslat();
    await ayar.takvimSec('sam', 'S');
    final not = await depo.notEkle(metin: 'Bağlı not', kaynak: Kaynak.yazili);
    await td.notuBagla(not, 'a', DateTime(2026, 11, 24, 10), DateTime(2026, 11, 24, 11));
    var g = depo.notlar.firstWhere((n) => n.id == not.id);
    expect(g.takvimEtkinlikId, 'a');
    // kullanıcı "yaptın mı"ya cevap verdi
    g.yaptinCevap = true;
    await depo.notGuncelle(g);
    // telefonda etkinlik başka saate taşındı
    sahte.disaridanTasi('a', DateTime(2026, 11, 27, 15), DateTime(2026, 11, 27, 16));
    await td.notlariSenkronla();
    g = depo.notlar.firstWhere((n) => n.id == not.id);
    expect(g.takvimBaslangic, DateTime(2026, 11, 27, 15).millisecondsSinceEpoch);
    expect(g.takvimBitis, DateTime(2026, 11, 27, 16).millisecondsSinceEpoch);
    expect(g.yaptinCevap, isFalse);
  });

  test('Etkinlik takvimden silinirse notun bağlantısı kalkar, not durur', () async {
    sahte.izin = true;
    await td.baslat();
    final not = await depo.notEkle(metin: 'Silinecek bağlantı', kaynak: Kaynak.yazili);
    await td.notuBagla(not, 'b', DateTime(2026, 11, 24, 12), DateTime(2026, 11, 24, 13));
    sahte.disaridanSil('b');
    await td.notlariSenkronla();
    final g = depo.notlar.firstWhere((n) => n.id == not.id);
    expect(g.takvimEtkinlikId, isNull);
    expect(g.takvimBitis, isNull);
    expect(g.metin, 'Silinecek bağlantı');
  });

  test('İzin yoksa ya da takvim hata verirse senkron notlara dokunmaz', () async {
    sahte.izin = true;
    await td.baslat();
    final not = await depo.notEkle(metin: 'Dokunulmamalı', kaynak: Kaynak.yazili);
    await td.notuBagla(not, 'a', DateTime(2026, 11, 24, 10), DateTime(2026, 11, 24, 11));
    sahte.hataFirlat = true;
    await td.notlariSenkronla();
    expect(depo.notlar.firstWhere((n) => n.id == not.id).takvimEtkinlikId, 'a');
    sahte.hataFirlat = false;
    final td2 = TakvimDeposu(SahteTakvim(izin: false), ayar);
    await td2.baslat();
    await td2.notlariSenkronla();
    expect(depo.notlar.firstWhere((n) => n.id == not.id).takvimEtkinlikId, 'a');
  });

  test('Boş zaman bulma takvimdeki dolu saatleri ve uyku ayarını kullanır', () async {
    sahte.izin = true;
    await td.baslat();
    await ayar.takvimSec('sam', 'S');
    await ayar.uykuAyarla(
        haftaIci: const UykuAraligi(23 * 60, 7 * 60), haftaSonu: const UykuAraligi(60, 10 * 60));
    // 24 Kasım 10:00-11:00 Toplantı dolu. 24 Kasım 09:40'ta 60 dk'lık yer arıyoruz.
    final t = await td.bosZamanBul(sureDk: 60, isNotu: false, simdi: DateTime(2026, 11, 24, 9, 10));
    expect(t, DateTime(2026, 11, 24, 11)); // 09:40→10:00 sınırı toplantıya çarpar, 11:00 ilk uygun yer
  });

  test('İş notu için iş bloğu yoksa boş zaman bulunamaz', () async {
    sahte.izin = true;
    await td.baslat();
    await ayar.takvimSec('sam', 'S');
    await ayar.uykuAyarla(
        haftaIci: const UykuAraligi(23 * 60, 7 * 60), haftaSonu: const UykuAraligi(60, 10 * 60));
    expect(await td.bosZamanBul(sureDk: 30, isNotu: true, simdi: DateTime(2026, 11, 24, 8)), isNull);
  });

  test('Ayarlar telefonda saklanır ve geri okunur', () async {
    await ayar.uykuAyarla(
        haftaIci: const UykuAraligi(22 * 60 + 30, 6 * 60 + 45), haftaSonu: const UykuAraligi(0, 9 * 60));
    await ayar.isKelimesiAyarla('Mesai');
    await ayar.izinGunuEkle(DateTime(2026, 12, 25));
    await ayar.takvimSec('sam', 'Samsung takvimim');
    // yeniden yükleme (uygulama kapatılıp açılıyor gibi)
    final p = await SharedPreferences.getInstance();
    expect(p.getStringList('uyku_hafta_ici'), ['1350', '405']);
    await ayar.yukle();
    expect(ayar.uykuHaftaIci, const UykuAraligi(22 * 60 + 30, 6 * 60 + 45));
    expect(ayar.isKelimesi, 'Mesai');
    expect(ayar.izinGunleri, {'2026-12-25'});
    expect(ayar.takvimId, 'sam');
    await ayar.izinGunuKaldir('2026-12-25');
    expect(ayar.izinGunleri, isEmpty);
    await ayar.isKelimesiAyarla('   ');
    expect(ayar.isKelimesi, 'İş');
  });

  group('"Yaptın mı?" kartları', () {
    Not n(String id, {int? bitis, bool cevap = false, String durum = Durum.yapilacak, bool arsiv = false}) => Not(
        id: id, metin: id, kaynak: Kaynak.yazili, olusturma: 0, guncelleme: 0, sonDokunma: 0,
        takvimBitis: bitis, yaptinCevap: cevap, durum: durum, arsiv: arsiv);
    final simdi = DateTime(2026, 11, 24, 12);
    int dk(int d) => simdi.subtract(Duration(minutes: d)).millisecondsSinceEpoch;

    test('Bitişten 5 dakika sonra sorulur, öncesinde sorulmaz', () {
      final l = YaptinMiKartlari.sorulacaklar([n('az', bitis: dk(4)), n('tam', bitis: dk(5)), n('cok', bitis: dk(60))], simdi);
      expect(l.map((x) => x.id), ['cok', 'tam']);
    });
    test('Cevaplanmış, tamamlanmış, arşivlenmiş ve takvimsiz notlar sorulmaz', () {
      final l = YaptinMiKartlari.sorulacaklar([
        n('cevaplandi', bitis: dk(60), cevap: true),
        n('bitti', bitis: dk(60), durum: Durum.yapildi),
        n('arsiv', bitis: dk(60), arsiv: true),
        n('takvimsiz'),
      ], simdi);
      expect(l, isEmpty);
    });
  });
}
