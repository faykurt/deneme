# Aklımda — Tasarım Kararları

Durum: **Tasarım aşaması. Kod yazımına başlanmadı.** Kod yalnızca kullanıcı açıkça "yap" dediğinde yazılır.
Çalışma kuralları: (1) "yap" denmeden hiçbir şey yapılmaz, (2) tahmin yapılmaz, boşluklar sorularak doldurulur.

## 1. Amaç
Günlük hayat, tez ve iş yerindeki işler, mini projeler, dekorasyon fikirleri, önerilen dizi/film vb. unutulup gitmesin. Uygulama, kullanıcı listeye bakmadan, doğru zamanda ve kolayca (seamless) hatırlatsın. Yalnızca kişisel kullanım (mağazaya konmayacak).

## 2. Platform ve dağıtım
- Flutter, sadece Android. Cihaz: Samsung A52, Android 14. Tek cihaz.
- Önerilen yol (kullanıcı henüz açıkça onaylamadı): kod GitHub'a pushlanır, GitHub Actions APK derler, telefona APK ile kurulur. Güncelleme için Obtainium önerildi. Aynı imza anahtarı kullanılacak ki güncelleme veriyi silmesin.
- Veri ilk aşamada sadece telefonda (yedek sonradan eklenebilir).

## 3. Not alma
- Not türleri: metin, link, fotoğraf/ekran görüntüsü.
- Sesli not: tek dokunuşla kayıt, Android ses tanıma ile Türkçe metne çevrilir, ses dosyası saklanmaz.
- Ana ekranda iki widget butonu: sesli not ve yazılı not.
- Android paylaş menüsünde "Aklımda" görünür (ekran görüntüsü sonrası paylaş dahil). Galeri otomatik taranmaz.
- Not alınca otomatik doldurulmuş bir onay penceresi açılır (kategori, tarih vb.). Direkt onaylanabilir ya da değiştirilebilir. Her şey sonra notun içinden düzenlenebilir.
- Not içindeki tarih tanınır, takvime ekleme önerisi sunulur.
- Bilinen kısıt: Instagram paylaşımı çoğunlukla link verir ve içeriği okunamayabilir, ekran görüntüsü daha güvenilir.

## 4. Kategoriler
- İç içe, en fazla 2 seviye (örn. Hobi → Dizi, Film, Kitap, Oyun). Başlangıç fikirleri: İş, Tez, Dekorasyon, Hobi, Dizi/Film.
- Bir not birden fazla kategoriye girebilir.
- Uygulama kategori tahmin eder, kullanıcı tek dokunuşla onaylar. Yeni kategori oluşturmadan önce kullanıcıya sorar.
- Düzenleme: notu açarak, Drive tarzı sürükle-bırakla, çoklu seçip toplu taşıyarak.

## 5. Adımlara bölme
- Yalnızca uygulama notu "yapılabilir bir iş" olarak anlarsa seçenek çıkar, adımlar otomatik önerilir (yaklaşık süreyle: 5 dk, 3 dk...).
- Kullanıcı adımları onaylar ya da atlar. Adımlar ve süreler düzenlenebilir.
- Biten adımın üstü çizilir.
- Bekleme durumu vardır (örn. "kargo bekleniyor, 3 gün sonra hatırlat").
- Sıradaki adımın ne zaman önerileceği öneri sisteminin kuralları içinde belirlenir.

## 6. Takvim
- Samsung Takvim'e bağlanır (telefonun takvim deposu üzerinden), iki yönlü okuma/yazma. Sadece Samsung takvimi sayılır.
- Uygulamada ay görünümü varsayılan. Gün ve hafta görünümü seçilebilir.
- Etkinlik alanları: başlık, saat, tekrar (günlük, haftalık, aylık, yıllık).
- Uyku ve mesai saatleri kullanıcı tarafından tanımlanır, hafta içi ve hafta sonu ayrı. Bunların dışı "boş" sayılır.
- İzin günleri hafta sonu gibi sayılır. Türkiye resmi tatilleri otomatik alınır, kişisel izinleri kullanıcı tanımlar.
- Notlardan çıkan adımlar takvime otomatik yazılmaz, uygulama boş zaman önerir, kullanıcı kabul ederse işlenir.
- Samsung Hatırlatıcı (Reminder) kapsam dışı.

## 7. Öneri ve hatırlatma
- Zamanlama karma: kategori başına saat aralıkları (uygulama başta önerir, kullanıcı onaylar/düzenler), uygulama aralık içinde takvimde boş olan en uygun anı seçer. Örnek: hobi mesai/uyku saatinde gelmez, tez kullanıcının belirlediği saatlerde gelir.
- Konuma göre tetikleme: sadece ev ve iş yeri. İş notları işteyken, diğerleri evdeyken önerilir. Saat konumdan önceliklidir. "Her zaman konum izni" verilecek.
- Sıklık: günde en fazla 3 öneri bildirimi, hafta içi ve hafta sonu aynı.
- Bildirimde tek öneri vardır, bildirim üzerinde buton yoktur, dokununca uygulama açılır. Ana sayfada 2-3 öneri gösterilir.
- Öneri seçimi: boşluk süresine uyum, bekleme süresi, yaklaşan tarih ve önceki reddetmeler dengeli kullanılır.
- Öneri seçenekleri: Yaptım (tamamlanmış olarak arşive gider, silinmez), Sonra hatırlat (sabit 1 gün sonra), Sil (notu tamamen siler).
- Reddedilen türler zamanla daha az önerilir.
- Hafta sonu özeti: Cuma 22:00 (cumartesi için), Cumartesi 22:00 (pazar için). İlgili günün planı hafta sonu boyunca ana sayfada kalır.
- Tarih hatırlatması: kullanıcı not içinde hatırlatma seçmediyse hatırlatma yoktur. Seçtiyse ne zaman hatırlatılacağını da kendisi seçer, uygulama o zamanda hatırlatır. Günlük 3 öneri sınırına dahil değildir.
- Sessiz saatler: ayrı sessiz mod yok, uyku/mesai tanımı ve takvim doluluğu yeter.

## 8. Ekranlar
- Alt menü: Ana sayfa, Takvim, Notlar, Ayarlar. Belirgin sesli not butonu.
- Ana sayfa (sade): bugünün takvimi, 2-3 öneri, hafta sonu önerileri (hafta sonu planı), hızlı sesli/yazılı not alanı.
- Notlar: klasör görünümü (varsayılan) ve liste görünümü (arama, sıralama). Arşiv, Notlar sekmesinde ayrı bir bölüm.
- Dil: Türkçe. Özel isimler (film, mekan, uygulama adı) çevrilmez.

## 8b. Tema ve görsel (ilk sürüm)
- Açık temayla başlanır. Koyu tema ve telefona göre otomatik seçenek sonraya kalır.
- Ana sayfada arka planda piksel art bir görsel olur, kartlar/pencereler onun üzerinde durur. Görselleri Claude kodla hazırlar (basit/sade kalite, sonra hazır görselle değiştirilebilir).
- 3 görsel: sabah, öğle, akşam. Saate göre otomatik geçer. Konu: doğa temalı, sıcak tonlar.
- Diğer ekranlar (Takvim, Notlar, Ayarlar): sade arka plan, ana sayfadaki görseli kullanmaz.
- Etkileşimli sahne, sana benzeyen karakter, animasyonlar (kahve dumanı, ışık huzmesi, sesli not sırasında yazma animasyonu vb.), ambiyans sesi: 2. ve 3. sürümlerde detaylarıyla kararlaştırılacak.

## 8c. Ayarlar
- Ev ve iş yeri konumları Ayarlar'dan girilir.
- Başlangıç kategorilerini uygulama önerir, kullanıcı onaylar/düzenler.
- Uyku/mesai saatleri, kategori başı öneri saat aralıkları, izin günleri, API anahtarı Ayarlar'dadır.

## 9. Yapay zeka ve teknik
- Anthropic API kullanılacak (kategori, adım çıkarma, tarih tanıma, görsel okuma). Ücretli, kullandığın kadar öde, Claude üyeliğinden ayrı. Kullanıcı bunu kabul etti.
- API anahtarı koda/APK'ya gömülmez, Ayarlar'dan bir kere girilir, telefonda saklanır.
- Gizlilik kısıtı yok, iş dahil tüm notlar yapay zekaya gidebilir.
- Ses tanıma: Android'in kendi özelliği (API ücreti yok).
- İnternet yokken not kaydedilir, işleme bağlantı gelince yapılır.

## 10. Adı
**Aklımda**

## 11. Açık konular
- Uygulama ikonu.
- Sabah/öğle/akşam görsellerinin saat sınırları ve gece saatlerinde hangi görselin kullanılacağı.
- GitHub Actions + APK yolunun açık onayı (alternatifler tartışılıyor).
- Not başına hatırlatma seçenekleri: zaman seçiminin biçimi (hazır seçenekler mi, serbest tarih/saat mi).
