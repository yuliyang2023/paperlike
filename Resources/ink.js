(() => {
  'use strict';
  if (window.PaperlikeReader) return;
  const style = document.createElement('style');
  style.id = 'paperlike-reader-style';
  style.textContent = `
    html[data-paperlike-ink="true"] { color-scheme: light !important; background: white !important; }
    html[data-paperlike-ink="true"] body { background: white !important; color: #000 !important; }
    html[data-paperlike-ink="true"] *, html[data-paperlike-ink="true"] *::before, html[data-paperlike-ink="true"] *::after {
      animation-duration: 0.001s !important; animation-delay: 0s !important; animation-iteration-count: 1 !important;
      transition-duration: 0.001s !important; transition-delay: 0s !important; scroll-behavior: auto !important;
      box-shadow: none !important; text-shadow: none !important;
    }
    html[data-paperlike-ink="true"] .renderTargetContent { filter: grayscale(1) contrast(1.12); }
    html[data-paperlike-ink="true"] .readerContent,
    html[data-paperlike-ink="true"] .readerTopBar,
    html[data-paperlike-ink="true"] .readerControls,
    html[data-paperlike-ink="true"] .readerControls_item,
    html[data-paperlike-ink="true"] .wr_horizontalReader_app_content,
    html[data-paperlike-ink="true"] .readerChapterContent_container,
    html[data-paperlike-ink="true"] .readerChapterContent,
    html[data-paperlike-ink="true"] .readerFooter { background-color: white !important; color: black !important; }
    html[data-paperlike-ink="true"] .readerTopBar_link,
    html[data-paperlike-ink="true"] .readerTopBar_title_link,
    html[data-paperlike-ink="true"] .renderTargetPageInfo_header_chapterTitle,
    html[data-paperlike-ink="true"] .renderTarget_pager_button { color: black !important; }
    html[data-paperlike-ink="true"] :focus-visible { outline: 2px solid black !important; outline-offset: 2px; }
  `;
  (document.head || document.documentElement).appendChild(style);
  const controlsStyle = document.createElement('style');
  controlsStyle.id = 'paperlike-large-controls-style';
  controlsStyle.textContent = `
    .readerControls {
      --paperlike-control-size: 64px;
      position: fixed !important; left: auto !important; right: 16px !important;
      top: 80px !important; bottom: auto !important;
      width: var(--paperlike-control-size) !important; height: auto !important;
      display: flex !important; flex-direction: column; gap: 10px !important;
      transform: none !important; max-height: none !important;
      overflow: visible !important;
    }
    .readerControls > *, .readerControls .wr_tooltip_container { margin: 0 !important; flex-shrink: 0; }
    .readerControls .readerControls_item {
      box-sizing: border-box; width: var(--paperlike-control-size) !important; height: var(--paperlike-control-size) !important;
      min-width: var(--paperlike-control-size); min-height: var(--paperlike-control-size); flex-shrink: 0;
      margin: 0 !important;
    }
    .readerControls .readerControls_item > .icon,
    .readerControls .readerControls_item > svg { transform: scale(1.25); }
    :is(.font-panel-content, .readerCatalog, .readerNotePanel,
        .reader_float_panel_container:not(.reader_float_review_writer_content)) {
      width: 600px !important; max-width: calc(100vw - 48px) !important;
      box-sizing: border-box; font-size: 20px !important;
    }
    :is(.font-panel-content, .reader_float_panel_container) {
      max-height: calc(100vh - 96px) !important; overflow: auto;
    }
    .font-panel-content {
      position: fixed !important; top: 80px !important; bottom: 24px !important;
      right: 96px !important; left: auto !important; height: auto !important;
      max-height: calc(100vh - 104px) !important;
      max-width: calc(100vw - 120px) !important;
    }
    @media (max-height: 680px) {
      .readerControls { --paperlike-control-size: 56px; top: 72px !important; gap: 6px !important; }
      .readerControls .readerControls_item > .icon,
      .readerControls .readerControls_item > svg { transform: scale(1.1); }
    }
    :is(.font-panel-content, .readerCatalog, .readerNotePanel, .reader_float_panel_container)
      :where(*:not(svg):not(svg *):not(.icon):not([class*="icon"]):not(.ls-font)) {
      font-size: 20px !important; line-height: 1.5 !important;
    }
    :is(.font-panel-content, .readerCatalog, .readerNotePanel, .reader_float_panel_container)
      :is(button, input, select, textarea, [role="button"]) {
      min-height: 48px !important; box-sizing: border-box;
    }
    .font-panel-content-inner, .font-panel-content_sticky { width: auto !important; }
    .font-panel-content-fonts { grid-template-columns: repeat(3, minmax(0, 1fr)) !important; gap: 12px !important; }
    .font-panel-content-fonts-item {
      width: auto !important; height: 64px !important; min-height: 64px;
      padding: 8px; box-sizing: border-box;
    }
    .font-panel-content-fonts-item svg { width: 160px !important; max-width: 100%; height: 36px !important; }
    .font-panel-content-fonts-tab-item { min-height: 48px; display: flex; align-items: center; justify-content: center; }
    .font-panel-content-inner { display: block; height: auto !important; }
    .font-panel-content_sticky {
      height: auto !important; min-height: 0 !important; flex-shrink: 0;
      z-index: 5; background: white !important; padding-bottom: 16px;
      border-bottom: 2px solid black;
    }
    .font-panel-content .font-panel-content-title:first-child {
      font-size: 26px !important; font-weight: 700; color: black !important;
    }
    .font-panel-content-size-wrapper {
      padding: 14px; border: 2px solid black; border-radius: 8px;
      box-sizing: border-box; background: white !important;
    }
    .font-panel-content .font-panel-content-size-wrapper::before {
      content: "当前字号  " attr(data-paperlike-font-size);
      display: block; margin-bottom: 12px; color: black !important;
      font-size: 30px !important; font-weight: 800; line-height: 1.5;
    }
    .font-panel-content .font-panel-content-size-wrapper::after {
      content: "小字号 ← 点击或拖动滑块 → 大字号"; display: block;
      margin-top: 8px; font-size: 18px !important; font-weight: 600; color: black !important;
    }
    .reader_font_control_slider_wrapper {
      display: block !important; width: 100% !important;
      min-height: 56px; padding: 12px 0; box-sizing: border-box;
      background: white !important;
    }
    .reader_font_control_slider_track {
      display: block !important; width: 100% !important; height: 32px !important;
      border-radius: 8px; outline: 2px solid black; background: #e4e4e4 !important;
    }
    .reader_font_control_slider_track_progress { background: #aaa !important; }
    .reader_font_control_slider_track_level_dot {
      opacity: 1 !important; visibility: visible !important; background: black !important;
    }
    .reader_font_control_slider_dot {
      background: black !important; border: 2px solid white;
      outline: 2px solid black; box-sizing: border-box;
    }
    .readerCatalog_list_item_inner { min-height: 56px; padding-top: 12px !important; padding-bottom: 12px !important; box-sizing: border-box; }
    .readerCatalog_list_item_title_text { white-space: normal !important; overflow-wrap: anywhere; }
    :is(.reader_float_panel_header_closeBtn, .reader_float_panel_header_backBtn,
        .wr_reader_note_panel_footer_button) { min-width: 48px !important; min-height: 48px !important; }
  `;
  (document.head || document.documentElement).appendChild(controlsStyle);
  const layoutStyle = document.createElement('style');
  layoutStyle.id = 'paperlike-layout-style';
  (document.head || document.documentElement).appendChild(layoutStyle);
  const pulseStyle = document.createElement('style');
  pulseStyle.id = 'paperlike-layout-reflow';
  (document.head || document.documentElement).appendChild(pulseStyle);
  const layout = {margin: 0, lineHeight: 0};
  let layoutRoot = null;
  let layoutMode = null;
  let defaultLineHeight = 1.5;
  let effectiveMargin = 0;
  let reflowTimer = null;
  let pulseTimer = null;
  let pendingReflow = false;
  const ownResizeEvents = new WeakSet();
  const dispatchResize = () => {
    const event = new Event('resize');
    ownResizeEvents.add(event);
    window.dispatchEvent(event);
  };
  const readerReady = () => [...document.querySelectorAll('.renderTarget_pager_button_right, .readerFooter_button')]
    .some(el => el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden');
  const queueReflow = () => {
    pendingReflow = true;
    if (!readerReady() || reflowTimer !== null || pulseTimer !== null) return;
    reflowTimer = setTimeout(() => {
      reflowTimer = null;
      if (!readerReady()) return;
      pendingReflow = false;
      // Use the reader's normal resize/recollect path to preserve pagination
      // and reading position; resizing the finished bitmap would distort text.
      if (document.querySelector('.wr_horizontalReader')) {
        dispatchResize();
        // Shrinking line height can leave the previous page index past the
        // last rendered page. A second layout pass normalizes that index.
        pulseTimer = setTimeout(() => {
          pulseTimer = null;
          dispatchResize();
        }, 900);
      } else {
        // The vertical reader ignores resize notifications when width has not
        // changed. Briefly change the measured width, then restore it exactly.
        const root = document.querySelector('.readerChapterContent');
        if (!root) return;
        const width = parseFloat(getComputedStyle(root).width);
        pulseStyle.textContent = `.readerChapterContent { width: ${Math.max(180, width - 2)}px !important; }`;
        dispatchResize();
        pulseTimer = setTimeout(() => {
          pulseStyle.textContent = '';
          pulseTimer = null;
          pendingReflow = false;
          dispatchResize();
        }, 650);
      }
    }, 180);
  };
  const applyLayout = (reflow = false) => {
    const root = document.querySelector('.readerChapterContent');
    if (!root || !location.pathname.startsWith('/web/reader/')) return false;
    const horizontal = !!document.querySelector('.wr_horizontalReader');
    // Measure the website's current responsive width without our override.
    // This avoids hard-coding desktop widths or accumulating adjustments.
    layoutStyle.disabled = true;
    pulseStyle.disabled = true;
    const natural = getComputedStyle(root);
    const width = parseFloat(natural.width);
    const padding = parseFloat(natural.paddingLeft) + parseFloat(natural.paddingRight);
    const fontSize = parseFloat(natural.fontSize);
    const source = document.querySelector('#preRenderContent, #preRenderContents') || root;
    const sourceStyle = getComputedStyle(source);
    const ratio = parseFloat(sourceStyle.lineHeight) / (parseFloat(sourceStyle.fontSize) || fontSize);
    if (layoutRoot !== root && layout.lineHeight === 0 && Number.isFinite(ratio)) defaultLineHeight = Math.min(3, Math.max(1.2, ratio));
    layoutStyle.disabled = false;
    pulseStyle.disabled = false;
    if (!Number.isFinite(width) || width < 100) return false;
    const activeCanvases = [...root.querySelectorAll('.wr_canvasContainer canvas')].filter(canvas =>
      canvas.getClientRects().length && canvas.getBoundingClientRect().width > 0);
    const dualPage = horizontal && (activeCanvases.length ? activeCanvases.length > 1 : width >= 800);
    const minimum = Math.min(width, dualPage ? 720 : 280);
    const maximum = Math.max(width, innerWidth - 128 - padding);
    const adjusted = Math.max(minimum, Math.min(maximum, width - layout.margin * 2));
    effectiveMargin = Math.round((width - adjusted) / 2);
    const rules = [];
    if (layout.margin !== 0) rules.push(`.readerChapterContent { width: ${adjusted}px !important; }`);
    if (layout.lineHeight !== 0) rules.push(`
      html body #preRenderContent, html body #preRenderContent *,
      html body #preRenderContents, html body #preRenderContents * {
        line-height: ${layout.lineHeight} !important;
      }`);
    const css = rules.join('\n');
    if (layoutStyle.textContent !== css) layoutStyle.textContent = css;
    layoutRoot = root;
    layoutMode = horizontal;
    if (reflow) queueReflow();
    return true;
  };
  const syncLayout = () => {
    const root = document.querySelector('.readerChapterContent');
    const horizontal = !!document.querySelector('.wr_horizontalReader');
    if (root && (root !== layoutRoot || horizontal !== layoutMode)) {
      applyLayout(layout.margin !== 0 || layout.lineHeight !== 0);
    }
    if (pendingReflow && readerReady()) queueReflow();
  };
  window.addEventListener('resize', event => {
    if (ownResizeEvents.has(event)) return;
    applyLayout(layout.margin !== 0 || layout.lineHeight !== 0);
  });
  const layoutState = () => ({
    reader: location.pathname.startsWith('/web/reader/') && !!document.querySelector('.readerChapterContent'),
    margin: layout.margin, effectiveMargin, lineHeight: layout.lineHeight,
    defaultLineHeight, horizontal: !!document.querySelector('.wr_horizontalReader'),
    reflowing: pendingReflow || reflowTimer !== null || pulseTimer !== null
  });
  const syncFontSize = () => {
    const wrapper = document.querySelector('.font-panel-content-size-wrapper');
    if (!wrapper) return;
    const panel = wrapper.closest('.font-panel-content');
    if (!panel || !panel.getClientRects().length || getComputedStyle(panel).visibility === 'hidden') return;
    const count = wrapper.querySelectorAll('.reader_font_control_slider_track_level_dot').length || 7;
    const match = document.body.className.match(/\bwr_reader_font_size_level_(\d+)\b/);
    const initial = wrapper.querySelector('[init-level]')?.getAttribute('init-level');
    const level = Number(match?.[1] || initial);
    const label = level >= 1 && level <= count ? `第 ${level} 档 / 共 ${count} 档` : '拖动滑块调节';
    // Keep Vue-owned children intact, including during SSR hydration.
    // CSS renders the label without inserting nodes into the site's component.
    if (wrapper.dataset.paperlikeFontSize !== label) {
      wrapper.dataset.paperlikeFontSize = label;
      wrapper.setAttribute('aria-label', `当前字号：${label}`);
    }
  };
  let fontSizeTimer = null;
  let lastPageState = null;
  const reportReaderState = (force = false) => {
    let state = 'home';
    if (location.pathname.startsWith('/web/reader/')) {
      const ready = [...document.querySelectorAll('.renderTarget_pager_button_right, .readerFooter_button')].some(el =>
        el.getClientRects().length && getComputedStyle(el).visibility !== 'hidden');
      state = ready ? 'ready' : 'loading';
    }
    if (force || state !== lastPageState) {
      lastPageState = state;
      window.webkit?.messageHandlers?.paperlikeStatus?.postMessage(state);
    }
  };
  const controlsObserver = new MutationObserver(() => {
    if (fontSizeTimer !== null) return;
    fontSizeTimer = setTimeout(() => { fontSizeTimer = null; syncFontSize(); syncLayout(); reportReaderState(); }, 50);
  });
  controlsObserver.observe(document.documentElement, {subtree: true, childList: true, attributes: true, attributeFilter: ['class', 'style']});
  syncFontSize();
  const visible = element => element && element.getClientRects().length && getComputedStyle(element).visibility !== 'hidden';
  let themeTimer = null;
  // Use the site's own light-theme route parameter so canvas text is drawn
  // in dark ink too. This also catches reader routes entered through SPA links.
  const ensureLightTheme = () => {
    if (document.documentElement.dataset.paperlikeInk !== 'true' ||
        !location.pathname.startsWith('/web/reader/') ||
        document.body.classList.contains('wr_whiteTheme')) return;
    const control = document.querySelector('button.readerControls_item.white');
    if (visible(control)) {
      const url = new URL(location.href);
      if (url.searchParams.get('wtheme') === 'white') return;
      url.searchParams.set('wtheme', 'white');
      location.replace(url.href);
    }
  };
  const observer = new MutationObserver(() => {
    if (themeTimer !== null) return;
    themeTimer = setTimeout(() => { themeTimer = null; ensureLightTheme(); }, 80);
  });
  window.PaperlikeReader = {
    layoutState,
    setLayout(margin, lineHeight) {
      const nextMargin = Math.max(-60, Math.min(200, Number(margin) || 0));
      const spacing = Number(lineHeight) || 0;
      const nextLineHeight = spacing === 0 ? 0 : Math.max(1.2, Math.min(3, spacing));
      const changed = nextMargin !== layout.margin || nextLineHeight !== layout.lineHeight;
      layout.margin = nextMargin;
      layout.lineHeight = nextLineHeight;
      const applied = applyLayout(changed);
      return {...layoutState(), applied};
    },
    reportState() { reportReaderState(true); },
    setInk(enabled) {
      document.documentElement.dataset.paperlikeInk = String(Boolean(enabled));
      observer.disconnect();
      if (themeTimer !== null) { clearTimeout(themeTimer); themeTimer = null; }
      if (enabled) {
        observer.observe(document.documentElement, {subtree: true, childList: true, attributes: true, attributeFilter: ['class']});
        ensureLightTheme();
      }
      reportReaderState(true);
    },
    turn(direction) {
      const active = document.activeElement;
      if (active && (active.matches('input, textarea, select') || active.isContentEditable)) return 'editing';
      if (!location.pathname.startsWith('/web/reader/')) return 'not-reader';
      // Use site controls only after finding a visible, unambiguous match.
      const selector = direction > 0
        ? '.renderTarget_pager_button_right, .readerFooter_button, .readerControls_item.nextPage, [aria-label="下一页"], [title="下一页"]'
        : '.renderTarget_pager_button:not(.renderTarget_pager_button_right), .readerControls_item.prevPage, [aria-label="上一页"], [title="上一页"]';
      const candidates = [...document.querySelectorAll(selector)].filter(visible).filter(el => !el.matches(':disabled, [aria-disabled="true"]')).filter(el => {
        const text = [el.textContent, el.getAttribute('title'), el.getAttribute('aria-label')].join('');
        return direction > 0 ? /下一页|下一章/.test(text) : /上一页|上一章/.test(text);
      });
      if (candidates.length === 1) { candidates[0].click(); return 'control'; }
      const scroller = document.scrollingElement;
      if (!scroller) return 'unavailable';
      const before = scroller.scrollTop;
      window.scrollBy({top: direction * Math.max(100, window.innerHeight - 100), behavior: 'instant'});
      return scroller.scrollTop !== before ? 'scroll' : 'edge';
    }
  };
})();
