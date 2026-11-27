import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının etkinliklere kendi seçtiği ikonlar (telefonda saklanır; Samsung Takvim'de görünmez).
/// Emoji seçilirse başlığa yazılır, bu liste yalnızca hazır ikonlar içindir.
class EtkinlikIkonlari extends ChangeNotifier {
  EtkinlikIkonlari._();
  static final EtkinlikIkonlari instance = EtkinlikIkonlari._();

  static const _anahtar = 'etkinlik_ikonlari';

  static const secenekler = <String, IconData>{
    'yemek': Icons.restaurant,
    'kahve': Icons.local_cafe,
    'market': Icons.shopping_basket,
    'toplanti': Icons.groups,
    'is': Icons.work,
    'ders': Icons.school,
    'kitap': Icons.menu_book,
    'spor': Icons.directions_run,
    'yoga': Icons.self_improvement,
    'saglik': Icons.medical_services,
    'ev': Icons.home,
    'temizlik': Icons.cleaning_services,
    'film': Icons.movie,
    'muzik': Icons.music_note,
    'oyun': Icons.sports_esports,
    'telefon': Icons.call,
    'ucak': Icons.flight,
    'araba': Icons.directions_car,
    'parti': Icons.cake,
    'kutlama': Icons.celebration,
    'para': Icons.account_balance_wallet,
    'kuafor': Icons.content_cut,
    'insanlar': Icons.people,
    'evcil': Icons.pets,
    'uyku': Icons.bedtime,
    'bitki': Icons.local_florist,
    'fotograf': Icons.photo_camera,
    'yildiz': Icons.star,
    'kalp': Icons.favorite,
    'not': Icons.event_note,
  };

  Map<String, String> _harita = {};

  Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ham = p.getString(_anahtar);
      if (ham != null) _harita = Map<String, String>.from(jsonDecode(ham) as Map);
    } catch (_) {}
    notifyListeners();
  }

  /// Etkinliğe seçilmiş hazır ikon (yoksa null).
  IconData? ikonOf(String etkinlikId) {
    final k = _harita[etkinlikId];
    return k == null ? null : secenekler[k];
  }

  Future<void> ata(String etkinlikId, String? anahtar) async {
    if (anahtar == null) {
      _harita.remove(etkinlikId);
    } else {
      _harita[etkinlikId] = anahtar;
    }
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_anahtar, jsonEncode(_harita));
    } catch (_) {}
  }
}
