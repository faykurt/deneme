import 'package:device_calendar_plus/device_calendar_plus.dart' as dc;

import 'takvim_modeller.dart';

/// Takvim erişiminin arayüzü. Gerçek telefon takvimi [CihazTakvimi]'dir, testlerde sahtesi kullanılır.
abstract class TakvimKaynagi {
  Future<bool> izinVar();
  Future<bool> izinIste();
  Future<List<TakvimBilgi>> takvimler();
  Future<List<TEtkinlik>> etkinlikler(DateTime bas, DateTime bit, {List<String>? takvimIdler});
  Future<TEtkinlik?> getir(String id);
  Future<String> ekle(TEtkinlikTaslagi t);
  Future<void> guncelle(TEtkinlik eski, TEtkinlikTaslagi yeni, Kapsam kapsam);
  Future<void> sil(TEtkinlik e, Kapsam kapsam);
}

/// Takvimin bir isteği reddettiğinde fırlatılır; [mesaj] kullanıcıya gösterilir.
class TakvimHatasi implements Exception {
  final String mesaj;
  final bool izinYok;
  const TakvimHatasi(this.mesaj, {this.izinYok = false});
  @override
  String toString() => mesaj;
}

/// Eklentinin tekrar kuralını bizim sade türlerimize çevirir (ve tersi).
class TekrarDonusumu {
  static const _haftaIci = [
    dc.DayOfWeek.monday,
    dc.DayOfWeek.tuesday,
    dc.DayOfWeek.wednesday,
    dc.DayOfWeek.thursday,
    dc.DayOfWeek.friday,
  ];

  static (TekrarTuru, DateTime?) coz(dc.RecurrenceRule? kural) {
    if (kural == null) return (TekrarTuru.yok, null);
    final bitis = kural.end is dc.UntilEnd ? (kural.end as dc.UntilEnd).until.toLocal() : null;
    final sade = kural.interval == 1 && kural.end is! dc.CountEnd;
    final tur = switch (kural) {
      dc.DailyRecurrence() => sade ? TekrarTuru.gunluk : TekrarTuru.ozel,
      dc.WeeklyRecurrence(:final daysOfWeek) => !sade
          ? TekrarTuru.ozel
          : (daysOfWeek == null || daysOfWeek.isEmpty)
              ? TekrarTuru.haftalik
              : _haftaIciMi(daysOfWeek)
                  ? TekrarTuru.haftaIci
                  : (daysOfWeek.length == 1 ? TekrarTuru.haftalik : TekrarTuru.ozel),
      dc.MonthlyByDate(:final daysOfMonth) =>
        sade && (daysOfMonth == null || daysOfMonth.length <= 1) ? TekrarTuru.aylik : TekrarTuru.ozel,
      dc.YearlyByDate(:final daysOfMonth, :final months) => sade &&
              (daysOfMonth == null || daysOfMonth.length <= 1) &&
              (months == null || months.length <= 1)
          ? TekrarTuru.yillik
          : TekrarTuru.ozel,
      _ => TekrarTuru.ozel,
    };
    return (tur, tur == TekrarTuru.ozel ? null : bitis);
  }

  static bool _haftaIciMi(List<dc.DayOfWeek> gunler) =>
      gunler.length == 5 && _haftaIci.every(gunler.contains);

  /// [ozel] için null döner: özel kurallara dokunulmaz.
  static dc.RecurrenceRule? kur(TekrarTuru tur, DateTime? bitis) {
    final son = bitis == null ? null : dc.UntilEnd(DateTime.utc(bitis.year, bitis.month, bitis.day, 23, 59, 59));
    return switch (tur) {
      TekrarTuru.yok || TekrarTuru.ozel => null,
      TekrarTuru.gunluk => dc.DailyRecurrence(end: son),
      TekrarTuru.haftaIci => dc.WeeklyRecurrence(daysOfWeek: _haftaIci, end: son),
      TekrarTuru.haftalik => dc.WeeklyRecurrence(end: son),
      TekrarTuru.aylik => dc.MonthlyRecurrence(end: son),
      TekrarTuru.yillik => dc.YearlyRecurrence(end: son),
    };
  }
}

/// Telefonun gerçek takvimi (Samsung Takvim'in kullandığı Android takvim deposu).
class CihazTakvimi implements TakvimKaynagi {
  final dc.DeviceCalendar _p = dc.DeviceCalendar.instance;

  Future<T> _koru<T>(Future<T> Function() is_) async {
    try {
      return await is_();
    } on dc.DeviceCalendarException catch (e) {
      switch (e.errorCode) {
        case dc.DeviceCalendarError.permissionDenied:
        case dc.DeviceCalendarError.permissionsNotDeclared:
          throw const TakvimHatasi('Takvim izni verilmemiş.', izinYok: true);
        case dc.DeviceCalendarError.readOnly:
          throw const TakvimHatasi('Bu takvim sadece okunabiliyor, değişiklik yapılamaz.');
        case dc.DeviceCalendarError.notFound:
          throw const TakvimHatasi('Etkinlik takvimde bulunamadı, silinmiş olabilir.');
        default:
          throw TakvimHatasi('Takvim bu işlemi kabul etmedi (${e.errorCode.name}).');
      }
    }
  }

  @override
  Future<bool> izinVar() async => (await _p.hasPermissions()) == dc.CalendarPermissionStatus.granted;

  @override
  Future<bool> izinIste() async => (await _p.requestPermissions()) == dc.CalendarPermissionStatus.granted;

  @override
  Future<List<TakvimBilgi>> takvimler() => _koru(() async {
        final liste = await _p.listCalendars();
        return [
          for (final c in liste)
            TakvimBilgi(
              id: c.id,
              ad: c.name,
              hesap: c.accountName,
              hesapTuru: c.accountType,
              saltOkunur: c.readOnly,
              gizli: c.hidden,
              renk: c.color,
            ),
        ];
      });

  @override
  Future<List<TEtkinlik>> etkinlikler(DateTime bas, DateTime bit, {List<String>? takvimIdler}) =>
      _koru(() async {
        final liste = await _p.listEvents(bas, bit, calendarIds: takvimIdler);
        return liste.map(_cevir).toList();
      });

  @override
  Future<TEtkinlik?> getir(String id) => _koru(() async {
        final e = await _p.getEvent(id);
        return e == null ? null : _cevir(e);
      });

  TEtkinlik _cevir(dc.Event e) {
    final (tur, bitis) = TekrarDonusumu.coz(e.recurrenceRule);
    final musait = switch (e.availability) {
      dc.EventAvailability.free => false,
      dc.EventAvailability.notSupported => !e.isAllDay,
      _ => true,
    };
    return TEtkinlik(
      instanceId: e.instanceId,
      eventId: e.eventId,
      takvimId: e.calendarId,
      baslik: e.title,
      baslangic: e.startDate,
      bitis: e.endDate,
      tumGun: e.isAllDay,
      meshgul: musait,
      tekrarli: e.isRecurring,
      tekrar: e.isRecurring && e.recurrenceRule == null ? TekrarTuru.ozel : tur,
      tekrarBitis: bitis,
      aciklama: e.description,
    );
  }

  dc.EventAvailability _musaitlik(bool meshgul) =>
      meshgul ? dc.EventAvailability.busy : dc.EventAvailability.free;

  @override
  Future<String> ekle(TEtkinlikTaslagi t) => _koru(() async {
        final bitis = t.tumGun && !t.bitis.isAfter(t.baslangic) ? sonrakiGun(t.baslangic) : t.bitis;
        return _p.createEvent(
          calendarId: t.takvimId,
          title: t.baslik,
          startDate: t.baslangic,
          endDate: bitis,
          isAllDay: t.tumGun,
          description: t.aciklama,
          availability: _musaitlik(t.meshgul),
          recurrenceRule: TekrarDonusumu.kur(t.tekrar, t.tekrarBitis),
        );
      });

  @override
  Future<void> guncelle(TEtkinlik eski, TEtkinlikTaslagi yeni, Kapsam kapsam) => _koru(() async {
        final bitis = yeni.tumGun && !yeni.bitis.isAfter(yeni.baslangic) ? sonrakiGun(yeni.baslangic) : yeni.bitis;
        final tekrarDegisti = yeni.tekrar != eski.tekrar && yeni.tekrar != TekrarTuru.ozel ||
            (yeni.tekrar == eski.tekrar && yeni.tekrarBitis != eski.tekrarBitis && yeni.tekrar != TekrarTuru.yok && yeni.tekrar != TekrarTuru.ozel);
        final aciklama = (yeni.aciklama == null || yeni.aciklama!.isEmpty)
            ? const dc.Patch<String>.clear()
            : dc.Patch<String>.set(yeni.aciklama!);

        final seriMi = eski.tekrarli || tekrarDegisti;
        if (!seriMi || (kapsam == Kapsam.sadeceBu && !tekrarDegisti)) {
          await _p.updateEvent(
            instanceId: eski.instanceId,
            title: yeni.baslik,
            startDate: yeni.baslangic,
            endDate: bitis,
            isAllDay: yeni.tumGun,
            description: aciklama,
            availability: _musaitlik(yeni.meshgul),
          );
          return;
        }
        await _p.updateRecurring(
          eski.instanceId,
          kapsam == Kapsam.buVeSonrakiler ? dc.EventSpan.thisAndFollowing : dc.EventSpan.allEvents,
          title: yeni.baslik,
          start: yeni.baslangic != eski.baslangic ? yeni.baslangic : null,
          duration: bitis.difference(yeni.baslangic) != eski.bitis.difference(eski.baslangic)
              ? bitis.difference(yeni.baslangic)
              : null,
          description: aciklama,
          isAllDay: yeni.tumGun != eski.tumGun ? yeni.tumGun : null,
          availability: _musaitlik(yeni.meshgul),
          recurrenceRule: tekrarDegisti
              ? (yeni.tekrar == TekrarTuru.yok
                  ? const dc.Patch<dc.RecurrenceRule>.clear()
                  : dc.Patch<dc.RecurrenceRule>.set(TekrarDonusumu.kur(yeni.tekrar, yeni.tekrarBitis)!))
              : null,
        );
      });

  @override
  Future<void> sil(TEtkinlik e, Kapsam kapsam) => _koru(() async {
        if (!e.tekrarli) {
          await _p.deleteEvent(instanceId: e.instanceId);
        } else if (kapsam == Kapsam.sadeceBu) {
          await _p.deleteEvent(instanceId: e.instanceId);
        } else {
          await _p.deleteRecurring(
            e.instanceId,
            kapsam == Kapsam.hepsi ? dc.EventSpan.allEvents : dc.EventSpan.thisAndFollowing,
          );
        }
      });
}
