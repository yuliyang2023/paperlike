(() => {
  'use strict';
  if (window.PaperlikeAI) return;
  const siteOrigin = 'https://weread.qq.com';
  let currentURL = location;
  // Same-origin srcdoc frames inherit the reader's origin. Keep this scoped
  // to the site's named AI iframe; login and unrelated frames stay untouched.
  if (location.href === 'about:srcdoc') {
    try {
      if (parent.location.origin !== siteOrigin || !frameElement?.matches('iframe.readerAIChatPanel_frame')) return;
      currentURL = new URL(document.baseURI);
    } catch (_) { return; }
  }
  if (currentURL.origin !== siteOrigin) return;
  const chatFrame = /^\/winktemplate\/multi-turn(?:\/|$)/.test(currentURL.pathname);
  const reader = window === window.top && location.pathname.startsWith('/web/reader/');
  if (!chatFrame && !reader) return;
  const root = document.documentElement;
  const style = document.createElement('style');
  style.id = 'paperlike-ai-style';
  style.textContent = chatFrame ? `
    html { font-size: 20px !important; }
    body { font-size: 20px !important; line-height: 1.7 !important; }
    :is([class*="markdown-body"], [class*="UserMessage_text"], [class*="BotMessage_container"]) {
      font-size: 20px !important; line-height: 1.75 !important;
      overflow-wrap: anywhere; max-width: 100%;
    }
    [class*="markdown-body"] :is(p, li, div, span, blockquote, td, th) {
      font-size: inherit !important; line-height: inherit !important;
    }
    [class*="markdown-body"] :is(h1,h2,h3,h4) { font-size: 24px !important; line-height: 1.5 !important; }
    [class*="UserMessage_reference"], [class*="model_hint"], [class*="ChatMessageButtons_model_hint"] {
      font-size: 18px !important; line-height: 1.6 !important;
    }
    :is([class*="ChatSuggestion_question_item"], [class*="FollowSuggestion_item"], [class*="ChatInputHelper_item"]) {
      box-sizing: border-box; min-height: 52px !important; padding: 12px 14px !important;
      font-size: 20px !important; line-height: 1.5 !important;
      white-space: normal !important; overflow-wrap: anywhere;
      max-width: 100%; flex-shrink: 1 !important;
    }
    :is([class*="ChatInputHelper_content_container"], [class*="BotMessage_button_group"], [class*="ChatMessageButtons_button_group"]) {
      display: flex; flex-wrap: wrap !important; gap: 10px !important;
    }
    :is(button, [role="button"], [class*="ChatMenuButton_more_menu"], [class*="markdown-text-sender_copy_button"]) {
      box-sizing: border-box; min-width: 48px !important; min-height: 48px !important;
      font-size: 20px !important;
    }
    [class*="ChatMenuButton_more_menu"] { width: auto !important; height: auto !important; min-width: 64px !important; padding: 8px 12px !important; white-space: nowrap; }
    :is(input, textarea, [contenteditable="true"]) { font-size: 20px !important; line-height: 1.6 !important; }
    [class*="markdown-body"] pre { overflow-x: auto; }
    html[data-paperlike-ai-ink="true"] {
      color-scheme: light !important; background: white !important;
      --WR_BC3: #000; --WR_BC5: #111; --WR_BC15: #000; --WR_BC31: #fff;
    }
    html[data-paperlike-ai-ink="true"] body { background: white !important; color: black !important; }
    html[data-paperlike-ai-ink="true"] * {
      color: black !important; text-shadow: none !important; box-shadow: none !important;
      background-image: none !important;
      animation-duration: 0.001s !important; animation-delay: 0s !important; animation-iteration-count: 1 !important;
      transition-duration: 0.001s !important; scroll-behavior: auto !important;
    }
    html[data-paperlike-ai-ink="true"] :is([class*="container"], [class*="content"], [class*="UserMessage_background"],
        [class*="UserMessage_card"], [class*="ChatSuggestion_question_item"], [class*="FollowSuggestion_item"], [class*="ChatInputHelper_item"]) {
      background-color: white !important;
    }
    html[data-paperlike-ai-ink="true"] :is([class*="UserMessage_card"], [class*="ChatSuggestion_question_item"],
        [class*="FollowSuggestion_item"], [class*="ChatInputHelper_item"], button, [role="button"],
        [class*="ChatMenuButton_more_menu"], [class*="markdown-text-sender_copy_button"]) {
      border: 2px solid black !important; border-radius: 8px !important;
      background-color: white !important;
    }
    html[data-paperlike-ai-ink="true"] :is([class*="ChatSuggestion_question_item"], [class*="FollowSuggestion_item"])::after {
      border: 0 !important;
    }
    html[data-paperlike-ai-ink="true"] a { color: black !important; text-decoration: underline !important; text-underline-offset: 3px; }
    html[data-paperlike-ai-ink="true"] :focus-visible { outline: 3px solid black !important; outline-offset: 2px; }
    html[data-paperlike-ai-ink="true"] :is([disabled], [aria-disabled="true"]) { opacity: 1 !important; border-style: dashed !important; }
  ` : `
    html body .readerAIChatPanel {
      left: auto !important; right: 96px !important; top: 16px !important; bottom: 16px !important;
      margin-left: 0 !important; width: 760px !important; max-width: calc(100vw - 120px) !important;
      box-sizing: border-box; font-size: 20px !important; border-radius: 10px !important;
    }
    html body .readerAIChatPanel .readerAIChatPanel {
      position: static !important; inset: auto !important; margin: 0 !important;
      width: 100% !important; max-width: 100% !important; height: 100% !important;
      border: 0 !important; box-shadow: none !important;
    }
    .readerAIChatPanel_header_title { font-size: 22px !important; line-height: 1.5 !important; }
    .readerAIChatPanel_header { flex-shrink: 0; padding: 14px 18px !important; }
    .readerAIChatPanel_header_icon { transform: scale(1.25); transform-origin: left center; margin: 6px 0 !important; }
    .readerAIChatPanel_header_subtitle, .readerAIChatPanel_header_subtitle_link,
    .readerAIChatPanel_header_subtitle_link * { font-size: 20px !important; line-height: 1.5 !important; }
    .readerAIChatPanel_container { min-height: 0 !important; flex: 1 !important; }
    .readerAIChatPanel_frame { min-height: 0 !important; flex: 1 1 0% !important; height: 0 !important; width: 100% !important; }
    .readerAIChatPanel_footer { flex-shrink: 0 !important; padding: 12px 16px 16px !important; }
    .readerAIChatPanel_footer_inputContainer { box-sizing: border-box; gap: 14px !important; padding: 12px !important; }
    .readerAIChatPanel_footer_textarea {
      font-size: 22px !important; line-height: 1.6 !important; min-height: 44px !important;
      max-height: 160px !important; min-width: 0 !important; resize: none;
    }
    .readerAIChatPanel_footer_sendButton_container { flex-shrink: 0 !important; }
    .readerAIChatPanel_footer_sendButton {
      box-sizing: border-box; width: 56px !important; height: 56px !important;
      min-width: 56px !important; min-height: 56px !important;
    }
    @media (max-width: 700px) {
      html body .readerAIChatPanel { right: 16px !important; max-width: calc(100vw - 32px) !important; }
    }
    @media (max-height: 400px) {
      html body .readerAIChatPanel { top: 8px !important; bottom: 8px !important; }
      .readerAIChatPanel_header { padding: 4px 12px !important; }
      .readerAIChatPanel_header_icon { margin: 0 !important; }
      .readerAIChatPanel_footer { padding: 6px !important; }
      .readerAIChatPanel_footer_inputContainer { padding: 6px !important; }
      .readerAIChatPanel_footer_textarea { max-height: 56px !important; }
    }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel {
      background: white !important; color: black !important; border: 2px solid black !important; box-shadow: none !important;
    }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel .readerAIChatPanel { border: 0 !important; }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel :is(.readerAIChatPanel_header, .readerAIChatPanel_container, .readerAIChatPanel_footer) {
      background: white !important; color: black !important;
    }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel_header { border-bottom: 2px solid black !important; }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel_header_subtitle_link,
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel_header_subtitle_link * { color: black !important; }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel_footer_inputContainer,
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel_footer_sendButton {
      background: white !important; color: black !important; border: 2px solid black !important; box-shadow: none !important;
    }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel_footer_textarea { background: white !important; color: black !important; caret-color: black; }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel_footer_textarea::placeholder { color: #222 !important; opacity: 1; }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel_header_icon,
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel_footer_sendButton_icon { filter: grayscale(1) brightness(0); }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel_footer_sendButton.disabled { opacity: 1 !important; border-style: dashed !important; }
    html[data-paperlike-ai-ink="true"] .readerAIChatPanel :focus-visible { outline: 3px solid black !important; outline-offset: 2px; }
  `;
  (document.head || root).appendChild(style);
  let ink = true;
  const syncFrame = frame => {
    try {
      if (frame.srcdoc || new URL(frame.src, location.href).origin === siteOrigin) {
        frame.contentWindow?.postMessage({type: 'paperlike-ai-theme', enabled: ink}, siteOrigin);
      }
    } catch (_) {}
  };
  const boundFrames = new WeakSet();
  const syncFrames = () => {
    if (!reader) return;
    for (const frame of document.querySelectorAll('iframe.readerAIChatPanel_frame')) {
      if (!boundFrames.has(frame)) {
        frame.addEventListener('load', () => syncFrame(frame));
        boundFrames.add(frame);
        syncFrame(frame);
      }
    }
  };
  window.PaperlikeAI = {
    setInk(enabled) {
      ink = Boolean(enabled);
      root.dataset.paperlikeAiInk = String(ink);
      if (reader) {
        syncFrames();
        document.querySelectorAll('iframe.readerAIChatPanel_frame').forEach(syncFrame);
      }
    }
  };
  if (reader) {
    new MutationObserver(syncFrames).observe(document.documentElement, {childList: true, subtree: true});
    syncFrames();
  } else {
    root.dataset.paperlikeAiFrame = 'true';
    window.addEventListener('message', event => {
      if (event.origin !== siteOrigin || event.source !== window.parent || event.data?.type !== 'paperlike-ai-theme') return;
      if (typeof event.data.enabled === 'boolean') window.PaperlikeAI.setInk(event.data.enabled);
    });
  }
  window.PaperlikeAI.setInk(true);
})();
