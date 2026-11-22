import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'not_detay.dart';

/// Yazılı not penceresini açar. [kameraIleBasla] true ise önce kamera açılır.
Future<void> yaziliNotAc({bool kameraIleBasla = false}) async {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;
  final not = await showModalBottomSheet<Not>(
    context: ctx,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Renk.krem,
    builder: (_) => _YaziliNotPenceresi(kameraIleBasla: kameraIleBasla),
  );
  if (not != null) {
    mesajGoster('Not kaydedildi',
        eylem: 'Aç',
        eylemFn: () => navigatorKey.currentState
            ?.push(MaterialPageRoute(builder: (_) => NotDetay(notId: not.id))));
  }
}

/// Kameradan ya da galeriden fotoğraf seçtirir, dosya yollarını döner.
Future<List<String>> fotografSec({required bool kamera}) async {
  final secici = ImagePicker();
  if (kamera) {
    final f = await secici.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2000);
    return f == null ? [] : [f.path];
  }
  final liste = await secici.pickMultiImage(imageQuality: 85, maxWidth: 2000);
  return liste.map((f) => f.path).toList();
}

class _YaziliNotPenceresi extends StatefulWidget {
  final bool kameraIleBasla;
  const _YaziliNotPenceresi({required this.kameraIleBasla});

  @override
  State<_YaziliNotPenceresi> createState() => _YaziliNotPenceresiState();
}

class _YaziliNotPenceresiState extends State<_YaziliNotPenceresi> {
  final _metin = TextEditingController();
  final List<String> _fotograflar = [];
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    if (widget.kameraIleBasla) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fotoEkle(kamera: true));
    }
  }

  Future<void> _fotoEkle({required bool kamera}) async {
    final yollar = await fotografSec(kamera: kamera);
    if (mounted && yollar.isNotEmpty) setState(() => _fotograflar.addAll(yollar));
  }

  Future<void> _kaydet() async {
    if (_metin.text.trim().isEmpty && _fotograflar.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _kaydediliyor = true);
    final not = await Depo.instance.notEkle(
      metin: _metin.text,
      kaynak: Kaynak.yazili,
      fotografYollari: _fotograflar,
    );
    if (mounted) Navigator.pop(context, not);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _metin,
            autofocus: !widget.kameraIleBasla,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Aklında ne var?',
              filled: true,
              fillColor: Renk.acikKrem,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          if (_fotograflar.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final yol in _fotograflar)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(yol), width: 72, height: 72, fit: BoxFit.cover, cacheWidth: 216),
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: GestureDetector(
                            onTap: () => setState(() => _fotograflar.remove(yol)),
                            child: const CircleAvatar(
                                radius: 11,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close, size: 14, color: Colors.white)),
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                  onPressed: () => _fotoEkle(kamera: true),
                  icon: const Icon(Icons.photo_camera_outlined),
                  tooltip: 'Fotoğraf çek'),
              IconButton(
                  onPressed: () => _fotoEkle(kamera: false),
                  icon: const Icon(Icons.photo_library_outlined),
                  tooltip: 'Galeriden seç'),
              const Spacer(),
              FilledButton.icon(
                onPressed: _kaydediliyor ? null : _kaydet,
                icon: const Icon(Icons.check),
                label: const Text('Kaydet'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
