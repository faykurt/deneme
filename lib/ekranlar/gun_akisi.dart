import 'not_ac.dart';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../kategori_gorunum.dart';
import '../oneri/oneri_deposu.dart';
import '../ortak.dart';
import '../takvim/etkinlik_ikonlari.dart';
import '../takvim/etkinlik_simgesi.dart';
import '../takvim/takvim_deposu.dart';
import '../takvim/takvim_kaynagi.dart' show TakvimHatasi;
import '../takvim/takvim_modeller.dart';

/// Bir günün dikey akışı: süreyle uzayan renkli ikon kapsülleri, "şimdi" işareti,
/// etkinlikler arasındaki boşluklarda öneri ve gün sonunda "Günü kapatalım mı?" kartı.
class GunAkisi extends StatelessWidget {
  final DateTime gun;
  final void Function(TEtkinlik) onAc;

  /// Yeni etkinlik: başlık (önerilmişse) ve başlangıç zamanı ile.
  final Future<void> Function({String? baslik, DateTime? baslangic}) onEkle;
  final bool listele;

  const GunAkisi({super.key, required this.gun, required this.onAc, required this.onEkle, this.listele = true});

  static const _kolonSaat = 46.0;
  static const _kolonKapsul = 52.0;

  static String sureMetni(int dk) {
    if (dk < 60) return '$dk dk';
    final s = dk ~/ 60, d = dk % 60;
    return d == 0 ? '$s sa' : '$s sa $d dk';
  }

  @override
  Widget build(BuildContext context) {
    final depo = TakvimDeposu.instance;
    final simdi = DateTime.now();
    final bugun = gunBasi(simdi);
    final bugunMu = gunBasi(gun) == bugun;
    final gelecekGun = !gunBasi(gun).isBefore(bugun);
    final liste = depo.gununEtkinlikleri(gun);
    final tumGun = liste.where((e) => e.tumGun).toList();
    final saatli = liste.where((e) => !e.tumGun).toList();
    final g0 = gunBasi(gun);

    final satirlar = <Widget>[];
    var imlecKonum = g0.add(const Duration(hours: 6)); // gün başlangıcı gibi: boşluklar 06:00'dan sayılır
    var simdiyiKoyduk = !bugunMu;

    Widget simdiIsareti() => _SimdiIsareti(saat: DateFormat('HH:mm').format(simdi));

    for (final e in saatli) {
      final bas = e.baslangic.isBefore(g0) ? g0 : e.baslangic;
      final bit = e.bitis.isAfter(sonrakiGun(g0)) ? sonrakiGun(g0) : (e.bitis.isAfter(bas) ? e.bitis : bas.add(const Duration(minutes: 30)));
      // Boşluk (yalnızca bugün ve sonrası için, geçmişte öneri anlamsız)
      final bosDk = bas.difference(imlecKonum).inMinutes;
      if (gelecekGun && bosDk >= 25 && (bugunMu ? bas.isAfter(simdi) : true)) {
        final baslangicBos = bugunMu && imlecKonum.isBefore(simdi) ? simdi : imlecKonum;
        final dk = bas.difference(baslangicBos).inMinutes;
        if (dk >= 25) satirlar.add(_BosAralik(baslangic: baslangicBos, dakika: dk));
      }
      if (!simdiyiKoyduk && simdi.isBefore(bas)) {
        satirlar.add(simdiIsareti());
        simdiyiKoyduk = true;
      }
      satirlar.add(_EtkinlikSatiri(e: e, bas: bas, bit: bit, simdi: simdi, bugunMu: bugunMu, onAc: onAc));
      if (!simdiyiKoyduk && simdi.isBefore(bit)) simdiyiKoyduk = true; // etkinliğin içindeyiz: kapsülde gösterilir
      if (bit.isAfter(imlecKonum)) imlecKonum = bit;
    }
    // Son etkinlikten sonra gün sonuna (22:00) kadar boşluk
    if (!simdiyiKoyduk) satirlar.add(simdiIsareti());
    if (gelecekGun) {
      final son = g0.add(const Duration(hours: 22));
      final bas = bugunMu && imlecKonum.isBefore(simdi) ? simdi : imlecKonum;
      final dk = son.difference(bas).inMinutes;
      if (dk >= 25) satirlar.add(_BosAralik(baslangic: bas, dakika: math.min(dk, 240)));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
      children: [
        for (final e in tumGun) _TumGunSerit(e: e, onAc: onAc),
        if (saatli.isEmpty && tumGun.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text('Bu gün boş. Bir şey eklemek için + düğmesine dokun.',
                textAlign: TextAlign.center, style: TextStyle(color: Renk.yazi.withValues(alpha: 0.6))),
          ),
        ...satirlar,
        if (bugunMu) _GunuKapat(onEkle: onEkle),
      ],
    );
  }
}

Color _renk(TEtkinlik e) => TakvimDeposu.instance.renkOf(e) ?? Renk.vurgu;

/// Kapsülün içindeki daire: kendi seçtiğin ikon, emoji, kategori ikonu ya da türe göre ikon.
/// Dokununca ikon seçici açılır.
Widget _simge(BuildContext context, TEtkinlik e, Color renk) {
  final s = TakvimDeposu.instance.simgeOf(e, size: 20, renk: Renk.vurguUstu);
  return Tooltip(
    message: 'İkonu değiştir',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => etkinlikIkonuSec(context, e),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: s ?? Icon(Icons.event_note, size: 20, color: Renk.vurguUstu),
      ),
    ),
  );
}

/// Etkinlik için ikon seçici: hazır ikonlar ve emoji. Emoji başlığa yazılır (Samsung Takvim'de de görünür),
/// hazır ikon yalnızca Aklımda'da saklanır.
Future<void> etkinlikIkonuSec(BuildContext context, TEtkinlik e) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Renk.zemin,
    builder: (ctx) => _IkonSecici(e: e),
  );
}

class _IkonSecici extends StatefulWidget {
  final TEtkinlik e;
  const _IkonSecici({required this.e});

  @override
  State<_IkonSecici> createState() => _IkonSeciciState();
}

class _IkonSeciciState extends State<_IkonSecici> {
  final _emoji = TextEditingController();

  @override
  void dispose() {
    _emoji.dispose();
    super.dispose();
  }

  Future<void> _ikonSec(String? anahtar) async {
    await EtkinlikIkonlari.instance.ata(widget.e.eventId, anahtar);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _emojiUygula() async {
    final e = KategoriGorunum.ilkEmoji(_emoji.text);
    if (e == null) return;
    try {
      final taslak = TEtkinlikTaslagi.dan(widget.e)..baslik = EtkinlikSimgesi.baslikEmojiyle(widget.e.baslik, e);
      await TakvimDeposu.instance.guncelle(widget.e, taslak, Kapsam.hepsi);
      await EtkinlikIkonlari.instance.ata(widget.e.eventId, null);
    } on TakvimHatasi catch (h) {
      mesajGoster(h.mesaj);
    } catch (h) {
      mesajGoster('Emoji eklenemedi: $h');
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final renk = TakvimDeposu.instance.renkOf(widget.e) ?? Renk.vurgu;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Etkinlik ikonu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final k in EtkinlikIkonlari.secenekler.entries)
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _ikonSec(k.key),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: renk.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                    child: Icon(k.value, color: renk),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _emoji,
                  decoration: const InputDecoration(labelText: 'Ya da emoji', hintText: 'Klavyenin emoji düğmesiyle seç'),
                  onSubmitted: (_) => _emojiUygula(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _emojiUygula, child: const Text('Uygula')),
            ]),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _ikonSec(null),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Otomatik ikona dön'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _EtkinlikSatiri extends StatelessWidget {
  final TEtkinlik e;
  final DateTime bas;
  final DateTime bit;
  final DateTime simdi;
  final bool bugunMu;
  final void Function(TEtkinlik) onAc;
  const _EtkinlikSatiri({required this.e, required this.bas, required this.bit, required this.simdi, required this.bugunMu, required this.onAc});

  @override
  Widget build(BuildContext context) {
    final renk = _renk(e);
    final dk = bit.difference(bas).inMinutes;
    final gecmis = bugunMu ? bit.isBefore(simdi) : gunBasi(bas).isBefore(gunBasi(simdi));
    final suruyor = bugunMu && !simdi.isBefore(bas) && simdi.isBefore(bit);
    final kapsulYuksekligi = (dk * 0.9).clamp(52, 180).toDouble();
    final f = DateFormat('HH:mm');
    final temiz = EtkinlikSimgesi.temizBaslik(e.baslik);
    return Opacity(
      opacity: gecmis ? 0.6 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onAc(e),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: GunAkisi._kolonSaat,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(f.format(bas),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Renk.yazi.withValues(alpha: 0.75))),
              ),
            ),
            SizedBox(
              width: GunAkisi._kolonKapsul,
              child: Stack(alignment: Alignment.topCenter, children: [
                Positioned.fill(child: Center(child: Container(width: 2, color: Renk.yazi.withValues(alpha: 0.1)))),
                Container(
                  width: 44,
                  height: kapsulYuksekligi,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(24),
                    border: suruyor ? Border.all(color: renk, width: 2) : null,
                  ),
                  alignment: Alignment.topCenter,
                  child: _simge(context, e, renk),
                ),
              ]),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(8, 4, 0, 4),
                padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                constraints: BoxConstraints(minHeight: kapsulYuksekligi),
                decoration: BoxDecoration(
                  color: Renk.kart,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Renk.sinir),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(temiz.isEmpty ? e.baslik : temiz,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Renk.yazi, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${f.format(bas)} – ${f.format(bit)} · ${GunAkisi.sureMetni(dk)}${TakvimDeposu.instance.cokTakvimli && TakvimDeposu.instance.takvimAdi(e.takvimId) != null ? ' · ${TakvimDeposu.instance.takvimAdi(e.takvimId)}' : ''}',
                      style: TextStyle(color: Renk.yazi.withValues(alpha: 0.65), fontSize: 12)),
                  if (suruyor)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Şu an · ${GunAkisi.sureMetni(bit.difference(simdi).inMinutes)} kaldı',
                          style: TextStyle(color: renk, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SimdiIsareti extends StatelessWidget {
  final String saat;
  const _SimdiIsareti({required this.saat});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 36,
        child: Row(children: [
          SizedBox(width: GunAkisi._kolonSaat),
          SizedBox(
            width: GunAkisi._kolonKapsul,
            child: Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(color: Renk.vurgu, shape: BoxShape.circle))),
          ),
          Expanded(
            child: Row(children: [
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: Renk.vurgu, borderRadius: BorderRadius.circular(12)),
                child: Text('Şimdi · $saat', style: TextStyle(color: Renk.vurguUstu, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              Expanded(child: Container(height: 1.5, color: Renk.vurgu.withValues(alpha: 0.5))),
            ]),
          ),
        ]),
      );
}

/// Etkinlikler arasındaki boşluk: süre ve (varsa) uygulamadan öneri.
class _BosAralik extends StatelessWidget {
  final DateTime baslangic;
  final int dakika;
  const _BosAralik({required this.baslangic, required this.dakika});

  @override
  Widget build(BuildContext context) {
    final oneri = OneriDeposu.instance.suAnNeYapabilirim(math.min(dakika, 180), simdi: baslangic).firstOrNull;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(width: GunAkisi._kolonSaat),
        SizedBox(
          width: GunAkisi._kolonKapsul,
          child: Center(child: Container(width: 2, color: Renk.yazi.withValues(alpha: 0.1))),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 0, 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: oneri == null ? null : () => notuAc(context, oneri),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Renk.vurgu.withValues(alpha: 0.45), width: 1.5),
                ),
                child: Row(children: [
                  Icon(oneri == null ? Icons.hourglass_empty : Icons.bolt, size: 18, color: Renk.vurgu),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      oneri == null
                          ? '${GunAkisi.sureMetni(dakika)} boşluk'
                          : '${GunAkisi.sureMetni(dakika)} boşluk: ${oneri.gorunenBaslik} için uygun',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: Renk.yazi.withValues(alpha: 0.85)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TumGunSerit extends StatelessWidget {
  final TEtkinlik e;
  final void Function(TEtkinlik) onAc;
  const _TumGunSerit({required this.e, required this.onAc});

  @override
  Widget build(BuildContext context) {
    final renk = _renk(e);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: renk.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onAc(e),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              _simge(context, e, renk),
              const SizedBox(width: 10),
              Expanded(
                child: Text(EtkinlikSimgesi.temizBaslik(e.baslik),
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, color: Renk.yazi)),
              ),
              Text('Tüm gün', style: TextStyle(fontSize: 12, color: Renk.yazi.withValues(alpha: 0.65))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bugünün sonunda: "Bugün neler yaptın?" ve geçmişte sık yazdığın başlıklardan hızlı ekleme.
class _GunuKapat extends StatelessWidget {
  final Future<void> Function({String? baslik, DateTime? baslangic}) onEkle;
  const _GunuKapat({required this.onEkle});

  List<String> _oneriler() {
    final depo = TakvimDeposu.instance;
    final simdi = DateTime.now();
    final bugun = gunBasi(simdi);
    final bugunkuler = depo.gununEtkinlikleri(bugun).map((e) => EtkinlikSimgesi.temizBaslik(e.baslik).toLowerCase()).toSet();
    final sayac = <String, int>{};
    final goruntu = <String, String>{};
    for (final e in depo.etkinlikler) {
      if (e.tumGun || !e.baslangic.isBefore(bugun)) continue;
      final t = EtkinlikSimgesi.temizBaslik(e.baslik);
      if (t.isEmpty || t.length > 28) continue;
      final k = t.toLowerCase();
      if (bugunkuler.contains(k)) continue;
      sayac[k] = (sayac[k] ?? 0) + 1;
      goruntu[k] = t;
    }
    final sirali = sayac.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sirali.take(4)) goruntu[e.key]!];
  }

  DateTime _varsayilanBaslangic() {
    final s = DateTime.now().subtract(const Duration(hours: 1));
    return DateTime(s.year, s.month, s.day, s.hour, (s.minute ~/ 15) * 15);
  }

  @override
  Widget build(BuildContext context) {
    final oneriler = _oneriler();
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Renk.sinir),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.local_cafe_outlined, color: Renk.vurgu),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Günü kapatalım mı?',
                style: TextStyle(color: Renk.yazi, fontWeight: FontWeight.w800, fontSize: 17)),
          ),
        ]),
        const SizedBox(height: 2),
        Text('Bugün neler yaptığını takvime işle.', style: TextStyle(color: Renk.yazi.withValues(alpha: 0.7), fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final o in oneriler)
            ActionChip(
              label: Text(o),
              onPressed: () => onEkle(baslik: o, baslangic: _varsayilanBaslangic()),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Ekle'),
            onPressed: () => onEkle(baslangic: _varsayilanBaslangic()),
          ),
        ]),
      ]),
    );
  }
}
