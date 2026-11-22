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

  static const _surum = 1;
  late Database _db;
  late Directory fotografKlasoru;
  late String veritabaniYolu;

  List<Kategori> kategoriler = [];
  List<Not> notlar = []; // silinmemiş tüm notlar (arşiv dahil)

  KategoriAgaci get agac => KategoriAgaci(kategoriler);
  List<Not> get aktifNotlar => notlar.where((n) => !n.arsiv).toList();
  List<Not> get arsivNotlari => notlar.where((n) => n.arsiv).toList();

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
        takvim_etkinlik_id TEXT
      )''');
    await db.execute('''
      CREATE TABLE kategoriler (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ad TEXT NOT NULL,
        ust_id INTEGER REFERENCES kategoriler(id) ON DELETE CASCADE,
        sira INTEGER NOT NULL DEFAULT 0
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
        durum TEXT NOT NULL DEFAULT 'yapilacak'
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

  Future<void> yenile() async {
    final kRows = await _db.query('kategoriler', orderBy: 'sira, id');
    kategoriler = kRows.map(Kategori.fromMap).toList();
    final nRows = await _db.query('notlar', where: 'silindi = 0', orderBy: 'olusturma DESC');
    final fRows = await _db.query('fotograflar', orderBy: 'sira, id');
    final nkRows = await _db.query('not_kategori');
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

  Future<void> notGuncelle(Not not) async {
    not.guncelleme = _simdi;
    not.sonDokunma = not.guncelleme;
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
  Future<void> kategoriEkle(String ad, {int? ustId}) async {
    final sira = kategoriler.where((k) => k.ustId == ustId).length;
    await _db.insert('kategoriler', {'ad': ad.trim(), 'ust_id': ustId, 'sira': sira});
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
