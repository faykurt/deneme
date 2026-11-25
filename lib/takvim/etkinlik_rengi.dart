
import 'package:flutter/services.dart';

/// Etkinliğe özel rengi telefonun takvim deposundan okur ve oraya yazar
/// (Samsung Takvim'deki renk yuvarlağıyla aynı alan). Kanal yoksa (test, başka platform) sessizce boş döner.
class EtkinlikRengi {
  static const _kanal = MethodChannel('aklimda/etkinlik_rengi');

  /// eventId -> renk. Yalnızca etkinliğe özel rengi olanlar gelir.
  static Future<Map<String, Color>> oku(Iterable<String> eventIdler) async {
    final idler = eventIdler.toSet().toList();
    if (idler.isEmpty) return {};
    try {
      final ham = await _kanal.invokeMapMethod<String, int>('oku', {'idler': idler});
      return {for (final e in (ham ?? {}).entries) e.key: Color(e.value & 0xFFFFFFFF)};
    } on MissingPluginException {
      return {};
    } on PlatformException {
      return {};
    }
  }

  /// [renk] null ise etkinliğin özel rengi kaldırılır (takvimin rengine döner).
  static Future<bool> ayarla(String eventId, Color? renk) async {
    try {
      final tamam = await _kanal.invokeMethod<bool>('ayarla', {'id': eventId, 'renk': renk?.toARGB32()});
      return tamam ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
