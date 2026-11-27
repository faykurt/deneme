(function () {
  const KEY = 'baktim2';
  const NOTES_KEY = 'baktim_notes2';

  // Kayitlar filtre bazinda tutulur: filter=ID varsa o, yoksa jql metni, yoksa sayfa yolu
  function scope() {
    const p = new URLSearchParams(location.search);
    if (p.get('filter')) return 'filter:' + p.get('filter');
    if (p.get('jql')) return 'jql:' + p.get('jql').trim();
    return 'page:' + location.pathname;
  }
  const readAll = (k) => {
    try {
      return JSON.parse(localStorage.getItem(k) || '{}');
    } catch (e) {
      return {};
    }
  };
  const getScoped = (k) => readAll(k)[scope()] || {};
  const setScoped = (k, v) => {
    const all = readAll(k);
    Object.keys(v).length ? (all[scope()] = v) : delete all[scope()];
    localStorage.setItem(k, JSON.stringify(all));
  };
  const get = () => getScoped(KEY);
  const set = (v) => setScoped(KEY, v);
  const getNotes = () => getScoped(NOTES_KEY);
  const setNotes = (v) => setScoped(NOTES_KEY, v);

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
      l.title = text + '  (click to edit)';
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
    inp.title = 'Add note';
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
    const sc = scope();
    const seen = get();
    const list = Array.from(document.querySelectorAll('tr[data-issuekey]'));
    if (!list.length) return;

    list.forEach((tr) => {
      const key = tr.getAttribute('data-issuekey');

      // Not hucresi (en solda)
      let nt = tr.querySelector('td.baktim-note-td');
      if (!nt) {
        nt = document.createElement('td');
        nt.className = 'baktim-note-td';
        nt.style.cssText = 'min-width:140px;white-space:nowrap;';
        nt.onclick = (e) => e.stopPropagation();
        tr.prepend(nt);
      }
      if (nt.dataset.scope !== sc) {
        nt.dataset.scope = sc;
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

    // Baslik: "My notes" sutunu + hepsini sec kutusu
    const table = list[0].closest('table');
    const headRow = table && table.querySelector('thead tr');
    if (!headRow) return;
    if (!headRow.querySelector('th.baktim-note-th')) {
      const nth = document.createElement('th');
      nth.className = 'baktim-note-th';
      nth.appendChild(document.createTextNode('My notes '));
      const clr = document.createElement('a');
      clr.textContent = 'Clear all';
      clr.href = '#';
      clr.title = 'Delete all notes of this filter';
      clr.style.cssText = 'font-size:11px;font-weight:normal;margin-left:6px;';
      clr.onclick = (e) => {
        e.preventDefault();
        e.stopPropagation();
        const n = Object.keys(getNotes()).length;
        if (!n) return;
        if (confirm('All ' + n + ' saved notes of this filter will be deleted. Are you sure?')) {
          setNotes({});
          document.querySelectorAll('tr[data-issuekey]').forEach((tr) => {
            const td = tr.querySelector('td.baktim-note-td');
            if (td) renderNote(td, tr.getAttribute('data-issuekey'), false);
          });
        }
      };
      nth.appendChild(clr);
      headRow.prepend(nth);
    }
    const th = headRow.querySelector('th:not(.baktim-note-th)');
    if (!th) return;
    let all = th.querySelector('.baktim-all');
    if (!all) {
      all = document.createElement('input');
      all.type = 'checkbox';
      all.className = 'baktim-all';
      all.title = 'Check / uncheck all rows on this page (Shift+click: reset all checks of this filter; notes are kept)';
      all.onclick = (e) => {
        e.stopPropagation();
        if (e.shiftKey) {
          if (confirm('ALL saved checks of this filter will be cleared (notes are kept). Are you sure?')) set({});
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
