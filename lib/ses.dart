import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kısa arayüz sesleri: düğmelerde yumuşak tık, kitaplarda sayfa hışırtısı. Ortam sesi yok.
/// Eklenti yoksa (test) ya da hata olursa sessizce hiçbir şey yapmaz.
class Ses extends ChangeNotifier {
  Ses._();
  static final Ses instance = Ses._();

  static const _anahtar = 'ses_efektleri';
  bool acik = true;
  AudioPlayer? _tik;
  AudioPlayer? _sayfa;

  Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      acik = p.getBool(_anahtar) ?? true;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> acikAyarla(bool v) async {
    acik = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_anahtar, v);
    } catch (_) {}
  }

  Future<void> _cal(AudioPlayer? Function() al, void Function(AudioPlayer) sakla, String dosya, double ses) async {
    if (!acik) return;
    try {
      var o = al();
      if (o == null) {
        o = AudioPlayer();
        await o.setPlayerMode(PlayerMode.lowLatency);
        sakla(o);
      }
      await o.stop();
      await o.play(AssetSource(dosya), volume: ses);
    } catch (e) {
      debugPrint('Ses çalınamadı: $e');
    }
  }

  Future<void> tik() => _cal(() => _tik, (o) => _tik = o, 'ses/tik.wav', 0.5);
  Future<void> sayfa() => _cal(() => _sayfa, (o) => _sayfa = o, 'ses/hisirti.wav', 0.6);
}
