import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Fikir {
  final String id;
  final String metin;
  final int zaman;
  bool gonderildi;
  Fikir({required this.id, required this.metin, required this.zaman, this.gonderildi = false});

  Map<String, Object?> toJson() => {'id': id, 'metin': metin, 'zaman': zaman, 'gonderildi': gonderildi};
  factory Fikir.fromJson(Map<String, dynamic> m) => Fikir(
        id: m['id'] as String,
        metin: m['metin'] as String,
        zaman: m['zaman'] as int,
        gonderildi: m['gonderildi'] == true,
      );
}

/// Uygulamayı geliştirmek için yazdığın fikirler. Telefonda saklanır; tek tek ya da hepsi birden kopyalanır.
class FikirDeposu extends ChangeNotifier {
  FikirDeposu._();
  static final instance = FikirDeposu._();

  static const _anahtar = 'fikirler';

  List<Fikir> liste = [];

  Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ham = p.getString(_anahtar);
      if (ham != null) {
        liste = (jsonDecode(ham) as List).map((e) => Fikir.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      liste = [];
    }
    notifyListeners();
  }

  Future<void> _kaydet() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_anahtar, jsonEncode(liste.map((f) => f.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> ekle(String metin) async {
    final t = metin.trim();
    if (t.isEmpty) return;
    final simdi = DateTime.now().millisecondsSinceEpoch;
    liste.insert(0, Fikir(id: '$simdi', metin: t, zaman: simdi));
    await _kaydet();
  }

  Future<void> sil(String id) async {
    liste.removeWhere((f) => f.id == id);
    await _kaydet();
  }

  /// Tek fikrin kopyalanacak metni.
  static String kopyaMetni(Fikir f) => f.metin;

  /// Birden çok fikir: numaralı, aralarında boş satır.
  static String hepsiMetni(List<Fikir> l) =>
      [for (var i = 0; i < l.length; i++) '${i + 1}. ${l[i].metin}'].join('\n\n');
}
