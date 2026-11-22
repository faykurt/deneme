import 'package:material_ui/material_ui.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/ai_zamanlama.dart';
import '../ortak.dart';
import '../veri/modeller.dart';
import 'not_detay.dart';
import 'onay_penceresi.dart';

/// Yazılı ya da sesli bir not kaydedilince çağrılır. Yapay zeka notu hemen işlemez (maliyet için),
/// bir sonraki çalışma saatinde düzenler. İstenirse "Şimdi analiz et" ile hemen işletilebilir.
Future<void> kayitSonrasi(Not not, {String kayitMesaji = 'Not kaydedildi'}) async {
  if (AiAyarlar.instance.anahtarVar) {
    final siradaki = AiZamanlama.instance.sonrakiMetni(DateTime.now());
    mesajGoster(
      '$kayitMesaji. Yapay zeka $siradaki düzenleyecek.',
      eylem: 'Şimdi analiz et',
      eylemFn: () => onayPenceresiAc(not.id, canli: true),
      saniye: 5,
    );
    return;
  }
  mesajGoster('$kayitMesaji. Yapay zeka için Ayarlar\'dan anahtar ekleyebilirsin.',
      eylem: 'Aç',
      eylemFn: () => navigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (_) => NotDetay(notId: not.id))));
}
