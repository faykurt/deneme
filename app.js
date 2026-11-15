(function () {
  "use strict";
  var C = window.SITE_CONFIG || {};
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };

  // ---------- güvenli depolama ----------
  var store = {
    get: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  };

  // ---------- onay + izleme ----------
  var consent = store.get("consent"); // "yes" | "no" | null
  var vid = null;
  function visitorId() {
    if (vid) return vid;
    vid = store.get("vid");
    if (!vid) { vid = "v" + Math.random().toString(36).slice(2) + Date.now().toString(36); store.set("vid", vid); }
    return vid;
  }

  function post(payload) {
    if (!C.endpoint) {
      try {
        var key = payload.type === "lead" ? "local_leads" : "local_events";
        var arr = JSON.parse(store.get(key) || "[]"); arr.push(payload); store.set(key, JSON.stringify(arr.slice(-200)));
      } catch (e) {}
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
    if (consent !== "yes") return;
    params = params || {};
    post({ type: "event", event: name, params: params, vid: visitorId(), ts: new Date().toISOString(), path: location.pathname, ref: document.referrer || "", ua_mobile: /Mobi|Android/i.test(navigator.userAgent) });
    if (window.gtag) window.gtag("event", name, params);
  }

  function loadAnalytics() {
    if (C.ga4Id && !window.gtag) {
      var s = document.createElement("script"); s.async = true;
      s.src = "https://www.googletagmanager.com/gtag/js?id=" + encodeURIComponent(C.ga4Id);
      document.head.appendChild(s);
      window.dataLayer = window.dataLayer || [];
      window.gtag = function () { window.dataLayer.push(arguments); };
      window.gtag("js", new Date()); window.gtag("config", C.ga4Id, { anonymize_ip: true });
    }
    if (C.clarityId && !window.clarity) {
      (function (c, l, a, r, i, t, y) {
        c[a] = c[a] || function () { (c[a].q = c[a].q || []).push(arguments); };
        t = l.createElement(r); t.async = 1; t.src = "https://www.clarity.ms/tag/" + i;
        y = l.getElementsByTagName(r)[0]; y.parentNode.insertBefore(t, y);
      })(window, document, "clarity", "script", C.clarityId);
    }
  }

  var banner = $("#consent");
  function setConsent(v) {
    consent = v; store.set("consent", v); banner.hidden = true;
    if (v === "yes") { loadAnalytics(); track("page_view"); observeProducts(); }
  }
  $("#consent-yes").addEventListener("click", function () { setConsent("yes"); });
  $("#consent-no").addEventListener("click", function () { setConsent("no"); });
  $("#cookie-settings").addEventListener("click", function (e) { e.preventDefault(); banner.hidden = false; });

  // ---------- ürün kartları ----------
  var fmt = new Intl.NumberFormat("tr-TR");
  var grid = $("#product-grid");
  $("#price-note").textContent = C.priceNote || "";
  (C.products || []).forEach(function (p) {
    var el = document.createElement("article");
    el.className = "card"; el.dataset.pid = p.id;
    el.innerHTML =
      '<span class="tag ' + (p.type === "3D Baskı" ? "t3d" : "") + '">' + p.badge + '</span>' +
      '<h3></h3><p></p>' +
      '<div class="price">' + p.currency + fmt.format(p.price) + '<small>tahmini birim fiyat</small></div>' +
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
  $$("details").forEach(function (d) { d.addEventListener("toggle", function () { if (d.open) track("faq_open", { q: $("summary", d).textContent }); }); });

  // ---------- talep formu ----------
  var dlg = $("#lead-dialog"), form = $("#lead-form"), chips = $("#product-chips");
  var started = false, submitted = false;

  (C.products || []).forEach(function (p) {
    var l = document.createElement("label");
    l.innerHTML = '<input type="checkbox" name="products" value="' + p.id + '"> ' + p.title.replace("Uyumlu ", "");
    chips.appendChild(l);
  });

  function titles(ids) {
    return (C.products || []).filter(function (p) { return ids.indexOf(p.id) > -1; }).map(function (p) { return p.title; }).join(", ") || "Seçilmedi";
  }
  function syncProductLabel() {
    var ids = $$("input[name=products]:checked", form).map(function (i) { return i.value; });
    $("#lead-product").textContent = titles(ids);
  }
  chips.addEventListener("change", syncProductLabel);

  function openLead(ids, where) {
    submitted = false; started = false;
    $("#lead-body").hidden = false; $("#lead-done").hidden = true; $("#lead-error").hidden = true;
    $$("input[name=products]", form).forEach(function (i) { i.checked = ids.indexOf(i.value) > -1; });
    form.corporate.checked = where === "corp";
    syncProductLabel();
    if (!dlg.open) dlg.showModal();
    track("form_open", { where: where, products: ids.join(",") });
  }
  $$("[data-corp]").forEach(function (b) { b.addEventListener("click", function () { openLead([], "corp"); track("cta_click", { where: "corp" }); }); });

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
    else if (!form.profession.value) msg = "Lütfen mesleğinizi seçin.";
    else if (!ids.length && !form.corporate.checked) msg = "Lütfen en az bir set seçin.";
    else if (form.email.value && !/^\S+@\S+\.\S+$/.test(form.email.value)) msg = "E-posta adresi geçersiz görünüyor.";
    else if (!form.kvkk.checked) msg = "Devam etmek için aydınlatma metnini onaylamanız gerekir.";
    if (msg) { err.textContent = msg; err.hidden = false; track("form_error", { reason: msg }); return; }

    var btn = $("#lead-submit"); btn.disabled = true; btn.textContent = "Gönderiliyor…";
    var lead = {
      type: "lead", ts: new Date().toISOString(),
      name: name, phone: phone, email: form.email.value.trim(),
      profession: form.profession.value, city: form.city.value.trim(), institution: form.institution.value.trim(),
      qty: form.qty.value, products: titles(ids), corporate: form.corporate.checked ? "evet" : "hayır",
      price_feedback: (form.price_feedback.value || ""), note: form.note.value.trim(),
      kvkk: "onaylandı", vid: consent === "yes" ? visitorId() : "", ref: document.referrer || ""
    };
    post(lead).then(function () {
      submitted = true; track("form_submit", { products: ids.join(","), corporate: lead.corporate });
      if (window.gtag && consent === "yes") window.gtag("event", "generate_lead");
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

  // ---------- KVKK ----------
  var kv = $("#kvkk-dialog");
  $$("[data-open-kvkk]").forEach(function (a) { a.addEventListener("click", function (e) { e.preventDefault(); kv.showModal(); }); });
  $("#kvkk-close").addEventListener("click", function () { kv.close(); });

  // ---------- başlangıç ----------
  if (consent === "yes") { loadAnalytics(); track("page_view"); observeProducts(); }
  else if (consent !== "no") { banner.hidden = false; }
})();
