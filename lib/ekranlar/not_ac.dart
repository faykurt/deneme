import 'package:material_ui/material_ui.dart';

import '../veri/modeller.dart';
import 'not_detay.dart';
import 'tarif_sayfasi.dart';

/// Notu türüne göre açar: tarifler yemek kitabı sayfasında, diğerleri not detayında.
Route<void> notRotasi(Not n) => MaterialPageRoute<void>(
      builder: (_) => n.tarifMi ? TarifSayfasi(notId: n.id) : NotDetay(notId: n.id),
    );

void notuAc(BuildContext context, Not n) => Navigator.push(context, notRotasi(n));
