# Aklımda — Tasarım Kararları

Durum: **Tasarım aşaması. Kod yazımına başlanmadı.** Kod yalnızca kullanıcı açıkça "yap" dediğinde yazılır.
Çalışma kuralları: (1) "yap" denmeden hiçbir şey yapılmaz, (2) tahmin yapılmaz, boşluklar sorularak doldurulur.

## 1. Amaç
Günlük hayat, tez ve iş yerindeki işler, mini projeler, dekorasyon fikirleri, önerilen dizi/film vb. unutulup gitmesin. Uygulama, kullanıcı listeye bakmadan, doğru zamanda ve kolayca (seamless) hatırlatsın. Yalnızca kişisel kullanım (mağazaya konmayacak).

## 2. Platform ve dağıtım
- Flutter, sadece Android. Cihaz: Samsung A52, Android 14. Tek cihaz.
- Karar: GitHub Actions ile APK derlenir. Kod GitHub'a pushlanır, GitHub APK'yı derleyip Release olarak yayınlar, telefona APK ile kurulur. Güncelleme için Obtainium önerildi. Aynı imza anahtarı kullanılacak ki güncelleme veriyi silmesin.
- Tüm süreç (ilk kurulum dahil) telefondan yürütülecek, bilgisayar kullanılmayacak. Kullanıcı her güncellemeyi telefondan Claude'a anlatır.
- Depo `faykurt/deneme` şu an **public**. Private mı public mı kalacağı yeniden konuşulacak (kullanıcı "private'ı öylesine söylemiştim" dedi). İmza anahtarı depoya konmaz, GitHub Secrets'a eklenir (telefon tarayıcısından, masaüstü site modunda).
- Veri ilk aşamada sadece telefonda (yedek sonradan eklenebilir).
- Kurulum notları: Samsung pil ayarı "Sınırsız" yapılmalı. Gerekli izinler: bildirim, mikrofon, takvim, konum ("her zaman"), bilinmeyen kaynaklardan kurulum. Samsung Otomatik Engelleyici (Auto Blocker) kapatılmalı, Play Protect uyarısına "Yine de yükle" denmeli.

## 3. Not alma
- Not türleri: metin, link, fotoğraf/ekran görüntüsü.
- Link: sayfa başlığı ve önizleme alınmaya çalışılır, alınamazsa olduğu gibi kalır.
- Fotoğraf: kopyası notta saklanır, bir notta birden fazla olabilir. Uygulama içinden kamerayla çekip not oluşturulabilir.
- Sesli not: tek dokunuşla başlar, kullanıcı "Bitir"e basana kadar devam eder, Android ses tanıma ile Türkçe metne çevrilir, ses dosyası saklanmaz. İnternetsiz çalışma: önce çevrimdışı Türkçe ses paketi denenir (A), olmazsa internet yokken "yazılı not al" uyarısı verilir (B).
- Ana ekranda iki widget butonu: sesli not ve yazılı not. Sesli not widget'ı doğrudan kayıt ekranını açar. Yazılı not widget'ı açılınca klavye hazır gelir.
- Android paylaş menüsünde "Aklımda" ikonu görünür (ekran görüntüsü sonrası paylaş dahil). Tıklayınca içerik doğrudan kaydedilir. Paylaşırken isteğe bağlı kısa yorum ve sesli not eklenebilir. Galeri otomatik taranmaz.
- Uzun sesli notlara yapay zeka kısa bir başlık verir. Özel isimlere (İngilizce film/dizi adları vb.) yapay zeka dokunmaz. Not: ses tanımanın kendisi bu isimleri bozabilir, bunu uygulama engelleyemez, kullanıcı notta düzeltir.
- Tek kayıtta birden fazla fikir söylenirse yapay zeka bunları ayrı notlar olarak önerir.
- Her nota yapay zeka düzenlenebilir bir süre tahmini koyar.
- Kategoriye özel alanlar olabilir ama doldurmak zorunlu değildir. Örnek: Dizi/Film için ad, tür, kim önerdi. Yemek→Tarif için malzemeler, yapılış. (Diğer kategoriler açık soru.)
- Not içindeki tarih tanınır, takvime ekleme önerisi sunulur. Saatsiz tarihlerde hatırlatma 09:00'da verilir, saatsiz notlarda "5 dk önce" gibi seçenekler gizlenir.
- Tekrarlayan notlar olabilir, tekrar aralığını kullanıcı seçer.
- Onay penceresi: sesli not bitince otomatik doldurulmuş bir pencere açılır (kategori, tarih vb.). Direkt onaylanabilir ya da değiştirilebilir. Her şey sonra notun içinden düzenlenebilir. (Paylaş, yazılı not ve internetsiz durum için akış açık soru.)
- Bilinen kısıt: Instagram paylaşımı çoğunlukla link verir ve içeriği okunamayabilir, ekran görüntüsü daha güvenilir.

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
- Bir adım bitince sıradaki adım hemen gösterilir.
- Durumlar: yapılıyor, yapıldı, bekliyor gibi (tam liste ve kurallar açık soru). Bekliyor durumu seçilince pencere açılır, "hatırlatma ister misin" diye sorar, süre oradan seçilir.
- Devam eden işler için ek aşamalar eklenebilir (örn. dizi, kitap, tez bölümü).

## 6. Takvim
- Samsung Takvim'e bağlanır (telefonun takvim deposu üzerinden), iki yönlü okuma/yazma. Sadece Samsung takvimi sayılır.
- Uygulamada ay görünümü varsayılan. Gün ve hafta görünümü seçilebilir.
- Etkinlik alanları: başlık, başlangıç ve bitiş saati, tekrar (günlük, haftalık, aylık, yıllık, hafta içi her gün, bitiş tarihi seçilebilir). Tüm gün etkinlik eklenebilir, o gün tamamen dolu sayılır.
- Uygulamadan mevcut etkinlikler düzenlenebilir ve silinebilir.
- Uygulamanın yazdığı etkinliklerin başında küçük bir işaret (💭) olur. Takvime bağlı bir not silinirse etkinliği de silmek isteyip istemediği sorulur. Tarihi olan ama takvime eklenmemiş notlar farklı görünümle gösterilir.
- "Takvime ekle": öneri kartında, not kartında bir seçenek olarak bulunur. Tıklayınca takvim açılır, kullanıcı notu istediği yere yerleştirir. Ayrıca takvimde bir zaman aralığı seçilip ona not bağlanabilir.
- Uyku ve mesai saatleri kullanıcı tarafından tanımlanır, hafta içi ve hafta sonu ayrı. Mesai içinde "öğle arası" tanımlanabilir (kısa öneriler orada gelebilir). Bunların dışı "boş" sayılır.
- İzin günleri hafta sonu gibi sayılır. Türkiye resmi tatilleri otomatik alınır, kişisel izinleri kullanıcı tanımlar. Arife günlerinde öğleden sonrası tatil sayılır.
- Samsung Hatırlatıcı (Reminder) kapsam dışı.

## 7. Öneri ve hatırlatma
- Öneriyi **yapay zeka** seçer (kural tabanlı değil, çünkü kurallar hep aynı sonucu verir). Günlük öneriler ve hafta sonu planı yapay zeka tarafından hazırlanır. (Mekanizmanın ayrıntıları açık soru.)
- Zamanlama karma: kategori başına saat aralıkları (uygulama başta önerir, kullanıcı onaylar/düzenler), uygulama aralık içinde takvimde boş olan en uygun anı seçer.
- Konum: sadece ev ve iş yeri. **İş notları yalnızca iş konumundayken önerilir** (saat bakılmaksızın, hafta sonu işe gidilse bile). Diğer notlar saate göre gelir. Ev ya da iş dışındayken de saat kurallarına uygun öneri gelebilir. Eve varılan anda öneri gelmez, vardıktan yaklaşık yarım saat sonra uygun hale gelir. "Her zaman konum izni" verilecek, kapatılırsa uygulama sadece saate göre çalışır.
- Sıklık: günde en fazla 3 öneri bildirimi, hafta içi ve hafta sonu aynı (Ayarlar'dan değiştirilebilir).
- Bildirimde tek öneri ve kısa bir neden vardır ("20 dk boşsun, 2 haftadır bekliyor"), bildirim üzerinde buton yoktur, dokununca uygulama o öneriyle açılır. Ana sayfada 2-3 öneri gösterilir, gün bölümü (sabah/öğle/akşam) değişince yenilenir.
- Öneri kartı seçenekleri: **Yaptım** (tamamlanmış olarak arşive gider), **Sonra hatırlat** (ertesi gün uygun bir boşlukta), **Sil** (notu siler, 5 saniye "Geri al" çıkar), **Takvime ekle**. "Uymuyor" seçeneği yok. Arşivdeki notlar geri çıkarılabilir.
- Hafta sonu planı: bildirim **yok**, uygulamada görünen bir alan. Cuma boyunca hafta sonu fikirleri görünür, Cuma 22:00'de Cumartesi planına dönüşür, Cumartesi 22:00'de Pazar planına dönüşür. Plan gün bölümlüdür (sabah/öğle/akşam), saatli değildir. Uyku saatine denk gelse de hazırlanır. Resmi tatil ve izinlerden önceki akşam da hazırlanır. Plan hafta sonu boyunca ana sayfada kalır.
- Tarih hatırlatması: kullanıcı not içinde hatırlatma seçmediyse hatırlatma yoktur. Seçtiyse ne zaman hatırlatılacağını da kendisi seçer. Hazır seçenekler: 5 dk önce, 30 dk önce, 1 saat önce, 1 gün önce, 1 hafta önce, aynı gün sabah 09:00. Serbest tarih/saat de seçilebilir. Günlük 3 öneri sınırına dahil değildir.
- Sessiz saatler: ayrı sessiz mod yok, uyku/mesai tanımı ve takvim doluluğu yeter.

## 8. Ekranlar
- Alt menü: Ana sayfa, Takvim, Notlar, Ayarlar. Sesli not butonu alt menünün ortasında, her ekranda görünür.
- Ana sayfa (sade): bugünün takvimi, 2-3 öneri, hafta sonu önerileri/planı, hızlı sesli/yazılı not alanı.
- Notlar: klasör görünümü (varsayılan) ve liste görünümü (arama, sıralama). Arama ikisinde de var. Arşiv, Notlar sekmesinde ayrı bir bölüm.
- Dil: Türkçe. Özel isimler (film, mekan, uygulama adı) çevrilmez.

## 8b. Tema ve görsel (ilk sürüm)
- Açık temayla başlanır. Koyu tema sonraki sürümlere kalır. Butonlar ve kartlar sıcak tonlarda.
- Ana sayfada arka planda piksel art bir görsel olur, kartlar/pencereler onun üzerinde durur. Görselleri Claude kodla hazırlar (basit/sade kalite, sonra hazır görselle değiştirilebilir).
- Tek sahne, 3 ışık varyantı. Saate göre otomatik ve anında değişir (yumuşak geçiş ve ortam sesi sonraya kalır). Konu: doğa temalı, sıcak tonlar.
  - Sabah (06:00-11:00): güneş yeni doğuyor.
  - Öğle (11:00-17:00): güneş tepede.
  - Akşam (17:00-06:00): güneş yok, ortam ışıkları (lamba, ateş vb.) var.
- Diğer ekranlar (Takvim, Notlar, Ayarlar): sade arka plan, ana sayfadaki görseli kullanmaz.
- Etkileşimli sahne, sana benzeyen karakter, animasyonlar (kahve dumanı, ışık huzmesi, sesli not sırasında yazma animasyonu vb.), ambiyans sesi: 2. ve 3. sürümlerde detaylarıyla kararlaştırılacak.

## 8c. Ayarlar ve ilk kurulum
- İlk açılışta kısa bir kurulum sihirbazı: API anahtarı, uyku/mesai saatleri, ev ve iş konumu, kategoriler, izinler.
- Ev ve iş yeri konumları "Şu an buradayım, kaydet" butonuyla girilir (yaklaşık 150 m çevre). Haritadan seçme sonraya kalır.
- Başlangıç kategorilerini uygulama önerir, kullanıcı onaylar/düzenler.
- Uyku/mesai saatleri, kategori başı öneri saat aralıkları, izin günleri, günlük bildirim sınırı, API anahtarı Ayarlar'dadır.

## 9. Yapay zeka ve teknik
- Anthropic API: model **Claude Sonnet 5.5** (`claude-sonnet-5-5`), efor **medium**. (Ayarlardan değiştirilebilirlik açık soru.)
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
- Öğrenme sinyali ("Uymuyor" seçeneği olmadığı için reddedilenler nasıl anlaşılacak).
- Görmezden gelinen bildirim.
- "Takvime ekle"de uygun saatlerin vurgulanıp vurgulanmayacağı.
- Paylaş, yazılı not ve internetsiz durumda onay akışı ("Onay bekleyenler" alanı).
- Durumların tam listesi ve devam eden işlerde "Yaptım".
- Adımların sırası ve bekleme adımını kimin ekleyeceği.
- İş notlarının konumdayken saat kuralı, işe varışta gecikme.
- Hafta sonu planındaki gün bölümlerinin saatleri.
- Kategoriye özel alanlar (diğer kategoriler), tekrarlayan notta "Yaptım".
- Widget'a ek kısayollar (hızlı ayar kutucuğu, uygulama kısayolları).
- Tüm gün etkinliklerin doluluk sayılması, "Sonra hatırlat"ın günlük 3 sınırına dahil olup olmadığı.
- Yapay zekanın öneri üretme mekanizması (öneri paketi), model ayarı.
- Depo public mi private mı, Obtainium.

## 12. Sonra konuşulacak
Benzer uygulamalardan öneriler (Claude tekrar sunacak): "Şu an boşum" butonu, eski notları yoklama, "kim önerdi" alanı, dizi/film bilgisi, yedek, esnek plan, büyüyen sahne, enerji etiketi, doğal dille arama, 2 dakika kuralı.
