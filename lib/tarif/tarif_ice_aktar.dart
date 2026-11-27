import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../ai/ai_ayarlar.dart';
import '../ai/ai_servisi.dart';
import 'tarif_ayristirici.dart';
import 'tarif_modeli.dart';

class TarifHatasi implements Exception {
  final String mesaj;
  const TarifHatasi(this.mesaj);
  @override
  String toString() => mesaj;
}

/// İçe aktarılan tarif: veri ve indirilmiş yerel resim dosyaları (geçici klasörde).
class TarifSonucu {
  final Tarif tarif;
  final String? kapakDosya;
  final List<String?> adimDosyalari;
  const TarifSonucu(this.tarif, {this.kapakDosya, this.adimDosyalari = const []});
}

/// Bir tarif sayfasının bağlantısından (ya da yapıştırılan metinden) tarifi çıkarır.
/// Önce sayfanın kendi düzenli tarif verisi okunur; yoksa yapay zeka sayfa metninden çıkarır.
class TarifIceAktar {
  /// Testlerde sahte sunucu için.
  static http.Client Function() istemciUret = http.Client.new;

  static const _tarayici =
      'Mozilla/5.0 (Linux; Android 14; SM-A525F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';

  static bool instagramMi(String url) {
    final h = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return h.contains('instagram.com') || h.contains('instagr.am');
  }

  /// Metinden ilk bağlantıyı bulur (paylaşılan metinler bağlantıdan başka şey de içerebilir).
  static String? baglantiBul(String metin) {
    final m = RegExp(r'https?://[^\s<>"\x27]+').firstMatch(metin);
    return m?.group(0);
  }

  static Future<String> _getir(Uri adres) async {
    final c = istemciUret();
    try {
      final r = await c
          .get(adres, headers: {'User-Agent': _tarayici, 'Accept-Language': 'tr-TR,tr;q=0.9', 'Accept': 'text/html,*/*'})
          .timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw TarifHatasi('Sayfa açılamadı (kod ${r.statusCode}).');
      return utf8.decode(r.bodyBytes, allowMalformed: true);
    } on TarifHatasi {
      rethrow;
    } on SocketException {
      throw const TarifHatasi('İnternet bağlantısı yok gibi görünüyor.');
    } catch (_) {
      throw const TarifHatasi('Sayfa açılamadı. Bağlantıyı kontrol et.');
    } finally {
      c.close();
    }
  }

  /// Bağlantıdan tarifi alır. Instagram gibi giriş isteyen sayfalar okunamaz.
  static Future<TarifSonucu> urlden(String url) async {
    final adres = Uri.tryParse(url.trim());
    if (adres == null || !adres.hasScheme) throw const TarifHatasi('Geçerli bir bağlantı yaz ya da yapıştır.');
    if (instagramMi(url)) {
      throw const TarifHatasi(
          'Instagram sayfaları giriş istediği için okunamıyor. Videonun açıklamasını kopyalayıp "Metinden ekle" ile yapıştır, istersen ekran görüntüsü de ekle.');
    }
    final html = await _getir(adres);
    final recipe = TarifAyristirici.recipeBul(html);
    final cikan = recipe == null ? null : TarifAyristirici.tarifCikar(recipe, kaynakUrl: url.trim());
    if (cikan != null) {
      final kapak = await _resimIndir(cikan.kapakUrl ?? TarifAyristirici.ogResim(html), adres);
      final adimDosyalari = <String?>[];
      var indirilen = 0;
      for (final u in cikan.adimResimUrlleri) {
        if (u != null && indirilen < 10) {
          adimDosyalari.add(await _resimIndir(u, adres));
          indirilen++;
        } else {
          adimDosyalari.add(null);
        }
      }
      return TarifSonucu(cikan.tarif, kapakDosya: kapak, adimDosyalari: adimDosyalari);
    }
    // Düzenli veri yok: yapay zeka sayfa metninden çıkarır.
    final anahtar = AiAyarlar.instance.anahtar;
    if (anahtar == null || anahtar.isEmpty) {
      throw const TarifHatasi('Bu sayfadan tarif otomatik okunamadı. Yapay zeka anahtarı eklersen sayfa metninden de çıkarabilirim.');
    }
    final ham = await _aiyleCoz(anahtar, TarifAyristirici.sadeMetin(html), url.trim());
    final kapak = await _resimIndir(TarifAyristirici.ogResim(html), adres);
    return TarifSonucu(ham, kapakDosya: kapak);
  }

  /// Yapıştırılan açıklamadan (ve isteğe bağlı ekran görüntülerinden) tarif çıkarır. Yapay zeka anahtarı gerekir.
  static Future<TarifSonucu> metinden(String metin, {List<String> resimYollari = const [], String? kaynakUrl}) async {
    final anahtar = AiAyarlar.instance.anahtar;
    if (anahtar == null || anahtar.isEmpty) {
      throw const TarifHatasi('Metinden tarif çıkarmak için Ayarlar\'dan yapay zeka anahtarı eklemelisin.');
    }
    if (metin.trim().isEmpty && resimYollari.isEmpty) throw const TarifHatasi('Önce tarif metnini yapıştır ya da ekran görüntüsü ekle.');
    final b64 = <String>[];
    for (final y in resimYollari.take(4)) {
      final b = await compute(_kucultBase64, y);
      if (b != null) b64.add(b);
    }
    final tarif = await _aiyleCoz(anahtar, metin, kaynakUrl, resimler: b64);
    // Ekran görüntülerinden ilki kapak olur.
    String? kapak;
    if (resimYollari.isNotEmpty) kapak = await _kopyala(resimYollari.first);
    return TarifSonucu(tarif, kapakDosya: kapak);
  }

  static Future<Tarif> _aiyleCoz(String anahtar, String metin, String? kaynakUrl, {List<String> resimler = const []}) async {
    final m = await AiServisi.tarifCoz(apiKey: anahtar, metin: metin, resimlerBase64: resimler);
    final baslik = (m['baslik'] ?? '').toString().trim();
    final malzemeler = [for (final e in (m['malzemeler'] as List? ?? [])) if (e.toString().trim().isNotEmpty) e.toString().trim()];
    final adimlar = [for (final e in (m['adimlar'] as List? ?? [])) if (e.toString().trim().isNotEmpty) TarifAdimi(e.toString().trim())];
    if (baslik.isEmpty || (malzemeler.isEmpty && adimlar.isEmpty)) {
      throw const TarifHatasi('Bu metinden tarif çıkaramadım. Malzemeleri ve yapılışı içeren metni yapıştır.');
    }
    int? dk(dynamic v) => v is int && v > 0 ? v : null;
    final kisi = (m['kisi'] ?? '').toString().trim();
    final aciklama = (m['aciklama'] ?? '').toString().trim();
    final kat = (m['kategori'] ?? '').toString();
    return Tarif(
      baslik: baslik,
      aciklama: aciklama.isEmpty ? null : aciklama,
      kaynakUrl: kaynakUrl,
      hazirlikDk: dk(m['hazirlik_dk']),
      pisirmeDk: dk(m['pisirme_dk']),
      toplamDk: dk(m['toplam_dk']),
      kisi: kisi.isEmpty ? null : kisi,
      kategori: TarifKategorileri.hepsi.contains(kat) ? kat : TarifKategorileri.bul(kat, baslik),
      malzemeler: malzemeler,
      adimlar: adimlar,
    );
  }

  static String? _kucultBase64(String yol) {
    try {
      var r = img.decodeImage(File(yol).readAsBytesSync());
      if (r == null) return null;
      const sinir = 1400;
      if (r.width > sinir || r.height > sinir) {
        r = r.width >= r.height ? img.copyResize(r, width: sinir) : img.copyResize(r, height: sinir);
      }
      return base64Encode(img.encodeJpg(r, quality: 80));
    } catch (_) {
      return null;
    }
  }

  static Future<String> _geciciKlasor() async {
    final d = Directory(p.join(Directory.systemTemp.path, 'aklimda_tarif'));
    await d.create(recursive: true);
    return d.path;
  }

  static Future<String?> _kopyala(String yol) async {
    try {
      final hedef = p.join(await _geciciKlasor(), '${const Uuid().v4()}${p.extension(yol).isEmpty ? '.jpg' : p.extension(yol)}');
      await File(yol).copy(hedef);
      return hedef;
    } catch (_) {
      return null;
    }
  }

  /// Resmi indirip geçici dosyaya yazar; olmazsa null (tarif resimsiz de eklenir).
  static Future<String?> _resimIndir(String? url, Uri sayfa) async {
    if (url == null || url.trim().isEmpty) return null;
    final c = istemciUret();
    try {
      final adres = sayfa.resolve(url.trim());
      final r = await c.get(adres, headers: {'User-Agent': _tarayici}).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200 || r.bodyBytes.isEmpty || r.bodyBytes.length > 6 * 1024 * 1024) return null;
      var uzanti = p.extension(adres.path).toLowerCase();
      if (!['.jpg', '.jpeg', '.png', '.webp'].contains(uzanti)) uzanti = '.jpg';
      final hedef = p.join(await _geciciKlasor(), '${const Uuid().v4()}$uzanti');
      await File(hedef).writeAsBytes(r.bodyBytes);
      return hedef;
    } catch (_) {
      return null;
    } finally {
      c.close();
    }
  }
}
