(function () {
  "use strict";
  var C = window.SITE_CONFIG || {};
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  // ---------- anonim olay kaydı (çerez / tarayıcı depolaması yok) ----------
  // Her sayfa yüklemesi için bellekte rastgele bir kimlik üretilir; kalıcı değildir.
  var vid = "v" + Math.random().toString(36).slice(2, 10) + Date.now().toString(36);

  function post(payload) {
    if (!C.endpoint) {
      if (window.console) console.info("[test modu]", payload);
      return Promise.resolve();
    }
    return fetch(C.endpoint, {
      method: "POST", mode: "no-cors", keepalive: true,
      headers: { "Content-Type": "text/plain;charset=utf-8" },
      body: JSON.stringify(payload)
    });
  }

  function track(name, params) {
    post({ type: "event", event: name, params: params || {}, vid: vid, ts: new Date().toISOString(), ref: document.referrer || "", ua_mobile: /Mobi|Android/i.test(navigator.userAgent) });
  }

  // ---------- güven şeridi ----------
  var tl = $("#trust-list");
  (C.trust || []).forEach(function (t) {
    var li = document.createElement("li");
    li.textContent = t.icon + " " + t.text;
    tl.appendChild(li);
  });

  // ---------- ürün kartları ----------
  var fmt = new Intl.NumberFormat("tr-TR");
  var grid = $("#product-grid");
  $("#price-note").textContent = C.priceNote || "";
  (C.products || []).forEach(function (p) {
    var el = document.createElement("article");
    el.className = "card" + (p.type !== "Orijinal" ? " yerli" : ""); el.dataset.pid = p.id;
    el.innerHTML =
      '<span class="tag">' + p.badge + '</span>' +
      '<h3></h3><p></p>' +
      '<div class="price">' + p.currency + fmt.format(p.price) + '</div>' +
      '<button class="btn" type="button">Talep bırak</button>';
    $("h3", el).textContent = p.title; $("p", el).textContent = p.desc;
    $(".btn", el).addEventListener("click", function () { openLead([p.id], "card"); track("cta_click", { product: p.id, where: "card" }); });
    grid.appendChild(el);
  });

  var seen = {};
  function observeProducts() {
    if (!("IntersectionObserver" in window)) return;
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        var id = en.target.dataset.pid;
        if (en.isIntersecting && !seen[id]) { seen[id] = 1; track("price_seen", { product: id }); }
      });
    }, { threshold: 0.6 });
    $$(".card").forEach(function (c) { io.observe(c); });
  }

  $$("[data-track]").forEach(function (a) { a.addEventListener("click", function () { track("cta_click", { where: a.dataset.track }); }); });

  // ---------- talep formu ----------
  var dlg = $("#lead-dialog"), form = $("#lead-form"), chips = $("#product-chips");
  var started = false, submitted = false;

  (C.products || []).forEach(function (p) {
    var l = document.createElement("label");
    l.innerHTML = '<input type="checkbox" name="products" value="' + p.id + '"> ' + p.title;
    chips.appendChild(l);
  });

  function titles(ids) {
    return (C.products || []).filter(function (p) { return ids.indexOf(p.id) > -1; }).map(function (p) { return p.set + " " + p.title; }).join(", ") || "Seçilmedi";
  }

  function openLead(ids, where) {
    submitted = false; started = false;
    $("#lead-body").hidden = false; $("#lead-done").hidden = true; $("#lead-error").hidden = true;
    $$("input[name=products]", form).forEach(function (i) { i.checked = ids.indexOf(i.value) > -1; });
    if (!dlg.open) dlg.showModal();
    track("form_open", { where: where, products: ids.join(",") });
  }

  function closeLead() {
    if (dlg.open) dlg.close();
    if (!submitted) track("form_abandon", { started: started });
  }
  $("#lead-close").addEventListener("click", closeLead);
  $("#done-close").addEventListener("click", function () { dlg.close(); });
  dlg.addEventListener("cancel", function () { if (!submitted) track("form_abandon", { started: started }); });
  form.addEventListener("input", function () { if (!started) { started = true; track("form_start"); } });
  form.addEventListener("change", function (e) { if (e.target.name === "price_feedback") track("price_feedback", { value: e.target.value }); });

  form.addEventListener("submit", function (e) {
    e.preventDefault();
    var err = $("#lead-error"); err.hidden = true;
    if (form.website.value) { return; } // bot tuzağı
    var name = form.name.value.trim(), phone = form.phone.value.replace(/[^\d+]/g, "");
    var ids = $$("input[name=products]:checked", form).map(function (i) { return i.value; });
    var msg = "";
    if (!name) msg = "Lütfen ad soyadınızı yazın.";
    else if (phone.replace(/\D/g, "").length < 10) msg = "Lütfen geçerli bir telefon numarası yazın.";
    else if (!ids.length) msg = "Lütfen en az bir set seçin.";
    else if (form.email.value && !/^\S+@\S+\.\S+$/.test(form.email.value)) msg = "E-posta adresi geçersiz görünüyor.";
    if (msg) { err.textContent = msg; err.hidden = false; track("form_error", { reason: msg }); return; }

    var btn = $("#lead-submit"); btn.disabled = true; btn.textContent = "Gönderiliyor…";
    var lead = {
      type: "lead", ts: new Date().toISOString(),
      name: name, phone: phone, email: form.email.value.trim(),
      qty: form.qty.value, products: titles(ids),
      price_feedback: (form.price_feedback.value || ""),
      vid: vid, ref: document.referrer || ""
    };
    post(lead).then(function () {
      submitted = true; track("form_submit", { products: ids.join(",") });
      var num = (C.whatsappNumber || "").replace(/\D/g, "");
      var text = encodeURIComponent("Merhaba, " + titles(ids) + " için talep bıraktım. Ad: " + name);
      $("#wa-link").href = "https://wa.me/" + num + "?text=" + text;
      $("#wa-link").hidden = !/^\d{10,15}$/.test(num);
      $("#lead-body").hidden = true; $("#lead-done").hidden = false;
      form.reset(); btn.disabled = false; btn.textContent = "Talebi gönder";
    }).catch(function () {
      btn.disabled = false; btn.textContent = "Talebi gönder";
      err.textContent = "Gönderilemedi. Lütfen internet bağlantınızı kontrol edip tekrar deneyin."; err.hidden = false;
    });
  });


  // ---------- başlangıç ----------
  track("page_view");
  observeProducts();
})();
