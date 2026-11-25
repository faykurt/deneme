import 'package:material_ui/material_ui.dart';

/// Kategorilerin varsayılan renkleri ve seçilebilir ikonları.
class KategoriGorunum {
  static const renkler = <Color>[
    Color(0xFF5B8DB8), // mavi
    Color(0xFFC0714F), // kiremit
    Color(0xFF7A9E5C), // yeşil
    Color(0xFF9B6FB5), // mor
    Color(0xFFC9A23E), // hardal
    Color(0xFF4FA3A0), // turkuaz
    Color(0xFFC25E7C), // gül
    Color(0xFF8A7F72), // taş
    Color(0xFF6E86C8), // çivit
    Color(0xFFB5683A), // kahve
  ];

  static Color varsayilanRenk(int id) => renkler[id.abs() % renkler.length];

  static const ikonlar = <String, IconData>{
    'is': Icons.work_outline,
    'okul': Icons.school_outlined,
    'ev': Icons.home_outlined,
    'hobi': Icons.palette_outlined,
    'yemek': Icons.restaurant_outlined,
    'proje': Icons.lightbulb_outline,
    'gunluk': Icons.checklist,
    'film': Icons.movie_outlined,
    'kitap': Icons.menu_book_outlined,
    'oyun': Icons.sports_esports_outlined,
    'alisveris': Icons.shopping_cart_outlined,
    'saglik': Icons.favorite_outline,
    'spor': Icons.fitness_center,
    'seyahat': Icons.flight_outlined,
    'para': Icons.account_balance_wallet_outlined,
    'aile': Icons.people_outline,
    'klasor': Icons.folder_outlined,
  };

  /// Adına bakarak uygun varsayılan ikon anahtarı; bulunamazsa null.
  static String? varsayilanIkon(String ad) {
    final a = ad.toLowerCase().replaceAll('İ', 'i');
    const eslesme = <String, List<String>>{
      'is': ['iş', 'is ', 'çalış', 'toplantı'],
      'okul': ['tez', 'okul', 'ders', 'sınav', 'eğitim'],
      'ev': ['ev', 'dekor', 'ev işi'],
      'hobi': ['hobi', 'sanat', 'müzik'],
      'yemek': ['yemek', 'tarif', 'mutfak'],
      'proje': ['proje', 'fikir'],
      'gunluk': ['günlük', 'yapılacak', 'liste'],
      'film': ['film', 'dizi', 'sinema'],
      'kitap': ['kitap', 'okuma'],
      'oyun': ['oyun'],
      'alisveris': ['alışveriş', 'market', 'satın'],
      'saglik': ['sağlık', 'doktor', 'ilaç'],
      'spor': ['spor', 'egzersiz', 'koşu'],
      'seyahat': ['seyahat', 'gezi', 'tatil'],
      'para': ['para', 'finans', 'fatura', 'bütçe'],
      'aile': ['aile', 'arkadaş', 'dost'],
    };
    for (final e in eslesme.entries) {
      for (final k in e.value) {
        if (a == k.trim() || (k.length > 3 && a.contains(k))) return e.key;
      }
    }
    return null;
  }

  static IconData ikon(String? anahtar) => ikonlar[anahtar] ?? Icons.folder_outlined;
}
