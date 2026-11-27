import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'modeller.dart';

/// Tüm notların ve kategorilerin telefonda saklandığı yer.
/// Değişiklik olunca dinleyen ekranlar kendini yeniler.
class Depo extends ChangeNotifier {
  Depo._();
  static final Depo instance = Depo._();

  static const _surum = 5;

  /// Yeni notun yapay zeka dışı başlayıp başlamayacağı (Ayarlar'daki otomatik anahtarı).
  static bool Function() yeniNotAiDisi = () => false;
  late Database _db;
  late Directory fotografKlasoru;
  late String veritabaniYolu;

  List<Kategori> kategoriler = [];
  List<Not> notlar = []; // silinmemiş tüm notlar (arşiv dahil)

  KategoriAgaci get agac => KategoriAgaci(kategoriler);
  List<Not> get aktifNotlar => notlar.where((n) => !n.arsiv).toList();
  List<Not> get arsivNotlari => notlar.where((n) => n.arsiv).toList();
  List<Not> get onayBekleyenler => notlar.where((n) => !n.arsiv && n.onayBekliyor).toList();

  Future<void> ac() async {
    final belgeler = await getApplicationDocumentsDirectory();
    fotografKlasoru = Directory(p.join(belgeler.path, 'fotograflar'));
    await fotografKlasoru.create(recursive: true);
    veritabaniYolu = p.join(await getDatabasesPath(), 'aklimda.db');
    _db = await openDatabase(
      veritabaniYolu,
      version: _surum,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _olustur,
      onUpgrade: yukselt,
    );
    await _silinenleriTemizle();
    await yenile();
  }

  Future<void> _olustur(Database db, int surum) async {
    await db.execute('''
      CREATE TABLE notlar (
        id TEXT PRIMARY KEY,
        metin TEXT NOT NULL DEFAULT '',
        baslik TEXT,
        kaynak TEXT NOT NULL,
        olusturma INTEGER NOT NULL,
        guncelleme INTEGER NOT NULL,
        durum TEXT NOT NULL DEFAULT 'yapilacak',
        arsiv INTEGER NOT NULL DEFAULT 0,
        silindi INTEGER NOT NULL DEFAULT 0,
        onayli INTEGER NOT NULL DEFAULT 0,
        islendi INTEGER NOT NULL DEFAULT 0,
        sure_dk INTEGER,
        tarih INTEGER,
        tarih_saatli INTEGER NOT NULL DEFAULT 0,
        hatirlatma INTEGER,
        link TEXT,
        yorum TEXT,
        son_dokunma INTEGER NOT NULL,
        erteleme_sayisi INTEGER NOT NULL DEFAULT 0,
        gormezden_sayisi INTEGER NOT NULL DEFAULT 0,
        takvim_etkinlik_id TEXT,
        takvim_baslangic INTEGER,
        takvim_bitis INTEGER,
        yaptin_cevap INTEGER NOT NULL DEFAULT 0,
        ai_json TEXT,
        ai_disi INTEGER NOT NULL DEFAULT 0,
        tur TEXT NOT NULL DEFAULT 'not'
      )''');
    await db.execute('''
      CREATE TABLE kategoriler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ad TEXT NOT NULL,
        ust_id INTEGER REFERENCES kategoriler(id) ON DELETE CASCADE,
        sira INTEGER NOT NULL DEFAULT 0,
        renk INTEGER,
        ikon TEXT,
        kapak_resim TEXT
      )''');
    await db.execute('''
      CREATE TABLE not_kategori (
        not_id TEXT NOT NULL REFERENCES notlar(id) ON DELETE CASCADE,
        kategori_id INTEGER NOT NULL REFERENCES kategoriler(id) ON DELETE CASCADE,
        PRIMARY KEY (not_id, kategori_id)
      )''');
    await db.execute('''
      CREATE TABLE fotograflar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        not_id TEXT NOT NULL REFERENCES notlar(id) ON DELETE CASCADE,
        dosya TEXT NOT NULL,
        sira INTEGER NOT NULL DEFAULT 0
      )''');
    await db.execute('''
      CREATE TABLE adimlar (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        not_id TEXT NOT NULL REFERENCES notlar(id) ON DELETE CASCADE,
        sira INTEGER NOT NULL,
        metin TEXT NOT NULL,
        sure_dk INTEGER,
        durum TEXT NOT NULL DEFAULT 'yapilacak',
        bekleme INTEGER NOT NULL DEFAULT 0
      )''');
    // Başlangıç kategorileri (sonradan düzenlenebilir)
    const baslangic = <String, List<String>>{
      'İş': [],
      'Tez': [],
      'Ev': ['Dekorasyon'],
      'Hobi': ['Dizi', 'Film', 'Kitap', 'Oyun'],
      'Yemek': ['Tarif'],
      'Projeler': [],
      'Günlük işler': [],
    };
    var sira = 0;
    for (final e in baslangic.entries) {
      final ustId = await db.insert('kategoriler', {'ad': e.key, 'sira': sira++});
      var altSira = 0;
      for (final alt in e.value) {
        await db.insert('kategoriler', {'ad': alt, 'ust_id': ustId, 'sira': altSira++});
      }
    }
  }

  /// 1 → 2: yapay zeka önerisi ve adımlarda bekleme işareti eklendi. 2 → 3: takvim bağlantısı.
  /// 3 → 4: yapay zeka dışı bırakma, liste türü, kategori rengi ve ikonu.
  /// Eski (yapay zekadan önceki) notlar onaylı sayılır, "onay bekleyen" yığını oluşmaz.
  static Future<void> yukselt(Database db, int eski, int yeni) async {
    if (eski < 2) {
      await db.execute('ALTER TABLE notlar ADD COLUMN ai_json TEXT');
      await db.execute('ALTER TABLE adimlar ADD COLUMN bekleme INTEGER NOT NULL DEFAULT 0');
      await db.execute('UPDATE notlar SET onayli = 1');
    }
    if (eski < 3) {
      await db.execute('ALTER TABLE notlar ADD COLUMN takvim_baslangic INTEGER');
      await db.execute('ALTER TABLE notlar ADD COLUMN takvim_bitis INTEGER');
      await db.execute('ALTER TABLE notlar ADD COLUMN yaptin_cevap INTEGER NOT NULL DEFAULT 0');
    }
    if (eski < 4) {
      await db.execute('ALTER TABLE notlar ADD COLUMN ai_disi INTEGER NOT NULL DEFAULT 0');
      await db.execute("ALTER TABLE notlar ADD COLUMN tur TEXT NOT NULL DEFAULT 'not'");
      await db.execute('ALTER TABLE kategoriler ADD COLUMN renk INTEGER');
      await db.execute('ALTER TABLE kategoriler ADD COLUMN ikon TEXT');
    }
    if (eski < 5) {
      await db.execute('ALTER TABLE kategoriler ADD COLUMN kapak_resim TEXT');
    }
  }

  Future<void> yenile() async {
    final kRows = await _db.query('kategoriler', orderBy: 'sira, id');
    kategoriler = kRows.map(Kategori.fromMap).toList();
    final nRows = await _db.query('notlar', where: 'silindi = 0', orderBy: 'olusturma DESC');
    final fRows = await _db.query('fotograflar', orderBy: 'sira, id');
    final nkRows = await _db.query('not_kategori');
    final aRows = await _db.query('adimlar', orderBy: 'not_id, sira, id');
    final adimMap = <String, List<Adim>>{};
    for (final a in aRows) {
      adimMap.putIfAbsent(a['not_id'] as String, () => []).add(Adim.fromMap(a));
    }
    final fotoMap = <String, List<String>>{};
    for (final f in fRows) {
      fotoMap.putIfAbsent(f['not_id'] as String, () => []).add(f['dosya'] as String);
    }
    final katMap = <String, List<int>>{};
    for (final r in nkRows) {
      katMap.putIfAbsent(r['not_id'] as String, () => []).add(r['kategori_id'] as int);
    }
    notlar = nRows.map((r) {
      final n = Not.fromMap(r);
      n.fotograflar = fotoMap[n.id] ?? [];
      n.kategoriIdler = katMap[n.id] ?? [];
      n.adimlar = adimMap[n.id] ?? [];
      return n;
    }).toList();
    notifyListeners();
  }

  static int get _simdi => DateTime.now().millisecondsSinceEpoch;

  /// Yeni not kaydeder. Fotoğraf yolları uygulama klasörüne kopyalanır.
  Future<Not> notEkle({
    required String metin,
    required String kaynak,
    String? link,
    List<String> fotografYollari = const [],
    List<int> kategoriIdler = const [],
    String tur = NotTuru.not,
    bool aiDisi = false,
  }) async {
    final simdi = _simdi;
    final not = Not(
      id: const Uuid().v4(),
      metin: metin.trim(),
      kaynak: kaynak,
      link: link,
      olusturma: simdi,
      guncelleme: simdi,
      sonDokunma: simdi,
      tur: tur,
      aiDisi: aiDisi || yeniNotAiDisi(),
    );
    await _db.insert('notlar', not.toMap());
    for (final yol in fotografYollari) {
      await fotografEkle(not.id, yol, yenidenYukle: false);
    }
    for (final k in kategoriIdler) {
      await _db.insert('not_kategori', {'not_id': not.id, 'kategori_id': k},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await yenile();
    return notlar.firstWhere((n) => n.id == not.id);
  }

  /// [dokunma] false ise "son dokunma" zamanı değişmez (yapay zeka arka planda işlerken).
  Future<void> notGuncelle(Not not, {bool dokunma = true}) async {
    not.guncelleme = _simdi;
    if (dokunma) not.sonDokunma = not.guncelleme;
    await _db.update('notlar', not.toMap(), where: 'id = ?', whereArgs: [not.id]);
    await yenile();
  }

  Future<void> fotografEkle(String notId, String kaynakYol, {bool yenidenYukle = true}) async {
    final uzanti = p.extension(kaynakYol).isEmpty ? '.jpg' : p.extension(kaynakYol);
    final hedef = p.join(fotografKlasoru.path, '${const Uuid().v4()}$uzanti');
    await File(kaynakYol).copy(hedef);
    final sayi = Sqflite.firstIntValue(
            await _db.rawQuery('SELECT COUNT(*) FROM fotograflar WHERE not_id = ?', [notId])) ??
        0;
    await _db.insert('fotograflar', {'not_id': notId, 'dosya': hedef, 'sira': sayi});
    if (yenidenYukle) await yenile();
  }

  Future<void> fotografSil(String notId, String dosya) async {
    await _db.delete('fotograflar', where: 'not_id = ? AND dosya = ?', whereArgs: [notId, dosya]);
    final f = File(dosya);
    if (await f.exists()) await f.delete();
    await yenile();
  }

  Future<void> kategorileriAyarla(String notId, Iterable<int> kategoriIdler) async {
    await _db.transaction((tx) async {
      await tx.delete('not_kategori', where: 'not_id = ?', whereArgs: [notId]);
      for (final k in kategoriIdler.toSet()) {
        await tx.insert('not_kategori', {'not_id': notId, 'kategori_id': k});
      }
    });
    await yenile();
  }

  /// Notları başka bir kategoriye taşır (eskiKategori verilirse sadece ondan çıkarır).
  Future<void> tasi(Iterable<String> notIdler, int hedef, {int? eskiKategori}) async {
    await _db.transaction((tx) async {
      for (final id in notIdler) {
        if (eskiKategori != null) {
          await tx.delete('not_kategori',
              where: 'not_id = ? AND kategori_id = ?', whereArgs: [id, eskiKategori]);
        } else {
          await tx.delete('not_kategori', where: 'not_id = ?', whereArgs: [id]);
        }
        await tx.insert('not_kategori', {'not_id': id, 'kategori_id': hedef},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    await yenile();
  }

  Future<void> kopyala(Iterable<String> notIdler, int hedef) async {
    await _db.transaction((tx) async {
      for (final id in notIdler) {
        await tx.insert('not_kategori', {'not_id': id, 'kategori_id': hedef},
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
    await yenile();
  }

  Future<void> arsivle(Iterable<String> notIdler, bool arsiv) async {
    for (final id in notIdler) {
      await _db.update('notlar', {'arsiv': arsiv ? 1 : 0, 'guncelleme': _simdi},
          where: 'id = ?', whereArgs: [id]);
    }
    await yenile();
  }

  /// Silme geri alınabilir: önce işaretlenir, uygulama yeniden açılınca kalıcı silinir.
  Future<void> sil(Iterable<String> notIdler) async {
    for (final id in notIdler) {
      await _db.update('notlar', {'silindi': 1}, where: 'id = ?', whereArgs: [id]);
    }
    await yenile();
  }

  Future<void> silmeyiGeriAl(Iterable<String> notIdler) async {
    for (final id in notIdler) {
      await _db.update('notlar', {'silindi': 0}, where: 'id = ?', whereArgs: [id]);
    }
    await yenile();
  }

  Future<void> _silinenleriTemizle() async {
    final rows = await _db.rawQuery(
        'SELECT f.dosya FROM fotograflar f JOIN notlar n ON n.id = f.not_id WHERE n.silindi = 1');
    for (final r in rows) {
      final f = File(r['dosya'] as String);
      if (await f.exists()) await f.delete();
    }
    await _db.delete('notlar', where: 'silindi = 1');
  }

  // Kategori yönetimi
  Future<int> kategoriEkle(String ad, {int? ustId}) async {
    final sira = kategoriler.where((k) => k.ustId == ustId).length;
    final id = await _db.insert('kategoriler', {'ad': ad.trim(), 'ust_id': ustId, 'sira': sira});
    await yenile();
    return id;
  }

  // Adımlar
  /// Bir notun adımlarını verilen listeyle değiştirir (sıra listedeki sıradır).
  Future<void> adimlariKaydet(String notId, List<Adim> adimlar) async {
    await _db.transaction((tx) async {
      await tx.delete('adimlar', where: 'not_id = ?', whereArgs: [notId]);
      var sira = 0;
      for (final a in adimlar) {
        await tx.insert('adimlar', Adim(
          notId: notId,
          sira: sira++,
          metin: a.metin,
          sureDk: a.sureDk,
          durum: a.durum,
          bekleme: a.bekleme,
        ).toMap());
      }
    });
    await yenile();
  }

  Future<void> adimDurumu(int adimId, String durum) async {
    await _db.update('adimlar', {'durum': durum}, where: 'id = ?', whereArgs: [adimId]);
    await yenile();
  }

  /// Notları onaylı işaretler (yapay zekanın önerisi kabul edildi).
  Future<void> onayla(Iterable<String> notIdler) async {
    for (final id in notIdler) {
      await _db.update('notlar', {'onayli': 1, 'guncelleme': _simdi}, where: 'id = ?', whereArgs: [id]);
    }
    await yenile();
  }

  Future<void> kategoriGorunumu(int id, {int? renk, String? ikon, bool renkiTemizle = false}) async {
    await _db.update(
        'kategoriler',
        {
          if (renk != null || renkiTemizle) 'renk': renkiTemizle ? null : renk,
          'ikon': ?ikon,
        },
        where: 'id = ?',
        whereArgs: [id]);
    await yenile();
  }

  /// Kitabın kapağına resim koyar (dosya uygulama klasörüne kopyalanır) ya da kaldırır ([kaynakYol] null).
  Future<void> kategoriKapakResmi(int id, String? kaynakYol) async {
    final eski = kategoriler.where((k) => k.id == id).firstOrNull?.kapakResmi;
    String? yeni;
    if (kaynakYol != null) {
      final uzanti = p.extension(kaynakYol).isEmpty ? '.jpg' : p.extension(kaynakYol);
      yeni = p.join(fotografKlasoru.path, 'kapak_${const Uuid().v4()}$uzanti');
      await File(kaynakYol).copy(yeni);
    }
    await _db.update('kategoriler', {'kapak_resim': yeni}, where: 'id = ?', whereArgs: [id]);
    if (eski != null) {
      final f = File(eski);
      if (await f.exists()) await f.delete();
    }
    await yenile();
  }

  Future<void> kategoriAdlandir(int id, String ad) async {
    await _db.update('kategoriler', {'ad': ad.trim()}, where: 'id = ?', whereArgs: [id]);
    await yenile();
  }

  /// Kategori silinince notları silinmez, "Kategorisiz"e düşer.
  Future<void> kategoriSil(int id) async {
    await _db.delete('kategoriler', where: 'id = ?', whereArgs: [id]);
    await yenile();
  }

  /// Yedek için veritabanını diske tam yazar.
  Future<void> yedekIcinHazirla() async {
    await _db.rawQuery('PRAGMA wal_checkpoint(FULL)');
  }
}
