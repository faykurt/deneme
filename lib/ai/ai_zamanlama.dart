import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yapay zekanın notları düzenlediği günlük saatler (varsayılan 13:00 ve 21:00).
/// Notlar kaydedilince hemen işlenmez, bir sonraki saat geçtikten sonra uygulama açılınca işlenir.
class AiZamanlama extends ChangeNotifier {
  AiZamanlama._();
  static final AiZamanlama instance = AiZamanlama._();

  static const varsayilan = [13 * 60, 21 * 60];

  List<int> saatler = [...varsayilan];

  Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      final l = p.getStringList('ai_saatler')?.map(int.tryParse).whereType<int>().toList();
      if (l != null && l.isNotEmpty) saatler = (l..sort());
    } catch (_) {}
    notifyListeners();
  }

  Future<void> saatleriAyarla(List<int> dakikalar) async {
    if (dakikalar.isEmpty) return;
    saatler = ({...dakikalar}.toList()..sort());
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('ai_saatler', saatler.map((e) => '$e').toList());
    } catch (_) {}
    notifyListeners();
  }

  static DateTime _an(DateTime gun, int dk) => DateTime(gun.year, gun.month, gun.day, dk ~/ 60, dk % 60);

  /// [simdi] anına kadar gelmiş en son çalışma saati (yoksa null).
  DateTime? sonSlot(DateTime simdi) {
    DateTime? en;
    for (final gun in [DateTime(simdi.year, simdi.month, simdi.day - 1), DateTime(simdi.year, simdi.month, simdi.day)]) {
      for (final dk in saatler) {
        final t = _an(gun, dk);
        if (!t.isAfter(simdi) && (en == null || t.isAfter(en))) en = t;
      }
    }
    return en;
  }

  /// [simdi] anından sonraki ilk çalışma saati.
  DateTime sonrakiSlot(DateTime simdi) {
    DateTime? en;
    for (final gun in [DateTime(simdi.year, simdi.month, simdi.day), DateTime(simdi.year, simdi.month, simdi.day + 1)]) {
      for (final dk in saatler) {
        final t = _an(gun, dk);
        if (t.isAfter(simdi) && (en == null || t.isBefore(en))) en = t;
      }
    }
    return en!;
  }

  static String saatMetni(int dk) =>
      '${(dk ~/ 60).toString().padLeft(2, '0')}:${(dk % 60).toString().padLeft(2, '0')}';

  String get ozet => saatler.map(saatMetni).join(' ve ');

  /// "bugün 21:00" ya da "yarın 13:00"
  String sonrakiMetni(DateTime simdi) {
    final t = sonrakiSlot(simdi);
    final bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final fark = DateTime(t.year, t.month, t.day).difference(bugun).inDays;
    final gun = fark == 0 ? 'bugün' : 'yarın';
    return '$gun ${saatMetni(t.hour * 60 + t.minute)}';
  }
}
