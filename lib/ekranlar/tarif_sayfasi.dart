import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ortak.dart';
import '../tarif/tarif_modeli.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'not_detay.dart';

/// Yemek kitabındaki bir tarifin sayfası: büyük resim, süre ve kişi sayısı, malzeme listesi, adımlar, kaynak bağlantısı.
class TarifSayfasi extends StatelessWidget {
  final String notId;
  const TarifSayfasi({super.key, required this.notId});

  Not? _not() => Depo.instance.notlar.where((n) => n.id == notId).firstOrNull;

  Future<void> _kaynagiAc(String url) async {
    try {
      final tamam = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!tamam) mesajGoster('Bağlantı açılamadı.');
    } catch (_) {
      mesajGoster('Bağlantı açılamadı.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Depo.instance,
      builder: (context, _) {
        final n = _not();
        final t = n?.tarif;
        if (n == null || t == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Bu tarif artık yok.')),
          );
        }
        final kapak = n.fotograflar.isNotEmpty ? n.fotograflar.first : null;
        final yazi = Theme.of(context).textTheme;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: kapak == null ? 0 : 260,
                backgroundColor: Renk.zemin,
                foregroundColor: Renk.yazi,
                actions: [
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'not') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NotDetay(notId: n.id),
                          ),
                        );
                      } else if (v == 'sil') {
                        Navigator.pop(context);
                        await silVeGeriAlGoster([n.id]);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'not',
                        child: Text('Not olarak aç (kategori, yorum)'),
                      ),
                      PopupMenuItem(value: 'sil', child: Text('Tarifi sil')),
                    ],
                  ),
                ],
                flexibleSpace: kapak == null
                    ? null
                    : FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(kapak),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  ColoredBox(color: Renk.vurguKart(0.3)),
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0x00000000),
                                    Color(0x66000000),
                                  ],
                                  stops: [0.6, 1.0],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.baslik,
                        style: TextStyle(
                          fontFamily: 'Caveat',
                          fontVariations: const [FontVariation('wght', 700)],
                          fontSize: 38,
                          height: 1.05,
                          color: Renk.yazi,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Bilgi(
                            Icons.schedule,
                            t.sure == null
                                ? 'Süre yok'
                                : Tarif.sureMetni(t.sure!),
                          ),
                          if (t.hazirlikDk != null)
                            _Bilgi(
                              Icons.content_cut,
                              'Hazırlık ${Tarif.sureMetni(t.hazirlikDk!)}',
                            ),
                          if (t.pisirmeDk != null)
                            _Bilgi(
                              Icons.local_fire_department_outlined,
                              'Pişirme ${Tarif.sureMetni(t.pisirmeDk!)}',
                            ),
                          if (t.kisi != null)
                            _Bilgi(Icons.people_outline, t.kisi!),
                          _Bilgi(Icons.folder_outlined, t.kategori),
                        ],
                      ),
                      if (t.aciklama != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          t.aciklama!,
                          style: yazi.bodyMedium?.copyWith(
                            color: Renk.yazi.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                      if (t.kaynakUrl != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _kaynagiAc(t.kaynakUrl!),
                          icon: const Icon(Icons.open_in_new),
                          label: Text(
                            Uri.tryParse(t.kaynakUrl!)?.host
                                        .contains('instagram') ==
                                    true
                                ? 'Videoyu aç'
                                : 'Kaynağı aç',
                          ),
                        ),
                      ],
                      if (t.malzemeler.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _Baslik('Malzemeler'),
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Renk.kart,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Renk.sinir),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: Column(
                              children: [
                                for (var i = 0; i < t.malzemeler.length; i++)
                                  CheckboxListTile(
                                    dense: true,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    value: t.isaretli.contains(i),
                                    title: Text(
                                      t.malzemeler[i],
                                      style: TextStyle(
                                        color: Renk.yazi.withValues(
                                          alpha: t.isaretli.contains(i)
                                              ? 0.5
                                              : 1,
                                        ),
                                        decoration: t.isaretli.contains(i)
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                    onChanged: (v) {
                                      final yeni = {...t.isaretli};
                                      if (v == true) {
                                        yeni.add(i);
                                      } else {
                                        yeni.remove(i);
                                      }
                                      Depo.instance.tarifiGuncelle(
                                        n.id,
                                        t.kopya(
                                          isaretli: yeni.toList()..sort(),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (t.adimlar.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _Baslik('Yapılışı'),
                        const SizedBox(height: 8),
                        for (var i = 0; i < t.adimlar.length; i++)
                          _Adim(sira: i + 1, adim: t.adimlar[i]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Baslik extends StatelessWidget {
  final String metin;
  const _Baslik(this.metin);
  @override
  Widget build(BuildContext context) => Text(
    metin,
    style: TextStyle(
      color: Renk.yazi,
      fontWeight: FontWeight.w800,
      fontSize: 19,
    ),
  );
}

class _Bilgi extends StatelessWidget {
  final IconData ikon;
  final String metin;
  const _Bilgi(this.ikon, this.metin);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Renk.vurguKart(0.18),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ikon, size: 16, color: Renk.vurgu),
        const SizedBox(width: 6),
        Text(
          metin,
          style: TextStyle(
            fontSize: 13,
            color: Renk.yazi,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _Adim extends StatelessWidget {
  final int sira;
  final TarifAdimi adim;
  const _Adim({required this.sira, required this.adim});

  @override
  Widget build(BuildContext context) {
    final resim = adim.resim != null && File(adim.resim!).existsSync()
        ? adim.resim
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Renk.vurgu,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$sira',
              style: TextStyle(
                color: Renk.vurguUstu,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adim.metin,
                  style: TextStyle(color: Renk.yazi, fontSize: 15, height: 1.4),
                ),
                if (resim != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(resim),
                        width: double.infinity,
                        height: 170,
                        fit: BoxFit.cover,
                        cacheWidth: 900,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
