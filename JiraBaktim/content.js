(function () {
  const KEY = 'baktim';
  const get = () => JSON.parse(localStorage.getItem(KEY) || '{}');
  const set = (v) => localStorage.setItem(KEY, JSON.stringify(v));

  function apply() {
    const seen = get();
    document.querySelectorAll('tr[data-issuekey]').forEach((tr) => {
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
  }
  apply();
  new MutationObserver(apply).observe(document.body, { childList: true, subtree: true });
})();
