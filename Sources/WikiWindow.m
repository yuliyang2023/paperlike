#import "WikiWindow.h"
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

@interface WikiWindowController () <WKNavigationDelegate, WKUIDelegate, NSTextFieldDelegate>
@property WKWebView *webView;
@property NSTextField *searchField;
@property NSTextField *status;
@property NSButton *backButton;
@property NSButton *forwardButton;
@property NSUInteger testMode;
@property NSUInteger testStage;
@property NSUInteger testAttempts;
@property NSURL *requestedURL;
@end

@implementation WikiWindowController
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
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1100, 850)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self = [super initWithWindow:window];
    if (!self) return nil;
    self.testMode = mode;
    window.title = @"Wiki 搜索 · 墨读"; window.releasedWhenClosed = NO;
    window.minSize = NSMakeSize(820, 560);
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    window.backgroundColor = NSColor.whiteColor; window.titlebarAppearsTransparent = YES;
    [window center];
    WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore;
    NSString *script = [NSString stringWithContentsOfURL:[NSBundle.mainBundle URLForResource:@"wiki" withExtension:@"js"] encoding:NSUTF8StringEncoding error:nil];
    if (!script) { fprintf(stderr, "Missing wiki.js\n"); exit(1); }
    [configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:script injectionTime:WKUserScriptInjectionTimeAtDocumentEnd forMainFrameOnly:YES]];
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
    [self.searchField.widthAnchor constraintGreaterThanOrEqualToConstant:240].active = YES;
    [self.searchField setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSButton *search = [self button:@"搜索" action:@selector(submitSearch:)];
    NSStackView *toolbar = [NSStackView stackViewWithViews:@[self.backButton, self.forwardButton, self.searchField, search]];
    toolbar.orientation = NSUserInterfaceLayoutOrientationHorizontal; toolbar.alignment = NSLayoutAttributeCenterY;
    toolbar.spacing = 12; toolbar.edgeInsets = NSEdgeInsetsMake(12,16,12,16);
    toolbar.wantsLayer = YES; toolbar.layer.backgroundColor = NSColor.whiteColor.CGColor;
    toolbar.layer.borderColor = NSColor.blackColor.CGColor; toolbar.layer.borderWidth = 1;
    self.status = [NSTextField labelWithString:@"输入关键词后按回车搜索 · 书籍阅读窗口会保留"];
    self.status.font = [NSFont systemFontOfSize:20 weight:NSFontWeightMedium]; self.status.textColor = NSColor.blackColor;
    self.status.lineBreakMode = NSLineBreakByTruncatingTail;
    NSView *root = window.contentView;
    for (NSView *view in @[toolbar, self.webView, self.status]) { view.translatesAutoresizingMaskIntoConstraints = NO; [root addSubview:view]; }
    [NSLayoutConstraint activateConstraints:@[
        [toolbar.topAnchor constraintEqualToAnchor:root.topAnchor], [toolbar.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [toolbar.trailingAnchor constraintEqualToAnchor:root.trailingAnchor], [toolbar.heightAnchor constraintEqualToConstant:80],
        [self.webView.topAnchor constraintEqualToAnchor:toolbar.bottomAnchor], [self.webView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor], [self.webView.bottomAnchor constraintEqualToAnchor:self.status.topAnchor constant:-12],
        [self.status.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:16], [self.status.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-16],
        [self.status.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-12]
    ]];
    [self.webView loadHTMLString:@"<!doctype html><html lang='zh-CN'><meta charset='utf-8'><title>Wiki 搜索</title><main class='mw-page-container'><h1>Wiki 搜索</h1><p>在上方输入关键词，搜索中文维基百科。</p><p>搜索结果和词条将采用适合墨水屏的大字、白底黑字显示。</p></main>" baseURL:[NSURL URLWithString:@"https://zh.wikipedia.org/"]];
    return self;
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
- (void)showSearch {
    [self showWindow:nil]; [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeFirstResponder:self.searchField];
    [self configureSearchEditor];
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
    if (!query.length) { self.status.stringValue = @"请输入要查询的关键词。"; [self.window makeFirstResponder:self.searchField]; return; }
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
    self.backButton.enabled = webView.canGoBack; self.forwardButton.enabled = webView.canGoForward;
    self.window.title = [NSString stringWithFormat:@"%@ · Wiki · 墨读", webView.title ?: @"维基百科"];
    self.status.stringValue = @"Wiki 已就绪 · 可继续点击词条链接 · 返回阅读请切换到书籍窗口";
    if (self.testMode && self.testStage) {
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
    [self showSearch];
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
    NSString *js = @"(() => {const visible=x=>!!x&&x.getBoundingClientRect().width>0&&x.getBoundingClientRect().height>0;const search=document.querySelector('.mw-search-result-heading a'),article=document.querySelector('.mw-parser-output p');const target=visible(search)?search:article;if(!target)return {passed:false,missing:true};const s=getComputedStyle(target),r=target.getBoundingClientRect();const overlays=[...document.querySelectorAll('.test-overlay')].every(x=>getComputedStyle(x).backgroundColor==='rgba(0, 0, 0, 0)');return {passed:!!window.PaperlikeWiki&&parseFloat(s.fontSize)>=22&&s.color==='rgb(0, 0, 0)'&&getComputedStyle(document.body).backgroundColor==='rgb(255, 255, 255)'&&r.width>0&&r.height>0&&overlays,api:!!window.PaperlikeWiki,url:location.href,base:document.baseURI,styles:document.querySelectorAll('#paperlike-wiki-style').length,font:s.fontSize,color:s.color,overlays,title:document.title,article:visible(article),search:visible(search)};})()";
    [self.webView evaluateJavaScript:js completionHandler:^(id result, NSError *error) {
        NSDictionary *r = [result isKindOfClass:NSDictionary.class] ? result : @{};
        BOOL passed = !error && [r[@"passed"] boolValue] && (self.testStage == 1 ? [r[@"search"] boolValue] : [r[@"article"] boolValue]);
        if (!passed && self.testAttempts++ < 20) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ [self checkDisplayTest]; }); return;
        }
        if (!passed) { fprintf(stderr, "WIKI DISPLAY FAIL %s %s\n", r.description.UTF8String, error.description.UTF8String); exit(11); }
        if (self.testStage == 1) {
            self.testStage = 2;
            [self.webView evaluateJavaScript:@"document.querySelector('.mw-search-result-heading a').click();true" completionHandler:nil];
            return;
        }
        fprintf(stdout, "WIKI DISPLAY PASS · search, article, URL encoding, domain checks\n%s\n", r.description.UTF8String); fflush(stdout);
        NSView *root = self.window.contentView;
        NSRect toolbarRect = NSMakeRect(0, NSHeight(root.bounds) - 80, NSWidth(root.bounds), 80);
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
    }];
}
@end
