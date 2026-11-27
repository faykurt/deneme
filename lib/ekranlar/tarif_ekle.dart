import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/ai_modeller.dart';
import '../ortak.dart';
import '../tarif/tarif_ice_aktar.dart';
import '../veri/depo.dart';
import 'tarif_sayfasi.dart';
import 'yazili_not.dart' show fotografSec;

/// Tarif ekleme: bir tarif sayfasının bağlantısını yapıştır ya da (Instagram gibi) açıklama metnini yapıştır.
class TarifEkleEkrani extends StatefulWidget {
  final String? baglanti;

  /// Paylaşımdan gelen düz not: tarif eklenince silinir.
  final String? silinecekNotId;
  const TarifEkleEkrani({super.key, this.baglanti, this.silinecekNotId});

  @override
  State<TarifEkleEkrani> createState() => _TarifEkleEkraniState();
}

class _TarifEkleEkraniState extends State<TarifEkleEkrani> {
  late final _baglanti = TextEditingController(text: widget.baglanti ?? '');
  final _metin = TextEditingController();
  final List<String> _resimler = [];
  bool _calisiyor = false;
  String? _hata;

  @override
  void dispose() {
    _baglanti.dispose();
    _metin.dispose();
    super.dispose();
  }

  Future<void> _yapistir() async {
    final v = await Clipboard.getData(Clipboard.kTextPlain);
    final t = v?.text?.trim();
    if (t == null || t.isEmpty) return;
    final b = TarifIceAktar.baglantiBul(t);
    setState(() => _baglanti.text = b ?? t);
  }

  Future<void> _calistir(Future<TarifSonucu> Function() is_) async {
    setState(() {
      _calisiyor = true;
      _hata = null;
    });
    try {
      final sonuc = await is_();
      final not = await Depo.instance.tarifEkle(sonuc.tarif, kapakDosya: sonuc.kapakDosya, adimDosyalari: sonuc.adimDosyalari);
      if (widget.silinecekNotId != null) await Depo.instance.sil([widget.silinecekNotId!]);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      nav.push(MaterialPageRoute(builder: (_) => TarifSayfasi(notId: not.id)));
    } on TarifHatasi catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } on AiHata catch (e) {
      if (mounted) setState(() => _hata = e.mesaj);
    } catch (e) {
      if (mounted) setState(() => _hata = 'Beklenmeyen bir sorun oldu: $e');
    } finally {
      if (mounted) setState(() => _calisiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiVar = AiAyarlar.instance.anahtarVar;
    return Scaffold(
      appBar: AppBar(backgroundColor: Renk.zemin, title: const Text('Tarif ekle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
        children: [
          Text('Tarif sitesinden bağlantı yapıştırırsan başlık, resim, süre, malzemeler ve adımlar kendiliğinden gelir.',
              style: TextStyle(color: Renk.yazi.withValues(alpha: 0.75), fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _baglanti,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Tarif bağlantısı',
              hintText: 'https://…',
              filled: true,
              fillColor: Renk.kart,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              suffixIcon: IconButton(tooltip: 'Yapıştır', icon: const Icon(Icons.content_paste), onPressed: _yapistir),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _calisiyor ? null : () => _calistir(() => TarifIceAktar.urlden(_baglanti.text)),
            icon: const Icon(Icons.link),
            label: const Text('Bağlantıdan ekle'),
          ),
          const SizedBox(height: 22),
          Row(children: [
            Expanded(child: Divider(color: Renk.sinir)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('ya da', style: TextStyle(color: Renk.yazi.withValues(alpha: 0.6)))),
            Expanded(child: Divider(color: Renk.sinir)),
          ]),
          const SizedBox(height: 12),
          Text('Instagram gibi giriş isteyen yerlerde videonun açıklamasını kopyalayıp buraya yapıştır. İstersen videodan ekran görüntüsü de ekle, yapay zeka tarifi düzenler.',
              style: TextStyle(color: Renk.yazi.withValues(alpha: 0.75), fontSize: 13)),
          const SizedBox(height: 10),
          TextField(
            controller: _metin,
            minLines: 4,
            maxLines: 10,
            decoration: InputDecoration(
              hintText: 'Tarif metnini yapıştır (malzemeler ve yapılışı)',
              filled: true,
              fillColor: Renk.kart,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final y in _resimler)
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(y), width: 64, height: 64, fit: BoxFit.cover, cacheWidth: 200)),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _resimler.remove(y)),
                    child: const CircleAvatar(radius: 10, backgroundColor: Colors.black54, child: Icon(Icons.close, size: 12, color: Colors.white)),
                  ),
                ),
              ]),
            if (_resimler.length < 4)
              OutlinedButton.icon(
                onPressed: () async {
                  final yollar = await fotografSec(kamera: false);
                  if (yollar.isNotEmpty) setState(() => _resimler.addAll(yollar.take(4 - _resimler.length)));
                },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Ekran görüntüsü ekle'),
              ),
          ]),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _calisiyor || !aiVar
                ? null
                : () => _calistir(() => TarifIceAktar.metinden(_metin.text,
                    resimYollari: _resimler, kaynakUrl: TarifIceAktar.baglantiBul(_baglanti.text))),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Metinden ekle'),
          ),
          if (!aiVar)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Metinden ekleme için Ayarlar\'da yapay zeka anahtarı gerekir.', style: TextStyle(color: Renk.hata, fontSize: 12)),
            ),
          if (_calisiyor)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('Tarif okunuyor…', style: TextStyle(color: Renk.yazi)),
              ]),
            ),
          if (_hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(_hata!, style: TextStyle(color: Renk.hata)),
            ),
        ],
      ),
    );
  }
}
