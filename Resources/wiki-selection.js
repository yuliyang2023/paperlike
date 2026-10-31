(() => {
  'use strict';
  if (window.PaperlikeWikiSelection || window !== top || location.origin !== 'https://weread.qq.com') return;
  let selectedText = '';
  const stats = {readers:0, toolbars:0};

  const isReader = () => location.pathname.startsWith('/web/reader/');
  const fromObjects = objects => Array.isArray(objects) ? objects.filter(object => {
    try { return typeof object?.text === 'string' && (typeof object.isTextOrCanvasType !== 'function' || object.isTextOrCanvasType()); }
    catch (_) { return false; }
  }).map(object => object.text).join('').trim() : '';
  const currentText = () => {
    if (!isReader()) return '';
    const selection = getSelection();
    const anchor = selection?.anchorNode?.parentElement;
    const focus = selection?.focusNode?.parentElement;
    if (anchor && focus && !anchor.closest('input,textarea,[contenteditable="true"]') &&
        anchor.closest('.readerChapterContent,.readerContent,.wr_horizontalReader_app_content') &&
        focus.closest('.readerChapterContent,.readerContent,.wr_horizontalReader_app_content')) {
      const text = selection.toString().trim();
      if (text) return text;
    }
    return selectedText;
  };
  const requestSearch = () => {
    const text = currentText();
    if (!text) return false;
    const handler = window.webkit?.messageHandlers?.paperlikeWikiSearch;
    if (!handler) return false;
    handler.postMessage(text);
    return true;
  };
  const patchedOptions = new WeakSet();
  const patchOptions = options => {
    if (!options || typeof options !== 'object' || patchedOptions.has(options)) return;
    const methods = options.methods;
    if (methods && typeof methods.showSelectionToolBar === 'function') {
      const show = methods.showSelectionToolBar;
      methods.showSelectionToolBar = function(value, ...rest) {
        selectedText = fromObjects(value?.objs); return show.call(this, value, ...rest);
      };
      if (typeof methods.clearSelection === 'function') {
        const clear = methods.clearSelection;
        methods.clearSelection = function(...args) { selectedText = ''; return clear.apply(this,args); };
      }
      stats.readers++; patchedOptions.add(options);
    }
    if (options.name === 'ReaderSelectionToolBar' && options.computed?.showItems && methods?.handleClickItem) {
      const items = options.computed.showItems, click = methods.handleClickItem;
      options.computed.showItems = function() {
        const original = (typeof items === 'function' ? items : items.get).call(this);
        return original.concat({key:'paperlikeWiki',type:'paperlikeWiki',text:'Wiki 搜索',classNames:['paperlike_wiki'],requireLogin:false});
      };
      methods.handleClickItem = function(item,...args) {
        if (item?.type !== 'paperlikeWiki') return click.call(this,item,...args);
        if (requestSearch()) this.hide?.();
      };
      if (typeof methods.show === 'function') {
        const show = methods.show;
        methods.show = function(...args) {
          const result = show.apply(this,args);
          this.$nextTick?.(() => this.$el?.setAttribute('data-paperlike-wiki-toolbar','true'));
          return result;
        };
      }
      if (typeof methods.hide === 'function') {
        const hide = methods.hide;
        methods.hide = function(...args) { selectedText = ''; return hide.apply(this,args); };
      }
      stats.toolbars++; patchedOptions.add(options);
    }
  };
  // The site's production build omits DOM-to-Vue references. Adapt only the
  // reader/selection component exports as their normal webpack chunks load.
  const queue = window.webpackJsonp = window.webpackJsonp || [];
  const wrappedFactories = new WeakSet();
  const patchChunk = chunk => {
    const modules = chunk?.[1];
    if (!modules || typeof modules !== 'object') return;
    for (const key of Object.keys(modules)) {
      const factory = modules[key];
      if (typeof factory !== 'function' || wrappedFactories.has(factory)) continue;
      const source = Function.prototype.toString.call(factory);
      if (!source.includes("showSelectionToolBar") && !source.includes("ReaderSelectionToolBar")) continue;
      const wrapped = function(module,...args) {
        const result = factory.call(this,module,...args);
        patchOptions(module.exports?.default); patchOptions(module.exports);
        return result;
      };
      wrappedFactories.add(wrapped); modules[key] = wrapped;
    }
  };
  queue.forEach(patchChunk);
  let push = queue.push;
  Object.defineProperty(queue,'push',{configurable:true,
    get() { const delegate = push; return function(...chunks) { chunks.forEach(patchChunk); return delegate.apply(this,chunks); }; },
    set(next) { push = next; }
  });
  const style = document.createElement('style');
  style.textContent = `
    html body .reader_toolbar_container[data-paperlike-wiki-toolbar] .reader_toolbar_itemContainer { grid-template-columns: repeat(7,minmax(88px,1fr)) !important; }
    .paperlike_wiki .toolbarItem_icon { background: none !important; width: 28px !important; height: 28px !important; }
    .paperlike_wiki .toolbarItem_icon::before { content: 'W'; display: block; font: 700 26px/28px Georgia,serif; color: black; text-align: center; }
    @media(max-width:799px) { html body .reader_toolbar_container[data-paperlike-wiki-toolbar] .reader_toolbar_itemContainer { grid-template-columns: repeat(4,minmax(88px,1fr)) !important; } }
    @media(max-width:439px) { html body .reader_toolbar_container[data-paperlike-wiki-toolbar] .reader_toolbar_itemContainer { grid-template-columns: repeat(3,minmax(88px,1fr)) !important; } }
  `;
  const attachStyle = () => { if (!style.isConnected && document.documentElement) (document.head || document.documentElement).appendChild(style); };
  attachStyle();
  window.PaperlikeWikiSelection = {currentText, requestSearch, stats};
  addEventListener('DOMContentLoaded', attachStyle);
})();
