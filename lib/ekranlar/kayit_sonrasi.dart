import 'package:material_ui/material_ui.dart';

import '../ai/ai_ayarlar.dart';
import '../ortak.dart';
import '../veri/modeller.dart';
import 'not_detay.dart';
import 'onay_penceresi.dart';

/// Yazılı ya da sesli bir not kaydedilince çağrılır:
/// yapay zeka hazırsa onay penceresini açar, değilse kısa bir bildirim gösterir.
Future<void> kayitSonrasi(Not not, {String kayitMesaji = 'Not kaydedildi'}) async {
  if (AiAyarlar.instance.anahtarVar) {
    await onayPenceresiAc(not.id, canli: true);
    return;
  }
  mesajGoster('$kayitMesaji. Yapay zeka için Ayarlar\'dan anahtar ekleyebilirsin.',
      eylem: 'Aç',
      eylemFn: () => navigatorKey.currentState
          ?.push(MaterialPageRoute(builder: (_) => NotDetay(notId: not.id))));
}
