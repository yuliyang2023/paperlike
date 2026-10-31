#import <Cocoa/Cocoa.h>

@interface WikiPanelController : NSViewController
// 0: normal search, 1: offline fixtures, 2: public Wikipedia display check.
- (instancetype)initWithTestMode:(NSUInteger)mode;
- (void)presentInView:(NSView *)host readerView:(NSView *)reader query:(NSString *)query;
- (void)syncGeometry;
- (void)closePanel:(id)sender;
- (void)runDisplayTest;
@end
