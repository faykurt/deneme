import 'package:material_ui/material_ui.dart';

import '../ai/isleyici.dart';
import '../ortak.dart';
import '../veri/depo.dart';
import 'onay_penceresi.dart';

/// Yapay zekanın işlediği ama senin henüz onaylamadığın notlar.
class OnayBekleyenlerEkrani extends StatelessWidget {
  const OnayBekleyenlerEkrani({super.key});

  Future<void> _hepsiniOnayla(BuildContext context) async {
    final liste = Depo.instance.onayBekleyenler;
    if (liste.isEmpty) return;
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${liste.length} notun hepsi onaylansın mı?'),
        content: const Text('Yapay zekanın kategori, başlık ve süre önerileri olduğu gibi kalır. '
            'Adım önerileri eklenmez, onları notları tek tek açınca seçebilirsin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hepsini onayla')),
        ],
      ),
    );
    if (evet == true) await Depo.instance.onayla(liste.map((n) => n.id));
  }

  @override
  Widget build(BuildContext context) {
    final depo = Depo.instance;
    return ListenableBuilder(
      listenable: depo,
      builder: (context, _) {
        final liste = depo.onayBekleyenler;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Renk.krem,
            title: const Text('Onay bekleyenler'),
            actions: [
              if (liste.length > 1)
                TextButton(onPressed: () => _hepsiniOnayla(context), child: const Text('Hepsini onayla')),
            ],
          ),
          body: liste.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Text('Onay bekleyen not yok. 🎉',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Renk.kahve.withValues(alpha: 0.7), fontSize: 16)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text('Bir notu açıp yapay zekanın önerilerini kontrol edebilir, onaylayabilirsin. '
                          'Onaylamasan da notlar çalışmaya devam eder.',
                          style: TextStyle(color: Renk.kahve.withValues(alpha: 0.7), fontSize: 13)),
                    ),
                    for (final n in liste) NotKarti(not: n, onTap: () => onayPenceresiAc(n.id)),
                  ],
                ),
        );
      },
    );
  }
}

/// "X onay bekleyen notun var" şeridi. Bekleyen yoksa görünmez.
class OnayBandi extends StatelessWidget {
  const OnayBandi({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([Depo.instance, AiIsleyici.instance]),
      builder: (context, _) {
        final sayi = Depo.instance.onayBekleyenler.length;
        final isleniyor = AiIsleyici.instance.mesgul;
        if (sayi == 0 && !isleniyor) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: Renk.turuncu.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: sayi == 0
                  ? null
                  : () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const OnayBekleyenlerEkrani())),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  if (isleniyor)
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    const Icon(Icons.pending_actions, color: Renk.turuncu),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isleniyor && sayi == 0
                          ? 'Yapay zeka notlarını düzenliyor…'
                          : '$sayi onay bekleyen notun var',
                      style: const TextStyle(color: Renk.kahve, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (sayi > 0) const Icon(Icons.chevron_right, color: Renk.kahve),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}
