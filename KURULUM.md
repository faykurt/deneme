# Kurulum ve canlıya alma

Site tamamen statik (HTML/CSS/JS). Sunucu gerekmez.

## 1. Ayarları doldurun — `config.js`
- `whatsappNumber`: örn. `905551112233`
- Fiyatlar (`products[].price`) **taslaktır**, gerçek fiyatlarla değiştirin.
- Marka/ürün adlarını hukuk danışmanınızla netleştirin.

## 2. Talepleri Google Sheets'e düşürün (ücretsiz)
1. Yeni bir Google Sheet açın.
2. **Uzantılar → Apps Script** → `apps-script.gs` içeriğini yapıştırın.
3. İsterseniz `NOTIFY_EMAIL` alanına e-postanızı yazın (yeni talepte bildirim).
4. **Dağıt → Yeni dağıtım → Web uygulaması**; *Yürüt:* Ben, *Erişim:* Herkes. URL'yi kopyalayın.
5. URL'yi `config.js` içindeki `endpoint` alanına yapıştırın.

Sheet'te iki sekme oluşur: **Talepler** (kişiler) ve **Olaylar** (huni verisi).

## 3. Analitik
Sitede çerez, GA4 veya Clarity yoktur; çerez onay bandı da bu yüzden yoktur. Olaylar yalnızca kendi Google Sheet'inize anonim olarak yazılır. Her sayfa yüklemesi için bellekte rastgele bir kimlik üretilir, tarayıcıda saklanmaz. Aynı kişi siteye ikinci kez gelirse yeni ziyaretçi sayılır.
GA4 veya Clarity eklemek isterseniz çerez onay bandı da eklenmelidir.

## 4. Ölçülen olaylar (huni)
`page_view` → `price_seen` (kart ekranda görüldü) → `cta_click` → `form_open` → `form_start` → `form_submit`
Ayrıca: `form_abandon`, `form_error`, `price_feedback`, `faq_open`.

Sheet'te "Olaylar" sekmesinden benzersiz `Ziyaretçi ID` sayısını her aşama için sayarak huniyi çıkarabilirsiniz.

## 5. Canlıya alma (öneri: Cloudflare Pages, Netlify veya GitHub Pages — hepsi ücretsiz)
- **Netlify/Cloudflare Pages:** repoyu bağlayın, build komutu boş, yayın klasörü `/` (kök).
- Alan adını (`.com`) satın alıp hosting panelinden bağlayın.

## 6. Yayından önce kontrol listesi
- [ ] KVKK metnindeki `[...]` alanlarını doldurup hukukçuya onaylatın.
- [ ] WhatsApp numarasını ve fiyatları girin.
- [ ] `endpoint` ile bir deneme talebi gönderip Sheet'e düştüğünü doğrulayın.
- [ ] "Bayley" marka kullanımı ve 3D baskı ürünlerin hukuki durumu için avukat görüşü alın.
- [ ] Pearson görsellerini kullanmayın; kendi fotoğraflarınızı ekleyin.

## Test modu
`endpoint` boşsa hiçbir şey kaydedilmez, veriler yalnızca tarayıcı konsoluna yazılır.
