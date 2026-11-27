import 'package:flutter_test/flutter_test.dart';

import 'package:aklimda/veri/modeller.dart';

void main() {
  final agac = KategoriAgaci([
    Kategori(id: 1, ad: 'Hobi'),
    Kategori(id: 2, ad: 'Dizi', ustId: 1),
    Kategori(id: 3, ad: 'Film', ustId: 1, sira: 1),
    Kategori(id: 4, ad: 'Tez', sira: 1),
  ]);

  test('Kategori ağacı ana ve alt kategorileri doğru ayırır', () {
    expect(agac.anaKategoriler.map((k) => k.ad), ['Hobi', 'Tez']);
    expect(agac.altlari(1).map((k) => k.ad), ['Dizi', 'Film']);
    expect(agac.tamAd(2), 'Hobi › Dizi');
    expect(agac.kendisiVeAltlari(1), {1, 2, 3});
  });

  test('Başlığı olmayan notta ilk satır başlık olur', () {
    final n = Not(id: 'a', metin: 'Tablo asılacak\nÖnce ölçü al', kaynak: Kaynak.yazili,
        olusturma: 0, guncelleme: 0, sonDokunma: 0);
    expect(n.gorunenBaslik, 'Tablo asılacak');
  });
}
