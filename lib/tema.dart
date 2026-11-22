import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ortak.dart';

/// Koyu / açık gri tema seçimi. Varsayılan koyu.
class TemaAyari extends ChangeNotifier {
  TemaAyari._();
  static final instance = TemaAyari._();

  static const _anahtar = 'tema_koyu';
  bool _koyu = true;
  bool get koyu => _koyu;

  Future<void> yukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      _koyu = p.getBool(_anahtar) ?? true;
    } catch (_) {}
    Renk.koyu = _koyu;
  }

  Future<void> ayarla(bool koyu) async {
    if (koyu == _koyu) return;
    _koyu = koyu;
    Renk.koyu = koyu;
    notifyListeners();
    // Renkler çoğu yerde doğrudan okunduğu için açık ekranların hepsini yeniden çiz.
    _hepsiniYenile();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_anahtar, koyu);
    } catch (_) {}
  }

  void _hepsiniYenile() {
    void ziyaret(Element e) {
      e.markNeedsBuild();
      e.visitChildren(ziyaret);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(ziyaret);
  }

  ThemeData get tema {
    final k = _koyu;
    final sema = ColorScheme.fromSeed(
      seedColor: Renk.vurgu,
      brightness: k ? Brightness.dark : Brightness.light,
    ).copyWith(
      primary: Renk.vurgu,
      onPrimary: Renk.vurguUstu,
      surface: Renk.zemin,
      onSurface: Renk.yazi,
      surfaceContainerHighest: Renk.kart,
      surfaceContainerHigh: Renk.kart,
      surfaceContainer: Renk.kart,
      surfaceContainerLow: Renk.kart,
      surfaceContainerLowest: Renk.zemin,
      secondaryContainer: Renk.vurgu.withValues(alpha: 0.22),
      outline: k ? const Color(0xFF8A908C) : const Color(0xFF6E7471),
      outlineVariant: Renk.sinir,
    );
    return ThemeData(
      colorScheme: sema,
      scaffoldBackgroundColor: Renk.zemin,
      canvasColor: Renk.zemin,
      cardColor: Renk.kart,
      dialogTheme: DialogThemeData(backgroundColor: Renk.kart),
      appBarTheme: AppBarTheme(
        backgroundColor: Renk.zemin,
        foregroundColor: Renk.yazi,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: Renk.zemin),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: k ? const Color(0xFF2E3230) : const Color(0xFF2B2E2D),
        contentTextStyle: const TextStyle(color: Color(0xFFEDEFED)),
        actionTextColor: const Color(0xFF7ED9A5),
      ),
      useMaterial3: true,
    );
  }
}
