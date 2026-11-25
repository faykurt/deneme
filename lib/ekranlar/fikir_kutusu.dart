import 'package:material_ui/material_ui.dart';

import '../fikirler.dart';
import '../ortak.dart';

/// Ayarlar > Fikir kutusu: uygulama için aklına gelenleri yaz, sonra gönder.
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

  Future<void> _gonder(List<Fikir> liste) async {
    final tamam = await _depo.gonder(liste);
    if (!tamam) mesajGoster('Sayfa açılamadı. Tarayıcın açık mı?');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Renk.zemin, title: const Text('Fikir kutusu')),
      body: ListenableBuilder(
        listenable: _depo,
        builder: (context, _) {
          final bekleyen = _depo.gonderilmeyenler;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              Text(
                'Uygulama için aklına gelen fikirleri buraya yaz. "Gönder"e basınca GitHub sayfası açılır, '
                'orada bir kez "Submit new issue" demen yeterli. Sonra bana "fikirleri getir" dersin.',
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
              if (bekleyen.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _gonder(bekleyen),
                  icon: const Icon(Icons.send_outlined),
                  label: Text('Gönderilmeyen ${bekleyen.length} fikri gönder'),
                ),
              ],
              const SizedBox(height: 12),
              if (_depo.liste.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Henüz fikir yok.',
                      textAlign: TextAlign.center, style: TextStyle(color: Renk.yazi.withValues(alpha: 0.6))),
                ),
              for (final f in _depo.liste)
                Card(
                  elevation: 0,
                  color: Renk.kart,
                  child: ListTile(
                    title: Text(f.metin),
                    subtitle: Text(f.gonderildi ? 'Gönderildi' : 'Gönderilmedi'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Gönder',
                        icon: Icon(f.gonderildi ? Icons.check_circle_outline : Icons.send_outlined),
                        onPressed: () => _gonder([f]),
                      ),
                      IconButton(
                        tooltip: 'Sil',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _depo.sil(f.id),
                      ),
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
