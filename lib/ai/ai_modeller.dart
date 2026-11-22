import 'dart:convert';

/// Yapay zekanın önerdiği tek bir adım.
class AiAdim {
  String metin;
  int sureDk;
  bool bekleme;

  AiAdim({required this.metin, this.sureDk = 0, this.bekleme = false});

  factory AiAdim.fromJson(Map<String, dynamic> j) => AiAdim(
        metin: (j['metin'] as String?)?.trim() ?? '',
        sureDk: (j['sure_dk'] as num?)?.toInt() ?? 0,
        bekleme: j['bekleme'] == true,
      );

  Map<String, dynamic> toJson() => {'metin': metin, 'sure_dk': sureDk, 'bekleme': bekleme};
}

/// Bir kayıttan çıkan tek bir fikir/iş.
class AiFikir {
  String metin;
  String baslik;
  List<int> kategoriIdler;
  String yeniKategoriAd;
  int yeniKategoriUstId;
  int sureDk;
  String tarih;
  bool tarihSaatli;
  bool yapilabilirIs;
  List<AiAdim> adimlar;

  AiFikir({
    this.metin = '',
    this.baslik = '',
    List<int>? kategoriIdler,
    this.yeniKategoriAd = '',
    this.yeniKategoriUstId = 0,
    this.sureDk = 0,
    this.tarih = '',
    this.tarihSaatli = false,
    this.yapilabilirIs = false,
    List<AiAdim>? adimlar,
  })  : kategoriIdler = kategoriIdler ?? [],
        adimlar = adimlar ?? [];

  factory AiFikir.fromJson(Map<String, dynamic> j) => AiFikir(
        metin: (j['metin'] as String?)?.trim() ?? '',
        baslik: (j['baslik'] as String?)?.trim() ?? '',
        kategoriIdler: ((j['kategori_idler'] as List?) ?? []).whereType<num>().map((e) => e.toInt()).toList(),
        yeniKategoriAd: (j['yeni_kategori_ad'] as String?)?.trim() ?? '',
        yeniKategoriUstId: (j['yeni_kategori_ust_id'] as num?)?.toInt() ?? 0,
        sureDk: (j['sure_dk'] as num?)?.toInt() ?? 0,
        tarih: (j['tarih'] as String?)?.trim() ?? '',
        tarihSaatli: j['tarih_saatli'] == true,
        yapilabilirIs: j['yapilabilir_is'] == true,
        adimlar: ((j['adimlar'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => AiAdim.fromJson(Map<String, dynamic>.from(e)))
            .where((a) => a.metin.isNotEmpty)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'metin': metin,
        'baslik': baslik,
        'kategori_idler': kategoriIdler,
        'yeni_kategori_ad': yeniKategoriAd,
        'yeni_kategori_ust_id': yeniKategoriUstId,
        'sure_dk': sureDk,
        'tarih': tarih,
        'tarih_saatli': tarihSaatli,
        'yapilabilir_is': yapilabilirIs,
        'adimlar': adimlar.map((a) => a.toJson()).toList(),
      };

  /// "2026-12-15" ya da "2026-12-15T14:30" biçimindeki tarihi çözer. Çözemezse null.
  DateTime? get tarihDt {
    if (tarih.isEmpty) return null;
    try {
      return DateTime.parse(tarih.length == 10 ? '${tarih}T00:00:00' : tarih);
    } catch (_) {
      return null;
    }
  }

  /// Saat bilgisi gerçekten verilmiş mi?
  bool get saatVar => tarihSaatli && tarih.length > 10;
}

class AiSonuc {
  final List<AiFikir> fikirler;
  const AiSonuc(this.fikirler);

  Map<String, dynamic> toJson() => {'fikirler': fikirler.map((f) => f.toJson()).toList()};

  static AiSonuc? coz(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final m = jsonDecode(json) as Map<String, dynamic>;
      return AiSonuc(((m['fikirler'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => AiFikir.fromJson(Map<String, dynamic>.from(e)))
          .toList());
    } catch (_) {
      return null;
    }
  }
}

enum AiHataTuru { anahtarYok, anahtarGecersiz, kredi, cevrimdisi, gecici, diger }

class AiHata implements Exception {
  final String mesaj;
  final AiHataTuru tur;
  const AiHata(this.mesaj, this.tur);

  /// Kullanıcı bir şey yapmadan, sonra kendiliğinden yeniden denenebilir mi?
  bool get otomatikDeneme =>
      tur == AiHataTuru.cevrimdisi || tur == AiHataTuru.gecici || tur == AiHataTuru.kredi;

  @override
  String toString() => mesaj;
}
