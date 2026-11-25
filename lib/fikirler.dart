import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Uygulamayı geliştirmek için yazdığın fikirler. Telefonda saklanır; "Gönder" deyince
/// hazır doldurulmuş bir GitHub sayfası açılır, orada bir kez "Submit" demen yeterli.
class FikirDeposu extends ChangeNotifier {
  FikirDeposu._();
  static final instance = FikirDeposu._();

  static const _anahtar = 'fikirler';
  static const depoAdresi = 'https://github.com/faykurt/deneme';

  List<Fikir> liste = [];

  List<Fikir> get gonderilmeyenler => liste.where((f) => !f.gonderildi).toList();

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

  /// Verilen fikirleri tek bir GitHub "yeni konu" sayfasında açar ve gönderildi işaretler.
  static Uri gonderAdresi(List<Fikir> fikirler) {
    final baslik = fikirler.length == 1
        ? 'Fikir: ${_kisalt(fikirler.first.metin)}'
        : 'Fikirler (${fikirler.length})';
    final govde = fikirler.length == 1
        ? fikirler.first.metin
        : [for (var i = 0; i < fikirler.length; i++) '${i + 1}. ${fikirler[i].metin}'].join('\n\n');
    return Uri.parse('$depoAdresi/issues/new').replace(queryParameters: {'title': baslik, 'body': govde});
  }

  static String _kisalt(String s) {
    final ilk = s.split('\n').first.trim();
    return ilk.length > 50 ? '${ilk.substring(0, 50)}…' : ilk;
  }

  Future<bool> gonder(List<Fikir> fikirler) async {
    if (fikirler.isEmpty) return false;
    final tamam = await launchUrl(gonderAdresi(fikirler), mode: LaunchMode.externalApplication);
    if (tamam) {
      for (final f in fikirler) {
        f.gonderildi = true;
      }
      await _kaydet();
    }
    return tamam;
  }
}
