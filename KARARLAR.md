# Aklımda — Tasarım Kararları

Durum: **Geliştirme sürüyor.** 1-4. aşamalar ve yapay zeka maliyet düzenlemesi tamam (son sürüm v0.4.14). Sıradaki: 5. aşama (öneriler). Teknik durum ve devam planı için `DEVAM.md`'ye bak. Kod yalnızca kullanıcı açıkça "yap" dediğinde (aşama başına) yazılır.
Çalışma kuralları: (1) "yap" denmeden hiçbir şey yapılmaz, (2) tahmin yapılmaz, boşluklar sorularak doldurulur.

## 1. Amaç
Günlük hayat, tez ve iş yerindeki işler, mini projeler, dekorasyon fikirleri, önerilen dizi/film vb. unutulup gitmesin. Uygulama, kullanıcı listeye bakmadan, doğru zamanda ve kolayca (seamless) hatırlatsın. Yalnızca kişisel kullanım (mağazaya konmayacak).

**Tasarım ilkesi:** Hiçbir onay, durum güncellemesi ya da düzenleme zorunlu değildir. Kullanıcı hiçbir şeyi onaylamasa ya da düzenlemese de uygulama çalışır. Düzenleme isteğe bağlıdır.

## 2. Platform ve dağıtım
- Flutter, sadece Android. Cihaz: Samsung A52, Android 14. Tek cihaz.
- Karar: GitHub Actions ile APK derlenir. Kod GitHub'a pushlanır, GitHub APK'yı derleyip Release olarak yayınlar, telefona APK ile kurulur. Güncelleme için Obtainium varsayılan yöntemdir (depo public olduğu için ek anahtar gerekmez), istenirse APK Releases sayfasından elle de indirilebilir. Aynı imza anahtarı kullanılacak ki güncelleme veriyi silmesin.
- Tüm süreç (ilk kurulum dahil) telefondan yürütülecek, bilgisayar kullanılmayacak. Kullanıcı her güncellemeyi telefondan Claude'a anlatır.
- Depo `faykurt/deneme` şu an **public**. Public olarak başlanır, private sonra değerlendirilecek. İmza anahtarı depoya konmaz, GitHub Secrets'a eklenir (telefon tarayıcısından, masaüstü site modunda).
- Veri telefonda tutulur. Tek dokunuşla yedek alma ilk sürümde vardır (bölüm 12).
- Kurulum notları: Samsung pil ayarı "Sınırsız" yapılmalı. Gerekli izinler: bildirim, mikrofon, takvim, bilinmeyen kaynaklardan kurulum. Samsung Otomatik Engelleyici (Auto Blocker) kapatılmalı, Play Protect uyarısına "Yine de yükle" denmeli.

## 3. Not alma
- Not türleri: metin, link, fotoğraf/ekran görüntüsü.
- Link: sayfa başlığı ve önizleme alınmaya çalışılır, alınamazsa olduğu gibi kalır.
- Fotoğraf: kopyası notta saklanır, bir notta birden fazla olabilir. Uygulama içinden kamerayla çekip not oluşturulabilir.
- Sesli not: tek dokunuşla başlar, kullanıcı "Bitir"e basana kadar devam eder, Android ses tanıma ile Türkçe metne çevrilir, ses dosyası saklanmaz. İnternetsiz çalışma: önce çevrimdışı Türkçe ses paketi denenir (A), olmazsa internet yokken "yazılı not al" uyarısı verilir (B).
- Ana ekranda iki widget butonu: sesli not ve yazılı not. Sesli not widget'ı doğrudan kayıt ekranını açar. Yazılı not widget'ı açılınca klavye hazır gelir. Hızlı ayar kutucuğu ve uygulama kısayolları şimdilik yok.
- Android paylaş menüsünde "Aklımda" ikonu görünür (ekran görüntüsü sonrası paylaş dahil). Tıklayınca içerik doğrudan kaydedilir ve küçük bir "Kaydedildi" penceresi çıkar. İstenirse bu pencerede yazılı ya da sesli yorum eklenir, dokunulmazsa birkaç saniyede kapanır. Galeri otomatik taranmaz.
- Uzun sesli notlara yapay zeka kısa bir başlık verir. Özel isimlere (İngilizce film/dizi adları vb.) yapay zeka dokunmaz. Not: ses tanımanın kendisi bu isimleri bozabilir, bunu uygulama engelleyemez, kullanıcı notta düzeltir.
- Tek kayıtta birden fazla fikir söylenirse yapay zeka bunları ayrı notlar olarak önerir.
- Her nota yapay zeka düzenlenebilir bir süre tahmini koyar.
- Kategoriye özel alanlar olabilir, hiçbiri zorunlu değildir. Dizi/Film: ad, tür ("kim önerdi" alanı kaldırıldı). Tarif: malzemeler, yapılış. Kitap ve Oyun için yazar/kim önerdi önemli değil, onun yerine fiyat ve satın alma araması var (3b). Tez için özel alan yok.
- Not içindeki tarih tanınır, takvime ekleme önerisi sunulur. Saatsiz tarihlerde hatırlatma 09:00'da verilir, saatsiz notlarda "5 dk önce" gibi seçenekler gizlenir.
- Tekrarlayan notlar olabilir, tekrar aralığını kullanıcı seçer. Tamamlanan tekrar sayılır, bir sonraki tekrar planlanır, tamamlananlar arşivde kayıt olarak kalır.
- Yapay zeka notu kaydedilince hemen işlemez (maliyet için). Kaydedilince "Kaydedildi, yapay zeka 21:00'de düzenleyecek" bildirimi çıkar ve "Şimdi analiz et" ile istenirse hemen işletilir. Not, işlendikten sonra "Onay bekleyenler"e düşer. İşlenen notun onay penceresi: yapay zekanın atadığı kategori, tarih, süre vb. hazır gelir. Kullanıcı onaylar, "daha sonra onaylarım" der ya da düzenler.
- Onay bekleyen notlar Notlar sekmesinde ayrı bir bölümde toplanır, ana sayfada "X onay bekleyen notun var" uyarısı çıkar.
- Onaylanmamış notlar (paylaşılanlar ve "daha sonra onaylarım" denenler) yapay zekanın atadığı kategoriyle öneriye girer. Onay sadece bir düzeltme fırsatıdır. İnternet yokken kaydedilip henüz işlenmemiş notlar, işlenene kadar önerilmez.
- İnternet yokken not ham haliyle kaydedilir, otomatik atama yapılmaz. Bağlantı gelince yapay zeka doldurur ve not onay bekleyenlere düşer.
- Paylaş menüsünden gelen notlar doğrudan kaydedilir ve onay bekleyenlere düşer. Her şey sonra notun içinden düzenlenebilir.
- Bilinen kısıt: Instagram paylaşımı çoğunlukla link verir ve içeriği okunamayabilir, ekran görüntüsü daha güvenilir.

## 3b. Fiyat ve satın alma araması (Kitap, Oyun)
- **İlk sürümde yok, sonraya ertelendi.** Aşağıdaki tasarım ileride kullanılacak.
- Kitap notunda: kitabı alabileceğin yerler (3-4 mağaza, en uygun fiyat, bağlantı) bulunur. Oyun notunda: fiyatı ve hangi platformlarda olduğu bulunur. Amaç satın alma işini hızlandırmak.
- Otomatik aranmaz. Kullanıcı kitap veya oyun notundaki "Nerede bulurum?" butonuna basınca çalışır.
- Sadece Türkiye içi mağazalar (TL). Kitapta mağaza tercihi ya da hariç tutma yok. Oyunda sadece Xbox için fiyat ve bulunabilirlik gösterilir.
- Anthropic API'nin web arama aracıyla yapılır. Doğruluk sınırı: fiyatlar eski olabilir, bazı mağazalar bulunamayabilir, sonuçlar bağlantıyla gelir ve kullanıcı mağazada kendisi doğrular. Ek maliyet vardır, rakam kurulum aşamasında güncel fiyat listesinden doğrulanacak.

## 4. Kategoriler
- İç içe, en fazla 2 seviye. Bir not alt kategori seçmeden doğrudan ana kategoriye de girebilir.
- Başlangıç listesi (onaylandı): İş, Tez, Ev → Dekorasyon, Hobi → Dizi / Film / Kitap / Oyun, Yemek → Tarif, Projeler, Günlük işler. Uygulama başta önerir, kullanıcı onaylar/düzenler.
- Bir not birden fazla kategoriye girebilir.
- Uygulama kategori tahmin eder, kullanıcı tek dokunuşla onaylar. Yeni kategori oluşturmadan önce kullanıcıya sorar.
- Düzenleme: notu açarak, Drive tarzı sürükle-bırakla, çoklu seçip toplu taşıyarak. Sürükleyip bırakınca bir pencere açılır ve "Kopyala" veya "Taşı" seçilir.
- Silinen kategorinin notları "Kategorisiz"e düşer. Kategoriler yeniden adlandırılabilir.

## 5. Adımlar ve durumlar
- Yalnızca uygulama notu "yapılabilir bir iş" olarak anlarsa "adımlara böl" seçeneği çıkar, adımlar otomatik önerilir (yaklaşık süreyle). Kullanıcı onaylar ya da atlar. Adımlar ve süreler düzenlenebilir.
- Adım kartında "Yaptım" sadece o adımın üstünü çizer, "Sil" sadece o adımı siler. Tüm adımlar bitince not, arşive gitmeden önce kullanıcıya sorar.
- Adımlar sıralıdır: öncekiler bitmeden sonraki önerilmez. Bir adım bitince sıradaki hemen gösterilir. Yapay zeka başta adım önerir (bekleme adımı dahil), kullanıcı onaylar, kendisi ekler ve siler.
- Durumları kullanıcı **elle** yönetir. Liste: Yapılacak, Yapılıyor, Bekliyor, Yapıldı. "Yapılıyor" durumundaki notlar öneride gelmez. Not takvime eklendiyse etkinlik bitişinden 5 dakika sonra "yaptın mı?" sorusu çıkar. Bu bildirim değildir, uygulamayı açınca görünür. Durum oradan değiştirilir. Bekliyor durumu seçilince pencere açılır, "hatırlatma ister misin" diye sorar, süre oradan seçilir.
- Adımı olmayan bir notta "Yaptım"a basınca küçük bir soru çıkar: **"Tamamen bitti"** (not arşive gider) ya da **"Bugünlük bitti"** (not olduğu gibi kalır, ileride yine önerilir). Böylece dizi, kitap, tez bölümü gibi devam eden işler önerilmeye devam eder. "Yapılıyor" durumundaki notlar öneride gelmez kuralı aynen geçerlidir.

## 6. Takvim
- Samsung Takvim'e bağlanır (telefonun takvim deposu üzerinden), iki yönlü okuma/yazma. Varsayılan Samsung takvimidir. Kurulum sihirbazında telefondaki takvimler etkinlik sayılarıyla listelenir, okunup yazılacak takvimi kullanıcı seçer.
- Ay görünümü varsayılan ve Samsung Takvim düzenindedir: tüm sayfayı kaplar, günlerde etkinlik başlıkları görünür. Güne dokununca o günün etkinlikleri pencerede açılır (altta "… için ekle"). Yana kaydırarak ay değişir. Gün ve hafta görünümü seçilebilir.
- Etkinlik alanları: başlık, başlangıç ve bitiş saati, tekrar (günlük, haftalık, aylık, yıllık, hafta içi her gün, bitiş tarihi seçilebilir). Kullanıcının eklediği tüm gün etkinlik o günü tamamen dolu sayar. Resmi tatil, doğum günü gibi tüm gün etkinlikler günü dolu saymaz (o günlerde de öneri alınabilir). Ayırt etme: Android'in etkinliklerdeki Meşgul/Müsait bilgisine bakılır (tatiller genelde Müsait gelir). Uygulamada tüm gün etkinlik eklerken "Günü dolu say" anahtarı olur. Telefonda ilk sürümde doğrulanacak.
- Uygulamadan mevcut etkinlikler düzenlenebilir ve silinebilir.
- Uygulamanın yazdığı etkinliklerin başında küçük bir işaret (💭) olur. Takvime bağlı bir not silinirse etkinliği de silmek isteyip istemediği sorulur. Tarihi olan ama takvime eklenmemiş notlar farklı görünümle gösterilir.
- "Takvime ekle": öneri kartında ve not kartında bulunur. İki mod: **normal ekle** (takvim açılır, kullanıcı yeri seçer) ve **otomatik öner** (uygulama uygun bir zaman aralığı seçip yerleştirir, kullanıcı sonra değiştirebilir). Önerilen aralığın saati ve tarihi değiştirilebilir. Ayrıca takvimde bir zaman aralığı seçilip ona not bağlanabilir.
- Uyku saatleri kullanıcı tarafından tanımlanır, hafta içi ve hafta sonu ayrı. Mesai saati tanımı yoktur. Uyku dışında, etkinlik ve iş bloğu olmayan zaman "boş" sayılır.
- **İş bloğu:** Ayarlar'da bir kelime belirlenir (varsayılan "İş"). Başlığında bu kelime geçen takvim etkinliği iş bloğudur. İş notları sadece iş bloğunun içinde önerilir. Blok içindeki başka bir etkinlik (toplantı gibi) o saatleri dolu yapar. İş bloğunun içi diğer kategoriler için boş sayılmaz. Blok yoksa (izin günü, hafta sonu) iş notu gelmez.
- İzin günleri hafta sonu gibi sayılır. Türkiye resmi tatilleri otomatik alınır, kişisel izinleri kullanıcı tanımlar. Arife günlerinde öğleden sonrası tatil sayılır.
- Samsung Hatırlatıcı (Reminder) kapsam dışı.

## 7. Öneri ve hatırlatma
- Öneriyi **yapay zeka** seçer (kural tabanlı değil, çünkü kurallar hep aynı sonucu verir). Günlük öneriler ve hafta sonu planı yapay zeka tarafından hazırlanır.
- Mekanizma (onaylandı): telefon günde birkaç kez (gün bölümü başlarında ve uygulama açılınca) yapay zekadan bir öneri paketi alır (bildirim önerileri + ana sayfa önerileri). Bildirimler bu paketten telefonda zamanlanır. İnternet yoksa son paket kullanılır. Takvim ya da notlar değişirse uygulama açılınca paket yenilenir. Bildirim anında yapay zeka çağrılmaz (maliyet ve arka plan güvenilirliği için).
- Zamanlama karma: kategori başına saat aralıkları (uygulama başta önerir, kullanıcı onaylar/düzenler), uygulama aralık içinde takvimde boş olan en uygun anı seçer.
- Konum tetikleme ilk sürümde yok (Samsung'un pil yönetimi nedeniyle güvenilmez olabilir, sonraya ertelendi). İş notları, kullanıcının takvimde iş için kapattığı bloğun içinde önerilir (bkz. bölüm 6), blok dışında gelmez. Hafta sonu ve izin günlerinde iş notu önerilmez. Diğer notlar kategori saat aralıklarına göre gelir.
- Sıklık: günde en fazla 3 öneri bildirimi, hafta içi ve hafta sonu aynı (Ayarlar'dan değiştirilebilir). "Sonra hatırlat"la ertelenenler de bu 3'e dahildir. Bildirim hakkı, yapılma olasılığı en yüksek önerilere verilir. Ertelenenler birikip bildirim sayısını şişirmez.
- Bildirim metni belirli bir öneri ("şunu yapmak ister misin?") ya da genel ("önerilerine bak") olabilir. Bildirimde aksiyon butonu yoktur.
- Öğrenme sinyali: bir notun art arda üç kez ertelenmesi ve bildirime hiç dokunulmaması. Yapay zeka bu sinyallerle ilgili türü daha seyrek önerir.
- Bildirimde tek öneri ve kısa bir neden vardır ("20 dk boşsun, 2 haftadır bekliyor"), bildirim üzerinde buton yoktur, dokununca uygulama o öneriyle açılır. Ana sayfada 2-3 öneri gösterilir. Öneriler gün bölümü değişince yenilenir (sabah 06-11, öğle 11-17, akşam 17-06) ve öneri paketi de bu bölümlerin başında alınır. Hafta sonu planı bunlardan bağımsız kendi saatlerini kullanır (öğle 12-18, akşam 18-24).
- Öneri kartı seçenekleri: **Yaptım** (tamamlanmış sayılır ve arşive gider; adımlı notlarda sadece o adımı tamamlar, adımı olmayan notlarda "tamamen mi, bugünlük mü" diye sorar), **Sonra hatırlat** (ertesi gün uygun bir boşlukta; günlük 3 bildirim sınırı yüzünden bildirim garantisi yoktur, ertelenen not en azından ertesi gün ana sayfa önerilerine girer), **Sil** (notu siler, adımlı notlarda sadece o adımı siler, 5 saniye "Geri al" çıkar), **Takvime ekle**. "Uymuyor" seçeneği yok. Arşivdeki notlar geri çıkarılabilir.
- Hafta sonu planı: bildirim **yok**, uygulamada görünen bir alan. Cuma boyunca hafta sonu fikirleri görünür, Cuma 22:00'de Cumartesi planına dönüşür, Cumartesi 22:00'de Pazar planına dönüşür. Plan gün bölümlüdür, saatli değildir. İki bölüm: Öğle (12:00-18:00) ve Akşam (18:00-24:00). Sabah bölümü yok (bu sadece hafta sonu planı için geçerli, hafta içi öneriler kategori saat aralıklarına göre sabah dahil normal devam eder). Uyku saati tanımı bu aralıkları kısaltır. Uyku saatine denk gelse de hazırlanır. Resmi tatil ve izinlerden önceki akşam da hazırlanır. Plan hafta sonu boyunca ana sayfada kalır.
- Tarih hatırlatması: kullanıcı not içinde hatırlatma seçmediyse hatırlatma yoktur. Seçtiyse ne zaman hatırlatılacağını da kendisi seçer. Hazır seçenekler: 5 dk önce, 30 dk önce, 1 saat önce, 1 gün önce, 1 hafta önce, aynı gün sabah 09:00. Serbest tarih/saat de seçilebilir. Günlük 3 öneri sınırına dahil değildir.
- Sessiz saatler: ayrı sessiz mod yok, uyku tanımı ve takvim doluluğu yeter.

## 8. Ekranlar
- Alt menü: Ana sayfa, Takvim, Notlar, Ayarlar. Sesli not butonu alt menünün ortasında, her ekranda görünür.
- Ana sayfa (sade): bugünün takvimi, 2-3 öneri, hafta sonu önerileri/planı, hızlı sesli/yazılı not alanı, "Şu an ne yapabilirim?" butonu, onay bekleyen not uyarısı.
- Notlar: liste görünümü (varsayılan; arama, sıralama) ve klasör görünümü. Arama ikisinde de var. Arşiv, Notlar sekmesinde ayrı bir bölüm.
- Dil: Türkçe. Özel isimler (film, mekan, uygulama adı) çevrilmez.

## 8b. Tema ve görsel (v0.4.22'de yenilendi)
- Yeni görünüm (kullanıcının ChatGPT referansı): krem ve şeftali zemin, zeytin yeşili vurgu ve düğmeler, krem kartlar, açık meşe raf ve 3 boyutlu kitaplar, krem alt menü (yalnızca ikon, seçili ikonun arkasında yeşil daire), ortada yeşil mikrofon. Tüm ekranlarda aynı palet. Gri tema kalktı; açık (krem) varsayılan, koyu tema Ayarlar'da kalıyor.
- Ana sayfa arka planı gün boyu üç ton: sarı-yeşil, şeftali, mor (şimdilik kodla renk geçişi, saatler 06-16 / 16-19 / 19-06; kullanıcı saatleri ve temiz arka plan resimlerini gönderecek, sonra resimle değişecek). Koyu temada hep gece tonu. Diğer ekranlar sade zemin.
- Karşılama: tek satır, saate göre samimi selam (sabah 05-11, öğle 11-15, akşamüstü 15-18, akşam 18-22, gece 22-05); her açılışta farklı, art arda aynısı yok; "Tam da aklımdaydın." imza selamı 4-6 açılışta bir (rastgele).
- Fikir kutusu: tek tek Kopyala ve Hepsini kopyala (GitHub gönderimi kaldırıldı).

### Öneriler ve bildirimler (v0.4.2x)
- Yapay zeka (Haiku) gün bölümü başında (sabah/öğle/akşam) ve uygulama açılınca öneri paketi hazırlar; paket telefonda saklanır. Ana sayfada en çok 3 öneri kartı: Yaptım (adımlı notta sıradaki adımı tamamlar, değilse "tamamen mi / bugünlük mü" sorar), Sonra hatırlat (yarına), Takvime ekle, Sil (adımlı notta sıradaki adım, geri al ile).
- Bildirimler pakettendir, günde en fazla N (Ayarlar, varsayılan 3), bildirim anında yapay zeka çağrılmaz. Dokununca not açılır. Ayarlar'da "Bildirimi dene" ve pil uyarısı vardır.
- "Şu an ne yapabilirim?": süre seçilir (15 dk, 30 dk, 1 saat, bütün akşam), yapay zekasız yerel öneri (iş notları yalnızca iş bloğundayken).
- Hafta sonu planı: Cuma "hafta sonu fikirleri", Cuma 22:00'den Cumartesi planı, Cumartesi 22:00'den Pazar planı; öğle ve akşam bölümleri; bildirimsiz.
- Not tarih hatırlatması: nottaki "Hatırlat" ile hazır seçenekler (5 dk, 30 dk, 1 saat, 1 gün, 1 hafta önce, aynı gün 09:00) ya da serbest zaman; günlük sınıra dahil değil.
- Henüz yok: kategori başına saat aralığı ayarı (zamanlama şimdilik yapay zekaya takvim, uyku ve iş bloğu bilgisiyle bırakıldı), öğrenme sinyali olarak "bildirime dokunulmadı" sayımı (şimdilik yalnızca erteleme sayısı kullanılıyor).

### Kütüphane ve liste (v0.4.17)
- Ana sayfa: sahne arkada kalır, ortada kütüphane: her ana kategori bir kitap (renk ve ikon kategoriden; alt kategoriler üst kitabın içinde). Kitaba dokununca içindeki notlar açılır, orada "Liste ekle / Not ekle". Kategorisiz notlar rafta eğik post-it kâğıtlar (en yeni 8, "Tümü" ile hepsi). Kartlar (yaptın mı, onay bekleyen vb.) kütüphanenin altında. Alt menüde yalnızca ikon.
- Liste: not türünün bir şekli (`tur = liste`), maddeler `adimlar` tablosunda. Maddeler tek tek eklenir, işaretlenince üstü çizilir, hepsi bitince liste kendiliğinden tamamlanmaz. Tarihten bağımsız. Oluştururken "Yapay zeka düzenlesin" sorulur (varsayılan kapalı). Sesle madde eklenince metin yapay zekayla maddelere bölünür (hemen çalışır; anahtar yoksa tek madde).
- Yapay zeka: Ayarlar'da genel anahtar; kapalıyken yeni notlar `ai_disi` olur, kartta küçük "Yapay zekaya gönder" bağlantısı vardır. Not detayında da açılıp kapatılabilir.
- Takvim: kategorisi olan etkinlik kategori rengini (arka plan gibi) ve ikonunu gösterir. Kategori rengi/ikonu Ayarlar > Kategorileri düzenle'den seçilir.
- Fikir kutusu (Ayarlar): fikirler telefonda tutulur, "Gönder" hazır doldurulmuş GitHub "yeni konu" sayfasını açar (faykurt/deneme issues). Claude oradan okur.
- Sonra: hatırlatma bildirimleri ve sesli komutla kategori/hatırlatma (5. aşama ile).

## 8c. Ayarlar ve ilk kurulum
- İlk açılışta kısa bir kurulum sihirbazı: API anahtarı, takvim seçimi, uyku saatleri, iş bloğu kelimesi, kategoriler, izinler.
- Ev ve iş yeri konumu girişi (konum tetikleme) ilk sürümde yok.
- Başlangıç kategorilerini uygulama önerir, kullanıcı onaylar/düzenler.
- Uyku saatleri, iş bloğu kelimesi, kategori başı öneri saat aralıkları, izin günleri, günlük bildirim sınırı, API anahtarı Ayarlar'dadır.

## 9. Yapay zeka ve teknik
- Anthropic API: basit (kısa, yazılı) notlar **Claude Haiku 5.5** (`claude-haiku-5-5`) ile, fotoğraflı ya da 600 karakterden uzun notlar **Claude Sonnet 5.5** (`claude-sonnet-5-5`) ile işlenir. Efor **düşük**. Model ve efor ayarı arayüzde yok (sabit).
- İşleme saatleri: günde 13:00 ve 21:00 (Ayarlar'dan değiştirilebilir). Saat geçtikten sonra uygulama açılınca (ya da açıkken aralıklarla yoklanınca) o saate kadar kaydedilen notlar işlenir. Saatten sonra kaydedilenler bir sonraki saati bekler. "Şimdi işle" ve notta "Şimdi analiz et" ile hemen işletilebilir.
- Harcama sayacı Ayarlar'da: bu ayki tahmini maliyet, API'nin bildirdiği token sayılarından hesaplanır.
- Yapay zeka şunları yapar: kategori, başlık, süre tahmini, adım çıkarma, tarih tanıma, görsel okuma, günlük öneri ve hafta sonu planı, birden fazla fikri ayırma.
- Ücretli, kullandığın kadar öde, Claude üyeliğinden ayrı. Kullanıcı bunu kabul etti.
- API anahtarı koda/APK'ya gömülmez, Ayarlar'dan bir kere girilir, telefonda saklanır.
- Gizlilik kısıtı yok, iş dahil tüm notlar yapay zekaya gidebilir.
- Ses tanıma: Android'in kendi özelliği (API ücreti yok).
- İnternet yokken not kaydedilir, işleme bağlantı gelince yapılır. API anahtarı hatalıysa ya da kredi biterse notlar yine kaydedilir, uygulama uyarı gösterir, işler kredi gelince tamamlanır.

## 10. Adı ve ikon
- Ad: **Aklımda**
- İkon: piksel art tarzında düşünce balonu, sıcak turuncu zemin, içinde küçük bir ampul.

## 11. Açık sorular
Yok. Tasarım kararları tamamlandı. Kod yazımı kullanıcı "yap" diyene kadar başlamaz.

## 12. Sürüm planı ve geliştirme fikirleri
Benzer uygulamalardan gelen öneriler. Sürüm planı kullanıcı tarafından onaylandı.

**İlk sürüm (v1)** ekleri:
- "Şu an ne yapabilirim?" butonu (Ö1): ana sayfada ne kadar vaktin olduğu seçilir (örn. 15 dk, 1 saat, bütün akşam), uygulama o süreye uyan 2-3 şey gösterir. Metin değiştirilebilir.
- Eski notları yoklama (Ö2): 2-3 aydır dokunulmamış notlar için hafta sonu planında "Hâlâ ilgileniyor musun?" sorulur. Ayrıca Notlar sekmesinde "Uzun zamandır dokunulmayanlar" bölümü olur, kullanıcı oradan bakıp silebilir.
- Yedek (Ö5): tek dokunuşla tüm notlar bir dosyaya kaydedilir (Drive'a ya da telefona).

Sonraki sürümler:
- Esnek plan (Ö6): takvime yazılan bir öneri yeni bir etkinlikle çakışırsa uygulama başka bir boş saat önerir.
- Büyüyen sahne (Ö7): işler bittikçe sahne iyileşir ve değişir (2. sürüm, etkileşimli sahneyle birlikte).
- Enerji etiketi (Ö8): işler "yorgunken yapılabilir" ya da "odak ister" diye etiketlenir.
- Doğal dille arama (Ö9): "bu film neydi", "bu tarif neydi" gibi sorular sorulur.
- Dizi/film bilgisi (Ö4): afiş, süre, hangi platformda olduğu. Geliştirme fikri olarak tutuluyor.

Kaldırılan: "Kim önerdi?" alanı (Ö3).
Eklenmeyecek: 2 dakika kuralı (Ö10). Kullanırken eksik hissedilirse sonra değerlendirilir.

## 13. Geliştirme aşamaları (onaylandı)
1. **İskelet:** GitHub Actions ile APK derleme, imza, telefona kurulum, ikon. *(tamam)*
2. **Not alma:** yazılı, sesli, fotoğraf (kamera dahil), paylaş menüsü, widget, notlar ekranı (klasör/liste, arama, arşiv), yedek. *(tamam)*
3. **Yapay zeka:** kategori, başlık, süre, tarih, adımlar, birden fazla fikri ayırma, onay penceresi. Bu aşamadan önce kullanıcı Anthropic konsolunda hesap açıp kredi yükler ve API anahtarı oluşturur. *(tamam)*
4. **Takvim.** *(tamam; ay görünümü Samsung düzeninde, tam sayfa)*
5. **Öneriler:** *(sıradaki)* bildirimler, hafta sonu planı, "Şu an ne yapabilirim?".
6. **Görünüm:** piksel art arka plan ve son cila (sıcak renkler baştan kullanılır).

Her aşama sonunda kullanıcı telefonda dener. Kullanıcı "yap" demeden bir sonraki aşamaya geçilmez.
