# Aklımda — Devam Notları (geliştirici için)

Bu belge, oturum bağlamı sıkıştırılsa ya da yeni bir oturum açılsa da işe kaldığı yerden devam edilebilsin diye yazıldı.
Tasarım kararları `KARARLAR.md`'de, ertelenenler `TODO.md`'de. Bu belge **teknik durum ve çalışma şekli** içindir.

## 1. Kullanıcı ve çalışma şekli
- Kullanıcı yazılım bilmiyor, Türkçe konuşuyor. **Elinden gelen her şeyi sen yap**, ondan en az eylem iste. Adım adım, kısa ve açık anlat.
- Kural: kullanıcı onaylamadan kod yazma/çalıştırma yok ("yap" der). Her aşamada kullanıcı onayladıktan sonra o aşama yapılır. Tahmin yapma, boşluk varsa sor. Eski karar: "yap" denmeden hiçbir şey yapılmaz; aşama başında genel onay verildiyse o aşamanın içindeki işler yapılabilir.
- Kullanıcı kısa cevap verir ("onaylıyorum", "olabilir"); belirsiz bir şey varsa tek tek, numaralı sor.
- Uygulama telefondan (Samsung A52, Android 14) güncellenir: kullanıcı APK bağlantısına dokunur, "Güncelle" der. Her yeni sürümde **yeni bağlantıyı sen ver** (sürüm numarası 0.4.N, N = derleme numarası).
- Kullanıcı API anahtarını sohbete yazmamalı (Ayarlar'a kendisi girer). Gizli bilgileri (anahtar, keystore şifresi) depoya yazma.

## 2. Depo ve yayın hattı
- Depo: `faykurt/deneme` (public). Geliştirme dalı: `claude/nice-newton-osqq0d`. Sadece bu dala push edilir.
- `.github/workflows/build.yml`: push'ta çalışır (md dosyaları hariç). Sırayla: `flutter pub get`, `flutter analyze`, `flutter test`, imza anahtarını çöz, `flutter build apk --release` (geçici hatalarda 3 kez dener), Release yayınlar (`v0.4.N`, dosya `Aklimda-0.4.N.apk`).
- İndirme bağlantısı kalıbı: `https://github.com/faykurt/deneme/releases/download/v0.4.N/Aklimda-0.4.N.apk`
- İmza: `android/app/upload-keystore.p12.enc` (AES-256-CBC, pbkdf2, 200000 tur) depoda şifreli. Şifre GitHub Secret `KEYSTORE_PASSWORD` (kullanıcı ekledi, 24 karakter). Alias `aklimda`. Çözülmüş `.p12` asla commit edilmez (`.gitignore`'da). Aynı anahtar sayesinde güncellemeler veriyi silmez.
- Sürüm öneki `VERSION_PREFIX` workflow dosyasında (şu an `0.4`). Yeni büyük aşamada 0.5 yapılabilir.
- Derleme ortamı notları (çözülmüş sorunlar): `compileSdk = 37` (receive_sharing_intent istiyor), Java 21 (lint), Maven 429'larına karşı yeniden deneme. Flutter 3.50.1 (kararlı), Dart 3.14.
- Önemli: Material bileşenleri artık `package:flutter/material.dart` değil **`package:material_ui/material_ui.dart`**; yerelleştirme `GlobalMaterialLocalizations` da oradan (flutter_localizations'tan sadece `GlobalWidgetsLocalizations`).

## 3. Yerel (bu konteyner) çalışma ortamı
- Android SDK indirilemiyor (dl.google.com engelli) → APK sadece GitHub Actions'ta üretilir. Burada sadece `flutter analyze` ve `flutter test` çalışır.
- Flutter SDK scratchpad'e indirilmişti (geçici, konteyner sıfırlanırsa kaybolur). Yeniden kurmak için:
  `curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.50.1-stable.tar.xz`, aç, `git config --global --add safe.directory '*'`, `flutter/bin` PATH'e. (pub.dev ve storage.googleapis.com erişilebilir.)
- `flutter test` yaklaşık 15 sn sürer (104 test, hepsi geçiyordu). Tek bir çağrı 120 sn'yi aşarsa arka plana atılır; `timeout 115 flutter test --timeout 60s` kullan.
- Test altyapısı: gerçek SQLite (`sqflite_common_ffi`), sahte takvim (`test/sahte_takvim.dart`), sahte HTTP (`MockClient`), `SharedPreferences.setMockInitialValues`, `FlutterSecureStorage.setMockInitialValues`.
- Widget testi tuzakları: veritabanı (sqflite ffi) çağrıları sahte zamanda bitmez → `tester.runAsync` ya da `bekle`/`bekleKadar` yardımcılarıyla parça parça bekle. `runAsync` içinde tekrar `runAsync` çağrılamaz. Test yazı tipi (Ahem) metni geniş çizer; taşma testleri bunu abartır ama düzgün esnek yapı yine de gerekir. Ekran görüntüsü almak için gerçek yazı tipi (`bin/cache/artifacts/material_fonts/Roboto-*.ttf`) `setUpAll`'da `FontLoader` ile yüklenip `matchesGoldenFile --update-goldens` kullanılabilir (geçici test, commit etme).
- GitHub araçları (`mcp__github__*`) ertelenmiş araçtır: `ToolSearch select:mcp__github__actions_list,mcp__github__get_job_logs,mcp__github__get_latest_release` ile yükle. Derleme kontrolü: `actions_list list_workflow_runs` → başarısızsa `get_job_logs failed_only=true`. Derleme ~6-8 dk sürer; `send_later` ile 9 dk sonrasına kontrol kur, bitince kullanıcıya bağlantıyı ver.

## 4. Mimari (lib/)
- `main.dart`: başlatma (Depo, AiAyarlar, AiZamanlama, AiHarcama, TakvimAyarlari), tema (sıcak turuncu/krem), Türkçe.
- `ortak.dart`: `Renk`, `navigatorKey`, `sekmeSecici` (alt menü), `mesajGoster` (yüzen SnackBar), `silVeGeriAlGoster` (takvim bağlı not için "etkinlik de silinsin mi?"), `arsivleVeGeriAlGoster`, `NotKarti`.
- `veri/`: `modeller.dart` (Not, Adim, Kategori, KategoriAgaci, Durum, Kaynak), `depo.dart` (SQLite, **şema sürümü 3**; v1→2: ai_json, adım bekleme, eski notlar onaylı; v2→3: takvim_baslangic/bitis, yaptin_cevap). Singleton `Depo.instance`, `ChangeNotifier`.
- `ai/`: `ai_servisi.dart` (Anthropic Messages API, ham HTTP, `anthropic-version: 2026-10-21`, JSON şema çıktısı, hata türleri, kullanım dinleyicisi), `isleyici.dart` (notları sırayla işler; `zamanlanmisIsle`, `bekleyenleriIsle`, `hemenIsle`, `bol`), `ai_zamanlama.dart` (günde 13:00 ve 21:00), `ai_harcama.dart` (aylık tahmini maliyet), `ai_ayarlar.dart` (anahtar, `flutter_secure_storage`), `ai_modeller.dart`.
  - Model seçimi: kısa yazılı not → `claude-haiku-5-5` (fallbacks yok), fotoğraflı ya da >600 karakter → `claude-sonnet-5-5` (+ `fallbacks: "default"` ve `anthropic-beta: server-side-fallback-2026-07-01`; reddedilirse onsuz yeniden dener). Efor `low`. `temperature` vb. gönderilmez. Görsel JPEG'e küçültülür (en fazla 4).
  - Notlar kaydedilince hemen işlenmez; son çalışma saatinden önce kaydedilenler uygulama açılınca/yoklanınca işlenir. İşlenen not "onay bekleyen" olur (`islendi && !onayli`).
- `takvim/`: `takvim_kaynagi.dart` (arayüz + `CihazTakvimi` = `device_calendar_plus` sarmalayıcı), `takvim_deposu.dart` (izin, takvim seçimi, etkinlik yükleme/CRUD, not↔etkinlik bağlama/senkron, boş zaman), `bos_zaman.dart` (uyku, iş bloğu, izin günü kuralları), `takvim_ayarlari.dart` (SharedPreferences: seçili takvim, uyku saatleri, iş kelimesi, izin günleri), `takvim_modeller.dart`.
- `ekranlar/`: `iskelet.dart` (alt menü + ortadaki sesli not butonu, paylaş/widget girişleri, yaşam döngüsü), `ana_sayfa`, `notlar_ekrani` (varsayılan liste), `not_detay` (adımlar, süre, tarih, takvime ekle), `onay_penceresi`/`onay_bekleyenler`, `takvim` (Samsung düzeninde tam sayfa ay, güne dokununca pencere, hafta, gün), `etkinlik_duzenle`, `takvime_ekle`, `yaptin_mi`, `ayarlar`, `sesli_not`, `yazili_not`, `paylasim`.
- Android: `AklimdaWidget.kt` (ana ekran widget'ı: sesli/yazılı not), manifest (paylaş menüsü, mikrofon, takvim izinleri), imza ayarı `build.gradle.kts`, ikon (piksel art düşünce balonu).

## 5. Durum (son sürüm: v0.4.14)
Tamam: 1 (iskelet), 2 (not alma), 3 (yapay zeka), 4 (takvim), yapay zeka maliyet düzenlemesi (Haiku/Sonnet, saatli işleme, harcama sayacı, Notlar varsayılan liste, tam sayfa ay görünümü).
Kullanıcının telefonda doğruladıkları: 1, 2, 3 (anahtar ve yapay zeka çalışıyor), takvim bağlantısı (Samsung takvim görünüyor, ekran düzeni geri bildirimi verdi).
**Telefonda henüz doğrulanmayanlar** (kullanıcıdan geri bildirim bekleniyor): tam sayfa ay görünümü ve güne dokununca pencere, etkinlik ekleme/düzenleme gerçek takvimde, tüm gün "Günü dolu say", notu takvime ekle (kendim/otomatik), uyku saatleri, "yaptın mı", saatli yapay zeka işleme ve harcama sayacı, Haiku/Sonnet ayrımı.
Bilinen riskler: Samsung Takvim'in `accountType` değerleri bilinmiyor (kullanıcı listeden seçiyor); Samsung pil yönetimi arka plan işlerini geciktirebilir; tekrarlı etkinlik düzenleme eklentide bazı kısıtlar fırlatabilir (hata kullanıcıya gösteriliyor).

## 6. Sıradaki: 5. aşama (Öneriler) — plan
Onaylanan tasarım `KARARLAR.md` bölüm 7'de. Özet ve teknik notlar:
- **Öneri paketi:** yapay zeka, gün bölümü başlarında (sabah 06, öğle 11, akşam 17; hafta sonu planı için ayrı saatler) ve uygulama açılınca, notların (başlık, kategori, süre, tarih, bekleme süresi, durum, erteleme sayıları) ve takvimdeki boş zamanların özetiyle bir paket üretir (bildirim önerileri + ana sayfa önerileri). Bildirimler **yerelde** bu paketten zamanlanır (internet yoksa son paket). Bildirim anında API çağrılmaz. Maliyet için Haiku düşünülmeli (kısa JSON girdi/çıktı); öneri kalitesi için Sonnet gerekirse kullanıcıya sor.
- **Bildirim:** günde en fazla 3 (Ayarlar'da değişebilir), "Sonra hatırlat"la ertelenenler bu 3'e dahil, aksiyon butonu yok, metin kısa neden içerir, dokununca uygulama o öneriyle açılır. Gerekli: `flutter_local_notifications` (+ zamanlama için `timezone`), Android 13 `POST_NOTIFICATIONS` izni, gerekirse tam zamanlı alarm izni; Samsung pil ayarını kullanıcıya "Sınırsız" yaptırmak gerekebilir.
- **Kurallar:** iş notları sadece takvimdeki iş bloğunda ve hafta içinde; "Yapılıyor" durumundaki notlar önerilmez; uyku saatlerinde ve takvimde dolu zamanlarda öneri yok; kategori başına saat aralıkları (uygulama önerir, kullanıcı düzenler — kurulum sihirbazı ya da Ayarlar); öğrenme sinyali: 3 kez ertelenen ve bildirime hiç dokunulmayan türler seyrekleşir.
- **Ekranlar:** ana sayfada 2-3 öneri kartı (Yaptım / Sonra hatırlat (ertesi gün) / Sil (5 sn geri al) / Takvime ekle), "Şu an ne yapabilirim?" butonu (süre seç → uygun 2-3 şey), hafta sonu planı (Cuma 22:00'de Cumartesi, Cumartesi 22:00'de Pazar için; öğle 12-18, akşam 18-24; gün bölümlü, bildirimsiz), "Onay bekleyenler" önerilere girer.
- **Not hatırlatmaları:** nottaki tarih için kullanıcı hazır seçenek (5 dk, 30 dk, 1 saat, 1 gün, 1 hafta önce, aynı gün 09:00) ya da serbest zaman seçer; günlük 3 sınıra dahil değil. Durum "Bekliyor" seçilince hatırlatma süresi sorulur.
- Çalışma saatlerini (13:00/21:00) yapay zeka işlemesiyle öneri üretimi arasında çakıştırma; ikisi de aynı uygulama açılışı mantığıyla yoklanabilir.
- Sonraki: 6. aşama görünüm (piksel art ana sayfa arka planı, sabah/öğle/akşam ışık varyantı; saatler 06-11, 11-17, 17-06; diğer ekranlar sade). Ayrıntılar `KARARLAR.md` 8b ve `TODO.md`.

## 7. Küçük hatırlatmalar
- Kullanıcının İlk sürüm ekleri: "Şu an ne yapabilirim?", eski notları yoklama ve "Uzun zamandır dokunulmayanlar" bölümü `TODO.md`'de ertelenenler arasında olabilir; `KARARLAR.md` bölüm 12 ve `TODO.md` ile birlikte kontrol et.
- Yapay zeka maliyeti: kullanıcının konsolda $5 kredisi var, otomatik yükleme kapalı. Harcama sayacı Ayarlar'da. Gerçek maliyeti kullanıcıdan "Spend this month" rakamıyla doğrula.
- Eski kararlardan değişenler: Notlar varsayılan **liste**; not kaydedilince onay penceresi **açılmaz** (sadece "Kaydedildi" + "Şimdi analiz et"); ay görünümü tam sayfa; yapay zeka saatli çalışır; model otomatik seçilir (Ayarlar'da model/efor seçeneği yok).

## Güncelleme: Görünüm (v0.4.15)
- `Renk` (lib/ortak.dart) artık sabit değil, tema duyarlı getter'lar: `vurgu`, `vurguUstu`, `zemin`, `kart`, `yazi`, `hata`, `sinir`, `vurguKart()`. Eski adlar (turuncu/krem/kahve/acikKrem) kalktı. `const` ile kullanılamaz.
- `lib/tema.dart`: `TemaAyari` (koyu varsayılan, shared_preferences `tema_koyu`); değişince tüm element ağacı `markNeedsBuild` ile yenilenir.
- `lib/ekranlar/piksel_sahne.dart`: `SahneBolumu` + `PikselSahne` (CustomPainter, 36 sütunluk ızgara).
