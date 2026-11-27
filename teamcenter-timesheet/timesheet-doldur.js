/*
 * Teamcenter Active Workspace - Timesheet Entry otomatik doldurma
 * Başlangıç-bitiş arasındaki tüm hafta içi günlere: açıklama + 08 saat + 00 dk + tarih girer,
 * her gün için SADECE "Add" butonuna basar. "Submit" butonuna ASLA dokunmaz.
 */
(async function () {
  'use strict';

  var AYLAR = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  var SAAT = '08';
  var HAFIZA = 'tcTimesheetSonAciklama';

  if (window.__tcTimesheetCalisiyor) { alert('Script zaten çalışıyor.'); return; }
  window.__tcTimesheetCalisiyor = true;
  try {
    await ana();
  } catch (e) {
    console.error('[Timesheet]', e);
    alert('HATA: ' + e.message + '\n\nİşlem durduruldu. O ana kadar eklenen kayıtlar listede duruyor.');
  } finally {
    window.__tcTimesheetCalisiyor = false;
  }

  async function ana() {
    var bugun = trFormat(new Date());

    var s1 = prompt('Başlangıç tarihi (GG.AA.YYYY):', bugun);
    if (s1 === null) return;
    var bas = tarihCoz(s1);
    if (!bas) throw new Error('Geçersiz başlangıç tarihi: ' + s1);

    var s2 = prompt('Bitiş tarihi (GG.AA.YYYY):', trFormat(bas));
    if (s2 === null) return;
    var bit = tarihCoz(s2);
    if (!bit) throw new Error('Geçersiz bitiş tarihi: ' + s2);
    if (bit < bas) throw new Error('Bitiş tarihi başlangıçtan önce olamaz.');

    var son = '';
    try { son = localStorage.getItem(HAFIZA) || ''; } catch (e) {}
    var acik = prompt('Açıklama (yapıştırın):', son);
    if (acik === null) return;
    acik = acik.trim();
    if (!acik) throw new Error('Açıklama boş olamaz.');
    try { localStorage.setItem(HAFIZA, acik); } catch (e) {}

    var gunler = [];
    for (var d = new Date(bas); d <= bit; d.setDate(d.getDate() + 1)) {
      if (d.getDay() !== 0 && d.getDay() !== 6) gunler.push(new Date(d));
    }
    if (!gunler.length) { alert('Bu aralıkta hafta içi gün yok.'); return; }

    var onay = confirm(
      gunler.length + ' hafta içi gün girilecek:\n\n' +
      gunler.map(tcFormat).join(', ') +
      '\n\nAçıklama: ' + acik +
      '\nSüre: ' + SAAT + ' saat 00 dakika' +
      '\n\nSadece "Add" yapılacak, Submit YAPILMAYACAK.\nDevam edilsin mi?');
    if (!onay) return;

    for (var i = 0; i < gunler.length; i++) {
      var t = tcFormat(gunler[i]);
      console.log('[Timesheet] ' + (i + 1) + '/' + gunler.length + ' giriliyor: ' + t);
      await kayitEkle(acik, t);
      console.log('[Timesheet] Eklendi: ' + t);
      if (i === 0 && gunler.length > 1) {
        if (!confirm('İlk kayıt eklendi (' + t + ').\nListede doğru göründüğünü kontrol edin.\n\nKalan ' +
                     (gunler.length - 1) + ' gün için devam edilsin mi?')) {
          alert('Durduruldu. 1 kayıt eklendi.');
          return;
        }
      }
    }
    alert('Bitti. ' + gunler.length + ' kayıt eklendi.\nKontrol edip Submit\'e kendiniz basın.');
  }

  /* ---------- Tek bir kayıt ---------- */
  async function kayitEkle(aciklama, tarih) {
    if (!gorunur(tarihAlani())) {
      var addEntry = await bekle(function () { return butonBul('Add Entry'); }, 15000, '"Add Entry" butonu');
      tikla(addEntry);
    }

    var desc = await bekle(function () { return alanBul('Description', 'textarea') || alanBul('Description', 'input'); },
                           15000, 'Description alanı');
    await uyu(300);
    degerYaz(desc, aciklama);

    var saat = await bekle(function () { return alanBul('Hours', 'input'); }, 5000, 'Hours alanı');
    await listedenSec(saat, SAAT);

    var tarihInp = await bekle(tarihAlani, 5000, 'Work Date alanı');
    degerYaz(tarihInp, tarih);
    await uyu(500);

    var add = await bekle(function () {
      var b = butonBul('Add', desc);
      return b && !b.disabled && b.getAttribute('aria-disabled') !== 'true' ? b : null;
    }, 8000, 'aktif "Add" butonu (alanlardan biri kabul edilmemiş olabilir)');
    tikla(add);

    await bekle(function () { return (!gorunur(desc) || desc.value === '') ? true : null; },
                20000, 'kaydın eklenmesi (ekranda hata mesajı olabilir)');
    await uyu(1000);
  }

  /* ---------- Hours açılır listesi ---------- */
  async function listedenSec(input, deger) {
    var hedefler = [input, input.parentElement, input.parentElement && input.parentElement.parentElement];
    var oge = null;
    for (var i = 0; i < hedefler.length && !oge; i++) {
      if (!hedefler[i]) continue;
      tikla(hedefler[i]);
      try { oge = await bekle(function () { return secenekBul(deger, input); }, 2000, ''); } catch (e) {}
    }
    if (oge) {
      tikla(oge);
    } else {
      degerYaz(input, deger);
      tus(input, 'Enter');
    }
    await uyu(400);
    var v = (input.value || '').trim();
    if (/^\d+$/.test(v) && parseInt(v, 10) !== parseInt(deger, 10)) {
      throw new Error('Hours alanında ' + deger + ' seçilemedi (şu an: ' + v + ').');
    }
  }

  function secenekBul(deger, haric) {
    var adaylar = [deger, String(parseInt(deger, 10))];
    var hepsi = document.querySelectorAll('li, [role=option], div, span, a');
    for (var i = 0; i < hepsi.length; i++) {
      var e = hepsi[i];
      if (e === haric || !gorunur(e)) continue;
      if (adaylar.indexOf(kendiYazisi(e)) === -1) continue;
      return e.closest('li, [role=option]') || e;
    }
    return null;
  }

  /* ---------- Eleman bulma ---------- */
  function butonBul(yazi, kok) {
    var hedef = sade(yazi);
    var sec = 'button, [role=button], a';
    function ara(alan) {
      var list = Array.prototype.filter.call(alan.querySelectorAll(sec), gorunur);
      return list.find(function (b) { return sade(b.textContent) === hedef; }) ||
             list.find(function (b) { return sade(b.getAttribute('title')) === hedef || sade(b.getAttribute('aria-label')) === hedef; });
    }
    if (kok) {
      for (var p = kok.parentElement; p; p = p.parentElement) {
        var b = ara(p);
        if (b) return b;
      }
      return null;
    }
    return ara(document) || null;
  }

  function alanBul(etiket, sec) {
    var hedef = harfler(etiket);
    var hepsi = document.querySelectorAll('label, span, div, td, th, p');
    for (var i = 0; i < hepsi.length; i++) {
      var e = hepsi[i];
      if (harfler(kendiYazisi(e)) !== hedef || !gorunur(e)) continue;
      var p = e;
      for (var k = 0; p && k < 6; k++, p = p.parentElement) {
        var inp = Array.prototype.find.call(p.querySelectorAll(sec), function (x) {
          return gorunur(x) && x.type !== 'hidden' && x.type !== 'checkbox';
        });
        if (inp) return inp;
      }
    }
    return null;
  }

  function tarihAlani() {
    var inp = Array.prototype.find.call(document.querySelectorAll('input[placeholder]'), function (x) {
      return /DD-MMM-YYYY/i.test(x.getAttribute('placeholder')) && gorunur(x);
    });
    return inp || alanBul('Work Date', 'input');
  }

  /* ---------- Etkileşim ---------- */
  function tikla(el) {
    el.scrollIntoView({ block: 'center' });
    ['pointerdown', 'mousedown', 'pointerup', 'mouseup'].forEach(function (t) {
      el.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true, view: window }));
    });
    el.click();
  }

  function degerYaz(el, deger) {
    el.focus();
    var proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
    Object.getOwnPropertyDescriptor(proto, 'value').set.call(el, deger);
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    el.dispatchEvent(new FocusEvent('blur'));
    el.dispatchEvent(new FocusEvent('focusout', { bubbles: true }));
    el.blur();
  }

  function tus(el, key) {
    ['keydown', 'keypress', 'keyup'].forEach(function (t) {
      el.dispatchEvent(new KeyboardEvent(t, { bubbles: true, key: key, code: key, keyCode: 13, which: 13 }));
    });
  }

  /* ---------- Yardımcılar ---------- */
  function gorunur(el) {
    if (!el || !el.isConnected) return false;
    if (!el.getClientRects().length) return false;
    var s = getComputedStyle(el);
    return s.visibility !== 'hidden' && s.display !== 'none';
  }

  function kendiYazisi(el) {
    var t = '';
    for (var n = el.firstChild; n; n = n.nextSibling) if (n.nodeType === 3) t += n.nodeValue;
    return t.replace(/\s+/g, ' ').trim();
  }

  function sade(s) { return (s || '').replace(/\s+/g, ' ').trim().toLowerCase(); }
  function harfler(s) { return sade(s).replace(/[^a-z ]/g, '').trim(); }

  function uyu(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

  async function bekle(fn, ms, ad) {
    var t0 = Date.now();
    while (Date.now() - t0 < ms) {
      var r = fn();
      if (r) return r;
      await uyu(200);
    }
    throw new Error((ad || 'Eleman') + ' bulunamadı / zaman aşımı.');
  }

  function tarihCoz(s) {
    s = (s || '').trim();
    var m = s.match(/^(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{4})$/), y, a, g;
    if (m) { g = +m[1]; a = +m[2]; y = +m[3]; }
    else if ((m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/))) { y = +m[1]; a = +m[2]; g = +m[3]; }
    else return null;
    var d = new Date(y, a - 1, g);
    return (d.getFullYear() === y && d.getMonth() === a - 1 && d.getDate() === g) ? d : null;
  }

  function iki(n) { return (n < 10 ? '0' : '') + n; }
  function tcFormat(d) { return iki(d.getDate()) + '-' + AYLAR[d.getMonth()] + '-' + d.getFullYear(); }
  function trFormat(d) { return iki(d.getDate()) + '.' + iki(d.getMonth() + 1) + '.' + d.getFullYear(); }
})();
