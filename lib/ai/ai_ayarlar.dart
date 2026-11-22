import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// API anahtarı telefonda şifreli olarak saklanır. Kodun ya da depoya hiçbir yerinde yer almaz.
class AiAyarlar extends ChangeNotifier {
  AiAyarlar._();
  static final AiAyarlar instance = AiAyarlar._();

  static const _anahtarAdi = 'anthropic_api_anahtari';
  final _depo = const FlutterSecureStorage();
  String? _anahtar;

  bool get anahtarVar => _anahtar != null && _anahtar!.isNotEmpty;
  String? get anahtar => _anahtar;

  /// "sk-ant-…a1b2" gibi, anahtarı ele vermeyen kısa gösterim.
  String get maskeli {
    final a = _anahtar;
    if (a == null || a.length < 12) return '';
    return '${a.substring(0, 7)}…${a.substring(a.length - 4)}';
  }

  Future<void> yukle() async {
    try {
      _anahtar = await _depo.read(key: _anahtarAdi);
    } catch (_) {
      _anahtar = null;
    }
    notifyListeners();
  }

  Future<void> kaydet(String anahtar) async {
    // Telefondan kopyalarken eklenebilen boşluk ve satır sonlarını temizle.
    final temiz = anahtar.replaceAll(RegExp(r'\s+'), '');
    await _depo.write(key: _anahtarAdi, value: temiz);
    _anahtar = temiz;
    notifyListeners();
  }

  Future<void> sil() async {
    await _depo.delete(key: _anahtarAdi);
    _anahtar = null;
    notifyListeners();
  }
}
