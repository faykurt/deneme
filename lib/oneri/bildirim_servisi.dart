import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../veri/modeller.dart';
import 'oneri_modeller.dart';

/// Telefonda zamanlanan bildirimler: günlük öneriler (en fazla birkaç tane) ve not hatırlatmaları.
/// Bildirim anında yapay zeka çağrılmaz; metinler önceden hazırlanmış pakettendir.
/// Testlerde ya da eklenti yokken tüm işlemler sessizce hiçbir şey yapmaz.
class BildirimServisi {
  BildirimServisi._();
  static final BildirimServisi instance = BildirimServisi._();

  static const _oneriKanal = AndroidNotificationDetails(
    'oneriler',
    'Öneriler',
    channelDescription: 'Günlük öneriler ve hatırlatmalar',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  static const _detay = NotificationDetails(android: _oneriKanal);

  static const _planAnahtari = 'bildirim_planlari';
  static const _oneriIdTaban = 1000;
  static const _hatirlatmaIdTaban = 100000;

  final _p = FlutterLocalNotificationsPlugin();
  bool _hazir = false;

  /// Bildirime dokunulunca çağrılır (payload: "not:" ile başlayan not kimliği).
  void Function(String payload)? dokunuldu;

  Future<void> baslat() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      await _p.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.isNotEmpty) dokunuldu?.call(p);
        },
      );
      _hazir = true;
    } catch (e) {
      debugPrint('Bildirim başlatılamadı: $e');
    }
  }

  /// Uygulama bir bildirime dokunularak açıldıysa payload'ı döner.
  Future<String?> acilisPayloadi() async {
    if (!_hazir) return null;
    try {
      final d = await _p.getNotificationAppLaunchDetails();
      if (d != null && d.didNotificationLaunchApp) return d.notificationResponse?.payload;
    } catch (_) {}
    return null;
  }

  Future<bool> izinVarMi() async {
    if (!_hazir) return false;
    try {
      return await _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled() ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> izinIste() async {
    if (!_hazir) return false;
    try {
      return await _p
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Hemen bir deneme bildirimi gösterir (Ayarlar'daki "Bildirimi dene").
  Future<bool> denemeGoster() async {
    if (!_hazir) return false;
    try {
      await _p.show(
        id: 999,
        title: 'Aklımda',
        body: 'Bildirimler çalışıyor. Önerilerini burada göreceksin.',
        notificationDetails: _detay,
        payload: 'ana',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  tz.TZDateTime _tz(DateTime t) => tz.TZDateTime.from(t, tz.local);

  Future<List<PlanliBildirim>> _planlar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ham = p.getString(_planAnahtari);
      if (ham == null) return [];
      return [for (final e in jsonDecode(ham) as List) PlanliBildirim.fromJson(e as Map<String, dynamic>)];
    } catch (_) {
      return [];
    }
  }

  Future<void> _planlariYaz(List<PlanliBildirim> l) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_planAnahtari, jsonEncode(l.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  /// Bugün şimdiye kadar atılmış ya da zamanlanmış öneri bildirimlerinin sayısı.
  Future<int> bugunkuSayi([DateTime? simdi]) async {
    final s = simdi ?? DateTime.now();
    final gun = DateTime(s.year, s.month, s.day);
    return (await _planlar())
        .where((b) => DateTime.fromMillisecondsSinceEpoch(b.zamanMs).isAfter(gun.subtract(const Duration(seconds: 1))) &&
            DateTime.fromMillisecondsSinceEpoch(b.zamanMs).isBefore(gun.add(const Duration(days: 1))))
        .length;
  }

  /// Öneri bildirimlerini kurar: bekleyenleri iptal eder, bugün kalan hakka (günlük [sinir] - atılanlar) göre yenilerini zamanlar.
  /// [bildirimler]: (not, başlık, metin, zaman). Döner: kurulanların sayısı.
  Future<int> oneriBildirimleriniKur({
    required List<({String notId, String baslik, String metin, DateTime zaman})> bildirimler,
    required int sinir,
    DateTime? simdi,
  }) async {
    final s = simdi ?? DateTime.now();
    final eski = await _planlar();
    final atilanlar = eski.where((b) => b.zamanMs <= s.millisecondsSinceEpoch).toList();
    final bugunAtilan = atilanlar
        .where((b) {
          final t = DateTime.fromMillisecondsSinceEpoch(b.zamanMs);
          return t.year == s.year && t.month == s.month && t.day == s.day;
        })
        .length;
    if (_hazir) {
      for (final b in eski.where((b) => b.zamanMs > s.millisecondsSinceEpoch)) {
        try {
          await _p.cancel(id: b.id);
        } catch (_) {}
      }
    }
    final kalan = (sinir - bugunAtilan).clamp(0, 10);
    final yeni = <PlanliBildirim>[];
    final sirali = [...bildirimler]..sort((a, b) => a.zaman.compareTo(b.zaman));
    for (final b in sirali) {
      if (yeni.length >= kalan) break;
      if (!b.zaman.isAfter(s.add(const Duration(minutes: 1)))) continue;
      final id = _oneriIdTaban + yeni.length;
      if (_hazir) {
        try {
          await _p.zonedSchedule(
            id: id,
            scheduledDate: _tz(b.zaman),
            notificationDetails: _detay,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            title: b.baslik,
            body: b.metin,
            payload: 'not:${b.notId}',
          );
        } catch (e) {
          debugPrint('Bildirim zamanlanamadı: $e');
          continue;
        }
      }
      yeni.add(PlanliBildirim(id: id, zamanMs: b.zaman.millisecondsSinceEpoch, notId: b.notId));
    }
    // Yalnızca bugünün kayıtlarını tut (atılanlar + yeniler), eski günler silinir.
    final bugunku = atilanlar.where((b) {
      final t = DateTime.fromMillisecondsSinceEpoch(b.zamanMs);
      return t.year == s.year && t.month == s.month && t.day == s.day;
    }).toList();
    await _planlariYaz([...bugunku, ...yeni]);
    return yeni.length;
  }

  int _hatirlatmaId(String notId) => _hatirlatmaIdTaban + (notId.hashCode.abs() % 900000);

  /// Notun tarih hatırlatmasını zamanlar (zaman geçmişteyse hiçbir şey yapmaz).
  Future<bool> hatirlatmaKur(Not not) async {
    final ms = not.hatirlatma;
    if (!_hazir || ms == null) return false;
    final zaman = DateTime.fromMillisecondsSinceEpoch(ms);
    if (!zaman.isAfter(DateTime.now())) return false;
    try {
      await _p.zonedSchedule(
        id: _hatirlatmaId(not.id),
        scheduledDate: _tz(zaman),
        notificationDetails: _detay,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: not.gorunenBaslik,
        body: 'Hatırlatma',
        payload: 'not:${not.id}',
      );
      return true;
    } catch (e) {
      debugPrint('Hatırlatma kurulamadı: $e');
      return false;
    }
  }

  Future<void> hatirlatmaIptal(String notId) async {
    if (!_hazir) return;
    try {
      await _p.cancel(id: _hatirlatmaId(notId));
    } catch (_) {}
  }
}
