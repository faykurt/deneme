import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../ortak.dart';
import '../takvim/etkinlik_simgesi.dart';
import '../takvim/takvim_deposu.dart';
import '../takvim/takvim_modeller.dart';

DateTime _haftaBasi(DateTime d) => gunBasi(d).subtract(Duration(days: d.weekday - 1));

/// Haftanın özeti: yedi gün alt alta, her günün altında etkinlikler küçük ikonlu satırlar olarak.
/// Güne dokununca günlük görünüm açılır.
class HaftaOzeti extends StatelessWidget {
  final DateTime odak;
  final void Function(DateTime) onGun;
  final void Function(TEtkinlik) onAc;
  const HaftaOzeti({super.key, required this.odak, required this.onGun, required this.onAc});

  static const _gunAdlari = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

  @override
  Widget build(BuildContext context) {
    final depo = TakvimDeposu.instance;
    final bas = _haftaBasi(odak);
    final bugun = gunBasi(DateTime.now());
    final f = DateFormat('HH:mm');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 130),
      children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (context) {
            final g = bas.add(Duration(days: i));
            final bugunMu = g == bugun;
            final secili = g == gunBasi(odak);
            final liste = depo.gununEtkinlikleri(g);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Renk.kart.withValues(alpha: bugunMu ? 1 : 0.85),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: bugunMu ? Renk.vurgu : Renk.sinir, width: bugunMu ? 1.8 : 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InkWell(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  onTap: () => onGun(g),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: bugunMu || secili ? Renk.vurgu : Colors.transparent),
                        child: Text('${g.day}',
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: bugunMu || secili ? Renk.vurguUstu : (i >= 5 ? Renk.hata : Renk.yazi))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_gunAdlari[i],
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Renk.yazi)),
                      ),
                      if (liste.isNotEmpty)
                        Text('${liste.length} etkinlik', style: TextStyle(fontSize: 12, color: Renk.yazi.withValues(alpha: 0.6))),
                      Icon(Icons.chevron_right, size: 18, color: Renk.yazi.withValues(alpha: 0.5)),
                    ]),
                  ),
                ),
                if (liste.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 12, 12),
                    child: Text('Boş gün', style: TextStyle(fontSize: 13, color: Renk.yazi.withValues(alpha: 0.4))),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(children: [
                      for (final e in liste)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onAc(e),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            child: Row(children: [
                              Container(
                                width: 26,
                                height: 26,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: (depo.renkOf(e) ?? Renk.vurgu), shape: BoxShape.circle),
                                child: depo.simgeOf(e, size: 14, renk: Renk.vurguUstu) ??
                                    Icon(Icons.event_note, size: 14, color: Renk.vurguUstu),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(EtkinlikSimgesi.temizBaslik(e.baslik),
                                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Renk.yazi, fontSize: 14)),
                              ),
                              const SizedBox(width: 8),
                              Text(e.tumGun ? 'Tüm gün' : f.format(e.baslangic),
                                  style: TextStyle(fontSize: 12, color: Renk.yazi.withValues(alpha: 0.65), fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                    ]),
                  ),
              ]),
            );
          }),
      ],
    );
  }
}
