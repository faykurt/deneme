import 'dart:convert';

/// Yapay zekanın seçtiği tek bir öneri.
class Oneri {
  final String notId;
  final String neden;

  /// "HH:mm" (bugün) ya da boş: bildirim zamanı.
  final String bildirimSaati;
  const Oneri({required this.notId, required this.neden, this.bildirimSaati = ''});

  Map<String, Object?> toJson() => {'not_id': notId, 'neden': neden, 'bildirim_saati': bildirimSaati};
  factory Oneri.fromJson(Map<String, dynamic> m) => Oneri(
        notId: (m['not_id'] ?? '').toString(),
        neden: (m['neden'] ?? '').toString().trim(),
        bildirimSaati: (m['bildirim_saati'] ?? '').toString().trim(),
      );
}

/// Hafta sonu planı: öğle (12-18) ve akşam (18-24) bölümleri. [gun]: genel | cumartesi | pazar.
class HaftaSonuPlani {
  final String gun;
  final List<String> ogle;
  final List<String> aksam;
  const HaftaSonuPlani({required this.gun, this.ogle = const [], this.aksam = const []});

  bool get bos => ogle.isEmpty && aksam.isEmpty;

  Map<String, Object?> toJson() => {'gun': gun, 'ogle': ogle, 'aksam': aksam};
  factory HaftaSonuPlani.fromJson(Map<String, dynamic> m) => HaftaSonuPlani(
        gun: (m['gun'] ?? 'genel').toString(),
        ogle: [for (final e in (m['ogle'] as List? ?? [])) e.toString()],
        aksam: [for (final e in (m['aksam'] as List? ?? [])) e.toString()],
      );
}

/// Bir gün bölümü için hazırlanmış öneri paketi (telefonda saklanır, internet yoksa son paket kullanılır).
class OneriPaketi {
  final int olusturma;
  final String bolum; // sabah | ogle | aksam
  final String gun; // yyyy-MM-dd
  final List<Oneri> oneriler;
  final HaftaSonuPlani? plan;
  const OneriPaketi({
    required this.olusturma,
    required this.bolum,
    required this.gun,
    required this.oneriler,
    this.plan,
  });

  String toJsonMetni() => jsonEncode({
        'olusturma': olusturma,
        'bolum': bolum,
        'gun': gun,
        'oneriler': oneriler.map((o) => o.toJson()).toList(),
        'plan': plan?.toJson(),
      });

  static OneriPaketi? coz(String? metin) {
    if (metin == null || metin.isEmpty) return null;
    try {
      final m = jsonDecode(metin) as Map<String, dynamic>;
      return OneriPaketi(
        olusturma: m['olusturma'] as int,
        bolum: m['bolum'] as String,
        gun: m['gun'] as String,
        oneriler: [for (final e in (m['oneriler'] as List)) Oneri.fromJson(e as Map<String, dynamic>)],
        plan: m['plan'] == null ? null : HaftaSonuPlani.fromJson(m['plan'] as Map<String, dynamic>),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Zamanlanmış bildirim kaydı (günlük sınırı saymak için).
class PlanliBildirim {
  final int id;
  final int zamanMs;
  final String notId;
  const PlanliBildirim({required this.id, required this.zamanMs, required this.notId});

  Map<String, Object?> toJson() => {'id': id, 'zaman': zamanMs, 'not_id': notId};
  factory PlanliBildirim.fromJson(Map<String, dynamic> m) =>
      PlanliBildirim(id: m['id'] as int, zamanMs: m['zaman'] as int, notId: m['not_id'] as String);
}
