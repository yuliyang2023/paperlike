(() => {
  'use strict';
  if (window.PaperlikeWiki || location.protocol !== 'https:' ||
      !(location.hostname === 'wikipedia.org' || location.hostname.endsWith('.wikipedia.org'))) return;
  const style = document.createElement('style');
  style.id = 'paperlike-wiki-style';
  style.textContent = `
    html { color-scheme: light !important; background: white !important; }
    body { background: white !important; color: black !important; font-size: 22px !important; line-height: 1.85 !important; }
    *, *::before, *::after {
      color: black !important; text-shadow: none !important; box-shadow: none !important;
      animation-duration: 0.001s !important; animation-delay: 0s !important;
      transition-duration: 0.001s !important; scroll-behavior: auto !important;
    }
    /* Only paint known page surfaces; transparent overlays must stay transparent. */
    :is(.mw-page-container, .mw-page-container-inner, .mw-body, .vector-header-container,
      .vector-header, .mw-content-container, .mw-parser-output, .mw-search-results) { background: white !important; }
    .mw-page-container { max-width: 1400px !important; margin-inline: auto !important; padding: 20px 28px !important; }
    .mw-page-container-inner { display: block !important; }
    .vector-column-start, .vector-column-end { display: none !important; }
    .mw-content-container { max-width: 1040px !important; margin-inline: auto !important; width: auto !important; }
    :is(.mw-body-content, .mw-parser-output, .searchresults, .mw-search-results, .searchresult) {
      font-size: 22px !important; line-height: 1.85 !important; overflow-wrap: anywhere;
    }
    .mw-parser-output :is(p, li, dd, dt, blockquote), .searchresult { font-size: 22px !important; line-height: 1.85 !important; }
    :is(.vector-header, .vector-page-toolbar, .vector-dropdown-content) a {
      font-size: 20px !important; line-height: 1.6 !important;
    }
    .vector-header { flex-wrap: wrap !important; gap: 12px; }
    :is(.vector-dropdown-content, .cdx-menu) { background: white !important; border: 2px solid black !important; max-height: 75vh; overflow-y: auto; }
    h1, .firstHeading { font-size: 32px !important; line-height: 1.5 !important; }
    h2 { font-size: 28px !important; line-height: 1.5 !important; border-bottom: 2px solid black !important; }
    h3, .mw-search-result-heading { font-size: 24px !important; line-height: 1.6 !important; }
    :is(.mw-search-result-data, .reference, .references, .reflist, .mw-footer) { font-size: 18px !important; line-height: 1.7 !important; }
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
    @media (max-width: 700px) { .mw-page-container { padding: 16px !important; } }
  `;
  (document.head || document.documentElement).appendChild(style);
  window.PaperlikeWiki = {ready: true};
})();
