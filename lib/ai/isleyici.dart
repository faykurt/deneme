import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../veri/depo.dart';
import '../veri/modeller.dart';
import 'ai_ayarlar.dart';
import 'ai_modeller.dart';
import 'ai_servisi.dart';

/// Fotoğrafı yapay zekaya göndermeden önce küçültür (hız ve maliyet için).
String? _kucultBase64(String yol) {
  try {
    final bayt = File(yol).readAsBytesSync();
    var resim = img.decodeImage(bayt);
    if (resim == null) return null;
    const sinir = 1568;
    if (math.max(resim.width, resim.height) > sinir) {
      resim = resim.width >= resim.height
          ? img.copyResize(resim, width: sinir, interpolation: img.Interpolation.average)
          : img.copyResize(resim, height: sinir, interpolation: img.Interpolation.average);
    }
    return base64Encode(img.encodeJpg(resim, quality: 80));
  } catch (_) {
    return null;
  }
}

/// Notları sırayla yapay zekaya gönderip sonucu notlara yazar.
/// İnternet yoksa notlar bekler, bağlantı gelince (uygulama açılınca / belli aralıkla) devam edilir.
class AiIsleyici extends ChangeNotifier {
  AiIsleyici._();
  static final AiIsleyici instance = AiIsleyici._();

  final Set<String> _calisan = {};
  bool _dongu = false;
  AiHata? sonHata;

  bool get mesgul => _calisan.isNotEmpty;

  void hatayiTemizle() {
    sonHata = null;
    notifyListeners();
  }
  bool notIsleniyor(String id) => _calisan.contains(id);
  int get bekleyenSayisi => Depo.instance.notlar.where((n) => !n.islendi).length;

  /// Henüz işlenmemiş tüm notları sırayla işler. İlk hatada durur.
  Future<void> bekleyenleriIsle() async {
    if (_dongu || !AiAyarlar.instance.anahtarVar) return;
    _dongu = true;
    try {
      for (final n in List.of(Depo.instance.notlar.where((n) => !n.islendi))) {
        if (_calisan.contains(n.id)) continue;
        final hata = await _isle(n);
        if (hata != null) break;
      }
    } finally {
      _dongu = false;
      notifyListeners();
    }
  }

  /// Tek bir notu hemen işler (not kaydedilince açılan onay penceresi için). Hata varsa döner.
  Future<AiHata?> hemenIsle(Not not) => _calisan.contains(not.id) ? Future.value(null) : _isle(not);

  Future<AiHata?> _isle(Not not) async {
    _calisan.add(not.id);
    notifyListeners();
    try {
      final anahtar = AiAyarlar.instance.anahtar;
      if (anahtar == null || anahtar.isEmpty) {
        throw const AiHata('Yapay zeka için henüz anahtar eklenmedi.', AiHataTuru.anahtarYok);
      }
      final depo = Depo.instance;
      if (not.metin.trim().isEmpty && not.fotograflar.isEmpty) {
        not.islendi = true;
        await depo.notGuncelle(not, dokunma: false);
        return null;
      }
      final resimler = <String>[];
      for (final yol in not.fotograflar.take(4)) {
        final b = await compute(_kucultBase64, yol);
        if (b != null) resimler.add(b);
      }
      final sonuc = await AiServisi.notuIsle(
        apiKey: anahtar,
        not: not,
        agac: depo.agac,
        resimlerBase64: resimler,
      );
      await _uygula(not.id, sonuc);
      sonHata = null;
      return null;
    } on AiHata catch (e) {
      sonHata = e;
      return e;
    } catch (e) {
      sonHata = AiHata('Beklenmeyen bir sorun oldu: $e', AiHataTuru.diger);
      return sonHata;
    } finally {
      _calisan.remove(not.id);
      notifyListeners();
    }
  }

  Future<void> _uygula(String notId, AiSonuc sonuc) async {
    final depo = Depo.instance;
    final i = depo.notlar.indexWhere((n) => n.id == notId);
    if (i < 0) return; // arada silinmiş
    final not = depo.notlar[i];
    not.islendi = true;
    if (sonuc.fikirler.isNotEmpty) {
      not.aiJson = jsonEncode(sonuc.toJson());
      if (sonuc.fikirler.length == 1) {
        await fikriUygula(not, sonuc.fikirler.first);
        return;
      }
    }
    await depo.notGuncelle(not, dokunma: false);
  }

  /// Fikrin başlık, süre, tarih ve (notta kategori yoksa) kategorisini nota yazar.
  Future<void> fikriUygula(Not not, AiFikir f) async {
    final depo = Depo.instance;
    if (f.baslik.isNotEmpty) not.baslik = f.baslik;
    if (not.metin.trim().isEmpty && f.metin.isNotEmpty) not.metin = f.metin;
    if (f.sureDk > 0) not.sureDk = f.sureDk;
    final dt = f.tarihDt;
    if (dt != null) {
      not.tarih = dt.millisecondsSinceEpoch;
      not.tarihSaatli = f.saatVar;
    }
    not.islendi = true;
    await depo.notGuncelle(not, dokunma: false);
    if (not.kategoriIdler.isEmpty) {
      final gecerli = f.kategoriIdler.where((id) => depo.agac.bul(id) != null).toSet();
      if (gecerli.isNotEmpty) await depo.kategorileriAyarla(not.id, gecerli);
    }
  }

  /// Birden fazla fikri ayrı notlara böler. İlk fikir mevcut notta kalır (fotoğraflar da orada).
  Future<void> bol(Not not, List<AiFikir> fikirler) async {
    final depo = Depo.instance;
    for (var i = 0; i < fikirler.length; i++) {
      final f = fikirler[i];
      final tek = jsonEncode(AiSonuc([f]).toJson());
      if (i == 0) {
        not.metin = f.metin.isNotEmpty ? f.metin : not.metin;
        not.aiJson = tek;
        await fikriUygula(not, f);
      } else {
        final yeni = await depo.notEkle(metin: f.metin, kaynak: not.kaynak);
        yeni.aiJson = tek;
        yeni.yorum = not.yorum;
        await fikriUygula(yeni, f);
      }
    }
  }
}
