import 'dart:convert';

/// Tarifin adımı: metin ve (varsa) yerel resim dosyası.
class TarifAdimi {
  final String metin;
  final String? resim;
  const TarifAdimi(this.metin, {this.resim});

  Map<String, Object?> toJson() => {'metin': metin, if (resim != null) 'resim': resim};
  factory TarifAdimi.fromJson(Map<String, dynamic> m) => TarifAdimi((m['metin'] ?? '').toString(), resim: m['resim'] as String?);
}

/// Yemek kitabındaki bir tarif. Notun `tarif_json` alanında saklanır.
class Tarif {
  final String baslik;
  final String? aciklama;
  final String? kaynakUrl;
  final int? hazirlikDk;
  final int? pisirmeDk;
  final int? toplamDk;
  final String? kisi; // "4 kişilik" gibi
  final String kategori; // Tatlılar, Ana yemekler...
  final List<String> malzemeler;
  final List<TarifAdimi> adimlar;
  final List<int> isaretli; // işaretlenmiş malzeme sıraları

  const Tarif({
    required this.baslik,
    this.aciklama,
    this.kaynakUrl,
    this.hazirlikDk,
    this.pisirmeDk,
    this.toplamDk,
    this.kisi,
    this.kategori = 'Diğer tarifler',
    this.malzemeler = const [],
    this.adimlar = const [],
    this.isaretli = const [],
  });

  /// Listede gösterilen süre: toplam, yoksa hazırlık + pişirme.
  int? get sure {
    if (toplamDk != null && toplamDk! > 0) return toplamDk;
    final t = (hazirlikDk ?? 0) + (pisirmeDk ?? 0);
    return t > 0 ? t : null;
  }

  Tarif kopya({List<int>? isaretli, List<TarifAdimi>? adimlar, String? kategori}) => Tarif(
        baslik: baslik,
        aciklama: aciklama,
        kaynakUrl: kaynakUrl,
        hazirlikDk: hazirlikDk,
        pisirmeDk: pisirmeDk,
        toplamDk: toplamDk,
        kisi: kisi,
        kategori: kategori ?? this.kategori,
        malzemeler: malzemeler,
        adimlar: adimlar ?? this.adimlar,
        isaretli: isaretli ?? this.isaretli,
      );

  String toJsonMetni() => jsonEncode({
        'baslik': baslik,
        'aciklama': aciklama,
        'kaynak': kaynakUrl,
        'hazirlik': hazirlikDk,
        'pisirme': pisirmeDk,
        'toplam': toplamDk,
        'kisi': kisi,
        'kategori': kategori,
        'malzemeler': malzemeler,
        'adimlar': adimlar.map((a) => a.toJson()).toList(),
        'isaretli': isaretli,
      });

  static Tarif? coz(String? metin) {
    if (metin == null || metin.isEmpty) return null;
    try {
      final m = jsonDecode(metin) as Map<String, dynamic>;
      return Tarif(
        baslik: (m['baslik'] ?? '').toString(),
        aciklama: m['aciklama'] as String?,
        kaynakUrl: m['kaynak'] as String?,
        hazirlikDk: m['hazirlik'] as int?,
        pisirmeDk: m['pisirme'] as int?,
        toplamDk: m['toplam'] as int?,
        kisi: m['kisi'] as String?,
        kategori: (m['kategori'] ?? 'Diğer tarifler').toString(),
        malzemeler: [for (final e in (m['malzemeler'] as List? ?? [])) e.toString()],
        adimlar: [for (final e in (m['adimlar'] as List? ?? [])) TarifAdimi.fromJson(e as Map<String, dynamic>)],
        isaretli: [for (final e in (m['isaretli'] as List? ?? [])) e as int],
      );
    } catch (_) {
      return null;
    }
  }

  /// Süreyi "45 dk" ya da "1 sa 20 dk" biçiminde yazar.
  static String sureMetni(int dk) {
    if (dk < 60) return '$dk dk';
    final s = dk ~/ 60, d = dk % 60;
    return d == 0 ? '$s sa' : '$s sa $d dk';
  }
}

/// Tarifin kitapta hangi bölüme gireceğini söyleyen kategori adları.
class TarifKategorileri {
  static const hepsi = ['Ana yemekler', 'Çorbalar', 'Tatlılar', 'Salatalar', 'Hamur işleri', 'Kahvaltılıklar', 'İçecekler', 'Diğer tarifler'];

  /// Sitenin verdiği kategoriden ya da başlıktan uygun bölümü bulur.
  static String bul(String? siteKategorisi, String baslik) {
    final t = '${siteKategorisi ?? ''} $baslik'.toLowerCase().replaceAll('İ', 'i');
    bool var_(List<String> k) => k.any(t.contains);
    if (var_(['çorba', 'corba'])) return 'Çorbalar';
    if (var_(['tatlı', 'tatli', 'pasta', 'kek', 'kurabiye', 'puding', 'sütlaç', 'baklava', 'cheesecake', 'dondurma', 'kadayıf'])) return 'Tatlılar';
    if (var_(['salata'])) return 'Salatalar';
    if (var_(['börek', 'poğaça', 'hamur', 'pide', 'lahmacun', 'mantı', 'ekmek', 'pizza', 'simit', 'açma'])) return 'Hamur işleri';
    if (var_(['kahvaltı', 'omlet', 'menemen', 'gözleme'])) return 'Kahvaltılıklar';
    if (var_(['içecek', 'smoothie', 'limonata', 'kokteyl', 'çay', 'kahve', 'şerbet'])) return 'İçecekler';
    if (var_(['ana yemek', 'et ', 'tavuk', 'köfte', 'kebap', 'balık', 'pilav', 'makarna', 'sebze', 'dolma', 'yemek'])) return 'Ana yemekler';
    return 'Diğer tarifler';
  }
}
