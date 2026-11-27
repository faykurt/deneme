// kurulum.html dosyasını timesheet-doldur.js'den üretir:  node build.js
const fs = require('fs');
const kod = fs.readFileSync(__dirname + '/timesheet-doldur.js', 'utf8');
const bm = 'javascript:' + encodeURIComponent(kod);
const esc = s => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
const html = `<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><title>Timesheet Doldur - Kurulum</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;max-width:820px;margin:30px auto;padding:0 16px;line-height:1.5;color:#222;background:#fff}
h1{color:#005f87}.btn{display:inline-block;padding:10px 18px;background:#005f87;color:#fff;border-radius:6px;text-decoration:none;font-weight:bold}
textarea{width:100%;height:110px;font-family:Consolas,monospace;font-size:11px}
.not{background:#fff4ce;border-left:4px solid #f0b400;padding:8px 12px}code{background:#eee;padding:1px 4px}
</style></head><body>
<h1>Teamcenter Timesheet Otomatik Doldurma</h1>

<h2>Yöntem 1: Favori butonu (önerilen)</h2>
<ol>
<li>Edge'de favoriler çubuğu görünmüyorsa <b>Ctrl+Shift+B</b> ile açın.</li>
<li>Aşağıdaki mavi butonu fareyle tutup <b>favoriler çubuğuna sürükleyin</b>.<br><br>
<a class="btn" href="${esc(bm)}">TC Timesheet Doldur</a><br><br></li>
<li>Sürükleme çalışmazsa: favoriler çubuğuna sağ tıklayın, <b>Favori ekle</b>'yi seçin. Ad olarak <code>TC Timesheet Doldur</code> yazın. URL kutusuna aşağıdaki metnin tamamını yapıştırın (<b>Kopyala</b> butonunu kullanabilirsiniz).<br>
<textarea id="bm" readonly>${esc(bm)}</textarea><br>
<button onclick="var t=document.getElementById('bm');t.select();document.execCommand('copy');this.textContent='Kopyalandı ✓'">Kopyala</button></li>
</ol>

<h2>Kullanım</h2>
<ol>
<li>Teamcenter'da <b>Timesheet Entry</b> panelini açın. "Add Entry" butonu görünür olmalı ve doğru görev seçili olmalı.</li>
<li>Favorilerdeki <b>TC Timesheet Doldur</b>'a tıklayın.</li>
<li>Sırasıyla başlangıç tarihini, bitiş tarihini (ör. <code>01.12.2026</code>) ve açıklamayı girin.</li>
<li>Girilecek günlerin listesini kontrol edip <b>Tamam</b>'a basın.</li>
<li>İlk gün eklendikten sonra script durup sorar. Listede kaydın doğru göründüğünü kontrol edip devam edin.</li>
<li>Bitince kayıtları kontrol edip <b>Submit</b>'e kendiniz basın. Script Submit'e <b>asla</b> basmaz.</li>
</ol>
<p class="not">Hafta sonları otomatik atlanır. Resmi tatilleri sonradan elle silebilirsiniz.<br>
Script son kullandığınız açıklamayı hatırlar.<br>
Bir hata olursa script durur ve hangi adımda takıldığını yazar. O ana kadar eklenen kayıtlar listede kalır.</p>

<h2>Yöntem 2: Konsol (favori eklenemezse)</h2>
<p>Teamcenter sayfasında <b>F12</b>'ye basıp <b>Console</b> sekmesine geçin. <code>timesheet-doldur.js</code> dosyasının içeriğini yapıştırıp Enter'a basın. Edge yapıştırmaya izin vermezse önce <code>allow pasting</code> yazın.</p>
</body></html>
`;
fs.writeFileSync(__dirname + '/kurulum.html', html);
console.log('kurulum.html oluşturuldu, bookmarklet uzunluğu:', bm.length);
