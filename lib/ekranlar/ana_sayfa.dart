import 'package:material_ui/material_ui.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/isleyici.dart';
import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'kayit_sonrasi.dart';
import 'kutuphane.dart';
import 'piksel_sahne.dart';
import 'onay_bekleyenler.dart';
import 'sesli_not.dart';
import 'yaptin_mi.dart';
import 'yazili_not.dart';

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> with WidgetsBindingObserver {
  final _hizliNot = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hizliNot.dispose();
    super.dispose();
  }

  // Uygulamaya dönülünce gün bölümü (sabah/öğle/akşam) değişmiş olabilir.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

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
      body: Stack(children: [
        Positioned.fill(child: PikselSahne(bolum: SahneBolumu.simdi())),
        SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              decoration: BoxDecoration(
                color: Renk.kart.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_selam, style: yazi.headlineMedium?.copyWith(color: Renk.yazi, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('Aklındakileri buraya bırak.', style: yazi.bodyLarge?.copyWith(color: Renk.yazi)),
              ]),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
              decoration: BoxDecoration(
                color: Renk.kart.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Renk.vurgu.withValues(alpha: 0.5)),
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
            const Kutuphane(),
            const YaptinMiKartlari(),
            const OnayBandi(),
            const IslenecekBandi(),
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
                      color: Renk.kart,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Renk.vurgu.withValues(alpha: 0.4))),
                      child: ListTile(
                        leading: Icon(Icons.key, color: Renk.vurgu),
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
                        style: TextStyle(color: Renk.hata, fontSize: 13)),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Renk.vurguKart(0.14),
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
                      style: yazi.bodyMedium?.copyWith(color: Renk.yazi),
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
                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Renk.kart.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      sayi == 0 ? 'Henüz notun yok.' : 'Aklımda\'da $sayi notun var.',
                      style: yazi.bodySmall?.copyWith(color: Renk.yazi.withValues(alpha: 0.75)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        ),
      ]),
    );
  }
}
