import 'package:material_ui/material_ui.dart';

import 'takvim_modeller.dart';

/// Başlıktaki kelimeye göre bulunan etkinlik türü: ikon ve renk.
class EtkinlikTuru {
  final IconData ikon;
  final Color renk;
  const EtkinlikTuru(this.ikon, this.renk);
}

/// Etkinlik başlığından ikon, renk ve emoji çıkarır (kategorisi olmayan etkinlikler için).
class EtkinlikSimgesi {
  static const _turler = <(List<String>, EtkinlikTuru)>[
    (['yemek', 'tarif', 'kahvaltı', 'akşam yemeği', 'öğle yemeği', 'kahve', 'çay', 'brunch', 'restoran'],
        EtkinlikTuru(Icons.restaurant, Color(0xFFD9835F))),
    (['market', 'alışveriş', 'sipariş', 'pazar'], EtkinlikTuru(Icons.shopping_basket, Color(0xFFC9A23E))),
    (['toplantı', 'görüşme', 'meeting', 'sunum', 'randevu'], EtkinlikTuru(Icons.groups, Color(0xFF5B8DB8))),
    (['doktor', 'hastane', 'ilaç', 'diş', 'sağlık', 'muayene'], EtkinlikTuru(Icons.medical_services, Color(0xFFC25E7C))),
    (['spor', 'koşu', 'yürüyüş', 'egzersiz', 'yoga', 'pilates', 'antrenman', 'salon', 'yüzme'],
        EtkinlikTuru(Icons.directions_run, Color(0xFF7A9E5C))),
    (['tez', 'ders', 'sınav', 'okul', 'ödev', 'çalışma', 'makale', 'proje'], EtkinlikTuru(Icons.school, Color(0xFF6E86C8))),
    (['kitap', 'okuma', 'oku'], EtkinlikTuru(Icons.menu_book, Color(0xFF9B6FB5))),
    (['film', 'dizi', 'sinema', 'netflix'], EtkinlikTuru(Icons.movie, Color(0xFFB5683A))),
    (['müzik', 'konser', 'şarkı'], EtkinlikTuru(Icons.music_note, Color(0xFF4FA3A0))),
    (['temizlik', 'düzenle', 'dolap', 'ütü', 'çamaşır', 'bulaşık', 'ev işi'], EtkinlikTuru(Icons.cleaning_services, Color(0xFF8A7F72))),
    (['telefon', 'ara ', 'arama', 'görüntülü'], EtkinlikTuru(Icons.call, Color(0xFF4FA3A0))),
    (['uçak', 'otobüs', 'yolculuk', 'seyahat', 'tatil', 'bilet', 'otel'], EtkinlikTuru(Icons.flight, Color(0xFF5B8DB8))),
    (['doğum günü', 'parti', 'kutlama', 'düğün', 'nişan'], EtkinlikTuru(Icons.cake, Color(0xFFC25E7C))),
    (['kuaför', 'berber', 'manikür', 'bakım'], EtkinlikTuru(Icons.content_cut, Color(0xFF9B6FB5))),
    (['araba', 'servis', 'benzin', 'muayene aracı'], EtkinlikTuru(Icons.directions_car, Color(0xFF8A7F72))),
    (['fatura', 'ödeme', 'banka', 'vergi', 'kira'], EtkinlikTuru(Icons.account_balance_wallet, Color(0xFFC9A23E))),
    (['uyku', 'dinlen', 'şekerleme'], EtkinlikTuru(Icons.bedtime, Color(0xFF6E86C8))),
    (['arkadaş', 'aile', 'ziyaret', 'buluşma'], EtkinlikTuru(Icons.people, Color(0xFFD9835F))),
  ];

  /// Başlıktan uygulama işareti (💭) ve baştaki emoji çıkarılmış hâli.
  static String _isaretsiz(String baslik) {
    var t = baslik.trimLeft();
    if (t.startsWith(uygulamaIsareti)) t = t.substring(uygulamaIsareti.length).trimLeft();
    return t;
  }

  static bool _emojiMi(String grafem) => grafem.isNotEmpty && grafem.runes.first >= 0x2190;

  /// Başlığın başındaki emoji (varsa).
  static String? bastakiEmoji(String baslik) {
    final g = _isaretsiz(baslik).characters;
    return g.isNotEmpty && _emojiMi(g.first) ? g.first : null;
  }

  /// Gösterilecek başlık: işaret ve baştaki emoji olmadan.
  static String temizBaslik(String baslik) {
    final t = _isaretsiz(baslik);
    final g = t.characters;
    if (g.isNotEmpty && _emojiMi(g.first)) return g.skip(1).toString().trimLeft();
    return t;
  }

  /// Başlıkta geçen kelimeye göre tür; bulunamazsa null.
  static EtkinlikTuru? turBul(String baslik) {
    final t = ' ${temizBaslik(baslik).toLowerCase().replaceAll('İ', 'i')} ';
    for (final (kelimeler, tur) in _turler) {
      for (final k in kelimeler) {
        if (t.contains(k.length <= 3 ? ' $k' : k)) return tur;
      }
    }
    return null;
  }
}
