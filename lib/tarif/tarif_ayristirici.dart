import 'dart:convert';

import 'tarif_modeli.dart';

/// Web sayfasındaki tarifi ayrıştırır: önce sayfanın içindeki düzenli tarif verisi (schema.org Recipe), yoksa null.
class TarifAyristirici {
  /// Sayfadaki "application/ld+json" bloklarından Recipe nesnesini bulur.
  static Map<String, dynamic>? recipeBul(String html) {
    final blok = RegExp(r'<script[^>]*type=["\x27]application/ld\+json["\x27][^>]*>(.*?)</script>', caseSensitive: false, dotAll: true);
    for (final m in blok.allMatches(html)) {
      final ham = m.group(1)?.trim();
      if (ham == null || ham.isEmpty) continue;
      try {
        final r = _tara(jsonDecode(ham));
        if (r != null) return r;
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic>? _tara(dynamic d) {
    if (d is List) {
      for (final e in d) {
        final r = _tara(e);
        if (r != null) return r;
      }
    } else if (d is Map) {
      final tip = d['@type'];
      final recipeMi = tip == 'Recipe' || (tip is List && tip.contains('Recipe'));
      if (recipeMi) return Map<String, dynamic>.from(d);
      final graf = d['@graph'];
      if (graf != null) {
        final r = _tara(graf);
        if (r != null) return r;
      }
    }
    return null;
  }

  /// "PT1H20M" gibi süreyi dakikaya çevirir.
  static int? sureDk(dynamic v) {
    if (v == null) return null;
    final m = RegExp(r'^P(?:(\d+)D)?T?(?:(\d+)H)?(?:(\d+)M)?', caseSensitive: false).firstMatch(v.toString().trim());
    if (m == null) return null;
    final g = int.tryParse(m.group(1) ?? '') ?? 0;
    final s = int.tryParse(m.group(2) ?? '') ?? 0;
    final d = int.tryParse(m.group(3) ?? '') ?? 0;
    final t = g * 1440 + s * 60 + d;
    return t > 0 ? t : null;
  }

  static String temizle(String s) {
    var t = s.replaceAll(RegExp(r'<[^>]*>'), ' ');
    t = t
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    t = t.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)));
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String? _resimUrl(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is List && v.isNotEmpty) return _resimUrl(v.first);
    if (v is Map) return _resimUrl(v['url'] ?? v['contentUrl']);
    return null;
  }

  static List<({String metin, String? resim})> _adimlar(dynamic v) {
    final sonuc = <({String metin, String? resim})>[];
    void ekle(dynamic e) {
      if (e == null) return;
      if (e is String) {
        for (final satir in e.split(RegExp(r'\n+'))) {
          final t = temizle(satir);
          if (t.isNotEmpty) sonuc.add((metin: t, resim: null));
        }
      } else if (e is List) {
        for (final x in e) {
          ekle(x);
        }
      } else if (e is Map) {
        final tip = e['@type'];
        if (tip == 'HowToSection' || e['itemListElement'] != null) {
          ekle(e['itemListElement']);
        } else {
          final t = temizle((e['text'] ?? e['name'] ?? '').toString());
          if (t.isNotEmpty) sonuc.add((metin: t, resim: _resimUrl(e['image'])));
        }
      }
    }

    ekle(v);
    return sonuc;
  }

  /// Recipe nesnesinden tarif ve resim adresleri çıkarır. [kaynakUrl] yazılır.
  static ({Tarif tarif, String? kapakUrl, List<String?> adimResimUrlleri})? tarifCikar(Map<String, dynamic> r, {String? kaynakUrl}) {
    final baslik = temizle((r['name'] ?? '').toString());
    if (baslik.isEmpty) return null;
    final malzemeler = [
      for (final e in (r['recipeIngredient'] ?? r['ingredients'] ?? []) as List)
        if (temizle(e.toString()).isNotEmpty) temizle(e.toString()),
    ];
    final adimlar = _adimlar(r['recipeInstructions']);
    if (malzemeler.isEmpty && adimlar.isEmpty) return null;
    final kisi = r['recipeYield'];
    String? kisiMetni;
    if (kisi is List && kisi.isNotEmpty) {
      kisiMetni = kisi.map((e) => e.toString()).firstWhere((e) => RegExp(r'\d').hasMatch(e), orElse: () => kisi.first.toString());
    } else if (kisi != null) {
      kisiMetni = kisi.toString();
    }
    if (kisiMetni != null && RegExp(r'^\d+$').hasMatch(kisiMetni.trim())) kisiMetni = '${kisiMetni.trim()} kişilik';
    final kat = r['recipeCategory'];
    final katMetni = kat is List ? kat.join(' ') : kat?.toString();
    final tarif = Tarif(
      baslik: baslik,
      aciklama: r['description'] == null ? null : temizle(r['description'].toString()),
      kaynakUrl: kaynakUrl,
      hazirlikDk: sureDk(r['prepTime']),
      pisirmeDk: sureDk(r['cookTime']),
      toplamDk: sureDk(r['totalTime']),
      kisi: kisiMetni,
      kategori: TarifKategorileri.bul(katMetni, baslik),
      malzemeler: malzemeler,
      adimlar: [for (final a in adimlar) TarifAdimi(a.metin)],
    );
    return (tarif: tarif, kapakUrl: _resimUrl(r['image']), adimResimUrlleri: [for (final a in adimlar) a.resim]);
  }

  /// Sayfa başlığındaki og:image adresi.
  static String? ogResim(String html) {
    final m = RegExp(r'<meta[^>]+property=["\x27]og:image["\x27][^>]+content=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(html) ??
        RegExp(r'<meta[^>]+content=["\x27]([^"\x27]+)["\x27][^>]+property=["\x27]og:image["\x27]', caseSensitive: false).firstMatch(html);
    return m?.group(1);
  }

  /// Yapay zekaya vermek için sayfayı sade metne çevirir (script, stil, menü atılır).
  static String sadeMetin(String html, {int sinir = 18000}) {
    var t = html.replaceAll(RegExp(r'<(script|style|nav|footer|header|noscript)[^>]*>.*?</\1>', caseSensitive: false, dotAll: true), ' ');
    t = t.replaceAll(RegExp(r'<(br|/p|/li|/h\d|/div)[^>]*>', caseSensitive: false), '\n');
    t = temizle(t.replaceAll('\n', ' \u0001 ')).replaceAll(' \u0001 ', '\n');
    return t.length > sinir ? t.substring(0, sinir) : t;
  }
}
