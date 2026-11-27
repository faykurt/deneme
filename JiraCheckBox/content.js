(function () {
  const KEY = 'baktim';
  const HIDE_KEY = 'baktim_hide';
  const get = () => JSON.parse(localStorage.getItem(KEY) || '{}');
  const set = (v) => localStorage.setItem(KEY, JSON.stringify(v));
  const hideOn = () => localStorage.getItem(HIDE_KEY) === '1';

  function rows() {
    return Array.from(document.querySelectorAll('tr[data-issuekey]'));
  }

  function buildPanel() {
    if (document.getElementById('baktim-panel')) return;
    const p = document.createElement('div');
    p.id = 'baktim-panel';
    p.style.cssText =
      'position:fixed;top:8px;right:8px;z-index:99999;background:#fff;border:1px solid #999;' +
      'border-radius:4px;padding:6px 10px;font:12px Arial,sans-serif;box-shadow:0 2px 6px rgba(0,0,0,.3);' +
      'display:flex;gap:10px;align-items:center;';
    p.innerHTML =
      '<label style="cursor:pointer"><input type="checkbox" id="baktim-all"> Sayfadakilerin hepsi</label>' +
      '<label style="cursor:pointer"><input type="checkbox" id="baktim-hide"> Baktıklarımı gizle</label>' +
      '<button id="baktim-reset" style="cursor:pointer">Tümünü sıfırla</button>' +
      '<span id="baktim-count"></span>';
    document.body.appendChild(p);

    p.querySelector('#baktim-all').onclick = (e) => {
      const s = get();
      rows().forEach((tr) => {
        const k = tr.getAttribute('data-issuekey');
        e.target.checked ? (s[k] = 1) : delete s[k];
      });
      set(s);
      apply();
    };
    p.querySelector('#baktim-hide').onclick = (e) => {
      localStorage.setItem(HIDE_KEY, e.target.checked ? '1' : '0');
      apply();
    };
    p.querySelector('#baktim-reset').onclick = () => {
      const n = Object.keys(get()).length;
      if (confirm('Kayıtlı ' + n + ' işaretin HEPSİ silinecek. Emin misiniz?')) {
        set({});
        apply();
      }
    };
  }

  function apply() {
    const list = rows();
    if (!list.length) return;
    buildPanel();
    const seen = get();
    const hide = hideOn();
    let marked = 0;
    list.forEach((tr) => {
      const key = tr.getAttribute('data-issuekey');
      let cb = tr.querySelector('.baktim-cb');
      if (!cb) {
        cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.className = 'baktim-cb';
        cb.onclick = (e) => {
          e.stopPropagation();
          const s = get();
          cb.checked ? (s[key] = 1) : delete s[key];
          set(s);
          apply();
        };
        const td = tr.querySelector('td');
        if (td) td.prepend(cb);
      }
      const isSeen = !!seen[key];
      if (isSeen) marked++;
      cb.checked = isSeen;
      tr.style.opacity = isSeen ? '0.35' : '';
      tr.style.display = isSeen && hide ? 'none' : '';
    });
    document.getElementById('baktim-all').checked = marked === list.length;
    document.getElementById('baktim-hide').checked = hide;
    document.getElementById('baktim-count').textContent =
      'İşaretli: ' + marked + '/' + list.length + ' (toplam kayıt: ' + Object.keys(seen).length + ')';
  }

  apply();
  new MutationObserver(apply).observe(document.body, { childList: true, subtree: true });
})();
