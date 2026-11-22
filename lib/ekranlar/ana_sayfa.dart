import 'package:material_ui/material_ui.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/isleyici.dart';
import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'kayit_sonrasi.dart';
import 'onay_bekleyenler.dart';
import 'sesli_not.dart';
import 'yazili_not.dart';

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final _hizliNot = TextEditingController();

  String get _selam {
    final s = DateTime.now().hour;
    if (s >= 5 && s < 11) return 'Günaydın';
    if (s >= 11 && s < 17) return 'İyi günler';
    if (s >= 17 && s < 22) return 'İyi akşamlar';
    return 'İyi geceler';
  }

  Future<void> _hizliKaydet() async {
    final metin = _hizliNot.text.trim();
    if (metin.isEmpty) return;
    _hizliNot.clear();
    FocusScope.of(context).unfocus();
    final not = await Depo.instance.notEkle(metin: metin, kaynak: Kaynak.yazili);
    await kayitSonrasi(not);
  }

  @override
  Widget build(BuildContext context) {
    final yazi = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            Text(_selam, style: yazi.headlineMedium?.copyWith(color: Renk.kahve, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Aklındakileri buraya bırak.', style: yazi.bodyLarge?.copyWith(color: Renk.kahve)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
              decoration: BoxDecoration(
                color: Renk.acikKrem,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Renk.turuncu.withValues(alpha: 0.5)),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _hizliNot,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Aklında ne var?', border: InputBorder.none),
                    onSubmitted: (_) => _hizliKaydet(),
                  ),
                ),
                IconButton(
                    tooltip: 'Fotoğraflı not',
                    icon: const Icon(Icons.photo_camera_outlined),
                    onPressed: () => yaziliNotAc(kameraIleBasla: true)),
                IconButton(tooltip: 'Sesli not', icon: const Icon(Icons.mic_none), onPressed: sesliNotAc),
                IconButton.filled(tooltip: 'Kaydet', icon: const Icon(Icons.arrow_upward), onPressed: _hizliKaydet),
              ]),
            ),
            const OnayBandi(),
            ListenableBuilder(
              listenable: Listenable.merge([AiAyarlar.instance, AiIsleyici.instance]),
              builder: (context, _) {
                final ai = AiAyarlar.instance;
                final hata = AiIsleyici.instance.sonHata;
                if (!ai.anahtarVar) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                    child: Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Renk.turuncu.withValues(alpha: 0.4))),
                      child: ListTile(
                        leading: const Icon(Icons.key, color: Renk.turuncu),
                        title: const Text('Yapay zekayı aç'),
                        subtitle: const Text('Notların kendiliğinden düzenlenmesi için anahtarını ekle.'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => sekmeSecici.value = 3,
                      ),
                    ),
                  );
                }
                if (hata != null) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(hata.mesaj,
                        style: TextStyle(color: Colors.red.shade800, fontSize: 13)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Renk.turuncu.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  const Text('💡', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Önerilerin ve bugünün takvimi yakında burada olacak. '
                      'Şimdilik aklına geleni kaydetmeye başlayabilirsin.',
                      style: yazi.bodyMedium?.copyWith(color: Renk.kahve),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            ListenableBuilder(
              listenable: Depo.instance,
              builder: (context, _) {
                final sayi = Depo.instance.aktifNotlar.length;
                return Text(
                  sayi == 0 ? 'Henüz notun yok.' : 'Aklımda\'da $sayi notun var.',
                  textAlign: TextAlign.center,
                  style: yazi.bodySmall?.copyWith(color: Renk.kahve.withValues(alpha: 0.6)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
