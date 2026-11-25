import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../fikirler.dart';
import '../ortak.dart';

/// Ayarlar > Fikir kutusu: uygulama için aklına gelenleri yaz, kopyala.
class FikirKutusuEkrani extends StatefulWidget {
  const FikirKutusuEkrani({super.key});

  @override
  State<FikirKutusuEkrani> createState() => _FikirKutusuEkraniState();
}

class _FikirKutusuEkraniState extends State<FikirKutusuEkrani> {
  final _alan = TextEditingController();
  final _depo = FikirDeposu.instance;

  @override
  void dispose() {
    _alan.dispose();
    super.dispose();
  }

  Future<void> _ekle() async {
    final t = _alan.text;
    if (t.trim().isEmpty) return;
    _alan.clear();
    await _depo.ekle(t);
  }

  Future<void> _kopyala(String metin, String mesaj) async {
    await Clipboard.setData(ClipboardData(text: metin));
    mesajGoster(mesaj);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Renk.zemin, title: const Text('Fikir kutusu')),
      body: ListenableBuilder(
        listenable: _depo,
        builder: (context, _) {
          final liste = _depo.liste;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Text(
                'Uygulama için aklına gelen fikirleri buraya yaz. Tek tek ya da hepsini birden kopyalayıp bana yapıştırabilirsin.',
                style: TextStyle(color: Renk.yazi.withValues(alpha: 0.7), fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _alan,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Fikrin ne?',
                  filled: true,
                  fillColor: Renk.kart,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(onPressed: _ekle, icon: const Icon(Icons.add), label: const Text('Ekle')),
              ),
              if (liste.length > 1) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _kopyala(FikirDeposu.hepsiMetni(liste), '${liste.length} fikir kopyalandı.'),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text('Hepsini kopyala (${liste.length})'),
                ),
              ],
              const SizedBox(height: 12),
              if (liste.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Henüz fikir yok.',
                      textAlign: TextAlign.center, style: TextStyle(color: Renk.yazi.withValues(alpha: 0.6))),
                ),
              for (final f in liste)
                Card(
                  elevation: 0,
                  color: Renk.kart,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: double.infinity, child: Text(f.metin, style: TextStyle(color: Renk.yazi))),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        TextButton.icon(
                          onPressed: () => _kopyala(FikirDeposu.kopyaMetni(f), 'Fikir kopyalandı.'),
                          icon: const Icon(Icons.copy, size: 18),
                          label: const Text('Kopyala'),
                        ),
                        TextButton.icon(
                          onPressed: () => _depo.sil(f.id),
                          icon: Icon(Icons.delete_outline, size: 18, color: Renk.hata),
                          label: Text('Sil', style: TextStyle(color: Renk.hata)),
                        ),
                      ]),
                    ]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
