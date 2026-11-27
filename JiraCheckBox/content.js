(function () {
  const KEY = 'baktim';
  const get = () => JSON.parse(localStorage.getItem(KEY) || '{}');
  const set = (v) => localStorage.setItem(KEY, JSON.stringify(v));

  function apply() {
    const seen = get();
    const list = Array.from(document.querySelectorAll('tr[data-issuekey]'));
    if (!list.length) return;

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
      cb.checked = !!seen[key];
      tr.style.opacity = seen[key] ? '0.35' : '';
    });

    // Tablo basligindaki "hepsini sec / kaldir" kutusu
    const table = list[0].closest('table');
    const th = table && table.querySelector('thead th');
    if (!th) return;
    let all = th.querySelector('.baktim-all');
    if (!all) {
      all = document.createElement('input');
      all.type = 'checkbox';
      all.className = 'baktim-all';
      all.title = 'Sayfadakilerin hepsini işaretle / kaldır (Shift+tık: tüm kayıtları sıfırla)';
      all.onclick = (e) => {
        e.stopPropagation();
        if (e.shiftKey) {
          if (confirm('Kayıtlı TÜM işaretler silinecek. Emin misiniz?')) set({});
          apply();
          return;
        }
        const s = get();
        document.querySelectorAll('tr[data-issuekey]').forEach((tr) => {
          const k = tr.getAttribute('data-issuekey');
          all.checked ? (s[k] = 1) : delete s[k];
        });
        set(s);
        apply();
      };
      th.prepend(all);
    }
    all.checked = list.every((tr) => seen[tr.getAttribute('data-issuekey')]);
  }

  apply();
  new MutationObserver(apply).observe(document.body, { childList: true, subtree: true });
})();
