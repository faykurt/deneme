import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Günün hangi bölümünde olduğumuz: sabah 06-11, öğle 11-17, akşam 17-06.
enum SahneBolumu {
  sabah,
  ogle,
  aksam;

  static SahneBolumu simdi([DateTime? an]) {
    final s = (an ?? DateTime.now()).hour;
    if (s >= 6 && s < 11) return sabah;
    if (s >= 11 && s < 17) return ogle;
    return aksam;
  }
}

/// Ana sayfanın piksel art doğa sahnesi. Kodla çizilir, hazır görselle değiştirilebilir.
class PikselSahne extends StatelessWidget {
  final SahneBolumu bolum;
  const PikselSahne({super.key, required this.bolum});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: SahneCizici(bolum), size: Size.infinite),
    );
  }
}

class _Palet {
  final Color ustGok, altGok, gunes, uzak, orta, yakin, agac;
  const _Palet(this.ustGok, this.altGok, this.gunes, this.uzak, this.orta, this.yakin, this.agac);
}

const _paletler = {
  SahneBolumu.sabah: _Palet(Color(0xFF9DB0B8), Color(0xFFEBD3BC), Color(0xFFF7E2A6), Color(0xFFA7B8AE),
      Color(0xFF7F9886), Color(0xFF5B7765), Color(0xFF34503F)),
  SahneBolumu.ogle: _Palet(Color(0xFF86AEBE), Color(0xFFCFE1E4), Color(0xFFFFF4C9), Color(0xFF9DB8A6),
      Color(0xFF72957E), Color(0xFF527A62), Color(0xFF2F5240)),
  SahneBolumu.aksam: _Palet(Color(0xFF0E131B), Color(0xFF263341), Color(0xFFE4E9EC), Color(0xFF22302F),
      Color(0xFF19251F), Color(0xFF121C17), Color(0xFF0B1410)),
};

class SahneCizici extends CustomPainter {
  final SahneBolumu bolum;
  SahneCizici(this.bolum);

  static const _sutun = 36;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final p = _paletler[bolum]!;
    final hucre = size.width / _sutun;
    final satir = (size.height / hucre).ceil() + 1;
    final ufuk = (satir * 0.6).round();
    final boya = Paint()..isAntiAlias = false;

    void kare(int x, int y, Color c) {
      if (x < 0 || y < 0 || x >= _sutun || y >= satir) return;
      boya.color = c;
      canvas.drawRect(Rect.fromLTWH(x * hucre, y * hucre, hucre + 0.6, hucre + 0.6), boya);
    }

    // Gökyüzü: 9 basamaklı bantlar.
    const bant = 9;
    for (var y = 0; y < ufuk + 12; y++) {
      final t = (math.min(y, ufuk) / ufuk * bant).floor() / (bant - 1);
      final c = Color.lerp(p.ustGok, p.altGok, t.clamp(0.0, 1.0))!;
      for (var x = 0; x < _sutun; x++) {
        kare(x, y, c);
      }
    }

    // Yıldızlar (akşam).
    if (bolum == SahneBolumu.aksam) {
      final r = math.Random(11);
      for (var i = 0; i < 34; i++) {
        final x = r.nextInt(_sutun);
        final y = r.nextInt(math.max(1, (ufuk * 0.8).round()));
        kare(x, y, Colors.white.withValues(alpha: 0.35 + r.nextDouble() * 0.5));
      }
    }

    // Güneş ya da ay.
    void daire(int cx, int cy, double yaricap, Color c) {
      for (var y = cy - yaricap.ceil(); y <= cy + yaricap.ceil(); y++) {
        for (var x = cx - yaricap.ceil(); x <= cx + yaricap.ceil(); x++) {
          final dx = x - cx, dy = y - cy;
          if (dx * dx + dy * dy <= yaricap * yaricap) kare(x, y, c);
        }
      }
    }

    switch (bolum) {
      case SahneBolumu.sabah:
        daire(25, ufuk - 3, 3.2, p.gunes.withValues(alpha: 0.35));
        daire(25, ufuk - 3, 2.2, p.gunes);
      case SahneBolumu.ogle:
        daire(26, (ufuk * 0.28).round(), 3.2, p.gunes.withValues(alpha: 0.3));
        daire(26, (ufuk * 0.28).round(), 2.2, p.gunes);
      case SahneBolumu.aksam:
        final ay = (ufuk * 0.22).round();
        daire(9, ay, 2.4, p.gunes);
        daire(10, ay - 1, 2.0, Color.lerp(p.ustGok, p.altGok, 0.15)!); // hilal
    }

    // Bulutlar.
    if (bolum != SahneBolumu.aksam) {
      final bulut = (bolum == SahneBolumu.sabah ? const Color(0xFFF6EBE0) : const Color(0xFFF2F6F6))
          .withValues(alpha: 0.9);
      void bulutCiz(int x, int y, int w) {
        for (var i = 0; i < w; i++) {
          kare(x + i, y + 1, bulut);
          if (i > 0 && i < w - 1) kare(x + i, y, bulut);
        }
        kare(x + 1, y - 1, bulut);
      }

      bulutCiz(3, (ufuk * 0.2).round(), 7);
      bulutCiz(15, (ufuk * 0.42).round(), 5);
      bulutCiz(27, (ufuk * 0.55).round(), 6);
    }

    // Tepeler.
    int tepe(int x, int taban, double genlik, double sikLik, double faz) =>
        taban - (genlik * math.sin(x * sikLik + faz)).round();

    void tepeCiz(int taban, double genlik, double sik, double faz, Color c) {
      for (var x = 0; x < _sutun; x++) {
        for (var y = tepe(x, taban, genlik, sik, faz); y < satir; y++) {
          kare(x, y, c);
        }
      }
    }

    tepeCiz(ufuk, 2.4, 0.33, 0.6, p.uzak);
    tepeCiz(ufuk + 4, 2.0, 0.21, 2.2, p.orta);
    final yakinTaban = ufuk + 10;
    tepeCiz(yakinTaban, 1.5, 0.17, 4.1, p.yakin);

    // Çam ağaçları.
    void cam(int x, int yTaban, int boy) {
      final govde = math.max(1, boy ~/ 4);
      for (var i = 0; i < govde; i++) {
        kare(x, yTaban - i, p.agac);
      }
      final katSayisi = boy - govde;
      for (var k = 0; k < katSayisi; k++) {
        final genis = 1 + (k * 2 / 1.5).floor().clamp(0, 5);
        final y = yTaban - govde - (katSayisi - 1 - k);
        final yari = (genis ~/ 2);
        for (var dx = -yari; dx <= yari; dx++) {
          kare(x + dx, y, p.agac);
        }
      }
    }

    for (final x in const [2, 7, 12, 31, 34]) {
      cam(x, tepe(x, yakinTaban, 1.5, 0.17, 4.1) + 1, 8);
    }
    for (final x in const [20, 23, 29]) {
      cam(x, tepe(x, ufuk + 4, 2.0, 0.21, 2.2) + 1, 5);
    }

    // Akşam: kamp ateşi, parıltısı ve ateş böcekleri.
    if (bolum == SahneBolumu.aksam) {
      const fx = 18;
      final fy = tepe(fx, yakinTaban, 1.5, 0.17, 4.1) + 3;
      for (var dy = -5; dy <= 3; dy++) {
        for (var dx = -7; dx <= 7; dx++) {
          final d = math.sqrt(dx * dx + dy * dy * 2.5);
          if (d < 7) kare(fx + dx, fy + dy, const Color(0xFFFFA24A).withValues(alpha: 0.12 * (1 - d / 7)));
        }
      }
      kare(fx - 1, fy, const Color(0xFF5A3A24));
      kare(fx, fy, const Color(0xFF6B4630));
      kare(fx + 1, fy, const Color(0xFF5A3A24));
      kare(fx - 1, fy - 1, const Color(0xFFE5622B));
      kare(fx, fy - 1, const Color(0xFFF08A2E));
      kare(fx + 1, fy - 1, const Color(0xFFE5622B));
      kare(fx, fy - 2, const Color(0xFFFFC857));
      kare(fx, fy - 3, const Color(0xFFF08A2E));
      final r = math.Random(5);
      for (var i = 0; i < 7; i++) {
        kare(4 + r.nextInt(28), ufuk + 2 + r.nextInt(9), const Color(0xFFE6F28A).withValues(alpha: 0.8));
      }
    }
  }

  @override
  bool shouldRepaint(SahneCizici old) => old.bolum != bolum;
}
