#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import "InkControls.h"

static NSString * const HomeURL = @"https://weread.qq.com/";

static NSButton *ButtonForAction(NSView *view, SEL action) {
    if ([view isKindOfClass:NSButton.class] && ((NSButton *)view).action == action) return (NSButton *)view;
    for (NSView *child in view.subviews) { NSButton *button = ButtonForAction(child, action); if (button) return button; }
    return nil;
}

@interface ReaderApp : NSObject <NSApplicationDelegate, NSWindowDelegate, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>
@property NSWindow *window;
@property WKWebView *webView;
@property NSTextField *status;
@property NSButton *inkButton;
@property NSButton *zoomLabel;
@property NSProgressIndicator *progress;
@property BOOL ink;
@property double zoom;
@property double pageMargin;
@property double lineSpacing;
@property double defaultLineSpacing;
@property NSPopover *layoutPopover;
@property NSTextField *layoutValue;
@property NSString *layoutKind;
@property BOOL selfTest;
@property BOOL uiTest;
@property NSScrollView *toolbarScroll;
@property BOOL selectionTest;
@property BOOL selectionNarrowTest;
@property BOOL aiTest;
@property BOOL aiThemeTested;
@property BOOL smokeTest;
@property BOOL readerTest;
@property BOOL layoutTest;
@property NSDictionary *layoutTestBaseline;
@property NSDictionary *layoutTestWide;
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
- (void)showMargins:(id)sender;
- (void)showLineSpacing:(id)sender;
- (void)decreaseLayout:(id)sender;
- (void)increaseLayout:(id)sender;
- (void)resetLayout:(id)sender;
@end

@implementation ReaderApp
- (NSButton *)button:(NSString *)title action:(SEL)action tooltip:(NSString *)tooltip {
    InkButton *button = [[InkButton alloc] initWithFrame:NSZeroRect];
    button.cell = [[InkButtonCell alloc] initTextCell:title];
    button.title = title; button.target = self; button.action = action;
    button.buttonType = NSButtonTypeMomentaryPushIn;
    button.focusRingType = NSFocusRingTypeNone;
    button.bezelStyle = NSBezelStyleRegularSquare;
    button.controlSize = NSControlSizeLarge;
    button.font = [NSFont systemFontOfSize:22 weight:NSFontWeightSemibold];
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
    self.selectionTest = [NSProcessInfo.processInfo.arguments containsObject:@"--selection-test"];
    self.aiTest = [NSProcessInfo.processInfo.arguments containsObject:@"--ai-test"];
    self.uiTest = [NSProcessInfo.processInfo.arguments containsObject:@"--ui-test"];
    self.selfTest = self.uiTest || self.selectionTest || self.aiTest || [NSProcessInfo.processInfo.arguments containsObject:@"--self-test"];
    self.layoutTest = [NSProcessInfo.processInfo.arguments containsObject:@"--layout-test"];
    self.readerTest = self.layoutTest || [NSProcessInfo.processInfo.arguments containsObject:@"--reader-test"];
    self.smokeTest = self.readerTest || [NSProcessInfo.processInfo.arguments containsObject:@"--smoke-test"];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults registerDefaults:@{@"ink": @YES, @"zoom": @1.0, @"pageMargin": @0, @"lineSpacing": @0}];
    self.ink = [defaults boolForKey:@"ink"];
    if (self.readerTest) self.ink = YES;
    self.zoom = fmin(1.8, fmax(0.8, [defaults doubleForKey:@"zoom"]));
    self.pageMargin = fmin(200, fmax(-60, [defaults doubleForKey:@"pageMargin"]));
    double spacing = [defaults doubleForKey:@"lineSpacing"];
    self.lineSpacing = spacing > 0 ? fmin(3, fmax(1.2, spacing)) : 0;
    self.defaultLineSpacing = 1.5;
    if (self.selfTest || self.smokeTest) { self.pageMargin = 0; self.lineSpacing = 0; }
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
    if (!self.selfTest && !self.smokeTest) [self.window setFrameAutosaveName:@"ReaderWindow"];
    self.window.backgroundColor = NSColor.whiteColor;
    self.window.titlebarAppearsTransparent = YES;

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
    NSString *initialScript = [script stringByAppendingFormat:@"\nwindow.PaperlikeReader.setInk(%@);\nwindow.PaperlikeReader.setLayout(%g, %g);", self.ink ? @"true" : @"false", self.pageMargin, self.lineSpacing];
    [config.userContentController addUserScript:[[WKUserScript alloc] initWithSource:initialScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES]];
    NSString *aiScript = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"ai" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil];
    if (!aiScript) { fprintf(stderr, "Missing ai.js\n"); exit(1); }
    NSString *initialAIScript = [aiScript stringByAppendingFormat:@"\nwindow.PaperlikeAI?.setInk(%@);", self.ink ? @"true" : @"false"];
    [config.userContentController addUserScript:[[WKUserScript alloc] initWithSource:initialAIScript injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:NO]];
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
    NSButton *margins = [self button:@"页边距" action:@selector(showMargins:) tooltip:@"调节正文左右留白，可恢复默认"];
    NSButton *lineSpacing = [self button:@"行距" action:@selector(showLineSpacing:) tooltip:@"调节正文行间距，可恢复默认"];
    self.inkButton = [self button:@"墨水模式 ✓" action:@selector(toggleInk:) tooltip:@"灰度、高对比、减少动画（⌘I）"];
    [self.inkButton.widthAnchor constraintGreaterThanOrEqualToConstant:176].active = YES;
    NSButton *screen = [self button:@"移到 Paperlike" action:@selector(moveToPaperlike:) tooltip:@"定位已连接的 Paperlike 显示器（⌘P）"];
    NSButton *full = [self button:@"全屏" action:@selector(fullScreen:) tooltip:@"切换全屏（⌘F）"];
    NSStackView *toolbar = [NSStackView stackViewWithViews:@[home, reload, previous, next, smaller, self.zoomLabel, larger, margins, lineSpacing, self.inkButton, screen, full]];
    toolbar.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    toolbar.alignment = NSLayoutAttributeCenterY;
    toolbar.spacing = 12;
    toolbar.edgeInsets = NSEdgeInsetsMake(12, 16, 12, 16);
    // Keep the large controls in one row; narrow windows can scroll horizontally.
    NSSize toolbarSize = toolbar.fittingSize;
    toolbar.frame = NSMakeRect(0, 0, ceil(toolbarSize.width), 80);
    NSScrollView *toolbarScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    self.toolbarScroll = toolbarScroll;
    toolbarScroll.documentView = toolbar;
    toolbarScroll.hasHorizontalScroller = YES;
    toolbarScroll.hasVerticalScroller = NO;
    toolbarScroll.autohidesScrollers = NO;
    toolbarScroll.scrollerStyle = NSScrollerStyleLegacy;
    toolbarScroll.horizontalScroller = [[InkScroller alloc] initWithFrame:NSZeroRect];
    toolbarScroll.drawsBackground = YES;
    toolbarScroll.backgroundColor = NSColor.whiteColor;
    toolbar.wantsLayer = YES;
    toolbar.layer.backgroundColor = NSColor.whiteColor.CGColor;
    toolbarScroll.wantsLayer = YES;
    toolbarScroll.layer.borderColor = NSColor.blackColor.CGColor;
    toolbarScroll.layer.borderWidth = 1;
    toolbarScroll.borderType = NSNoBorder;

    self.status = [NSTextField labelWithString:@"正在连接微信读书…"];
    self.status.font = [NSFont systemFontOfSize:22 weight:NSFontWeightMedium];
    self.status.textColor = NSColor.blackColor;
    self.status.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.status setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    self.progress = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    self.progress.style = NSProgressIndicatorStyleSpinning;
    self.progress.controlSize = NSControlSizeRegular;
    self.progress.displayedWhenStopped = NO;
    NSStackView *footer = [NSStackView stackViewWithViews:@[self.progress, self.status]];
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.spacing = 12;
    footer.alignment = NSLayoutAttributeCenterY;
    footer.edgeInsets = NSEdgeInsetsMake(12, 16, 12, 16);
    footer.wantsLayer = YES;
    footer.layer.backgroundColor = NSColor.whiteColor.CGColor;
    footer.layer.borderColor = NSColor.blackColor.CGColor;
    footer.layer.borderWidth = 1;
    NSView *content = self.window.contentView;
    for (NSView *view in @[toolbarScroll, self.webView, footer]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [content addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [toolbarScroll.topAnchor constraintEqualToAnchor:content.topAnchor],
        [toolbarScroll.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [toolbarScroll.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [toolbarScroll.heightAnchor constraintEqualToConstant:100],
        [self.webView.topAnchor constraintEqualToAnchor:toolbarScroll.bottomAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:footer.topAnchor],
        [footer.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
        [footer.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
        [footer.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
        [footer.heightAnchor constraintEqualToConstant:56],
        [self.progress.widthAnchor constraintEqualToConstant:24],
        [self.progress.heightAnchor constraintEqualToConstant:24]
    ]];
    [self updateControls];
    if (self.selfTest) {
        if (self.selectionTest || self.aiTest || self.uiTest) {
            [self.window makeKeyAndOrderFront:nil];
            [NSApp activateIgnoringOtherApps:YES];
        }
        NSString *fixture = @"<!doctype html><html><head><meta charset='utf-8'></head><body><h1>墨读 · 显示测试</h1><p>Paperlike 2200 × 1650</p><div style='height:3000px'>阅读测试正文</div></body></html>";
        if (self.selectionTest) fixture = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"selection-test" withExtension:@"html"] encoding:NSUTF8StringEncoding error:nil];
        if (self.aiTest) fixture = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"ai-test" withExtension:@"html"] encoding:NSUTF8StringEncoding error:nil];
        [self.webView loadHTMLString:fixture baseURL:[NSURL URLWithString:@"https://weread.qq.com/web/reader/test"]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ fprintf(stderr, "SELFTEST timeout\n"); exit(2); });
    } else {
        [self.window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        [self placeOnPaperlike:NO];
        if (self.readerTest) [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://weread.qq.com/web/reader/1f5322605bfe8f1f5105803"]]];
        else [self home:nil];
        if (self.smokeTest) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (self.layoutTest ? 90 : 45) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ fprintf(stderr, "SMOKE timeout\n"); exit(5); });
    }
}
- (void)updateControls {
    self.zoomLabel.title = [NSString stringWithFormat:@"%.0f%%", self.zoom * 100];
    self.inkButton.state = self.ink ? NSControlStateValueOn : NSControlStateValueOff;
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
    if (!self.selfTest) [NSUserDefaults.standardUserDefaults setDouble:self.zoom forKey:@"zoom"];
    [self updateControls];
}
- (void)zoomIn:(id)sender { (void)sender; [self setPageZoom:self.zoom + 0.1]; }
- (void)zoomOut:(id)sender { (void)sender; [self setPageZoom:self.zoom - 0.1]; }
- (void)resetZoom:(id)sender { (void)sender; [self setPageZoom:1]; }
- (void)updateLayoutValue {
    if ([self.layoutKind isEqualToString:@"margin"]) {
        self.layoutValue.stringValue = fabs(self.pageMargin) < 0.1 ? @"默认" :
            [NSString stringWithFormat:@"%@ %.0f px", self.pageMargin > 0 ? @"加宽" : @"收窄", fabs(self.pageMargin)];
    } else {
        self.layoutValue.stringValue = self.lineSpacing == 0 ? @"默认" : [NSString stringWithFormat:@"%.1f 倍", self.lineSpacing];
    }
}
- (void)showLayout:(NSString *)kind sender:(NSButton *)sender {
    [self.layoutPopover close];
    self.layoutKind = kind;
    [self.webView evaluateJavaScript:@"window.PaperlikeReader?.layoutState()" completionHandler:^(id result, NSError *error) {
        if (![self.layoutKind isEqualToString:kind]) return;
        if (error || ![result isKindOfClass:NSDictionary.class] || ![result[@"reader"] boolValue]) {
            self.status.stringValue = @"请先打开一本书，再调节页边距和行距。";
            return;
        }
        self.pageMargin = [result[@"effectiveMargin"] doubleValue];
        self.lineSpacing = [result[@"lineHeight"] doubleValue];
        self.defaultLineSpacing = [result[@"defaultLineHeight"] doubleValue];
        BOOL margin = [kind isEqualToString:@"margin"];
        NSTextField *title = [NSTextField labelWithString:margin ? @"页边距" : @"正文行距"];
        title.font = [NSFont systemFontOfSize:26 weight:NSFontWeightSemibold];
        title.textColor = NSColor.blackColor;
        self.layoutValue = [NSTextField labelWithString:@"默认"];
        self.layoutValue.font = [NSFont monospacedDigitSystemFontOfSize:30 weight:NSFontWeightSemibold];
        self.layoutValue.textColor = NSColor.blackColor;
        self.layoutValue.alignment = NSTextAlignmentCenter;
        [self.layoutValue.widthAnchor constraintEqualToConstant:224].active = YES;
        NSButton *minus = [self button:@"−" action:@selector(decreaseLayout:) tooltip:margin ? @"减少左右留白" : @"缩小行间距"];
        NSButton *plus = [self button:@"＋" action:@selector(increaseLayout:) tooltip:margin ? @"增加左右留白" : @"增大行间距"];
        NSStackView *row = [NSStackView stackViewWithViews:@[minus, self.layoutValue, plus]];
        row.spacing = 12;
        row.alignment = NSLayoutAttributeCenterY;
        NSTextField *hint = [NSTextField labelWithString:margin ? @"调整正文左右留白，每次 20 px" : @"每次调整 0.1 倍，数值越大越宽松"];
        hint.font = [NSFont systemFontOfSize:20 weight:NSFontWeightMedium];
        hint.textColor = NSColor.blackColor;
        NSButton *reset = [self button:@"恢复默认" action:@selector(resetLayout:) tooltip:@"恢复微信读书原来的排版"];
        NSStackView *content = [NSStackView stackViewWithViews:@[title, row, hint, reset]];
        content.orientation = NSUserInterfaceLayoutOrientationVertical;
        content.alignment = NSLayoutAttributeCenterX;
        content.spacing = 12;
        // Give the stack explicit padding in a wrapper. fittingSize alone does
        // not include stack edge insets reliably on older AppKit versions.
        NSSize stackSize = content.fittingSize;
        NSSize size = NSMakeSize(ceil(stackSize.width) + 40, ceil(stackSize.height) + 40);
        NSView *panel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, size.width, size.height)];
        panel.wantsLayer = YES;
        panel.layer.backgroundColor = NSColor.whiteColor.CGColor;
        panel.layer.borderColor = NSColor.blackColor.CGColor;
        panel.layer.borderWidth = 2;
        panel.layer.cornerRadius = 6;
        content.translatesAutoresizingMaskIntoConstraints = NO;
        [panel addSubview:content];
        [NSLayoutConstraint activateConstraints:@[
            [content.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:20],
            [content.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20],
            [content.topAnchor constraintEqualToAnchor:panel.topAnchor constant:20],
            [content.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20]
        ]];
        NSViewController *controller = [[NSViewController alloc] init];
        controller.view = panel;
        self.layoutPopover = [[NSPopover alloc] init];
        self.layoutPopover.behavior = NSPopoverBehaviorTransient;
        self.layoutPopover.animates = NO;
        self.layoutPopover.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        self.layoutPopover.contentViewController = controller;
        self.layoutPopover.contentSize = size;
        [self updateLayoutValue];
        [self.layoutPopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMinY];
    }];
}
- (void)showMargins:(id)sender { [self showLayout:@"margin" sender:sender]; }
- (void)showLineSpacing:(id)sender { [self showLayout:@"line" sender:sender]; }
- (void)applyPageMargin:(double)margin lineSpacing:(double)spacing {
    NSString *js = [NSString stringWithFormat:@"window.PaperlikeReader?.setLayout(%g, %g)", margin, spacing];
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (error || ![result isKindOfClass:NSDictionary.class] || ![result[@"applied"] boolValue]) {
            self.status.stringValue = @"排版尚未就绪，请等待正文加载完成后再试。";
            return;
        }
        self.pageMargin = [result[@"effectiveMargin"] doubleValue];
        self.lineSpacing = [result[@"lineHeight"] doubleValue];
        if (!self.selfTest) [NSUserDefaults.standardUserDefaults setDouble:self.pageMargin forKey:@"pageMargin"];
        if (!self.selfTest) [NSUserDefaults.standardUserDefaults setDouble:self.lineSpacing forKey:@"lineSpacing"];
        [self updateLayoutValue];
        // The footer may have remained visible throughout reflow, so ask for
        // current state after saving instead of leaving a one-way busy label.
        [self.webView evaluateJavaScript:@"window.PaperlikeReader?.reportState()" completionHandler:nil];
    }];
}
- (void)changeLayout:(double)direction {
    if ([self.layoutKind isEqualToString:@"margin"]) {
        [self applyPageMargin:fmin(200, fmax(-60, self.pageMargin + direction * 20)) lineSpacing:self.lineSpacing];
    } else {
        double current = self.lineSpacing == 0 ? self.defaultLineSpacing : self.lineSpacing;
        double spacing = fmin(3, fmax(1.2, round((current + direction * 0.1) * 10) / 10));
        [self applyPageMargin:self.pageMargin lineSpacing:spacing];
    }
}
- (void)decreaseLayout:(id)sender { (void)sender; [self changeLayout:-1]; }
- (void)increaseLayout:(id)sender { (void)sender; [self changeLayout:1]; }
- (void)resetLayout:(id)sender {
    (void)sender;
    BOOL margin = [self.layoutKind isEqualToString:@"margin"];
    [self applyPageMargin:margin ? 0 : self.pageMargin lineSpacing:margin ? self.lineSpacing : 0];
}
- (void)toggleInk:(id)sender {
    (void)sender;
    self.ink = !self.ink;
    if (!self.selfTest) [NSUserDefaults.standardUserDefaults setBool:self.ink forKey:@"ink"];
    NSString *js = [NSString stringWithFormat:@"window.PaperlikeReader && window.PaperlikeReader.setInk(%@)", self.ink ? @"true" : @"false"];
    [self.webView evaluateJavaScript:js completionHandler:nil];
    [self updateControls];
    self.status.stringValue = self.ink ? @"墨水模式已开启 · 灰度、高对比、减少动画" : @"已恢复网页原有显示";
    if (self.ink && !self.selfTest) {
        NSURL *lightURL = [self lightReaderURL:self.webView.URL];
        if (lightURL) [self.webView loadRequest:[NSURLRequest requestWithURL:lightURL]];
    }
}
- (void)userContentController:(WKUserContentController *)controller didReceiveScriptMessage:(WKScriptMessage *)message {
    (void)controller;
    if (self.selfTest || self.smokeTest || !message.frameInfo.mainFrame ||
        ![self.webView.URL.host isEqualToString:@"weread.qq.com"]) return;
    if ([message.body isEqual:@"reflowing"]) {
        [self.progress startAnimation:nil];
        self.status.stringValue = @"正在重新排版正文… · 设置已保存";
    } else if ([message.body isEqual:@"stalled"]) {
        [self.progress stopAnimation:nil];
        self.status.stringValue = @"正文排版尚未完成 · 可点击“重载”重试";
    } else if ([message.body isEqual:@"loading"]) {
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
    NSString *layoutJS = [NSString stringWithFormat:@"window.PaperlikeReader?.setLayout(%g, %g)", self.pageMargin, self.lineSpacing];
    [webView evaluateJavaScript:layoutJS completionHandler:nil];
    [webView evaluateJavaScript:@"window.PaperlikeReader?.reportState()" completionHandler:nil];
    if (self.uiTest) { [self checkNativeUITest:0]; return; }
    if (self.aiTest) { [self checkAITest:0]; return; }
    if (self.selectionTest) { [self checkSelectionTest:0]; return; }
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
        if (self.layoutTest && passed) { [self checkLayoutTest:0 attempt:0]; return; }
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
- (void)checkLayoutTest:(NSUInteger)stage attempt:(NSUInteger)attempt {
    NSString *js = @"(() => { const api=window.PaperlikeReader; const canvases=[...document.querySelectorAll('canvas')]; const c=canvases.find(x=>x.width>0&&x.height>0); const root=document.querySelector('.readerChapterContent'); let hash=0; for(const canvas of canvases){try{const d=canvas.getContext('2d').getImageData(0,0,canvas.width,canvas.height).data;for(let i=0;i<d.length;i+=16)hash=(Math.imul(hash,31)+d[i]+d[i+3])>>>0;}catch(_){}} return {width:c?.width||0,height:c?.height||0,hash,rootWidth:root?.getBoundingClientRect().width||0,...api.layoutState()}; })()";
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        NSDictionary *r = [result isKindOfClass:NSDictionary.class] ? result : @{};
        BOOL ready = !error && ![r[@"reflowing"] boolValue] && [r[@"reportedState"] isEqual:@"ready"] && [r[@"width"] doubleValue] > 0 && [r[@"hash"] unsignedIntValue] != 0;
        if (stage == 1) ready = ready && [r[@"width"] doubleValue] < [self.layoutTestBaseline[@"width"] doubleValue] - 10;
        if (stage == 2) ready = ready && ![r[@"hash"] isEqual:self.layoutTestWide[@"hash"]];
        if (stage == 3) ready = ready && fabs([r[@"width"] doubleValue] - [self.layoutTestBaseline[@"width"] doubleValue]) < 2 && [r[@"margin"] doubleValue] == 0 && [r[@"lineHeight"] doubleValue] == 0;
        if (!ready && attempt < 30) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 400 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkLayoutTest:stage attempt:attempt + 1]; });
            return;
        }
        if (!ready) { fprintf(stderr, "LAYOUT FAIL stage %lu: %s\n", (unsigned long)stage, r.description.UTF8String); exit(7); }
        fprintf(stdout, "LAYOUT stage %lu: %s\n", (unsigned long)stage, r.description.UTF8String); fflush(stdout);
        if (stage == 3) { fprintf(stdout, "LAYOUT PASS: margins, line spacing, reset\n"); fflush(stdout); exit(0); }
        if (stage == 0) self.layoutTestBaseline = r;
        if (stage == 1) self.layoutTestWide = r;
        NSString *change = stage == 0 ? @"window.PaperlikeReader.setLayout(60, 2.4)" : stage == 1 ? @"window.PaperlikeReader.setLayout(60, 1.4)" : @"window.PaperlikeReader.setLayout(0, 0)";
        [self.webView evaluateJavaScript:change completionHandler:^(id value, NSError *changeError) {
            (void)value;
            if (changeError) { fprintf(stderr, "Layout update failed\n"); exit(7); }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkLayoutTest:stage + 1 attempt:0]; });
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
- (void)checkSelectionTest:(NSUInteger)attempt {
    if (attempt == 0) fprintf(stdout, "Selection test: narrow=%d window=%.0fx%.0f web=%.0fx%.0f zoom=%.1f\n", self.selectionNarrowTest, self.window.contentView.bounds.size.width, self.window.contentView.bounds.size.height, self.webView.bounds.size.width, self.webView.bounds.size.height, self.webView.pageZoom);
    NSString *js = @"(() => {const menu=document.querySelector('.reader_toolbar_container');if(!menu)return {passed:false};const rect=menu.getBoundingClientRect(),style=getComputedStyle(menu);const buttons=[...menu.querySelectorAll('.toolbarItem')].map(button=>{const r=button.getBoundingClientRect();const text=getComputedStyle(button.querySelector('.toolbarItem_text'));return {height:r.height,width:r.width,font:parseFloat(text.fontSize),color:text.color,hit:button.contains(document.elementFromPoint(r.x+r.width/2,r.y+r.height/2))};});const inBounds=rect.left>=15&&rect.top>=15&&rect.right<=innerWidth-15&&rect.bottom<=innerHeight-15;const white=style.backgroundColor==='rgb(255, 255, 255)';const border=parseFloat(style.borderTopWidth)>=1.5&&style.borderTopColor==='rgb(0, 0, 0)';return {passed:inBounds&&white&&border&&buttons.length===6&&buttons.every(b=>b.height>=79.9&&b.width>=87.9&&b.font>=20&&b.color==='rgb(0, 0, 0)'&&b.hit),inBounds,white,border,buttons,viewport:[innerWidth,innerHeight],rect:rect.toJSON(),translation:style.translate};})()";
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        NSDictionary *r = [result isKindOfClass:NSDictionary.class] ? result : @{};
        BOOL passed = !error && [r[@"passed"] boolValue];
        if (!passed && attempt < 35) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkSelectionTest:attempt + 1]; });
            return;
        }
        if (passed && !self.selectionNarrowTest) {
            self.selectionNarrowTest = YES;
            [self.window setContentSize:NSMakeSize(820, 650)];
            [self.webView setPageZoom:1.5];
            [self.window.contentView layoutSubtreeIfNeeded];
            [self.window displayIfNeeded];
            [self.webView takeSnapshotWithConfiguration:nil completionHandler:^(NSImage *image, NSError *snapshotError) {
                (void)image; (void)snapshotError;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkSelectionTest:0]; });
            }];
            return;
        }
        fprintf(stdout, "SELECTION %s\n%s\n", passed ? "PASS" : "FAIL", r.description.UTF8String); fflush(stdout);
        WKSnapshotConfiguration *snapshot = [[WKSnapshotConfiguration alloc] init];
        snapshot.snapshotWidth = @1100;
        [self.webView takeSnapshotWithConfiguration:snapshot completionHandler:^(NSImage *image, NSError *snapshotError) {
            if (image && !snapshotError) {
                NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
                NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"paperlike-selection-toolbar.png"];
                [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
                fprintf(stdout, "Snapshot: %s\n", path.UTF8String); fflush(stdout);
            }
            exit(passed ? 0 : 8);
        }];
    }];
}
- (void)writeNativeSnapshot:(NSView *)view name:(NSString *)name {
    [view layoutSubtreeIfNeeded]; [view displayIfNeeded];
    NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
    fprintf(stdout, "Snapshot: %s\n", path.UTF8String); fflush(stdout);
}
- (void)checkNativeUITest:(NSUInteger)stage {
    NSView *panel = self.layoutPopover.contentViewController.view;
    BOOL passed = YES;
    if (stage == 0) {
        // Offline bridge exercises native button actions without changing books or saved settings.
        NSString *stub = @"window.PaperlikeNativeTestState={reader:true,effectiveMargin:0,lineHeight:0,defaultLineHeight:1.5};window.PaperlikeReader.layoutState=()=>PaperlikeNativeTestState;window.PaperlikeReader.setLayout=(margin,line)=>Object.assign(PaperlikeNativeTestState,{applied:true,effectiveMargin:margin,lineHeight:line});true";
        [self.webView evaluateJavaScript:stub completionHandler:^(id result, NSError *error) {
            (void)result; if (error) { fprintf(stderr, "NATIVE UI bridge FAIL\n"); exit(10); }
            NSButton *button = ButtonForAction(self.toolbarScroll.documentView, @selector(showMargins:));
            [self.toolbarScroll.documentView scrollRectToVisible:button.frame];
            [button performClick:nil];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkNativeUITest:1]; });
        }];
        return;
    } else if (stage == 1 || stage == 4) {
        passed = self.layoutPopover.shown && self.layoutValue.font.pointSize >= 30 &&
            [self.layoutValue.textColor isEqual:NSColor.blackColor] && [self.layoutValue.stringValue isEqualToString:@"默认"];
        NSButton *plus = ButtonForAction(panel, @selector(increaseLayout:));
        NSButton *minus = ButtonForAction(panel, @selector(decreaseLayout:));
        passed = passed && [plus.cell isKindOfClass:InkButtonCell.class] && plus.bounds.size.height >= 56 &&
            NSContainsRect(NSInsetRect(panel.bounds, 3, 3), [plus convertRect:plus.bounds toView:panel]) &&
            NSContainsRect(NSInsetRect(panel.bounds, 3, 3), [minus convertRect:minus.bounds toView:panel]);
        if (stage == 1) {
            [self writeNativeSnapshot:self.toolbarScroll.documentView name:@"paperlike-toolbar.png"];
            [self writeNativeSnapshot:panel name:@"paperlike-margins.png"];
        }
        if (passed) [plus performClick:nil];
    } else if (stage == 2) {
        passed = fabs(self.pageMargin - 20) < 0.01 && [self.layoutValue.stringValue containsString:@"20"];
        if (passed) [ButtonForAction(panel, @selector(resetLayout:)) performClick:nil];
    } else if (stage == 3) {
        passed = fabs(self.pageMargin) < 0.01 && [self.layoutValue.stringValue isEqualToString:@"默认"];
        NSButton *button = ButtonForAction(self.toolbarScroll.documentView, @selector(showLineSpacing:));
        [self.toolbarScroll.documentView scrollRectToVisible:button.frame];
        if (passed) [button performClick:nil];
    } else if (stage == 5) {
        passed = fabs(self.lineSpacing - 1.6) < 0.01 && [self.layoutValue.stringValue containsString:@"1.6"];
        [self writeNativeSnapshot:panel name:@"paperlike-line-spacing.png"];
        if (passed) [ButtonForAction(panel, @selector(resetLayout:)) performClick:nil];
    } else {
        passed = self.lineSpacing == 0 && [self.layoutValue.stringValue isEqualToString:@"默认"];
        [self.layoutPopover close];
        NSButton *last = ButtonForAction(self.toolbarScroll.documentView, @selector(fullScreen:));
        [self.toolbarScroll.documentView scrollRectToVisible:last.frame];
        NSRect visible = self.toolbarScroll.contentView.bounds;
        passed = passed && NSContainsRect(NSInsetRect(visible, -1, -1), last.frame);
        BOOL previousInk = self.ink;
        [self.inkButton performClick:nil];
        passed = passed && self.ink != previousInk && self.inkButton.state == (self.ink ? NSControlStateValueOn : NSControlStateValueOff);
        [self.inkButton performClick:nil];
        passed = passed && self.ink == previousInk;
        [self writeNativeSnapshot:self.toolbarScroll name:@"paperlike-toolbar-scroll.png"];
        fprintf(stdout, "NATIVE UI %s · margin/line buttons, reset, toolbar scrolling, ink state\n", passed ? "PASS" : "FAIL"); fflush(stdout);
        exit(passed ? 0 : 10);
    }
    if (!passed) { fprintf(stderr, "NATIVE UI FAIL at stage %lu\n", (unsigned long)stage); exit(10); }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 300 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkNativeUITest:stage + 1]; });
}
- (void)checkAITest:(NSUInteger)attempt {
    NSString *js = @"(() => {const frame=document.querySelector('.readerAIChatPanel_frame'),d=frame?.contentDocument;if(!d?.querySelector('.UserMessage_text__test')||!frame.contentWindow.PaperlikeAI)return {passed:false,frameReady:false};const cs=x=>getComputedStyle(x),fc=x=>frame.contentWindow.getComputedStyle(x);const input=document.querySelector('.readerAIChatPanel_footer_textarea'),send=document.querySelector('.readerAIChatPanel_footer_sendButton'),answer=d.querySelector('[class*=markdown-body]'),question=d.querySelector('[class*=UserMessage_text]'),reference=d.querySelector('[class*=UserMessage_reference]'),suggestion=d.querySelector('[class*=ChatSuggestion_question_item]'),scroll=d.querySelector('[class*=ChatSessions_container]');const panel=document.querySelector('.readerAIChatPanel').getBoundingClientRect(),ir=input.getBoundingClientRect(),fr=frame.getBoundingClientRect();const font=parseFloat(fc(answer).fontSize),inputFont=parseFloat(cs(input).fontSize),sendSize=send.getBoundingClientRect().width;const black=fc(answer).color==='rgb(0, 0, 0)'&&cs(input).color==='rgb(0, 0, 0)';const border=parseFloat(fc(suggestion).borderTopWidth)>=1.5;const overlay=d.querySelector('[class*=Toast_toast_container]');const overlayTransparent=!!overlay&&fc(overlay).backgroundColor==='rgba(0, 0, 0, 0)';const frameInk=d.documentElement.dataset.paperlikeAiInk==='true';const bounds=panel.left>=0&&panel.right<=innerWidth+1&&panel.top>=0&&panel.bottom<=innerHeight+1&&fr.height>80&&ir.top>=fr.bottom-2&&ir.bottom<=panel.bottom;scroll.scrollTop=scroll.scrollHeight;const scrollable=scroll.scrollHeight>scroll.clientHeight&&scroll.scrollTop>0;suggestion.click();const clicked=d.body.dataset.testClicked;return {passed:font>=20&&inputFont>=22&&sendSize>=55.9&&black&&border&&overlayTransparent&&frameInk&&bounds&&scrollable&&Number(clicked)>0,font,inputFont,sendSize,black,border,overlayTransparent,borderStyle:fc(suggestion).borderTopStyle,borderWidth:fc(suggestion).borderTopWidth,frameInk,bounds,scrollable,clicked,questionFont:parseFloat(fc(question).fontSize),referenceFont:parseFloat(fc(reference).fontSize)};})()";
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        NSDictionary *r = [result isKindOfClass:NSDictionary.class] ? result : @{};
        BOOL passed = !error && [r[@"passed"] boolValue];
        if (!passed && attempt < 30) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkAITest:attempt + 1]; });
            return;
        }
        if (passed && !self.aiThemeTested) {
            self.aiThemeTested = YES;
            [self.webView evaluateJavaScript:@"window.PaperlikeReader.setInk(false)" completionHandler:nil];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                [self.webView evaluateJavaScript:@"(() => {const d=document.querySelector('iframe').contentDocument;return d.documentElement.dataset.paperlikeAiInk==='false'&&getComputedStyle(d.querySelector('[class*=markdown-body]')).fontSize==='20px';})()" completionHandler:^(id value, NSError *themeError) {
                    if (themeError || ![value boolValue]) { fprintf(stderr, "AI THEME FAIL\n"); exit(9); }
                    [self.webView evaluateJavaScript:@"window.PaperlikeReader.setInk(true)" completionHandler:nil];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkAITest:0]; });
                }];
            });
            return;
        }
        fprintf(stdout, "AI DISPLAY %s\n%s\n", passed ? "PASS" : "FAIL", r.description.UTF8String); fflush(stdout);
        WKSnapshotConfiguration *snapshot = [[WKSnapshotConfiguration alloc] init];
        snapshot.snapshotWidth = @1100;
        [self.webView takeSnapshotWithConfiguration:snapshot completionHandler:^(NSImage *image, NSError *snapshotError) {
            if (image && !snapshotError) {
                NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
                NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"paperlike-ai-panel.png"];
                [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
                fprintf(stdout, "Snapshot: %s\n", path.UTF8String); fflush(stdout);
            }
            exit(passed ? 0 : 9);
        }];
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
