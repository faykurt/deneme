import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'tarif_ekle.dart';

final _linkDeseni = RegExp(r'https?://\S+');

/// Başka bir uygulamadan paylaşılan içeriği hemen kaydeder,
/// sonra isteğe bağlı yorum için küçük bir "Kaydedildi" penceresi gösterir.
Future<void> paylasimiIsle(List<SharedMediaFile> dosyalar) async {
  final yazilar = <String>[];
  final fotograflar = <String>[];
  for (final d in dosyalar) {
    switch (d.type) {
      case SharedMediaType.text:
      case SharedMediaType.url:
        yazilar.add(d.path);
      case SharedMediaType.image:
        fotograflar.add(d.path);
        if (d.message != null && d.message!.trim().isNotEmpty) yazilar.add(d.message!);
      default:
        break;
    }
  }
  if (yazilar.isEmpty && fotograflar.isEmpty) return;
  final metin = yazilar.join('\n').trim();
  final link = _linkDeseni.firstMatch(metin)?.group(0);
  final not = await Depo.instance.notEkle(
    metin: metin,
    kaynak: Kaynak.paylasim,
    link: link,
    fotografYollari: fotograflar,
  );
  final ctx = navigatorKey.currentContext;
  if (ctx == null || !ctx.mounted) return;
  await showModalBottomSheet<void>(
    context: ctx,
    isScrollControlled: true,
    backgroundColor: Renk.zemin,
    builder: (_) => _KaydedildiPenceresi(not: not),
  );
}

class _KaydedildiPenceresi extends StatefulWidget {
  final Not not;
  const _KaydedildiPenceresi({required this.not});

  @override
  State<_KaydedildiPenceresi> createState() => _KaydedildiPenceresiState();
}

class _KaydedildiPenceresiState extends State<_KaydedildiPenceresi> {
  final _yorum = TextEditingController();
  final _odak = FocusNode();
  Timer? _kapat;

  @override
  void initState() {
    super.initState();
    // Dokunulmazsa birkaç saniyede kendiliğinden kapanır.
    _kapat = Timer(const Duration(seconds: 5), () {
      if (mounted) Navigator.pop(context);
    });
    _odak.addListener(() {
      if (_odak.hasFocus) _kapat?.cancel();
    });
  }

  Future<void> _bitir() async {
    final y = _yorum.text.trim();
    if (y.isNotEmpty) {
      widget.not.yorum = y;
      await Depo.instance.notGuncelle(widget.not);
    }
    if (mounted) Navigator.pop(context);
  }

  void _tarifEkle() {
    _kapat?.cancel();
    final nav = Navigator.of(context);
    final not = widget.not;
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => TarifEkleEkrani(baglanti: not.link, silinecekNotId: not.id)));
  }

  @override
  void dispose() {
    _kapat?.cancel();
    _odak.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.check_circle, color: Renk.vurgu, size: 28),
            SizedBox(width: 10),
            Text('Aklımda\'ya kaydedildi',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Renk.yazi)),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _yorum,
            focusNode: _odak,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'İstersen kısa bir yorum ekle',
              filled: true,
              fillColor: Renk.kart,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onSubmitted: (_) => _bitir(),
          ),
          const SizedBox(height: 10),
          Row(children: [
            if (widget.not.link != null)
              TextButton.icon(
                onPressed: _tarifEkle,
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Tarif olarak ekle'),
              ),
            const Spacer(),
            FilledButton(onPressed: _bitir, child: const Text('Tamam')),
          ]),
        ],
      ),
    );
  }
}
