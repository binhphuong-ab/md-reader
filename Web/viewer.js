// MD Reader — renders Markdown (+ KaTeX math, Mermaid, GFM tables) into #content.
// Swift calls MDR.render(text, dir, keepScroll) and MDR.setOutline(bool);
// this page talks back through window.webkit.messageHandlers.mdr.
(() => {
  'use strict';

  const post = (msg) => window.webkit?.messageHandlers?.mdr?.postMessage(msg);
  const $ = (sel) => document.querySelector(sel);
  const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) => ESC[c]);

  // ---------- markdown-it setup ----------
  const md = window.markdownit({ html: true, linkify: true, typographer: false });
  md.use(texmath, {
    engine: katex,
    delimiters: ['dollars', 'brackets'], // $…$, $$…$$, \(…\), \[…\]
    katexOptions: { throwOnError: false, strict: 'ignore' },
  });
  md.use(window.markdownitFootnote);
  md.use(window.markdownitTaskLists, { enabled: false, label: true });

  // Fenced blocks: mermaid → placeholder, math → KaTeX, everything else → highlighted code.
  md.renderer.rules.fence = (tokens, idx) => {
    const t = tokens[idx];
    const lang = (t.info || '').trim().split(/\s+/)[0].toLowerCase();
    const src = t.content;
    if (lang === 'mermaid') {
      return `<div class="mermaid-block" data-src="${escapeHtml(src)}"><div class="mermaid-loading">Rendering diagram…</div></div>\n`;
    }
    if (lang === 'math' || lang === 'katex') {
      return `<div class="math-block">${katex.renderToString(src, { displayMode: true, throwOnError: false })}</div>\n`;
    }
    return codeBlock(src, lang);
  };
  md.renderer.rules.code_block = (tokens, idx) => codeBlock(tokens[idx].content, '');

  function codeBlock(src, lang) {
    let body;
    if (lang && hljs.getLanguage(lang)) {
      try { body = hljs.highlight(src, { language: lang, ignoreIllegals: true }).value; } catch (_) {}
    }
    if (body === undefined) body = escapeHtml(src);
    const cls = lang ? ` language-${escapeHtml(lang)}` : '';
    return `<div class="code-block"><div class="code-head"><span class="code-lang">${escapeHtml(lang || 'text')}</span>` +
      `<button class="copy-btn" type="button">Copy</button></div><pre><code class="hljs${cls}">${body}</code></pre></div>\n`;
  }

  // Wide tables scroll sideways instead of squashing.
  md.renderer.rules.table_open = () => '<div class="table-wrap"><table>\n';
  md.renderer.rules.table_close = () => '</table></div>\n';

  // GitHub-style heading ids (Unicode-aware, so Vietnamese headings keep their letters).
  const slugify = (s) => s.trim().toLowerCase().normalize('NFC')
    .replace(/[^\p{L}\p{M}\p{N}\s_-]/gu, '').replace(/\s+/g, '-');
  md.core.ruler.push('heading_ids', (state) => {
    const used = Object.create(null);
    state.tokens.forEach((tok, i) => {
      if (tok.type !== 'heading_open') return;
      const inline = state.tokens[i + 1];
      const text = (inline.children || [])
        .filter((c) => c.type === 'text' || c.type === 'code_inline' || c.type === 'math_inline')
        .map((c) => c.content).join('') || inline.content;
      let slug = slugify(text) || 'section';
      if (slug in used) slug += '-' + (++used[slug]); else used[slug] = 0;
      tok.attrSet('id', slug);
    });
  });

  // ---------- Mermaid ----------
  // 'base' is Mermaid's customisable theme: everything is derived from these colours.
  mermaid.initialize({
    startOnLoad: false,
    theme: 'base',
    darkMode: true,
    fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif',
    themeVariables: {
      darkMode: true,
      background: '#1b1e24',
      fontSize: '15px',
      // Dark green palette: deep forest fills, muted green borders, sage lines.
      primaryColor: '#1c3327',
      primaryTextColor: '#e4efe8',
      primaryBorderColor: '#3f8a62',
      secondaryColor: '#213a2d',
      secondaryTextColor: '#e4efe8',
      secondaryBorderColor: '#3f8a62',
      tertiaryColor: '#18261f',
      tertiaryTextColor: '#e4efe8',
      tertiaryBorderColor: '#2f6a4b',
      lineColor: '#7d9688',
      textColor: '#d6e0da',
      mainBkg: '#1c3327',
      nodeBorder: '#3f8a62',
      edgeLabelBackground: '#1e2a23',
      clusterBkg: '#17201b',
      clusterBorder: '#2f5a43',
      titleColor: '#e4efe8',
      // state diagrams
      stateBkg: '#1c3327',
      stateBorder: '#3f8a62',
      stateLabelColor: '#e4efe8',
      compositeBackground: '#161e1a',
      compositeTitleBackground: '#1f3a2c',
      compositeBorder: '#2f6a4b',
      altBackground: '#18241e',
      transitionColor: '#7d9688',
      transitionLabelColor: '#d6e0da',
      specialStateColor: '#5fb886',
      innerEndBackground: '#5fb886',
      // sequence diagrams
      actorBkg: '#1c3327',
      actorBorder: '#3f8a62',
      actorTextColor: '#e4efe8',
      actorLineColor: '#3f8a62',
      signalColor: '#c4d2ca',
      signalTextColor: '#d6e0da',
      labelBoxBkgColor: '#1c3327',
      labelBoxBorderColor: '#3f8a62',
      labelTextColor: '#e4efe8',
      activationBkgColor: '#24402f',
      activationBorderColor: '#3f8a62',
      noteBkgColor: '#3a3424',
      noteTextColor: '#efe6cf',
      noteBorderColor: '#7d6a3e',
      // pie
      pieStrokeColor: '#1b1e24', pieOuterStrokeColor: '#1b1e24', pieStrokeWidth: '2px',
      pieTitleTextColor: '#e4efe8', pieLegendTextColor: '#d6e0da', pieSectionTextColor: '#0f1512',
      pie1: '#4fae7b', pie2: '#86c9a0', pie3: '#2e7a55', pie4: '#b9dcc6', pie5: '#c9b26b', pie6: '#5a9c9e',
    },
    flowchart: { curve: 'basis', htmlLabels: true },
  });

  const mermaidCache = new Map(); // source → svg, so live reloads don't make the page jump
  let mermaidCounter = 0;

  async function renderMermaid(root, seq) {
    const blocks = [...root.querySelectorAll('.mermaid-block')];
    for (const b of blocks) {
      const svg = mermaidCache.get(b.dataset.src);
      if (svg) b.innerHTML = svg;
    }
    for (const b of blocks) {
      if (seq !== renderSeq) return;
      if (b.querySelector('svg')) continue;
      const src = b.dataset.src;
      const id = 'mmd-' + (++mermaidCounter);
      try {
        const { svg } = await mermaid.render(id, src);
        mermaidCache.set(src, svg);
        b.innerHTML = svg;
      } catch (e) {
        document.getElementById('d' + id)?.remove(); // mermaid leaves its scratch node behind on errors
        b.classList.add('has-error');
        b.innerHTML = `<div class="mermaid-error"><div class="err-title">Mermaid syntax error</div>` +
          `<pre class="err-msg">${escapeHtml(e?.message || e)}</pre><pre class="err-src">${escapeHtml(src)}</pre></div>`;
      }
    }
  }

  // ---------- local files (images / links relative to the .md) ----------
  let docDir = '';
  const hasScheme = (h) => /^[a-z][a-z0-9+.-]*:/i.test(h);
  function resolveLocal(href) {
    if (!href || href.startsWith('#') || hasScheme(href)) return null;
    const base = 'mdr://file' + docDir.split('/').map(encodeURIComponent).join('/') + '/';
    try { return new URL(href, base).href; } catch (_) { return null; }
  }
  function fixResources(root) {
    root.querySelectorAll('img[src], video[src], source[src]').forEach((el) => {
      const u = resolveLocal(el.getAttribute('src'));
      if (u) el.setAttribute('src', u);
    });
  }

  // ---------- outline ----------
  let headings = [];
  function buildToc(root) {
    headings = [...root.querySelectorAll('h1, h2, h3, h4')].filter((h) => h.id);
    const toc = $('#toc');
    if (!headings.length) { toc.innerHTML = '<li class="empty">No headings</li>'; return; }
    toc.innerHTML = headings.map((h) => {
      const clone = h.cloneNode(true);
      clone.querySelectorAll('.katex-mathml').forEach((n) => n.remove());
      return `<li class="lvl-${h.tagName[1]}"><a href="#${encodeURIComponent(h.id)}" data-id="${escapeHtml(h.id)}">${escapeHtml(clone.textContent.trim())}</a></li>`;
    }).join('');
    updateActive();
  }

  let activeId = null;
  function updateActive() {
    if (!headings.length) return;
    let current = headings[0];
    for (const h of headings) {
      if (h.getBoundingClientRect().top <= 90) current = h; else break;
    }
    if (current.id === activeId) return;
    activeId = current.id;
    const toc = $('#outline');
    toc.querySelectorAll('a.active').forEach((a) => a.classList.remove('active'));
    const link = toc.querySelector(`a[data-id="${CSS.escape(current.id)}"]`);
    if (!link) return;
    link.classList.add('active');
    const top = link.offsetTop, bottom = top + link.offsetHeight;
    if (top < toc.scrollTop + 40) toc.scrollTop = top - 40;
    else if (bottom > toc.scrollTop + toc.clientHeight - 60) toc.scrollTop = bottom - toc.clientHeight + 60;
  }
  let ticking = false;
  window.addEventListener('scroll', () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => { ticking = false; updateActive(); });
  }, { passive: true });

  function updateStats(text) {
    const words = (text.match(/[\p{L}\p{N}]+/gu) || []).length;
    $('#stats').textContent = `${words.toLocaleString()} words · ${Math.max(1, Math.round(words / 230))} min read`;
  }

  // ---------- render ----------
  let renderSeq = 0;
  async function render(text, dir, keepScroll) {
    const seq = ++renderSeq;
    const y = window.scrollY;
    docDir = dir || '';
    text = String(text).replace(/^﻿/, '');

    let front = '';
    const fm = text.match(/^---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)[ \t]*(?:\r?\n|$)/);
    if (fm) {
      front = `<details class="frontmatter"><summary>Front matter</summary><pre>${escapeHtml(fm[1])}</pre></details>`;
      text = text.slice(fm[0].length);
    }

    let html;
    try { html = md.render(text); } catch (e) { html = `<pre class="render-error">${escapeHtml(e?.stack || e)}</pre>`; }
    const content = $('#content');
    content.innerHTML = front + html;
    fixResources(content);
    updateStats(text);
    activeId = null;
    window.scrollTo(0, keepScroll ? y : 0);
    buildToc(content);

    await renderMermaid(content, seq);
    if (seq !== renderSeq) return;
    if (keepScroll) window.scrollTo(0, y);
    activeId = null;
    updateActive();
  }

  // Only animate when the user toggles it, not when a window first opens.
  function setOutline(on, animate) {
    document.body.classList.toggle('animate', !!animate);
    document.body.classList.toggle('outline-open', !!on);
    activeId = null;
    updateActive();
  }

  // ---------- interaction ----------
  const overlay = $('#overlay');
  function openOverlay(svg) {
    const clone = svg.cloneNode(true);
    clone.removeAttribute('style');
    clone.setAttribute('width', '100%');
    clone.setAttribute('height', '100%');
    overlay.replaceChildren(clone);
    overlay.hidden = false;
  }
  overlay.addEventListener('click', () => { overlay.hidden = true; });
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape') overlay.hidden = true; });

  document.addEventListener('click', (e) => {
    const copy = e.target.closest('.copy-btn');
    if (copy) {
      const code = copy.closest('.code-block').querySelector('code').innerText;
      post({ type: 'copy', text: code });
      copy.textContent = 'Copied';
      setTimeout(() => { copy.textContent = 'Copy'; }, 1200);
      return;
    }
    const svg = e.target.closest('.mermaid-block svg');
    if (svg && !e.target.closest('a')) { openOverlay(svg); return; }

    const a = e.target.closest('a[href]');
    if (!a) return;
    const href = a.getAttribute('href');
    e.preventDefault();
    if (href.startsWith('#')) {
      const target = document.getElementById(decodeURIComponent(href.slice(1)));
      target?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      return;
    }
    post({ type: 'open', href: resolveLocal(href) || href });
  });

  window.MDR = { render, setOutline };
  post({ type: 'ready' });
})();
