import 'package:material_ui/material_ui.dart';

import '../kategori_gorunum.dart';
import '../tarif/tarif_modeli.dart';

/// Not durumları. Kullanıcı isterse elle değiştirir, zorunlu değildir.
class Durum {
  static const yapilacak = 'yapilacak';
  static const yapiliyor = 'yapiliyor';
  static const bekliyor = 'bekliyor';
  static const yapildi = 'yapildi';

  static const hepsi = [yapilacak, yapiliyor, bekliyor, yapildi];

  static String ad(String durum) => switch (durum) {
        yapiliyor => 'Yapılıyor',
        bekliyor => 'Bekliyor',
        yapildi => 'Yapıldı',
        _ => 'Yapılacak',
      };
}

/// Not türü: düz not ya da yapılacaklar listesi (maddeler [Adim] olarak saklanır).
class NotTuru {
  static const not = 'not';
  static const liste = 'liste';
  static const tarif = 'tarif';
}

/// Notun nereden geldiği.
class Kaynak {
  static const yazili = 'yazili';
  static const sesli = 'sesli';
  static const paylasim = 'paylasim';
}

class Kategori {
  final int id;
  String ad;
  final int? ustId;
  final int sira;

  /// Kullanıcının seçtiği renk (ARGB) ve ikon anahtarı. Boşsa varsayılan kullanılır.
  int? renkDegeri;
  String? ikonAnahtari;

  /// Kitabın kapağına konan kullanıcı resmi (dosya yolu). Varsa ikon ve emojiden önce gelir.
  String? kapakResmi;

  Kategori({required this.id, required this.ad, this.ustId, this.sira = 0, this.renkDegeri, this.ikonAnahtari, this.kapakResmi});

  factory Kategori.fromMap(Map<String, Object?> m) => Kategori(
        id: m['id'] as int,
        ad: m['ad'] as String,
        ustId: m['ust_id'] as int?,
        sira: (m['sira'] as int?) ?? 0,
        renkDegeri: m['renk'] as int?,
        ikonAnahtari: m['ikon'] as String?,
        kapakResmi: m['kapak_resim'] as String?,
      );
}

/// Bir notun adımı. Adımlar sıralıdır.
class Adim {
  int? id;
  final String notId;
  int sira;
  String metin;
  int? sureDk;
  String durum; // yapilacak | yapildi
  bool bekleme;

  Adim({
    this.id,
    required this.notId,
    required this.sira,
    required this.metin,
    this.sureDk,
    this.durum = Durum.yapilacak,
    this.bekleme = false,
  });

  bool get yapildi => durum == Durum.yapildi;

  factory Adim.fromMap(Map<String, Object?> m) => Adim(
        id: m['id'] as int,
        notId: m['not_id'] as String,
        sira: m['sira'] as int,
        metin: m['metin'] as String,
        sureDk: m['sure_dk'] as int?,
        durum: (m['durum'] as String?) ?? Durum.yapilacak,
        bekleme: m['bekleme'] == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'not_id': notId,
        'sira': sira,
        'metin': metin,
        'sure_dk': sureDk,
        'durum': durum,
        'bekleme': bekleme ? 1 : 0,
      };
}

class Not {
  final String id;
  String metin;
  String? baslik;
  final String kaynak;
  int olusturma;
  int guncelleme;
  String durum;
  bool arsiv;
  bool onayli;
  bool islendi;
  int? sureDk;
  int? tarih;
  bool tarihSaatli;
  int? hatirlatma;
  String? link;
  String? yorum;
  int sonDokunma;
  int ertelemeSayisi;
  int gormezdenSayisi;
  String? takvimEtkinlikId;
  int? takvimBaslangic;
  int? takvimBitis;
  bool yaptinCevap;
  String? aiJson;
  /// true ise yapay zeka bu notu kendiliğinden işlemez (kullanıcı "yapay zekaya gönder" derse işlenir).
  bool aiDisi;

  /// true ise not öneri ve hatırlatmalarda kullanılır (kullanıcı kendi seçer, varsayılan kapalı).
  bool oneriDahil;
  String tur;

  /// Yemek kitabındaki tarif verisi (JSON). Yalnızca `tur == tarif` notlarda dolu.
  String? tarifJson;
  List<String> fotograflar;
  List<int> kategoriIdler;
  List<Adim> adimlar;

  Not({
    required this.id,
    required this.metin,
    this.baslik,
    required this.kaynak,
    required this.olusturma,
    required this.guncelleme,
    this.durum = Durum.yapilacak,
    this.arsiv = false,
    this.onayli = false,
    this.islendi = false,
    this.sureDk,
    this.tarih,
    this.tarihSaatli = false,
    this.hatirlatma,
    this.link,
    this.yorum,
    required this.sonDokunma,
    this.ertelemeSayisi = 0,
    this.gormezdenSayisi = 0,
    this.takvimEtkinlikId,
    this.takvimBaslangic,
    this.takvimBitis,
    this.yaptinCevap = false,
    this.aiJson,
    this.aiDisi = false,
    this.oneriDahil = false,
    this.tur = NotTuru.not,
    this.tarifJson,
    List<String>? fotograflar,
    List<int>? kategoriIdler,
    List<Adim>? adimlar,
  })  : fotograflar = fotograflar ?? [],
        kategoriIdler = kategoriIdler ?? [],
        adimlar = adimlar ?? [];

  /// Yapay zeka işledi ama kullanıcı henüz onaylamadı.
  bool get onayBekliyor => islendi && !onayli;

  bool get liste => tur == NotTuru.liste;

  bool get tarifMi => tur == NotTuru.tarif;

  Tarif? get tarif => tarifMi ? Tarif.coz(tarifJson) : null;

  /// Listede görünen başlık: yapay zeka başlığı yoksa metnin ilk satırı.
  String get gorunenBaslik {
    if (baslik != null && baslik!.trim().isNotEmpty) return baslik!.trim();
    final ilk = metin.trim().split('\n').first.trim();
    if (ilk.isNotEmpty) return ilk.length > 60 ? '${ilk.substring(0, 60)}…' : ilk;
    if (link != null) return link!;
    if (fotograflar.isNotEmpty) return 'Fotoğraf';
    return 'Boş not';
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'metin': metin,
        'baslik': baslik,
        'kaynak': kaynak,
        'olusturma': olusturma,
        'guncelleme': guncelleme,
        'durum': durum,
        'arsiv': arsiv ? 1 : 0,
        'onayli': onayli ? 1 : 0,
        'islendi': islendi ? 1 : 0,
        'sure_dk': sureDk,
        'tarih': tarih,
        'tarih_saatli': tarihSaatli ? 1 : 0,
        'hatirlatma': hatirlatma,
        'link': link,
        'yorum': yorum,
        'son_dokunma': sonDokunma,
        'erteleme_sayisi': ertelemeSayisi,
        'gormezden_sayisi': gormezdenSayisi,
        'takvim_etkinlik_id': takvimEtkinlikId,
        'takvim_baslangic': takvimBaslangic,
        'takvim_bitis': takvimBitis,
        'yaptin_cevap': yaptinCevap ? 1 : 0,
        'ai_json': aiJson,
        'ai_disi': aiDisi ? 1 : 0,
        'oneri': oneriDahil ? 1 : 0,
        'tur': tur,
        'tarif_json': tarifJson,
      };

  factory Not.fromMap(Map<String, Object?> m) => Not(
        id: m['id'] as String,
        metin: (m['metin'] as String?) ?? '',
        baslik: m['baslik'] as String?,
        kaynak: m['kaynak'] as String,
        olusturma: m['olusturma'] as int,
        guncelleme: m['guncelleme'] as int,
        durum: (m['durum'] as String?) ?? Durum.yapilacak,
        arsiv: m['arsiv'] == 1,
        onayli: m['onayli'] == 1,
        islendi: m['islendi'] == 1,
        sureDk: m['sure_dk'] as int?,
        tarih: m['tarih'] as int?,
        tarihSaatli: m['tarih_saatli'] == 1,
        hatirlatma: m['hatirlatma'] as int?,
        link: m['link'] as String?,
        yorum: m['yorum'] as String?,
        sonDokunma: m['son_dokunma'] as int,
        ertelemeSayisi: (m['erteleme_sayisi'] as int?) ?? 0,
        gormezdenSayisi: (m['gormezden_sayisi'] as int?) ?? 0,
        takvimEtkinlikId: m['takvim_etkinlik_id'] as String?,
        takvimBaslangic: m['takvim_baslangic'] as int?,
        takvimBitis: m['takvim_bitis'] as int?,
        yaptinCevap: m['yaptin_cevap'] == 1,
        aiJson: m['ai_json'] as String?,
        aiDisi: m['ai_disi'] == 1,
        oneriDahil: m['oneri'] == 1,
        tur: (m['tur'] as String?) ?? NotTuru.not,
        tarifJson: m['tarif_json'] as String?,
      );
}

/// Kategori ağacı yardımcıları (test edilebilir, veritabanından bağımsız).
class KategoriAgaci {
  final List<Kategori> tum;
  KategoriAgaci(this.tum);

  List<Kategori> get anaKategoriler =>
      tum.where((k) => k.ustId == null).toList()..sort((a, b) => a.sira.compareTo(b.sira));

  List<Kategori> altlari(int id) =>
      tum.where((k) => k.ustId == id).toList()..sort((a, b) => a.sira.compareTo(b.sira));

  Kategori? bul(int id) {
    for (final k in tum) {
      if (k.id == id) return k;
    }
    return null;
  }

  /// "Hobi › Dizi" gibi tam ad.
  String tamAd(int id) {
    final k = bul(id);
    if (k == null) return '';
    if (k.ustId == null) return k.ad;
    final ust = bul(k.ustId!);
    return ust == null ? k.ad : '${ust.ad} › ${k.ad}';
  }

  /// Kategorinin rengi: kendi seçimi, yoksa üst kategorisinin, yoksa sıradaki varsayılan.
  Color renkOf(int id) {
    final k = bul(id);
    if (k == null) return KategoriGorunum.varsayilanRenk(0);
    if (k.renkDegeri != null) return Color(k.renkDegeri!);
    final ust = k.ustId == null ? null : bul(k.ustId!);
    if (ust != null) return renkOf(ust.id);
    return KategoriGorunum.varsayilanRenk(k.id);
  }

  /// Kategori için emoji seçilmişse (kendisinin ya da üst kategorisinin) o emoji.
  String? emojiOf(int id) {
    final k = bul(id);
    if (k == null) return null;
    final a = k.ikonAnahtari ?? (k.ustId == null ? null : bul(k.ustId!)?.ikonAnahtari);
    return KategoriGorunum.emojiMi(a) ? a : null;
  }

  IconData ikonOf(int id) {
    final k = bul(id);
    if (k == null) return Icons.folder_outlined;
    final own = KategoriGorunum.emojiMi(k.ikonAnahtari) ? null : k.ikonAnahtari;
    final a = own ??
        KategoriGorunum.varsayilanIkon(k.ad) ??
        (k.ustId == null ? null : (bul(k.ustId!)?.ikonAnahtari ?? KategoriGorunum.varsayilanIkon(bul(k.ustId!)!.ad)));
    return KategoriGorunum.ikon(a);
  }

  /// Bir kategori ve (ana kategoriyse) alt kategorilerinin id'leri.
  Set<int> kendisiVeAltlari(int id) => {id, ...altlari(id).map((k) => k.id)};
}
