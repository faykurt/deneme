import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/ai_modeller.dart';
import '../ai/ai_servisi.dart';
import '../ekranlar/piksel_sahne.dart';
import '../ekranlar/takvime_ekle.dart' show notIsMi;
import '../takvim/bos_zaman.dart';
import '../takvim/takvim_ayarlari.dart';
import '../takvim/takvim_deposu.dart';
import '../takvim/takvim_modeller.dart';
import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'bildirim_servisi.dart';
import 'oneri_modeller.dart';

/// Günlük öneriler: yapay zekadan gün bölümü başında alınan paket, ana sayfa kartları, ertelemeler ve bildirimler.
class OneriDeposu extends ChangeNotifier {
  OneriDeposu._();
  static final OneriDeposu instance = OneriDeposu._();

  static const _paketAnahtari = 'oneri_paketi';
  static const _acikAnahtari = 'oneri_acik';
  static const _sinirAnahtari = 'bildirim_siniri';
  static const _ertelemeAnahtari = 'oneri_ertelenen';
  static const _izinSorulduAnahtari = 'bildirim_izni_soruldu';

  bool acik = true;
  int bildirimSiniri = 3;
  OneriPaketi? paket;

  /// notId -> "yyyy-MM-dd": o güne kadar öneri dışı kalır, o gün tekrar girer.
  Map<String, String> ertelenen = {};
  bool yenileniyor = false;
  AiHata? sonHata;

  Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      acik = p.getBool(_acikAnahtari) ?? true;
      bildirimSiniri = p.getInt(_sinirAnahtari) ?? 3;
      paket = OneriPaketi.coz(p.getString(_paketAnahtari));
      final e = p.getStringList(_ertelemeAnahtari) ?? [];
      ertelenen = {
        for (final s in e)
          if (s.contains('|')) s.split('|').first: s.split('|').last,
      };
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _yaz() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_acikAnahtari, acik);
      await p.setInt(_sinirAnahtari, bildirimSiniri);
      if (paket != null) await p.setString(_paketAnahtari, paket!.toJsonMetni());
      await p.setStringList(_ertelemeAnahtari, [for (final e in ertelenen.entries) '${e.key}|${e.value}']);
    } catch (_) {}
  }

  Future<void> acikAyarla(bool v) async {
    acik = v;
    await _yaz();
    notifyListeners();
  }

  Future<void> sinirAyarla(int n) async {
    bildirimSiniri = n.clamp(0, 3);
    await _yaz();
    notifyListeners();
  }

  // ---- Zaman yardımcıları

  static String bolumAdi(DateTime t) => SahneBolumu.simdi(t).name;

  /// Hafta sonu planı hedefi: Cuma "genel", Cuma 22:00'den sonra ve Cumartesi "cumartesi",
  /// Cumartesi 22:00'den sonra ve Pazar "pazar". Diğer günler null.
  static String? planHedefi(DateTime t) => switch (t.weekday) {
        DateTime.friday => t.hour < 22 ? 'genel' : 'cumartesi',
        DateTime.saturday => t.hour < 22 ? 'cumartesi' : 'pazar',
        DateTime.sunday => 'pazar',
        _ => null,
      };

  // ---- Adaylar

  bool _ertelemede(String notId, DateTime simdi) {
    final g = ertelenen[notId];
    return g != null && g.compareTo(gunAnahtari(simdi)) > 0;
  }

  /// Önerilebilecek notlar: kullanıcının "Bana hatırlat / öner" dediği, arşivde olmayan, bitmemiş, liste olmayan, ertelemede olmayanlar.
  List<Not> adaylar(DateTime simdi) => Depo.instance.notlar
      .where((n) => n.oneriDahil && !n.arsiv && !n.liste && n.durum != Durum.yapildi && !_ertelemede(n.id, simdi))
      .toList();

  bool paketGuncelMi(DateTime simdi) {
    final p = paket;
    if (p == null) return false;
    if (p.gun != gunAnahtari(simdi) || p.bolum != bolumAdi(simdi)) return false;
    final hedef = planHedefi(simdi);
    return hedef == null || p.plan?.gun == hedef;
  }

  /// Ana sayfada gösterilecek öneriler (kaybolmuş, bitmiş ya da ertelenmiş notlar çıkarılır).
  List<({Not not, Oneri oneri})> gosterilecekler([DateTime? simdi]) {
    final s = simdi ?? DateTime.now();
    final p = paket;
    if (p == null || !acik) return [];
    final sonuc = <({Not not, Oneri oneri})>[];
    for (final o in p.oneriler) {
      final n = Depo.instance.notlar.where((x) => x.id == o.notId).firstOrNull;
      if (n == null || n.arsiv || n.durum == Durum.yapildi || _ertelemede(n.id, s)) continue;
      sonuc.add((not: n, oneri: o));
    }
    return sonuc.take(3).toList();
  }

  /// Hafta sonu planındaki notlar (bölüm başına), plan yoksa ya da hedef bugünkü hedef değilse boş.
  ({String gun, List<Not> ogle, List<Not> aksam})? haftaSonuPlani([DateTime? simdi]) {
    final s = simdi ?? DateTime.now();
    final plan = paket?.plan;
    final hedef = planHedefi(s);
    if (!acik || plan == null || hedef == null || plan.gun != hedef || plan.bos) return null;
    List<Not> coz(List<String> idler) {
      final sonuc = <Not>[];
      for (final id in idler) {
        final n = Depo.instance.notlar.where((x) => x.id == id && !x.arsiv && x.durum != Durum.yapildi).firstOrNull;
        if (n != null) sonuc.add(n);
      }
      return sonuc;
    }

    return (gun: plan.gun, ogle: coz(plan.ogle), aksam: coz(plan.aksam));
  }

  // ---- "Şu an ne yapabilirim?" (yapay zekasız, anında)

  List<Not> suAnNeYapabilirim(int dakika, {DateTime? simdi, bool isBlogundayim = false}) {
    final s = simdi ?? DateTime.now();
    final ayar = TakvimAyarlari.instance.kurallar;
    final liste = adaylar(s).where((n) {
      final sure = n.sureDk ?? 30;
      if (sure > dakika) return false;
      if (notIsMi(n) && (ayar.haftaSonuGibi(s) || !isBlogundayim)) return false;
      return true;
    }).toList();
    // En uzun süredir dokunulmayan ve tarihi yaklaşan önce.
    liste.sort((a, b) {
      final ta = a.tarih, tb = b.tarih;
      if (ta != null && tb != null && ta != tb) return ta.compareTo(tb);
      if (ta != null && tb == null) return -1;
      if (ta == null && tb != null) return 1;
      return a.sonDokunma.compareTo(b.sonDokunma);
    });
    return liste.take(3).toList();
  }

  /// Şu an takvimde iş bloğu içinde miyim?
  Future<bool> isBlogundaMi([DateTime? simdi]) async {
    final s = simdi ?? DateTime.now();
    final tk = TakvimDeposu.instance;
    if (!tk.hazir) return false;
    final liste = await tk.gunEtkinlikleri(s);
    final kelime = TakvimAyarlari.instance.isKelimesi;
    return liste.any((e) => BosZamanBulucu.isBlogu(e, kelime) && !e.baslangic.isAfter(s) && e.bitis.isAfter(s));
  }

  // ---- Paket yenileme

  Future<void> yenile({bool zorla = false, DateTime? simdi}) async {
    if (!acik || !AiAyarlar.instance.anahtarVar || yenileniyor) return;
    final s = simdi ?? DateTime.now();
    if (!zorla && paketGuncelMi(s)) return;
    yenileniyor = true;
    notifyListeners();
    try {
      final hedef = planHedefi(s);
      final adaylarListesi = adaylar(s);
      if (adaylarListesi.isEmpty) {
        paket = OneriPaketi(
            olusturma: s.millisecondsSinceEpoch,
            bolum: bolumAdi(s),
            gun: gunAnahtari(s),
            oneriler: const [],
            plan: hedef == null ? null : HaftaSonuPlani(gun: hedef));
        await _yaz();
        return;
      }
      final baglam = await baglamMetni(s, adaylarListesi, hedef);
      final ham = await AiServisi.oneriPaketi(apiKey: AiAyarlar.instance.anahtar!, baglam: baglam);
      final gecerliIdler = adaylarListesi.map((n) => n.id).toSet();
      final oneriler = <Oneri>[
        for (final e in (ham['oneriler'] as List? ?? []))
          if (e is Map<String, dynamic> && gecerliIdler.contains(e['not_id']) && (e['neden'] ?? '').toString().trim().isNotEmpty)
            Oneri.fromJson(e),
      ].take(3).toList();
      List<String> idler(Object? x) => [
            for (final i in (x as List? ?? []))
              if (gecerliIdler.contains(i)) i.toString(),
          ].take(3).toList();
      final hs = ham['hafta_sonu'] as Map<String, dynamic>? ?? {};
      paket = OneriPaketi(
        olusturma: s.millisecondsSinceEpoch,
        bolum: bolumAdi(s),
        gun: gunAnahtari(s),
        oneriler: oneriler,
        plan: hedef == null ? null : HaftaSonuPlani(gun: hedef, ogle: idler(hs['ogle']), aksam: idler(hs['aksam'])),
      );
      sonHata = null;
      await _yaz();
      await bildirimleriKur(s);
    } on AiHata catch (e) {
      sonHata = e;
    } catch (e) {
      sonHata = AiHata('Öneriler hazırlanamadı: $e', AiHataTuru.diger);
    } finally {
      yenileniyor = false;
      notifyListeners();
    }
  }

  /// Paketteki bildirim saatlerinden bugünün bildirimlerini kurar (günlük sınır içinde).
  Future<void> bildirimleriKur(DateTime simdi) async {
    final p = paket;
    if (p == null) return;
    final liste = <({String notId, String baslik, String metin, DateTime zaman})>[];
    if (bildirimSiniri > 0) {
      for (final o in p.oneriler) {
        final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(o.bildirimSaati);
        if (m == null) continue;
        final saat = int.parse(m.group(1)!), dk = int.parse(m.group(2)!);
        if (saat > 23 || dk > 59) continue;
        final not = Depo.instance.notlar.where((n) => n.id == o.notId).firstOrNull;
        if (not == null) continue;
        liste.add((
          notId: not.id,
          baslik: not.gorunenBaslik,
          metin: o.neden,
          zaman: DateTime(simdi.year, simdi.month, simdi.day, saat, dk),
        ));
      }
    }
    final b = BildirimServisi.instance;
    await _izniBirKezSor();
    await b.oneriBildirimleriniKur(bildirimler: liste, sinir: bildirimSiniri, simdi: simdi);
  }

  Future<void> _izniBirKezSor() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_izinSorulduAnahtari) == true) return;
      await p.setBool(_izinSorulduAnahtari, true);
    } catch (_) {}
    await BildirimServisi.instance.izinIste();
  }

  // ---- Kart eylemleri

  /// Notun yapılmayan ilk adımı varsa onu tamamlar ve true döner; adım yoksa false.
  Future<bool> sonrakiAdimiTamamla(Not not) async {
    final adim = not.adimlar.where((a) => !a.yapildi).firstOrNull;
    if (adim == null || adim.id == null) return false;
    await Depo.instance.adimDurumu(adim.id!, Durum.yapildi);
    notifyListeners();
    return true;
  }

  /// Not tamamen bitti: tamamlandı olarak arşive gider.
  Future<void> tamamenBitti(Not not) async {
    not.durum = Durum.yapildi;
    await Depo.instance.notGuncelle(not);
    await Depo.instance.arsivle([not.id], true);
    notifyListeners();
  }

  /// "Sonra hatırlat" ya da "bugünlük yaptım": yarına kadar öneri dışı kalır.
  Future<void> yarinaBirak(Not not, {bool ertelemeSay = true, DateTime? simdi}) async {
    final s = simdi ?? DateTime.now();
    ertelenen[not.id] = gunAnahtari(sonrakiGun(s));
    if (ertelemeSay) {
      not.ertelemeSayisi++;
      await Depo.instance.notGuncelle(not, dokunma: false);
    }
    await _yaz();
    notifyListeners();
  }

  // ---- Bağlam metni (yapay zekaya giden)

  Future<String> baglamMetni(DateTime s, List<Not> aday, String? hedef) async {
    final tr = DateFormat('d MMMM y, EEEE, HH:mm', 'tr');
    final ayar = TakvimAyarlari.instance;
    final kurallar = ayar.kurallar;
    final b = StringBuffer()
      ..writeln('Şu an: ${tr.format(s)} (Türkiye saati)')
      ..writeln('Gün bölümü: ${switch (bolumAdi(s)) {
        'sabah' => 'sabah (06-11)',
        'ogle' => 'öğle (11-17)',
        _ => 'akşam (17-06)',
      }}')
      ..writeln('Bugün hafta sonu ya da izin günü mü: ${kurallar.haftaSonuGibi(s) ? 'evet' : 'hayır'}');
    final uykular = kurallar.uykular(gunBasi(s), gunBasi(s).add(const Duration(days: 1)));
    if (uykular.isEmpty) {
      b.writeln('Uyku saatleri: tanımlı değil');
    } else {
      final f = DateFormat('HH:mm');
      b.writeln('Uyku: ${uykular.map((u) => '${f.format(u.$1)}-${f.format(u.$2)}').join(', ')}');
    }
    b.writeln('İş bloğu kelimesi (takvim başlığında): ${ayar.isKelimesi}');
    final tk = TakvimDeposu.instance;
    if (tk.hazir) {
      final evs = await tk.gunEtkinlikleri(s);
      final f = DateFormat('HH:mm');
      b.writeln('Bugünün takvimi:');
      if (evs.isEmpty) b.writeln('- (etkinlik yok)');
      for (final e in evs) {
        final tur = BosZamanBulucu.isBlogu(e, ayar.isKelimesi) ? ' [İŞ BLOĞU]' : '';
        b.writeln('- ${e.tumGun ? 'tüm gün' : '${f.format(e.baslangic)}-${f.format(e.bitis)}'} ${e.baslik}$tur');
      }
    } else {
      b.writeln('Takvim bağlı değil.');
    }
    b
      ..writeln('bildirim_hakki: ${bildirimSiniri == 0 ? 0 : bildirimSiniri}')
      ..writeln(hedef == null
          ? 'Hafta sonu planı istenmedi.'
          : 'Hafta sonu planı isteniyor (${hedef == 'genel' ? 'genel hafta sonu fikirleri' : hedef}).')
      ..writeln()
      ..writeln('Aday notlar (veri):');
    final agac = Depo.instance.agac;
    for (final n in (aday..sort((a, b) => a.sonDokunma.compareTo(b.sonDokunma))).take(40)) {
      final yas = s.difference(DateTime.fromMillisecondsSinceEpoch(n.olusturma)).inDays;
      final kat = n.kategoriIdler.map(agac.tamAd).where((e) => e.isNotEmpty).join(', ');
      final yapilmayan = n.adimlar.where((a) => !a.yapildi).length;
      final ozet = n.gorunenBaslik.replaceAll('\n', ' ');
      b.writeln('- id=${n.id} | $ozet | kategori: ${kat.isEmpty ? '-' : kat}'
          '${n.sureDk != null ? ' | süre ${n.sureDk} dk' : ''}'
          '${n.tarih != null ? ' | tarih ${DateFormat('d MMM', 'tr').format(DateTime.fromMillisecondsSinceEpoch(n.tarih!))}' : ''}'
          ' | $yas gündür bekliyor'
          '${n.adimlar.isNotEmpty ? ' | $yapilmayan adım kaldı' : ''}'
          '${n.ertelemeSayisi > 0 ? ' | ${n.ertelemeSayisi} kez ertelendi' : ''}'
          '${n.gormezdenSayisi > 0 ? ' | gormezden: ${n.gormezdenSayisi}' : ''}'
          '${notIsMi(n) ? ' | İŞ NOTU' : ''}'
          '${ertelenen.containsKey(n.id) ? ' | ertelenmis' : ''}');
    }
    return b.toString();
  }
}
