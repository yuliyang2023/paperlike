#import "WikiPanel.h"
#import "InkControls.h"
#import <WebKit/WebKit.h>

@interface WikiSearchCell : NSTextFieldCell
@end
@implementation WikiSearchCell
- (NSRect)drawingRectForBounds:(NSRect)bounds {
    NSRect rect = [super drawingRectForBounds:bounds];
    CGFloat height = MIN(NSHeight(rect), ceil(self.font.ascender - self.font.descender + self.font.leading) + 4);
    rect.origin.y += (NSHeight(rect) - height) / 2; rect.size.height = height;
    rect.origin.x += 10; rect.size.width = MAX(0, NSWidth(rect) - 20);
    return rect;
}
- (void)editWithFrame:(NSRect)frame inView:(NSView *)view editor:(NSText *)editor delegate:(id)delegate event:(NSEvent *)event {
    [super editWithFrame:[self drawingRectForBounds:frame] inView:view editor:editor delegate:delegate event:event];
}
- (void)selectWithFrame:(NSRect)frame inView:(NSView *)view editor:(NSText *)editor delegate:(id)delegate start:(NSInteger)start length:(NSInteger)length {
    [super selectWithFrame:[self drawingRectForBounds:frame] inView:view editor:editor delegate:delegate start:start length:length];
}
@end

@interface WikiPanelController () <WKNavigationDelegate, WKUIDelegate, NSTextFieldDelegate>
@property WKWebView *webView;
@property NSTextField *searchField;
@property NSTextField *status;
@property NSButton *backButton;
@property NSButton *forwardButton;
@property NSUInteger testMode;
@property NSUInteger testStage;
@property NSUInteger testAttempts;
@property NSURL *requestedURL;
@property NSString *pageStyleScript;
@property CGFloat fontSize;
@property CGFloat pageMargin;
@property NSTextField *fontValue;
@property NSButton *fontMinus;
@property NSButton *fontPlus;
@property NSButton *marginButton;
@property NSButton *resetButton;
@property NSScrollView *toolbarScroll;
@property NSPopover *marginPopover;
@property NSTextField *marginValue;
@property NSButton *marginMinus;
@property NSButton *marginPlus;
@property NSDictionary *baselineLayout;
@property id outsideClickMonitor;
@property (weak) NSView *readerView;
@end

@implementation WikiPanelController
- (NSButton *)button:(NSString *)title action:(SEL)action {
    InkButton *button = [[InkButton alloc] initWithFrame:NSZeroRect];
    button.cell = [[InkButtonCell alloc] initTextCell:title];
    button.title = title; button.target = self; button.action = action;
    button.buttonType = NSButtonTypeMomentaryPushIn;
    button.focusRingType = NSFocusRingTypeNone;
    button.font = [NSFont systemFontOfSize:22 weight:NSFontWeightSemibold];
    [NSLayoutConstraint activateConstraints:@[
        [button.heightAnchor constraintEqualToConstant:56],
        [button.widthAnchor constraintGreaterThanOrEqualToConstant:ceil([title sizeWithAttributes:@{NSFontAttributeName:button.font}].width) + 32]
    ]];
    return button;
}
- (instancetype)initWithTestMode:(NSUInteger)mode {
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    self.testMode = mode;
    [NSUserDefaults.standardUserDefaults registerDefaults:@{@"wikiFontSize":@28, @"wikiPageMargin":@60}];
    self.fontSize = mode ? 28 : fmin(48, fmax(20, [NSUserDefaults.standardUserDefaults doubleForKey:@"wikiFontSize"]));
    self.pageMargin = mode ? 60 : fmin(240, fmax(0, [NSUserDefaults.standardUserDefaults doubleForKey:@"wikiPageMargin"]));
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 900, 800)];
    self.view.wantsLayer = YES; self.view.layer.backgroundColor = NSColor.whiteColor.CGColor;
    self.view.layer.borderColor = NSColor.blackColor.CGColor; self.view.layer.borderWidth = 2; self.view.layer.cornerRadius = 8;
    self.view.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    NSString *script = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"wiki" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil];
    if (!script) { fprintf(stderr, "Missing wiki.js\n"); exit(1); }
    self.pageStyleScript = script;
    NSString *initial = [script stringByAppendingFormat:@"\nwindow.PaperlikeWiki?.setLayout(%g, %g);", self.fontSize, self.pageMargin];
    [configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:initial injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES]];
    self.webView = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:configuration];
    self.webView.navigationDelegate = self; self.webView.UIDelegate = self;
    self.webView.allowsBackForwardNavigationGestures = YES;
    self.backButton = [self button:@"← 返回" action:@selector(goBack:)];
    self.forwardButton = [self button:@"前进 →" action:@selector(goForward:)];
    self.backButton.enabled = NO; self.forwardButton.enabled = NO;
    self.searchField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.searchField.cell = [[WikiSearchCell alloc] initTextCell:@""];
    self.searchField.delegate = self;
    self.searchField.editable = YES; self.searchField.selectable = YES;
    self.searchField.font = [NSFont systemFontOfSize:22 weight:NSFontWeightMedium];
    self.searchField.placeholderAttributedString = [[NSAttributedString alloc] initWithString:@"搜索中文维基百科" attributes:@{NSForegroundColorAttributeName:NSColor.blackColor,NSFontAttributeName:self.searchField.font}];
    self.searchField.textColor = NSColor.blackColor; self.searchField.backgroundColor = NSColor.whiteColor;
    self.searchField.drawsBackground = YES; self.searchField.bordered = NO; self.searchField.bezeled = NO;
    self.searchField.wantsLayer = YES; self.searchField.layer.borderWidth = 2;
    self.searchField.layer.borderColor = NSColor.blackColor.CGColor; self.searchField.layer.cornerRadius = 6;
    self.searchField.focusRingType = NSFocusRingTypeNone;
    self.searchField.target = self; self.searchField.action = @selector(submitSearch:);
    [self.searchField.heightAnchor constraintEqualToConstant:56].active = YES;
    [self.searchField.widthAnchor constraintEqualToConstant:280].active = YES;
    [self.searchField setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSButton *search = [self button:@"搜索" action:@selector(submitSearch:)];
    self.fontMinus = [self button:@"字号 −" action:@selector(decreaseFont:)];
    self.fontPlus = [self button:@"字号 ＋" action:@selector(increaseFont:)];
    self.fontValue = [NSTextField labelWithString:@"28 px"];
    self.fontValue.font = [NSFont monospacedDigitSystemFontOfSize:26 weight:NSFontWeightSemibold];
    self.fontValue.textColor = NSColor.blackColor; self.fontValue.alignment = NSTextAlignmentCenter;
    [self.fontValue.widthAnchor constraintEqualToConstant:100].active = YES;
    self.marginButton = [self button:@"页边距" action:@selector(showMargin:)];
    self.resetButton = [self button:@"恢复默认" action:@selector(resetReadingLayout:)];
    NSStackView *toolbar = [NSStackView stackViewWithViews:@[self.backButton, self.forwardButton, self.searchField, search, self.fontMinus, self.fontValue, self.fontPlus, self.marginButton, self.resetButton]];
    toolbar.orientation = NSUserInterfaceLayoutOrientationHorizontal; toolbar.alignment = NSLayoutAttributeCenterY;
    toolbar.spacing = 12; toolbar.edgeInsets = NSEdgeInsetsMake(12,16,12,16);
    toolbar.wantsLayer = YES; toolbar.layer.backgroundColor = NSColor.whiteColor.CGColor;
    toolbar.layer.borderColor = NSColor.blackColor.CGColor; toolbar.layer.borderWidth = 1;
    NSSize toolbarSize = toolbar.fittingSize;
    toolbar.frame = NSMakeRect(0, 0, ceil(toolbarSize.width) + 32, 80);
    self.toolbarScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    self.toolbarScroll.documentView = toolbar;
    self.toolbarScroll.hasHorizontalScroller = YES; self.toolbarScroll.hasVerticalScroller = NO;
    self.toolbarScroll.autohidesScrollers = NO; self.toolbarScroll.scrollerStyle = NSScrollerStyleLegacy;
    self.toolbarScroll.horizontalScroller = [[InkScroller alloc] initWithFrame:NSZeroRect];
    self.toolbarScroll.drawsBackground = YES; self.toolbarScroll.backgroundColor = NSColor.whiteColor;
    self.toolbarScroll.wantsLayer = YES; self.toolbarScroll.layer.borderWidth = 1;
    self.toolbarScroll.layer.borderColor = NSColor.blackColor.CGColor;
    [self updateReadingControls];
    NSTextField *heading = [NSTextField labelWithString:@"Wiki 搜索"];
    heading.font = [NSFont systemFontOfSize:26 weight:NSFontWeightSemibold]; heading.textColor = NSColor.blackColor;
    NSButton *close = [self button:@"关闭" action:@selector(closePanel:)];
    NSView *spacer = [[NSView alloc] initWithFrame:NSZeroRect];
    NSStackView *header = [NSStackView stackViewWithViews:@[heading,spacer,close]];
    header.orientation = NSUserInterfaceLayoutOrientationHorizontal; header.alignment = NSLayoutAttributeCenterY;
    header.edgeInsets = NSEdgeInsetsMake(8,16,8,16);
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    self.status = [NSTextField labelWithString:@"书内查词 · 关闭侧栏即可继续阅读"];
    self.status.font = [NSFont systemFontOfSize:20 weight:NSFontWeightMedium]; self.status.textColor = NSColor.blackColor;
    self.status.lineBreakMode = NSLineBreakByTruncatingTail;
    NSView *root = self.view;
    for (NSView *view in @[header, self.toolbarScroll, self.webView, self.status]) { view.translatesAutoresizingMaskIntoConstraints = NO; [root addSubview:view]; }
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:root.topAnchor], [header.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:root.trailingAnchor], [header.heightAnchor constraintEqualToConstant:72],
        [self.toolbarScroll.topAnchor constraintEqualToAnchor:header.bottomAnchor], [self.toolbarScroll.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.toolbarScroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor], [self.toolbarScroll.heightAnchor constraintEqualToConstant:100],
        [self.webView.topAnchor constraintEqualToAnchor:self.toolbarScroll.bottomAnchor], [self.webView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor], [self.webView.bottomAnchor constraintEqualToAnchor:self.status.topAnchor constant:-12],
        [self.status.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:16], [self.status.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-16],
        [self.status.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-12]
    ]];
    [self.webView loadHTMLString:@"<!doctype html><html lang='zh-CN'><meta charset='utf-8'><title>Wiki 搜索</title><main class='mw-page-container'><h1>Wiki 搜索</h1><p>在书中划词后点击选文工具条的 Wiki 搜索。</p><p>搜索结果和词条将采用适合墨水屏的大字、白底黑字显示。</p></main>" baseURL:[NSURL URLWithString:@"https://zh.wikipedia.org/"]];
    self.view.postsFrameChangedNotifications = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(panelFrameChanged:) name:NSViewFrameDidChangeNotification object:self.view];
    return self;
}
- (CGFloat)maximumMargin {
    CGFloat width = NSWidth(self.view.bounds);
    return MAX(0, MIN(240, floor((width - 336) / 40) * 20));
}
- (void)panelFrameChanged:(NSNotification *)notification {
    (void)notification;
    if (self.view.superview && self.pageMargin > [self maximumMargin]) [self applyReadingLayout];
    else [self updateReadingControls];
}
- (void)updateReadingControls {
    self.fontValue.stringValue = [NSString stringWithFormat:@"%.0f px", self.fontSize];
    self.fontMinus.enabled = self.fontSize > 20; self.fontPlus.enabled = self.fontSize < 48;
    self.marginValue.stringValue = [NSString stringWithFormat:@"%.0f px", self.pageMargin];
    self.marginMinus.enabled = self.pageMargin > 0; self.marginPlus.enabled = self.pageMargin < [self maximumMargin];
}
- (void)applyReadingLayout {
    self.pageMargin = MIN(self.pageMargin, [self maximumMargin]);
    [self updateReadingControls];
    NSString *command = [NSString stringWithFormat:@"window.PaperlikeWiki?.setLayout(%g, %g)", self.fontSize, self.pageMargin];
    [self.webView evaluateJavaScript:command completionHandler:nil];
    // Update future navigations as well as the currently visible page.
    NSString *initial = [self.pageStyleScript stringByAppendingFormat:@"\n%@;", command];
    [self.webView.configuration.userContentController removeAllUserScripts];
    [self.webView.configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:initial injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES]];
    if (!self.testMode) {
        [NSUserDefaults.standardUserDefaults setDouble:self.fontSize forKey:@"wikiFontSize"];
        [NSUserDefaults.standardUserDefaults setDouble:self.pageMargin forKey:@"wikiPageMargin"];
    }
}
- (void)decreaseFont:(id)sender { (void)sender; self.fontSize = MAX(20, self.fontSize - 2); [self applyReadingLayout]; }
- (void)increaseFont:(id)sender { (void)sender; self.fontSize = MIN(48, self.fontSize + 2); [self applyReadingLayout]; }
- (void)decreaseMargin:(id)sender { (void)sender; self.pageMargin = MAX(0, self.pageMargin - 20); [self applyReadingLayout]; }
- (void)increaseMargin:(id)sender { (void)sender; self.pageMargin = MIN([self maximumMargin], self.pageMargin + 20); [self applyReadingLayout]; }
- (void)resetReadingLayout:(id)sender { (void)sender; self.fontSize = 28; self.pageMargin = 60; [self applyReadingLayout]; }
- (void)showMargin:(id)sender {
    (void)sender; [self.marginPopover close];
    NSTextField *title = [NSTextField labelWithString:@"Wiki 左右页边距"];
    title.font = [NSFont systemFontOfSize:26 weight:NSFontWeightSemibold]; title.textColor = NSColor.blackColor;
    self.marginValue = [NSTextField labelWithString:@"60 px"];
    self.marginValue.font = [NSFont monospacedDigitSystemFontOfSize:30 weight:NSFontWeightSemibold];
    self.marginValue.textColor = NSColor.blackColor; self.marginValue.alignment = NSTextAlignmentCenter;
    [self.marginValue.widthAnchor constraintEqualToConstant:224].active = YES;
    self.marginMinus = [self button:@"−" action:@selector(decreaseMargin:)];
    self.marginPlus = [self button:@"＋" action:@selector(increaseMargin:)];
    [self.marginMinus.widthAnchor constraintGreaterThanOrEqualToConstant:80].active = YES;
    [self.marginPlus.widthAnchor constraintGreaterThanOrEqualToConstant:80].active = YES;
    NSStackView *row = [NSStackView stackViewWithViews:@[self.marginMinus,self.marginValue,self.marginPlus]];
    row.spacing = 12; row.alignment = NSLayoutAttributeCenterY;
    NSTextField *hint = [NSTextField labelWithString:@"左右同时调整，每次 20 px"];
    hint.font = [NSFont systemFontOfSize:20 weight:NSFontWeightMedium]; hint.textColor = NSColor.blackColor;
    NSStackView *stack = [NSStackView stackViewWithViews:@[title,row,hint]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical; stack.alignment = NSLayoutAttributeCenterX; stack.spacing = 12;
    NSSize size = stack.fittingSize; size.width += 40; size.height += 40;
    NSView *panel = [[NSView alloc] initWithFrame:NSMakeRect(0,0,size.width,size.height)];
    panel.wantsLayer = YES; panel.layer.backgroundColor = NSColor.whiteColor.CGColor;
    panel.layer.borderColor = NSColor.blackColor.CGColor; panel.layer.borderWidth = 2; panel.layer.cornerRadius = 6;
    stack.translatesAutoresizingMaskIntoConstraints = NO; [panel addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:20], [stack.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-20],
        [stack.topAnchor constraintEqualToAnchor:panel.topAnchor constant:20], [stack.bottomAnchor constraintEqualToAnchor:panel.bottomAnchor constant:-20]
    ]];
    NSViewController *controller = [[NSViewController alloc] init]; controller.view = panel;
    self.marginPopover = [[NSPopover alloc] init]; self.marginPopover.behavior = NSPopoverBehaviorTransient;
    self.marginPopover.animates = NO; self.marginPopover.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    self.marginPopover.contentViewController = controller; self.marginPopover.contentSize = size;
    [self updateReadingControls];
    [self.toolbarScroll.documentView scrollRectToVisible:self.marginButton.frame];
    [self.marginPopover showRelativeToRect:self.marginButton.bounds ofView:self.marginButton preferredEdge:NSRectEdgeMinY];
}
- (BOOL)isWikiURL:(NSURL *)url {
    NSString *host = url.host.lowercaseString;
    return [url.scheme.lowercaseString isEqualToString:@"https"] && ([host isEqualToString:@"wikipedia.org"] || [host hasSuffix:@".wikipedia.org"]);
}
- (NSURL *)searchURL:(NSString *)query {
    NSURLComponents *parts = [NSURLComponents componentsWithString:@"https://zh.wikipedia.org/w/index.php"];
    parts.queryItems = @[[NSURLQueryItem queryItemWithName:@"search" value:query],
        [NSURLQueryItem queryItemWithName:@"title" value:@"Special:Search"],
        [NSURLQueryItem queryItemWithName:@"fulltext" value:@"1"], [NSURLQueryItem queryItemWithName:@"ns0" value:@"1"]];
    // Search uses form-style query decoding, where a literal plus would become a space.
    parts.percentEncodedQuery = [parts.percentEncodedQuery stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
    return parts.URL;
}
- (void)presentInView:(NSView *)host readerView:(NSView *)reader query:(NSString *)query {
    if (self.readerView != reader) {
        if (self.readerView) [NSNotificationCenter.defaultCenter removeObserver:self name:NSViewFrameDidChangeNotification object:self.readerView];
        self.readerView = reader; reader.postsFrameChangedNotifications = YES;
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(readerFrameChanged:) name:NSViewFrameDidChangeNotification object:reader];
    }
    if (!self.view.superview) {
        self.view.translatesAutoresizingMaskIntoConstraints = YES;
        [host addSubview:self.view positioned:NSWindowAbove relativeTo:reader];
    }
    [self syncGeometry];
    [host layoutSubtreeIfNeeded];
    if (!self.outsideClickMonitor) {
        __weak WikiPanelController *weakSelf = self;
        self.outsideClickMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown handler:^NSEvent *(NSEvent *event) {
            return [weakSelf handleOutsideClick:event] ? nil : event;
        }];
    }
    if (query.length) { self.searchField.stringValue = query; [self submitSearch:nil]; }
}
- (void)readerFrameChanged:(NSNotification *)notification { (void)notification; [self syncGeometry]; }
- (void)syncGeometry {
    NSView *reader = self.readerView, *host = self.view.superview;
    if (!reader || !host) return;
    CGFloat zoom = [(WKWebView *)reader pageZoom];
    CGFloat width = MIN(760 * zoom, MAX(0, NSWidth(reader.bounds) - 32 * zoom));
    CGFloat inset = (NSHeight(reader.bounds) / zoom <= 400 ? 8 : 16) * zoom;
    NSRect rect = NSMakeRect((NSWidth(reader.bounds)-width)/2, inset, width, MAX(0,NSHeight(reader.bounds)-2*inset));
    self.view.frame = [reader convertRect:rect toView:host];
}
- (BOOL)handleOutsideClick:(NSEvent *)event {
    NSWindow *window = self.view.window;
    if (!window || !self.view.superview) return NO;
    // The margin popover has its own AppKit window. Its controls belong to Wiki.
    if (self.marginPopover.shown && event.window == self.marginPopover.contentViewController.view.window) return NO;
    if (event.window != window) return NO;
    NSPoint point = [self.view convertPoint:event.locationInWindow fromView:nil];
    if (NSPointInRect(point, self.view.bounds)) return NO;
    [self closePanel:nil];
    // Match a dismissible overlay: the dismissing click must not turn a book page.
    return YES;
}
- (void)closePanel:(id)sender {
    (void)sender;
    if (self.outsideClickMonitor) { [NSEvent removeMonitor:self.outsideClickMonitor]; self.outsideClickMonitor = nil; }
    [self.marginPopover close]; [self.view removeFromSuperview];
}
- (void)dealloc {
    if (_outsideClickMonitor) [NSEvent removeMonitor:_outsideClickMonitor];
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
- (void)loadWikiURL:(NSURL *)url {
    self.requestedURL = url;
    if (self.testMode == 1) {
        NSString *fixture = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"wiki-test" withExtension:@"html"] encoding:NSUTF8StringEncoding error:nil];
        [self.webView loadHTMLString:fixture baseURL:url];
    } else [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}
- (void)configureSearchEditor {
    NSTextView *editor = (NSTextView *)self.searchField.currentEditor;
    editor.insertionPointColor = NSColor.blackColor;
    editor.selectedTextAttributes = @{NSBackgroundColorAttributeName:NSColor.blackColor, NSForegroundColorAttributeName:NSColor.whiteColor};
}
- (void)controlTextDidBeginEditing:(NSNotification *)notification {
    (void)notification; [self configureSearchEditor];
}
- (void)submitSearch:(id)sender {
    (void)sender;
    NSString *query = [self.searchField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!query.length) { self.status.stringValue = @"请输入要查询的关键词。"; [self.view.window makeFirstResponder:self.searchField]; return; }
    [self loadWikiURL:[self searchURL:query]];
}
- (void)goBack:(id)sender { (void)sender; [self.webView goBack]; }
- (void)goForward:(id)sender { (void)sender; [self.webView goForward]; }
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))handler {
    (void)webView;
    NSURL *url = action.request.URL;
    if ([self isWikiURL:url] || [url.absoluteString isEqualToString:@"about:blank"]) {
        if (self.testMode == 1 && action.navigationType == WKNavigationTypeLinkActivated) {
            handler(WKNavigationActionPolicyCancel); [self loadWikiURL:url]; return;
        }
        handler(WKNavigationActionPolicyAllow); return;
    }
    handler(WKNavigationActionPolicyCancel);
    if (!self.testMode && action.navigationType == WKNavigationTypeLinkActivated && [@[@"https",@"http"] containsObject:url.scheme.lowercaseString]) [NSWorkspace.sharedWorkspace openURL:url];
}
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)action windowFeatures:(WKWindowFeatures *)features {
    (void)webView; (void)configuration; (void)features;
    if ([self isWikiURL:action.request.URL]) [self loadWikiURL:action.request.URL];
    else if (!self.testMode && [@[@"https",@"http"] containsObject:action.request.URL.scheme.lowercaseString]) [NSWorkspace.sharedWorkspace openURL:action.request.URL];
    return nil;
}
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    (void)webView; (void)navigation; self.status.stringValue = @"正在加载 Wiki 页面…";
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    (void)navigation;
    [self applyReadingLayout];
    self.backButton.enabled = webView.canGoBack; self.forwardButton.enabled = webView.canGoForward;
    self.view.toolTip = webView.title ?: @"Wiki 搜索";
    self.status.stringValue = @"Wiki 已就绪 · 关闭侧栏返回阅读";
    if (self.testMode && (self.testStage == 1 || self.testStage == 2 || self.testStage == 4)) {
        // WebKit on older macOS can report pre-paint styles until the first snapshot.
        [self.webView takeSnapshotWithConfiguration:nil completionHandler:^(NSImage *image, NSError *error) {
            (void)image; (void)error; self.testAttempts = 0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkDisplayTest]; });
        }];
    }
}
- (void)failed:(NSError *)error {
    if (error.code == NSURLErrorCancelled) return;
    self.status.stringValue = @"Wiki 加载失败 · 请检查网络后重新搜索";
    if (self.testMode) { fprintf(stderr, "WIKI load FAIL: %s\n", error.localizedDescription.UTF8String); exit(11); }
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { (void)webView; (void)navigation; [self failed:error]; }
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { (void)webView; (void)navigation; [self failed:error]; }
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView { (void)webView; self.status.stringValue = @"Wiki 页面已停止 · 请重新搜索"; }
- (void)runDisplayTest {
    NSString *special = @"墨水屏 & Paperlike+#?";
    NSURLComponents *parts = [NSURLComponents componentsWithURL:[self searchURL:special] resolvingAgainstBaseURL:NO];
    BOOL encoding = [parts.queryItems.firstObject.value isEqualToString:special] && [parts.percentEncodedQuery containsString:@"%2B"] && parts.queryItems.count == 4 && parts.fragment.length == 0;
    BOOL domains = [self isWikiURL:[NSURL URLWithString:@"https://zh.wikipedia.org/wiki/Test"]] &&
        [self isWikiURL:[NSURL URLWithString:@"https://en.wikipedia.org/wiki/Test"]] &&
        ![self isWikiURL:[NSURL URLWithString:@"https://wikipedia.org.evil.example/"]] && ![self isWikiURL:[NSURL URLWithString:@"http://zh.wikipedia.org/"]];
    if (!encoding || !domains) { fprintf(stderr, "WIKI URL FAIL\n"); exit(11); }
    self.testStage = 1; self.searchField.stringValue = @"电子纸"; [self submitSearch:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ fprintf(stderr, "WIKI timeout\n"); exit(11); });
}
- (void)checkDisplayTest {
    NSUInteger expectedStage = self.testStage;
    NSString *js = @"(() => {const visible=x=>!!x&&x.getBoundingClientRect().width>0&&x.getBoundingClientRect().height>0;const search=document.querySelector('.mw-search-result-heading a'),article=document.querySelector('.mw-parser-output p');const target=visible(search)?search:article;if(!target)return {passed:false,missing:true};const s=getComputedStyle(target),r=target.getBoundingClientRect();const overlays=[...document.querySelectorAll('.test-overlay')].every(x=>getComputedStyle(x).backgroundColor==='rgba(0, 0, 0, 0)');return {passed:!!window.PaperlikeWiki&&parseFloat(s.fontSize)>=22&&s.color==='rgb(0, 0, 0)'&&getComputedStyle(document.body).backgroundColor==='rgb(255, 255, 255)'&&r.width>0&&r.height>0&&overlays,api:!!window.PaperlikeWiki,url:location.href,base:document.baseURI,styles:document.querySelectorAll('#paperlike-wiki-style').length,margin:window.PaperlikeWiki?.layoutState().effectiveMargin,requestedMargin:window.PaperlikeWiki?.layoutState().margin,viewport:innerWidth,contentWidth:document.querySelector('.mw-content-container')?.getBoundingClientRect().width,font:s.fontSize,color:s.color,overlays,title:document.title,article:visible(article),search:visible(search)};})()";
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        if (self.testStage != expectedStage) return;
        NSDictionary *r = [result isKindOfClass:NSDictionary.class] ? result : @{};
        BOOL passed = !error && [r[@"passed"] boolValue] && (self.testStage == 1 ? [r[@"search"] boolValue] : [r[@"article"] boolValue]);
        if (self.testStage == 3 || self.testStage == 4) {
            passed = passed && fabs([r[@"font"] doubleValue] - 30) < 0.1 && [r[@"margin"] intValue] == 80 &&
                [r[@"contentWidth"] doubleValue] < [self.baselineLayout[@"contentWidth"] doubleValue] - 30 &&
                [self.fontValue.stringValue isEqualToString:@"30 px"];
        } else if (self.testStage == 5) {
            passed = passed && fabs([r[@"font"] doubleValue] - 28) < 0.1 && [r[@"margin"] intValue] == 60 &&
                fabs([r[@"contentWidth"] doubleValue] - [self.baselineLayout[@"contentWidth"] doubleValue]) < 2;
        }
        if (!passed && self.testAttempts++ < 20) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkDisplayTest]; }); return;
        }
        if (!passed) { fprintf(stderr, "WIKI DISPLAY FAIL stage=%lu nativeFont=%g nativeMargin=%g panelWidth=%g %s %s\n", (unsigned long)self.testStage,self.fontSize,self.pageMargin,NSWidth(self.view.bounds),r.description.UTF8String,error.description.UTF8String); exit(11); }
        if (self.testStage == 1) {
            self.testStage = 2;
            [self.webView evaluateJavaScript:@"document.querySelector('.mw-search-result-heading a').click();true" completionHandler:nil];
            return;
        }
        if (self.testStage == 2) {
            self.testStage = 20; // Block duplicate navigation callbacks while the panel opens.
            self.baselineLayout = r;
            [self.fontPlus performClick:nil];
            [self showMargin:nil];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                NSView *panel = self.marginPopover.contentViewController.view;
                if (!self.marginPopover.shown || !NSContainsRect(NSInsetRect(panel.bounds,3,3), [self.marginPlus convertRect:self.marginPlus.bounds toView:panel])) { fprintf(stderr, "WIKI margin panel FAIL\n"); exit(11); }
                [self.marginPlus performClick:nil];
                NSBitmapImageRep *image = [panel bitmapImageRepForCachingDisplayInRect:panel.bounds];
                [panel cacheDisplayInRect:panel.bounds toBitmapImageRep:image];
                NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"paperlike-wiki-margin.png"];
                [[image representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
                [self.marginPopover close];
                self.testStage = 3; self.testAttempts = 0;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkDisplayTest]; });
            });
            return;
        }
        if (self.testStage == 3) {
            self.testStage = 4;
            [self loadWikiURL:self.webView.URL];
            return;
        }
        if (self.testStage == 4) {
            [self.resetButton performClick:nil];
            self.testStage = 5; self.testAttempts = 0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 200*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkDisplayTest]; });
            return;
        }
        [self verifyMatchingAIGeometry:0 completion:^{
            [self checkOutsideDismissal:0 completion:^{ [self finishDisplayTest:r]; }];
        }];
    }];
}
- (void)verifyMatchingAIGeometry:(NSUInteger)attempt completion:(void (^)(void))completion {
    WKWebView *reader = (WKWebView *)self.readerView;
    NSString *script = @"(() => {let p=document.querySelector('#paperlike-ai-geometry-test');if(!p){p=document.createElement('div');p.id='paperlike-ai-geometry-test';p.className='readerAIChatPanel';p.style.position='fixed';document.body.appendChild(p);}return p.getBoundingClientRect().toJSON();})()";
    [reader evaluateJavaScript:script completionHandler:^(id value,NSError *error) {
        NSRect rect = [self.view convertRect:self.view.bounds toView:reader];
        CGFloat zoom = reader.pageZoom;
        BOOL passed = !error && [value isKindOfClass:NSDictionary.class] &&
            fabs([value[@"x"] doubleValue]*zoom - NSMinX(rect)) < 2 &&
            fabs([value[@"width"] doubleValue]*zoom - NSWidth(rect)) < 2 &&
            fabs([value[@"height"] doubleValue]*zoom - NSHeight(rect)) < 2 &&
            fabs([value[@"y"] doubleValue]*zoom - (NSHeight(reader.bounds)-NSMaxY(rect))) < 2;
        if (!passed && attempt < 20) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self verifyMatchingAIGeometry:attempt+1 completion:completion];});return; }
        [reader evaluateJavaScript:@"document.querySelector('#paperlike-ai-geometry-test')?.remove();true" completionHandler:nil];
        if (!passed) {fprintf(stderr,"WIKI AI GEOMETRY FAIL %s native=%s zoom=%g\n",[value description].UTF8String,NSStringFromRect(rect).UTF8String,zoom);exit(11);}
        fprintf(stdout,"WIKI AI GEOMETRY PASS · same center and size at current zoom\n");fflush(stdout);
        completion();
    }];
}
- (void)checkOutsideDismissal:(NSUInteger)step completion:(void (^)(void))completion {
    NSView *host = self.view.superview, *reader = self.readerView;
    NSWindow *window = reader.window;
    if (!host || self.view.window != window || !self.outsideClickMonitor) { fprintf(stderr,"WIKI dismiss setup FAIL\n");exit(11); }
    NSPoint point = step == 0 ? [self.view convertPoint:NSMakePoint(20,NSHeight(self.view.bounds)-30) toView:nil] : [reader convertPoint:NSMakePoint(4,NSHeight(reader.bounds)/2) toView:nil];
    NSWindow *eventWindow = window;
    if (step == 1) {
        [self showMargin:nil];
        NSView *popover = self.marginPopover.contentViewController.view;
        eventWindow = popover.window;
        point = [popover convertPoint:NSMakePoint(20,NSHeight(popover.bounds)-30) toView:nil];
    }
    NSEventType type = step == 3 ? NSEventTypeRightMouseDown : NSEventTypeLeftMouseDown;
    NSEvent *event = [NSEvent mouseEventWithType:type location:point modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:eventWindow.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];
    NSURL *bookURL = [(WKWebView *)reader URL];
    [NSApp postEvent:event atStart:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,150*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        BOOL shown = self.view.superview == host && self.outsideClickMonitor != nil;
        BOOL closed = self.view.superview == nil && self.outsideClickMonitor == nil;
        BOOL unchanged = [[(WKWebView *)reader URL] isEqual:bookURL];
        if (!unchanged || (step < 2 ? !shown : !closed)) { fprintf(stderr,"WIKI outside click FAIL step=%lu\n",(unsigned long)step);exit(11); }
        if (step == 1) [self.marginPopover close];
        if (step >= 2) [self presentInView:host readerView:reader query:@""];
        if (step < 3) [self checkOutsideDismissal:step+1 completion:completion];
        else {
            fprintf(stdout,"WIKI DISMISS PASS · inside/popover retained, outside left/right closed, reopen, book retained\n");fflush(stdout);
            completion();
        }
    });
}
- (void)finishDisplayTest:(NSDictionary *)r {
        fprintf(stdout, "WIKI DISPLAY PASS · search, article, font/margins, navigation persistence, reset, URL checks\n%s\n", r.description.UTF8String); fflush(stdout);
        NSView *root = self.view;
        NSRect toolbarRect = NSMakeRect(0, NSHeight(root.bounds) - 172, NSWidth(root.bounds), 172);
        NSBitmapImageRep *toolbarImage = [root bitmapImageRepForCachingDisplayInRect:toolbarRect];
        [root cacheDisplayInRect:toolbarRect toBitmapImageRep:toolbarImage];
        NSString *toolbarPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"paperlike-wiki-toolbar.png"];
        [[toolbarImage representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:toolbarPath atomically:YES];
        fprintf(stdout, "Snapshot: %s\n", toolbarPath.UTF8String); fflush(stdout);
        WKSnapshotConfiguration *config = [[WKSnapshotConfiguration alloc] init]; config.snapshotWidth = @1100;
        [self.webView takeSnapshotWithConfiguration:config completionHandler:^(NSImage *image, NSError *snapshotError) {
            if (image && !snapshotError) {
                NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
                NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"paperlike-wiki.png"];
                [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}] writeToFile:path atomically:YES];
                fprintf(stdout, "Snapshot: %s\n", path.UTF8String); fflush(stdout);
            }
            exit(0);
        }];
}
@end
