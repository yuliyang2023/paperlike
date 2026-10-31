#import <Cocoa/Cocoa.h>

@interface WikiWindowController : NSWindowController
// 0: normal search, 1: offline fixtures, 2: public Wikipedia display check.
- (instancetype)initWithTestMode:(NSUInteger)mode;
- (void)showSearch;
- (void)runDisplayTest;
@end
