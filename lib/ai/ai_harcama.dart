import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yapay zeka kullanımının aylık tahmini maliyeti. Rakam tahminidir: Anthropic'in belirttiği
/// güncel fiyatlarla (milyon token başına dolar) ve API'nin bildirdiği token sayılarıyla hesaplanır.
class AiHarcama extends ChangeNotifier {
  AiHarcama._();
  static final AiHarcama instance = AiHarcama._();

  /// Model → (girdi, çıktı) fiyatı, milyon token başına dolar.
  static const fiyatlar = <String, (double, double)>{
    'claude-haiku-5-5': (0.10, 0.50),
    'claude-sonnet-5-5': (2.0, 10.0),
    'claude-opus-5-5': (4.0, 20.0),
  };

  String ay = '';
  double dolar = 0;
  int istek = 0;
  int girdi = 0;
  int cikti = 0;

  static String _anahtar(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}';

  static double maliyet(String model, int girdiTokeni, int ciktiTokeni) {
    var fiyat = fiyatlar['claude-sonnet-5-5']!; // bilinmeyen model: temkinli olmak için Sonnet fiyatı
    for (final e in fiyatlar.entries) {
      if (model.startsWith(e.key)) fiyat = e.value;
    }
    return girdiTokeni * fiyat.$1 / 1e6 + ciktiTokeni * fiyat.$2 / 1e6;
  }

  Future<void> yukle({DateTime? simdi}) async {
    final t = simdi ?? DateTime.now();
    try {
      final p = await SharedPreferences.getInstance();
      final m = jsonDecode(p.getString('ai_harcama') ?? '{}') as Map<String, dynamic>;
      if (m['ay'] == _anahtar(t)) {
        ay = m['ay'] as String;
        dolar = (m['dolar'] as num?)?.toDouble() ?? 0;
        istek = (m['istek'] as num?)?.toInt() ?? 0;
        girdi = (m['girdi'] as num?)?.toInt() ?? 0;
        cikti = (m['cikti'] as num?)?.toInt() ?? 0;
      } else {
        _sifirla(t);
      }
    } catch (_) {
      _sifirla(t);
    }
    notifyListeners();
  }

  void _sifirla(DateTime t) {
    ay = _anahtar(t);
    dolar = 0;
    istek = 0;
    girdi = 0;
    cikti = 0;
  }

  Future<void> kaydet(String model, int girdiTokeni, int ciktiTokeni, {DateTime? simdi}) async {
    final t = simdi ?? DateTime.now();
    if (ay != _anahtar(t)) _sifirla(t);
    dolar += maliyet(model, girdiTokeni, ciktiTokeni);
    istek += 1;
    girdi += girdiTokeni;
    cikti += ciktiTokeni;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          'ai_harcama', jsonEncode({'ay': ay, 'dolar': dolar, 'istek': istek, 'girdi': girdi, 'cikti': cikti}));
    } catch (_) {}
  }

  /// "yaklaşık 0,07 $" gibi.
  String get dolarMetni {
    if (dolar < 0.005) return dolar == 0 ? '0 \$' : '1 sentten az';
    return 'yaklaşık ${dolar.toStringAsFixed(2).replaceAll('.', ',')} \$';
  }

  String get ozet => '$dolarMetni · $istek istek';
}
