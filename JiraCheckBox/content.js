(function () {
  const KEY = 'baktim';
  const NOTES_KEY = 'baktim_notes';
  const get = () => JSON.parse(localStorage.getItem(KEY) || '{}');
  const set = (v) => localStorage.setItem(KEY, JSON.stringify(v));
  const getNotes = () => JSON.parse(localStorage.getItem(NOTES_KEY) || '{}');
  const setNotes = (v) => localStorage.setItem(NOTES_KEY, JSON.stringify(v));

  const LOZENGE =
    'display:inline-block;max-width:130px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;' +
    'vertical-align:middle;cursor:pointer;font:bold 11px Arial,sans-serif;padding:2px 6px;' +
    'border:1px solid #b3c6e0;border-radius:3px;background:#f0f4fa;color:#205081;';
  const INPUT =
    'width:130px;box-sizing:border-box;font:12px Arial,sans-serif;padding:2px 4px;' +
    'border:1px dashed #bbb;border-radius:3px;background:transparent;';

  function renderNote(td, key, edit) {
    td.textContent = '';
    const text = getNotes()[key];
    if (text && !edit) {
      const l = document.createElement('span');
      l.style.cssText = LOZENGE;
      l.textContent = text;
      l.title = text + '  (düzenlemek için tıklayın)';
      l.onclick = (e) => {
        e.stopPropagation();
        e.preventDefault();
        renderNote(td, key, true);
      };
      td.appendChild(l);
      return;
    }
    const inp = document.createElement('input');
    inp.type = 'text';
    inp.style.cssText = INPUT;
    inp.placeholder = '+ not';
    inp.value = text || '';
    let done = false;
    const commit = () => {
      if (done) return;
      done = true;
      const n = getNotes();
      const v = inp.value.trim();
      v ? (n[key] = v) : delete n[key];
      setNotes(n);
      renderNote(td, key, false);
    };
    inp.onkeydown = (e) => {
      e.stopPropagation(); // Jira kisayollari (j, k, c...) tetiklenmesin
      if (e.key === 'Enter') {
        e.preventDefault();
        commit();
      } else if (e.key === 'Escape') {
        done = true;
        renderNote(td, key, false);
      }
    };
    inp.onkeyup = inp.onkeypress = (e) => e.stopPropagation();
    inp.onclick = (e) => e.stopPropagation();
    inp.onblur = commit;
    td.appendChild(inp);
    if (edit) setTimeout(() => inp.focus(), 0);
  }

  function apply() {
    const seen = get();
    const list = Array.from(document.querySelectorAll('tr[data-issuekey]'));
    if (!list.length) return;

    list.forEach((tr) => {
      const key = tr.getAttribute('data-issuekey');

      // Not hucresi (en solda)
      if (!tr.querySelector('td.baktim-note-td')) {
        const nt = document.createElement('td');
        nt.className = 'baktim-note-td';
        nt.style.cssText = 'min-width:140px;white-space:nowrap;';
        nt.onclick = (e) => e.stopPropagation();
        tr.prepend(nt);
        renderNote(nt, key, false);
      }

      // Tik kutusu
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
        const td = tr.querySelector('td:not(.baktim-note-td)');
        if (td) td.prepend(cb);
      }
      cb.checked = !!seen[key];
      tr.style.opacity = seen[key] ? '0.35' : '';
    });

    // Baslik: "Not" sutunu + hepsini sec kutusu
    const table = list[0].closest('table');
    const headRow = table && table.querySelector('thead tr');
    if (!headRow) return;
    if (!headRow.querySelector('th.baktim-note-th')) {
      const nth = document.createElement('th');
      nth.className = 'baktim-note-th';
      nth.textContent = 'Not';
      headRow.prepend(nth);
    }
    const th = headRow.querySelector('th:not(.baktim-note-th)');
    if (!th) return;
    let all = th.querySelector('.baktim-all');
    if (!all) {
      all = document.createElement('input');
      all.type = 'checkbox';
      all.className = 'baktim-all';
      all.title = 'Sayfadakilerin hepsini işaretle / kaldır (Shift+tık: tüm tikleri sıfırla; notlar silinmez)';
      all.onclick = (e) => {
        e.stopPropagation();
        if (e.shiftKey) {
          if (confirm('Kayıtlı TÜM tikler silinecek (notlar kalır). Emin misiniz?')) set({});
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
