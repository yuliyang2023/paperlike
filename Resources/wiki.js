(() => {
  'use strict';
  if (window.PaperlikeWiki || location.protocol !== 'https:' ||
      !(location.hostname === 'wikipedia.org' || location.hostname.endsWith('.wikipedia.org'))) return;
  const style = document.createElement('style');
  style.id = 'paperlike-wiki-style';
  style.textContent = `
    html { color-scheme: light !important; background: white !important; }
    body { background: white !important; color: black !important; font-size: var(--paperlike-wiki-font, 28px) !important; line-height: 1.85 !important; }
    *, *::before, *::after {
      color: black !important; text-shadow: none !important; box-shadow: none !important;
      animation-duration: 0.001s !important; animation-delay: 0s !important;
      transition-duration: 0.001s !important; scroll-behavior: auto !important;
    }
    /* Only paint known page surfaces; transparent overlays must stay transparent. */
    :is(.mw-page-container, .mw-page-container-inner, .mw-body, .vector-header-container,
      .vector-header, .mw-content-container, .mw-parser-output, .mw-search-results) { background: white !important; }
    .mw-page-container { box-sizing: border-box !important; width: 100% !important; max-width: none !important; margin: 0 !important; padding: 20px var(--paperlike-wiki-margin, 60px) !important; }
    .mw-page-container-inner { display: block !important; padding: 0 !important; }
    .mw-body { box-sizing: border-box !important; width: 100% !important; max-width: none !important; margin: 0 !important; padding: 0 !important; }
    .vector-column-start, .vector-column-end { display: none !important; }
    .mw-content-container { box-sizing: border-box !important; max-width: none !important; margin: 0 !important; width: 100% !important; }
    :is(.mw-body-content, .mw-parser-output, .searchresults, .mw-search-results, .searchresult) {
      font-size: var(--paperlike-wiki-font, 28px) !important; line-height: 1.85 !important; overflow-wrap: anywhere;
    }
    .mw-parser-output :is(p, li, dd, dt, blockquote), .searchresult { font-size: var(--paperlike-wiki-font, 28px) !important; line-height: 1.85 !important; }
    #mw-content-text :is(p, li, dd, dt, blockquote, td, th, div, span, a, small) {
      font-size: var(--paperlike-wiki-font, 28px) !important; line-height: 1.85 !important;
    }
    #mw-content-text .mw-search-result-heading, #mw-content-text .mw-search-result-heading * {
      font-size: var(--paperlike-wiki-h3, 30px) !important; line-height: 1.6 !important;
    }
    #mw-content-text :is(h1, h2, h3, h4) * { font-size: inherit !important; line-height: inherit !important; }
    #mw-content-text :is(.reference, .references, .reflist), #mw-content-text :is(.reference, .references, .reflist) * {
      font-size: var(--paperlike-wiki-note, 24px) !important; line-height: 1.7 !important;
    }
    :is(.vector-header, .vector-page-toolbar, .vector-dropdown-content) a {
      font-size: 20px !important; line-height: 1.6 !important;
    }
    .vector-header { flex-wrap: wrap !important; gap: 12px; }
    :is(.vector-dropdown-content, .cdx-menu) { background: white !important; border: 2px solid black !important; max-height: 75vh; overflow-y: auto; }
    h1, .firstHeading { font-size: var(--paperlike-wiki-h1, 40px) !important; line-height: 1.5 !important; }
    h2 { font-size: var(--paperlike-wiki-h2, 34px) !important; line-height: 1.5 !important; border-bottom: 2px solid black !important; }
    h3, .mw-search-result-heading { font-size: var(--paperlike-wiki-h3, 30px) !important; line-height: 1.6 !important; }
    :is(.mw-search-result-data, .reference, .references, .reflist, .mw-footer) { font-size: var(--paperlike-wiki-note, 24px) !important; line-height: 1.7 !important; }
    :is(.mw-body, #mw-content-text) a { color: black !important; text-decoration: underline !important; text-underline-offset: 3px; }
    .mw-search-result { padding: 16px 0 !important; border-bottom: 2px solid black !important; }
    .mw-search-result-heading a { display: inline-block; min-height: 48px; font-weight: 700; }
    :is(button, input[type="submit"], .cdx-button, .mw-ui-button) {
      min-height: 48px !important; min-width: 48px !important; font-size: 20px !important;
      border: 2px solid black !important; background: white !important; border-radius: 6px !important;
    }
    :is(input[type="text"], input[type="search"], textarea, select) {
      min-height: 48px !important; font-size: 22px !important; color: black !important;
      background: white !important; border: 2px solid black !important; box-sizing: border-box;
    }
    ::selection { background: black !important; color: white !important; }
    :focus-visible { outline: 3px solid black !important; outline-offset: 2px; }
    :is(button, input)[disabled] { opacity: 1 !important; border-style: dashed !important; }
    :is(.infobox, .sidebar) { float: none !important; max-width: 100% !important; margin: 16px 0 !important; }
    :is(.infobox, .wikitable, .ambox, .toc) { background: white !important; border: 2px solid black !important; }
    #mw-content-text :is(td, th) { background-color: white !important; color: black !important; border-color: black !important; }
    :is(img, video) { max-width: 100%; height: auto; filter: grayscale(1) contrast(1.1); }
    .mw-parser-output { overflow-x: auto; }

  `;
  (document.head || document.documentElement).appendChild(style);
  const root = document.documentElement;
  let fontSize = 28, margin = 60;
  const apply = () => {
    const effectiveMargin = Math.min(margin, Math.max(0, Math.floor((innerWidth - 320) / 2)));
    root.style.setProperty('--paperlike-wiki-font', `${fontSize}px`);
    root.style.setProperty('--paperlike-wiki-margin', `${effectiveMargin}px`);
    root.style.setProperty('--paperlike-wiki-h1', `${Math.round(fontSize * 1.45)}px`);
    root.style.setProperty('--paperlike-wiki-h2', `${Math.round(fontSize * 1.2)}px`);
    root.style.setProperty('--paperlike-wiki-h3', `${fontSize + 2}px`);
    root.style.setProperty('--paperlike-wiki-note', `${Math.max(20, fontSize - 4)}px`);
    return {fontSize, margin, effectiveMargin};
  };
  window.PaperlikeWiki = {
    ready: true,
    setLayout(font, padding) {
      if (Number.isFinite(font)) fontSize = Math.min(48, Math.max(20, Math.round(font)));
      if (Number.isFinite(padding)) margin = Math.min(240, Math.max(0, Math.round(padding)));
      return apply();
    },
    layoutState: apply
  };
  addEventListener('resize', apply);
  apply();
})();
