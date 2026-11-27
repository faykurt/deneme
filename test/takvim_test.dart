import 'package:aklimda/takvim/bos_zaman.dart';
import 'package:aklimda/takvim/takvim_ayarlari.dart';
import 'package:aklimda/takvim/takvim_kaynagi.dart';
import 'package:aklimda/takvim/takvim_modeller.dart';
import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;
import 'package:flutter_test/flutter_test.dart';

TEtkinlik _e(String baslik, DateTime b, DateTime s,
        {bool tumGun = false, bool meshgul = true, TekrarTuru tekrar = TekrarTuru.yok}) =>
    TEtkinlik(
      instanceId: '$baslik@${b.millisecondsSinceEpoch}',
      eventId: baslik,
      takvimId: 'c1',
      baslik: baslik,
      baslangic: b,
      bitis: s,
      tumGun: tumGun,
      meshgul: meshgul,
      tekrar: tekrar,
    );

// 23 Kasım 2026 = Pazartesi
final _pzt = DateTime(2026, 11, 23);
const _kurallar = ZamanKurallari(
  uykuHaftaIci: UykuAraligi(23 * 60, 7 * 60),
  uykuHaftaSonu: UykuAraligi(1 * 60, 10 * 60),
);

void main() {
  group('Etkinlik gün kapsama', () {
    test('Saatli etkinlik sadece kendi gününü kapsar', () {
      final e = _e('x', DateTime(2026, 11, 23, 14), DateTime(2026, 11, 23, 15));
      expect(e.gunuKapsar(_pzt), isTrue);
      expect(e.gunuKapsar(DateTime(2026, 11, 24)), isFalse);
    });
    test('Gece yarısını aşan etkinlik iki günü de kapsar', () {
      final e = _e('x', DateTime(2026, 11, 23, 23), DateTime(2026, 11, 24, 1));
      expect(e.gunuKapsar(DateTime(2026, 11, 23)), isTrue);
      expect(e.gunuKapsar(DateTime(2026, 11, 24)), isTrue);
      expect(e.gunuKapsar(DateTime(2026, 11, 25)), isFalse);
    });
    test('Gece yarısında biten etkinlik ertesi günü kapsamaz', () {
      final e = _e('x', DateTime(2026, 11, 23, 22), DateTime(2026, 11, 24));
      expect(e.gunuKapsar(DateTime(2026, 11, 24)), isFalse);
    });
    test('Tüm gün etkinliğin bitişi dahil değildir', () {
      final e = _e('x', DateTime(2026, 11, 23), DateTime(2026, 11, 24), tumGun: true);
      expect(e.gunuKapsar(DateTime(2026, 11, 23)), isTrue);
      expect(e.gunuKapsar(DateTime(2026, 11, 24)), isFalse);
      final uc = _e('y', DateTime(2026, 11, 23), DateTime(2026, 11, 26), tumGun: true);
      expect(uc.gunuKapsar(DateTime(2026, 11, 25)), isTrue);
      expect(uc.gunuKapsar(DateTime(2026, 11, 26)), isFalse);
    });
    test('Bitişi başlangıçtan önce/aynı olan tüm gün etkinlik tek gün sayılır', () {
      final e = _e('x', DateTime(2026, 11, 23), DateTime(2026, 11, 23), tumGun: true);
      expect(e.gunuKapsar(DateTime(2026, 11, 23)), isTrue);
      expect(e.gunuKapsar(DateTime(2026, 11, 24)), isFalse);
    });
    test('Uygulamanın etkinliği işaretten tanınır', () {
      expect(_e('💭 Tablo', _pzt, _pzt).uygulamaninMi, isTrue);
      expect(_e('Toplantı', _pzt, _pzt).uygulamaninMi, isFalse);
    });
  });

  group('Uyku aralıkları', () {
    test('Hafta içi 23:00-07:00 gece yarısını aşar, kalkış ertesi günün türüne göre', () {
      // Pazartesi gecesi → Salı sabahı (ikisi de hafta içi): 23:00 → 07:00
      final u = _kurallar.uykular(DateTime(2026, 11, 24), DateTime(2026, 11, 25));
      expect(u.any((a) => a.$1 == DateTime(2026, 11, 23, 23) && a.$2 == DateTime(2026, 11, 24, 7)), isTrue);
    });
    test('Cuma gecesi yatış hafta içine, Cumartesi kalkışı hafta sonuna göre (10:00)', () {
      final u = _kurallar.uykular(DateTime(2026, 11, 28), DateTime(2026, 11, 29)); // Cumartesi
      expect(u.any((a) => a.$1 == DateTime(2026, 11, 27, 23) && a.$2 == DateTime(2026, 11, 28, 10)), isTrue);
    });
    test('Gece yarısını aşmayan hafta sonu uykusu (01:00-10:00) aynı gün içindedir', () {
      final u = _kurallar.uykular(DateTime(2026, 11, 28), DateTime(2026, 11, 29));
      expect(u.any((a) => a.$1 == DateTime(2026, 11, 28, 1) && a.$2 == DateTime(2026, 11, 28, 10)), isTrue);
    });
    test('İzin günü hafta sonu gibi sayılır', () {
      final k = ZamanKurallari(
        uykuHaftaIci: const UykuAraligi(23 * 60, 7 * 60),
        uykuHaftaSonu: const UykuAraligi(1 * 60, 10 * 60),
        izinGunleri: {gunAnahtari(DateTime(2026, 11, 24))},
      );
      expect(k.haftaSonuGibi(DateTime(2026, 11, 24)), isTrue);
      expect(k.haftaSonuGibi(DateTime(2026, 11, 25)), isFalse);
      expect(k.haftaSonuGibi(DateTime(2026, 11, 28)), isTrue);
    });
    test('Uyku tanımlı değilse aralık üretilmez', () {
      expect(const ZamanKurallari().uykular(_pzt, _pzt.add(const Duration(days: 2))), isEmpty);
    });
  });

  group('Boş zaman bulucu', () {
    test('Hiçbir şey yoksa şimdi + bekleme süresinden sonraki ilk 15 dk sınırını verir', () {
      final t = BosZamanBulucu.bul(
        simdi: DateTime(2026, 11, 23, 12, 10),
        sureDk: 30,
        isNotu: false,
        etkinlikler: [],
        kurallar: _kurallar,
      );
      expect(t, DateTime(2026, 11, 23, 12, 45)); // 12:10 + 30 dk = 12:40 → 12:45
    });
    test('Dolu etkinliğin üstüne yerleşmez', () {
      final t = BosZamanBulucu.bul(
        simdi: DateTime(2026, 11, 23, 12, 10),
        sureDk: 60,
        isNotu: false,
        etkinlikler: [_e('Toplantı', DateTime(2026, 11, 23, 12), DateTime(2026, 11, 23, 15))],
        kurallar: _kurallar,
      );
      expect(t, DateTime(2026, 11, 23, 15));
    });
    test('Müsait (free) etkinlik zamanı doldurmaz', () {
      final t = BosZamanBulucu.bul(
        simdi: DateTime(2026, 11, 23, 12, 10),
        sureDk: 60,
        isNotu: false,
        etkinlikler: [_e('Doğum günü', DateTime(2026, 11, 23), DateTime(2026, 11, 24), tumGun: true, meshgul: false)],
        kurallar: _kurallar,
      );
      expect(t, DateTime(2026, 11, 23, 12, 45));
    });
    test('Meşgul tüm gün etkinlik o günü tamamen kapatır', () {
      final t = BosZamanBulucu.bul(
        simdi: DateTime(2026, 11, 23, 12, 10),
        sureDk: 60,
        isNotu: false,
        etkinlikler: [_e('Tatil', DateTime(2026, 11, 23), DateTime(2026, 11, 24), tumGun: true)],
        kurallar: _kurallar,
      );
      expect(t, DateTime(2026, 11, 24, 7)); // Salı, uyku bittiği an
    });
    test('Uyku saatine yerleşmez', () {
      final t = BosZamanBulucu.bul(
        simdi: DateTime(2026, 11, 23, 22, 40),
        sureDk: 45,
        isNotu: false,
        etkinlikler: [],
        kurallar: _kurallar,
      );
      expect(t, DateTime(2026, 11, 24, 7));
    });
    test('İş bloğu iş dışı notlara kapalıdır', () {
      final t = BosZamanBulucu.bul(
        simdi: DateTime(2026, 11, 23, 9),
        sureDk: 30,
        isNotu: false,
        etkinlikler: [_e('İş', DateTime(2026, 11, 23, 9), DateTime(2026, 11, 23, 17))],
        kurallar: _kurallar,
      );
      expect(t, DateTime(2026, 11, 23, 17));
    });
    test('İş notu sadece iş bloğunun içine yerleşir ve toplantıyı atlar', () {
      final t = BosZamanBulucu.bul(
        simdi: DateTime(2026, 11, 23, 8),
        sureDk: 30,
        isNotu: true,
        etkinlikler: [
          _e('İş', DateTime(2026, 11, 23, 9), DateTime(2026, 11, 23, 17)),
          _e('Toplantı', DateTime(2026, 11, 23, 9), DateTime(2026, 11, 23, 11)),
        ],
        kurallar: _kurallar,
      );
      expect(t, DateTime(2026, 11, 23, 11));
    });
    test('İş notu bloğa sığmıyorsa ertesi günün bloğuna geçer', () {
      final t = BosZamanBulucu.bul(
        simdi: DateTime(2026, 11, 23, 16, 50),
        sureDk: 60,
        isNotu: true,
        etkinlikler: [
          _e('İş', DateTime(2026, 11, 23, 9), DateTime(2026, 11, 23, 17)),
          _e('İş', DateTime(2026, 11, 24, 9), DateTime(2026, 11, 24, 17)),
        ],
        kurallar: _kurallar,
      );
      expect(t, DateTime(2026, 11, 24, 9));
    });
    test('İş notu hafta sonu ve izin gününde yerleşmez', () {
      final k = ZamanKurallari(
        uykuHaftaIci: const UykuAraligi(23 * 60, 7 * 60),
        uykuHaftaSonu: const UykuAraligi(1 * 60, 10 * 60),
        izinGunleri: {gunAnahtari(DateTime(2026, 11, 24))},
      );
      final t = BosZamanBulucu.bul(
        simdi: DateTime(2026, 11, 23, 17, 30),
        sureDk: 30,
        isNotu: true,
        etkinlikler: [
          _e('İş', DateTime(2026, 11, 24, 9), DateTime(2026, 11, 24, 17)), // izin günü
          _e('İş', DateTime(2026, 11, 28, 9), DateTime(2026, 11, 28, 17)), // cumartesi
          _e('İş', DateTime(2026, 11, 30, 9), DateTime(2026, 11, 30, 17)), // pazartesi
        ],
        kurallar: k,
      );
      expect(t, DateTime(2026, 11, 30, 9));
    });
    test('İş bloğu hiç yoksa iş notu için null döner', () {
      expect(
          BosZamanBulucu.bul(
              simdi: _pzt, sureDk: 30, isNotu: true, etkinlikler: [], kurallar: _kurallar),
          isNull);
    });
    test('İş kelimesi büyük/küçük harften bağımsız bulunur', () {
      expect(BosZamanBulucu.isBlogu(_e('iş saatleri', _pzt, _pzt.add(const Duration(hours: 8))), 'İş'), isTrue);
      expect(BosZamanBulucu.isBlogu(_e('Toplantı', _pzt, _pzt.add(const Duration(hours: 1))), 'İş'), isFalse);
      // tüm gün etkinlik iş bloğu sayılmaz
      expect(BosZamanBulucu.isBlogu(_e('İş', _pzt, _pzt.add(const Duration(days: 1)), tumGun: true), 'İş'), isFalse);
    });
    test('Süre bilinmiyorsa 30 dk varsayılır, çok uzun süre 12 saate kısılır', () {
      final t = BosZamanBulucu.bul(
          simdi: DateTime(2026, 11, 23, 12), sureDk: 0, isNotu: false, etkinlikler: [], kurallar: _kurallar);
      expect(t, DateTime(2026, 11, 23, 12, 30));
    });
  });

  group('Tekrar dönüşümü', () {
    test('Sade kurallar tanınır', () {
      expect(TekrarDonusumu.coz(const dc.DailyRecurrence()).$1, TekrarTuru.gunluk);
      expect(TekrarDonusumu.coz(const dc.WeeklyRecurrence()).$1, TekrarTuru.haftalik);
      expect(TekrarDonusumu.coz(dc.MonthlyRecurrence()).$1, TekrarTuru.aylik);
      expect(TekrarDonusumu.coz(dc.YearlyRecurrence()).$1, TekrarTuru.yillik);
      expect(TekrarDonusumu.coz(null).$1, TekrarTuru.yok);
    });
    test('Hafta içi her gün doğru ayırt edilir', () {
      final k = TekrarDonusumu.kur(TekrarTuru.haftaIci, null)!;
      expect(TekrarDonusumu.coz(k).$1, TekrarTuru.haftaIci);
      expect(k.rruleString, contains('BYDAY=MO,TU,WE,TH,FR'));
    });
    test('Bitiş tarihi gidip gelir', () {
      final k = TekrarDonusumu.kur(TekrarTuru.haftalik, DateTime(2027, 3, 1))!;
      final (tur, bitis) = TekrarDonusumu.coz(k);
      expect(tur, TekrarTuru.haftalik);
      expect(bitis?.year, 2027);
      expect(k.rruleString, contains('UNTIL=20270301'));
    });
    test('Karmaşık kurallar "özel" sayılır ve değiştirilmez', () {
      expect(TekrarDonusumu.coz(const dc.DailyRecurrence(interval: 2)).$1, TekrarTuru.ozel);
      expect(TekrarDonusumu.coz(const dc.DailyRecurrence(end: dc.CountEnd(5))).$1, TekrarTuru.ozel);
      expect(TekrarDonusumu.kur(TekrarTuru.ozel, null), isNull);
      expect(TekrarDonusumu.kur(TekrarTuru.yok, null), isNull);
    });
  });
}
