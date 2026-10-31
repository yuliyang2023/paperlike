#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <CoreGraphics/CoreGraphics.h>

static NSString * const HomeURL = @"https://weread.qq.com/";

@interface ReaderApp : NSObject <NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>
@property NSWindow *window;
@property WKWebView *webView;
@property NSTextField *status;
@property NSButton *inkButton;
@property NSButton *zoomLabel;
@property NSProgressIndicator *progress;
@property BOOL ink;
@property double zoom;
@property BOOL selfTest;
@property BOOL smokeTest;
@property BOOL readerTest;
@property BOOL loadFailed;
@property id keyMonitor;
- (void)home:(id)sender;
- (void)reload:(id)sender;
- (void)previous:(id)sender;
- (void)next:(id)sender;
- (void)zoomIn:(id)sender;
- (void)zoomOut:(id)sender;
- (void)resetZoom:(id)sender;
- (void)toggleInk:(id)sender;
- (void)moveToPaperlike:(id)sender;
- (void)fullScreen:(id)sender;
- (void)help:(id)sender;
@end

@implementation ReaderApp
- (NSButton *)button:(NSString *)title action:(SEL)action tooltip:(NSString *)tooltip {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleRegularSquare;
    button.controlSize = NSControlSizeLarge;
    button.font = [NSFont systemFontOfSize:20 weight:NSFontWeightMedium];
    CGFloat titleWidth = [title sizeWithAttributes:@{NSFontAttributeName: button.font}].width;
    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintEqualToConstant:56],
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:MAX(80, ceil(titleWidth) + 32)]
    ]];
    button.toolTip = tooltip;
    [button setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    return button;
}
- (void)addMenu:(NSMenu *)menu title:(NSString *)title action:(SEL)action key:(NSString *)key {
    NSMenuItem *item = [menu addItemWithTitle:title action:action keyEquivalent:key];
    item.target = self;
}
- (void)buildMenus {
    NSMenu *main = [[NSMenu alloc] initWithTitle:@""];
    NSMenuItem *appItem = [main addItemWithTitle:@"墨读" action:nil keyEquivalent:@""];
    NSMenu *app = [[NSMenu alloc] initWithTitle:@"墨读"];
    appItem.submenu = app;
    [self addMenu:app title:@"使用说明" action:@selector(help:) key:@"?"];
    [app addItem:NSMenuItem.separatorItem];
    [app addItemWithTitle:@"退出墨读" action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenuItem *editItem = [main addItemWithTitle:@"编辑" action:nil keyEquivalent:@""];
    NSMenu *edit = [[NSMenu alloc] initWithTitle:@"编辑"];
    editItem.submenu = edit;
    [edit addItemWithTitle:@"撤销" action:@selector(undo:) keyEquivalent:@"z"];
    [edit addItemWithTitle:@"剪切" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"复制" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"粘贴" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:@"全选" action:@selector(selectAll:) keyEquivalent:@"a"];
    NSMenuItem *viewItem = [main addItemWithTitle:@"阅读" action:nil keyEquivalent:@""];
    NSMenu *view = [[NSMenu alloc] initWithTitle:@"阅读"];
    viewItem.submenu = view;
    [self addMenu:view title:@"微信读书首页 / 书架入口" action:@selector(home:) key:@"h"];
    [self addMenu:view title:@"重新载入" action:@selector(reload:) key:@"r"];
    [view addItem:NSMenuItem.separatorItem];
    [self addMenu:view title:@"上一屏" action:@selector(previous:) key:@"["];
    [self addMenu:view title:@"下一屏" action:@selector(next:) key:@"]"];
    [self addMenu:view title:@"放大" action:@selector(zoomIn:) key:@"="];
    [self addMenu:view title:@"缩小" action:@selector(zoomOut:) key:@"-"];
    [self addMenu:view title:@"重置缩放" action:@selector(resetZoom:) key:@"0"];
    [self addMenu:view title:@"切换墨水模式" action:@selector(toggleInk:) key:@"i"];
    [self addMenu:view title:@"移到 Paperlike" action:@selector(moveToPaperlike:) key:@"p"];
    [self addMenu:view title:@"全屏" action:@selector(fullScreen:) key:@"f"];
    NSApp.mainMenu = main;
}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.selfTest = [NSProcessInfo.processInfo.arguments containsObject:@"--self-test"];
    self.readerTest = [NSProcessInfo.processInfo.arguments containsObject:@"--reader-test"];
    self.smokeTest = self.readerTest || [NSProcessInfo.processInfo.arguments containsObject:@"--smoke-test"];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults registerDefaults:@{@"ink": @YES, @"zoom": @1.0}];
    self.ink = [defaults boolForKey:@"ink"];
    if (self.readerTest) self.ink = YES;
    self.zoom = fmin(1.8, fmax(0.8, [defaults doubleForKey:@"zoom"]));
    [self buildMenus];
    self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1100, 800)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title = @"墨读 · Paperlike";
    self.window.minSize = NSMakeSize(820, 560);
    self.window.delegate = self;
    self.window.releasedWhenClosed = NO;
    self.window.collectionBehavior = NSWindowCollectionBehaviorFullScreenPrimary;
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    [self.window center];
    [self.window setFrameAutosaveName:@"ReaderWindow"];

    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    [config.userContentController addScriptMessageHandler:self name:@"paperlikeStatus"];
    config.websiteDataStore = (self.selfTest || self.smokeTest) ? WKWebsiteDataStore.nonPersistentDataStore : WKWebsiteDataStore.defaultDataStore;
    if (self.readerTest) {
        NSString *diagnostics = @"window.PaperlikeDiagnostics=[]; addEventListener('error', e => { if(PaperlikeDiagnostics.length<10) PaperlikeDiagnostics.push({kind:'error',message:e.message,line:e.lineno}); }); addEventListener('unhandledrejection', e => { if(PaperlikeDiagnostics.length<10) PaperlikeDiagnostics.push({kind:'rejection',message:String(e.reason && e.reason.message || 'unhandled rejection')}); });";
        [config.userContentController addUserScript:[[WKUserScript alloc] initWithSource:diagnostics injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
    }
    NSURL *scriptURL = [NSBundle.mainBundle URLForResource:@"ink" withExtension:@"js"];
    NSString *script = [NSString stringWithContentsOfURL:scriptURL encoding:NSUTF8StringEncoding error:nil];
    if (!script) { fprintf(stderr, "Missing ink.js\n"); exit(1); }
    NSString *initialScript = [script stringByAppendingFormat:@"\nwindow.PaperlikeReader.setInk(%@);", self.ink ? @"true" : @"false"];
    [config.userContentController addUserScript:[[WKUserScript alloc] initWithSource:initialScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES]];
    self.webView = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:config];
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = NO;
    self.webView.pageZoom = self.zoom;

    NSButton *home = [self button:@"首页" action:@selector(home:) tooltip:@"微信读书首页，登录后进入书架（⌘H）"];
    NSButton *reload = [self button:@"重载" action:@selector(reload:) tooltip:@"重新载入网页（⌘R）"];
    NSButton *previous = [self button:@"← 上一屏" action:@selector(previous:) tooltip:@"向上翻一屏（⌘[）"];
    NSButton *next = [self button:@"下一屏 →" action:@selector(next:) tooltip:@"向下翻一屏（⌘]）"];
    NSButton *smaller = [self button:@"−" action:@selector(zoomOut:) tooltip:@"缩小页面（⌘−）"];
    self.zoomLabel = [self button:@"100%" action:@selector(resetZoom:) tooltip:@"重置页面缩放（⌘0）；正文字号可在微信读书内设置"];
    NSButton *larger = [self button:@"＋" action:@selector(zoomIn:) tooltip:@"放大页面（⌘+）"];
    self.inkButton = [self button:@"墨水模式 ✓" action:@selector(toggleInk:) tooltip:@"灰度、高对比、减少动画（⌘I）"];
    [self.inkButton.widthAnchor constraintGreaterThanOrEqualToConstant:176].active = YES;
    NSButton *screen = [self button:@"移到 Paperlike" action:@selector(moveToPaperlike:) tooltip:@"定位已连接的 Paperlike 显示器（⌘P）"];
    NSButton *full = [self button:@"全屏" action:@selector(fullScreen:) tooltip:@"切换全屏（⌘F）"];
    NSStackView *toolbar = [NSStackView stackViewWithViews:@[home, reload, previous, next, smaller, self.zoomLabel, larger, self.inkButton, screen, full]];
    toolbar.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    toolbar.alignment = NSLayoutAttributeCenterY;
    toolbar.spacing = 12;
    toolbar.edgeInsets = NSEdgeInsetsMake(12, 16, 12, 16);
    // Keep the large controls in one row; narrow windows can scroll horizontally.
    NSSize toolbarSize = toolbar.fittingSize;
    toolbar.frame = NSMakeRect(0, 0, ceil(toolbarSize.width), 80);
    NSScrollView *toolbarScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    toolbarScroll.documentView = toolbar;
    toolbarScroll.hasHorizontalScroller = YES;
    toolbarScroll.hasVerticalScroller = NO;
    toolbarScroll.autohidesScrollers = YES;
    toolbarScroll.scrollerStyle = NSScrollerStyleOverlay;
    toolbarScroll.drawsBackground = YES;
    toolbarScroll.backgroundColor = NSColor.windowBackgroundColor;
    toolbarScroll.borderType = NSNoBorder;

    self.status = [NSTextField labelWithString:@"正在连接微信读书…"];
    self.status.font = [NSFont systemFontOfSize:15];
    self.status.textColor = NSColor.blackColor;
    self.status.lineBreakMode = NSLineBreakByTruncatingTail;
    self.progress = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    self.progress.style = NSProgressIndicatorStyleSpinning;
    self.progress.controlSize = NSControlSizeSmall;
    self.progress.displayedWhenStopped = NO;
    NSStackView *footer = [NSStackView stackViewWithViews:@[self.progress, self.status]];
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.spacing = 8;
    footer.edgeInsets = NSEdgeInsetsMake(6, 12, 6, 12);
    NSView *content = self.window.contentView;
    for (NSView *view in @[toolbarScroll, self.webView, footer]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [toolbarScroll.topAnchor constraintEqualToAnchor:content.topAnchor],
        [toolbarScroll.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [toolbarScroll.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [toolbarScroll.heightAnchor constraintEqualToConstant:80],
        [self.webView.topAnchor constraintEqualToAnchor:toolbarScroll.bottomAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:footer.topAnchor],
        [footer.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [footer.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [footer.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [footer.heightAnchor constraintEqualToConstant:30],
        [self.progress.widthAnchor constraintEqualToConstant:14],
        [self.progress.heightAnchor constraintEqualToConstant:14]
    ]];
    [self updateControls];
    if (self.selfTest) {
        NSString *fixture = @"<!doctype html><html><head><meta charset='utf-8'></head><body><h1>墨读 · 显示测试</h1><p>Paperlike 2200 × 1650</p><div style='height:3000px'>阅读测试正文</div></body></html>";
        [self.webView loadHTMLString:fixture baseURL:[NSURL URLWithString:@"https://weread.qq.com/web/reader/test"]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ fprintf(stderr, "SELFTEST timeout\n"); exit(2); });
    } else {
        [self.window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        [self placeOnPaperlike:NO];
        if (self.readerTest) [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://weread.qq.com/web/reader/1f5322605bfe8f1f5105803"]]];
        else [self home:nil];
        if (self.smokeTest) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 45 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ fprintf(stderr, "SMOKE timeout\n"); exit(5); });
    }
}
- (void)updateControls {
    self.zoomLabel.title = [NSString stringWithFormat:@"%.0f%%", self.zoom * 100];
    self.inkButton.title = self.ink ? @"墨水模式 ✓" : @"墨水模式 关";
}
- (void)home:(id)sender { (void)sender; [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:HomeURL]]]; }
- (void)reload:(id)sender { (void)sender; [self.webView reload]; }
- (void)turn:(int)direction {
    NSString *js = [NSString stringWithFormat:@"window.PaperlikeReader ? window.PaperlikeReader.turn(%d) : 'unavailable'", direction];
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (error) self.status.stringValue = @"页面尚未就绪，请稍后重试。";
        else if ([result isEqual:@"not-reader"]) self.status.stringValue = @"请先打开一本书。";
        else if ([result isEqual:@"edge"]) self.status.stringValue = @"已到当前页边缘；可用微信读书的章节控件继续。";
        else if ([result isEqual:@"editing"]) self.status.stringValue = @"请先结束输入，再翻页。";
        else self.status.stringValue = @"墨水屏阅读 · ⌘[ 上一屏 · ⌘] 下一屏";
    }];
}
- (void)previous:(id)sender { (void)sender; [self turn:-1]; }
- (void)next:(id)sender { (void)sender; [self turn:1]; }
- (void)setPageZoom:(double)value {
    self.zoom = fmin(1.8, fmax(0.8, value));
    self.webView.pageZoom = self.zoom;
    [NSUserDefaults.standardUserDefaults setDouble:self.zoom forKey:@"zoom"];
    [self updateControls];
}
- (void)zoomIn:(id)sender { (void)sender; [self setPageZoom:self.zoom + 0.1]; }
- (void)zoomOut:(id)sender { (void)sender; [self setPageZoom:self.zoom - 0.1]; }
- (void)resetZoom:(id)sender { (void)sender; [self setPageZoom:1]; }
- (void)toggleInk:(id)sender {
    (void)sender;
    self.ink = !self.ink;
    [NSUserDefaults.standardUserDefaults setBool:self.ink forKey:@"ink"];
    NSString *js = [NSString stringWithFormat:@"window.PaperlikeReader && window.PaperlikeReader.setInk(%@)", self.ink ? @"true" : @"false"];
    [self.webView evaluateJavaScript:js completionHandler:nil];
    [self updateControls];
    self.status.stringValue = self.ink ? @"墨水模式已开启 · 灰度、高对比、减少动画" : @"已恢复网页原有显示";
    if (self.ink) {
        NSURL *lightURL = [self lightReaderURL:self.webView.URL];
        if (lightURL) [self.webView loadRequest:[NSURLRequest requestWithURL:lightURL]];
    }
}
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)controller;
    if (self.selfTest || self.smokeTest || !message.frameInfo.mainFrame ||
        ![self.webView.URL.host isEqualToString:@"weread.qq.com"]) return;
    if ([message.body isEqual:@"loading"]) {
        [self.progress startAnimation:nil];
        self.status.stringValue = @"正在加载书籍正文，请稍候…";
    } else if ([message.body isEqual:@"ready"]) {
        [self.progress stopAnimation:nil];
        self.status.stringValue = @"正文已就绪 · ⌘[ / ⌘] 翻屏 · 侧栏可调整正文字号";
    } else if ([message.body isEqual:@"home"]) {
        [self.progress stopAnimation:nil];
        self.status.stringValue = @"就绪 · 在网页内登录并选择书籍";
    }
}
- (NSScreen *)paperlikeScreen {
    for (NSScreen *screen in NSScreen.screens) {
        NSNumber *number = screen.deviceDescription[@"NSScreenNumber"];
        CGDirectDisplayID display = number.unsignedIntValue;
        if ([screen.localizedName.lowercaseString containsString:@"paperlike"] ||
            (CGDisplayVendorNumber(display) == 0x1263 && CGDisplayModelNumber(display) == 1)) return screen;
    }
    return nil;
}
- (void)placeOnPaperlike:(BOOL)report {
    NSScreen *screen = [self paperlikeScreen];
    if (!screen) {
        if (report) self.status.stringValue = @"当前桌面会话未找到 Paperlike，请检查连接后再试。";
        return;
    }
    if ((self.window.styleMask & NSWindowStyleMaskFullScreen) != 0) {
        if (report) self.status.stringValue = @"请先退出全屏，再移到 Paperlike。";
        return;
    }
    // NSScreen uses logical points, so scaled and rotated displays also fit.
    [self.window setFrame:screen.visibleFrame display:YES animate:NO];
    self.status.stringValue = [NSString stringWithFormat:@"已移到 %@ · %.0f × %.0f 逻辑点", screen.localizedName, screen.frame.size.width, screen.frame.size.height];
}
- (void)moveToPaperlike:(id)sender { (void)sender; [self placeOnPaperlike:YES]; }
- (void)fullScreen:(id)sender { (void)sender; [self.window toggleFullScreen:nil]; }
- (void)help:(id)sender {
    (void)sender;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"墨读 · Paperlike";
    alert.informativeText = @"微信读书网页版的独立阅读窗口。\n\n在网页内登录并打开书籍。\n⌘[ / ⌘]：上一屏 / 下一屏\n⌘+ / ⌘−：缩放，⌘0：重置\n⌘I：切换墨水模式\n⌘P：移到 Paperlike，⌘F：全屏\n\n正文字号、行距和背景请使用微信读书原有设置，建议白底黑字。应用保留网页的阅读、书架与同步功能。\n\n适配使用屏幕逻辑尺寸，支持横竖屏。应用无法控制硬件清屏或刷新模式，请用显示器按键调节。\n\n本应用为独立本地工具，与微信读书及 DASUNG 无隶属关系。";
    [alert runModal];
}
- (BOOL)isAllowedURL:(NSURL *)url {
    NSString *host = url.host.lowercaseString;
    return [url.scheme isEqualToString:@"https"] && ([host isEqualToString:@"weread.qq.com"] || [host hasSuffix:@".weread.qq.com"] || [host isEqualToString:@"open.weixin.qq.com"] || [host isEqualToString:@"mp.weixin.qq.com"]);
}
- (NSURL *)lightReaderURL:(NSURL *)url {
    if (![url.scheme isEqualToString:@"https"] || ![url.host.lowercaseString isEqualToString:@"weread.qq.com"] || ![url.path hasPrefix:@"/web/reader/"]) return nil;
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSMutableArray<NSURLQueryItem *> *items = [NSMutableArray array];
    for (NSURLQueryItem *item in components.queryItems) {
        if (![item.name isEqualToString:@"wtheme"]) [items addObject:item];
    }
    [items addObject:[NSURLQueryItem queryItemWithName:@"wtheme" value:@"white"]];
    components.queryItems = items;
    return components.URL;
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = action.request.URL;
    if (self.ink && !self.selfTest && action.targetFrame.mainFrame && (!action.request.HTTPMethod || [action.request.HTTPMethod isEqualToString:@"GET"])) {
        NSURL *lightURL = [self lightReaderURL:url];
        if (lightURL && ![lightURL isEqual:url]) {
            decisionHandler(WKNavigationActionPolicyCancel);
            NSMutableURLRequest *request = [action.request mutableCopy];
            request.URL = lightURL;
            [webView loadRequest:request];
            return;
        }
    }
    if (self.selfTest || !action.targetFrame.mainFrame || [self isAllowedURL:url] || [url.absoluteString isEqualToString:@"about:blank"]) {
        decisionHandler(WKNavigationActionPolicyAllow); return;
    }
    decisionHandler(WKNavigationActionPolicyCancel);
    if (action.navigationType == WKNavigationTypeLinkActivated && [@[@"https", @"http"] containsObject:url.scheme.lowercaseString]) [NSWorkspace.sharedWorkspace openURL:url];
    else self.status.stringValue = @"网页跳转未完成，请使用网页内的登录或阅读入口。";
}
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)action windowFeatures:(WKWindowFeatures *)features {
    (void)configuration; (void)features;
    if ([self isAllowedURL:action.request.URL]) [webView loadRequest:action.request];
    else if ([@[@"https", @"http"] containsObject:action.request.URL.scheme.lowercaseString]) [NSWorkspace.sharedWorkspace openURL:action.request.URL];
    return nil;
}
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    (void)webView; (void)navigation;
    self.loadFailed = NO;
    [self.progress startAnimation:nil];
    self.status.stringValue = @"正在连接微信读书…";
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    (void)navigation;
    [self.progress stopAnimation:nil];
    self.window.title = [NSString stringWithFormat:@"%@ · 墨读", webView.title ?: @"微信读书"];
    NSString *js = [NSString stringWithFormat:@"window.PaperlikeReader && window.PaperlikeReader.setInk(%@)", self.ink ? @"true" : @"false"];
    [webView evaluateJavaScript:js completionHandler:nil];
    self.status.stringValue = [webView.URL.path hasPrefix:@"/web/reader/"] ? @"页面已连接，正在加载正文…" : @"就绪 · 在网页内登录并选择书籍";
    [webView evaluateJavaScript:@"window.PaperlikeReader?.reportState()" completionHandler:nil];
    if (self.selfTest) [self runSelfTest];
    if (self.readerTest) { [self checkReaderTest:0 advanced:NO]; return; }
    if (self.smokeTest) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [webView evaluateJavaScript:@"({bridge:!!window.PaperlikeReader, hasSearch:!!document.querySelector('input[placeholder=\"搜索\"]')})" completionHandler:^(id result, NSError *error) {
                NSDictionary *r = [result isKindOfClass:NSDictionary.class] ? result : @{};
                BOOL passed = !error && [r[@"bridge"] boolValue] && [r[@"hasSearch"] boolValue] && [webView.URL.host isEqualToString:@"weread.qq.com"];
                fprintf(stdout, "SMOKE %s\n%s\n", passed ? "PASS" : "FAIL", r.description.UTF8String);
                fflush(stdout);
                exit(passed ? 0 : 6);
            }];
        });
    }
}
- (void)checkReaderTest:(NSUInteger)attempt advanced:(BOOL)advanced {
    NSString *js = @"(() => { const visible = x => x && x.getClientRects().length && x.getBoundingClientRect().width > 0 && x.getBoundingClientRect().height > 0; const canvases=[...document.querySelectorAll('canvas')]; let painted=false; for (const source of canvases) { if (!source.width || !source.height) continue; try { const probe=document.createElement('canvas'); probe.width=128; probe.height=128; const ctx=probe.getContext('2d'); ctx.drawImage(source,0,0,128,128); const d=ctx.getImageData(0,0,128,128).data; for(let i=0;i<d.length;i+=4) { if(d[i+3]>20 && Math.min(d[i],d[i+1],d[i+2])<200) { painted=true; break; } } } catch(_) {} if(painted) break; } const chapter=document.querySelector('.readerChapterContent'); return {whiteTheme:document.body.classList.contains('wr_whiteTheme'),background:chapter?getComputedStyle(chapter).backgroundColor:null,pageReady:[...document.querySelectorAll('.renderTarget_pager_button_right')].some(visible),canvases:canvases.length,painted,bridge:!!window.PaperlikeReader,errors:window.PaperlikeDiagnostics||[],readyState:document.readyState}; })()";
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        NSDictionary *r = [result isKindOfClass:NSDictionary.class] ? result : @{};
        BOOL ready = !error && ([r[@"painted"] boolValue] || (!advanced && [r[@"pageReady"] boolValue]));
        if (!ready && attempt < 40) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkReaderTest:attempt + 1 advanced:advanced]; });
            return;
        }
        if (ready && !advanced) {
            [self.webView evaluateJavaScript:@"window.PaperlikeReader ? window.PaperlikeReader.turn(1) : document.querySelector('.renderTarget_pager_button_right')?.click()" completionHandler:^(id value, NSError *turnError) {
                (void)value; (void)turnError;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 800 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkReaderTest:0 advanced:YES]; });
            }];
            return;
        }
        BOOL passed = ready && advanced && [r[@"painted"] boolValue] && [r[@"whiteTheme"] boolValue] && [r[@"background"] isEqual:@"rgb(255, 255, 255)"];
        fprintf(stdout, "READER %s after %lu checks\n%s\n", passed ? "PASS" : "FAIL", (unsigned long)attempt + 1, r.description.UTF8String);
        fflush(stdout);
        WKSnapshotConfiguration *snapshot = [[WKSnapshotConfiguration alloc] init];
        snapshot.snapshotWidth = @1100;
        [self.webView takeSnapshotWithConfiguration:snapshot completionHandler:^(NSImage *image, NSError *snapshotError) {
            if (image && !snapshotError) {
                NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
                NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"paperlike-reader-light.png"];
                [png writeToFile:path atomically:YES];
                fprintf(stdout, "Snapshot: %s\n", path.UTF8String);
            }
            fflush(stdout);
            exit(passed ? 0 : 6);
        }];
    }];
}
- (void)failed:(NSError *)error {
    if (error.code == NSURLErrorCancelled) return;
    self.loadFailed = YES;
    [self.progress stopAnimation:nil];
    self.status.stringValue = [NSString stringWithFormat:@"加载失败：%@ · 点击“重载”重试", error.localizedDescription];
    if (self.selfTest || self.smokeTest) { fprintf(stderr, "TEST load failed: %s\n", error.localizedDescription.UTF8String); exit(3); }
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { (void)webView; (void)navigation; [self failed:error]; }
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { (void)webView; (void)navigation; [self failed:error]; }
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    (void)webView;
    [self.progress stopAnimation:nil];
    self.status.stringValue = @"网页进程已停止，请点击“重载”恢复。";
}
- (void)runSelfTest {
    // Exercise the actual bundled script and WKWebView, not a separate DOM model.
    NSString *js = @"(() => { const api = window.PaperlikeReader; if (!api) throw Error('missing bridge'); api.setInk(true); const on = document.documentElement.dataset.paperlikeInk === 'true'; api.setInk(false); const off = document.documentElement.dataset.paperlikeInk === 'false'; api.setInk(true); const before = window.scrollY; const next = api.turn(1); const moved = window.scrollY > before; const previous = api.turn(-1); const returned = window.scrollY === before; const btn=document.createElement('button'); btn.className='renderTarget_pager_button renderTarget_pager_button_right'; btn.textContent='下一页'; let clicks=0; btn.onclick=()=>clicks++; document.body.prepend(btn); const control=api.turn(1)==='control' && clicks===1; const input=document.createElement('input'); document.body.prepend(input); input.focus(); const editing=api.turn(1)==='editing' && clicks===1; return {on,off,next,moved,previous,returned,control,editing,styleCount:document.querySelectorAll('#paperlike-reader-style').length}; })()";
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        NSDictionary *r = [result isKindOfClass:NSDictionary.class] ? result : @{};
        BOOL passed = !error && [r[@"on"] boolValue] && [r[@"off"] boolValue] && [r[@"moved"] boolValue] && [r[@"returned"] boolValue] && [r[@"control"] boolValue] && [r[@"editing"] boolValue] && [r[@"styleCount"] intValue] == 1;
        double previousZoom = self.zoom;
        [self setPageZoom:1.3];
        passed = passed && fabs(self.webView.pageZoom - 1.3) < 0.001;
        [self setPageZoom:previousZoom];
        passed = passed && [self isAllowedURL:[NSURL URLWithString:HomeURL]] && ![self isAllowedURL:[NSURL URLWithString:@"https://weread.qq.com.example.org/"]];
        fprintf(stdout, "SELFTEST %s\n%s\nScreens: %lu\n", passed ? "PASS" : "FAIL", [[r description] UTF8String], (unsigned long)NSScreen.screens.count);
        if (error) fprintf(stderr, "%s\n", error.description.UTF8String);
        fflush(stdout);
        exit(passed ? 0 : 4);
    }];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { (void)sender; return YES; }
- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)visible { (void)sender; if (!visible) [self.window makeKeyAndOrderFront:nil]; return YES; }
@end

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        ReaderApp *delegate = [[ReaderApp alloc] init];
        app.delegate = delegate;
        [app run];
    }
    return 0;
}
