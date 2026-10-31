#import "InkControls.h"

@implementation InkButtonCell
- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view {
    BOOL pressed = self.highlighted && self.enabled;
    BOOL selected = self.state == NSControlStateValueOn;
    NSRect border = NSInsetRect(frame, 1.5, 1.5);
    NSBezierPath *shape = [NSBezierPath bezierPathWithRoundedRect:border xRadius:6 yRadius:6];
    [(pressed ? NSColor.blackColor : NSColor.whiteColor) setFill];
    [shape fill];
    [NSColor.blackColor setStroke];
    shape.lineWidth = selected ? 3 : 2;
    if (!self.enabled) { CGFloat dash[] = {5, 4}; [shape setLineDash:dash count:2 phase:0]; }
    [shape stroke];
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *attributes = @{
        NSFontAttributeName: self.font ?: [NSFont systemFontOfSize:22 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: pressed ? NSColor.whiteColor : NSColor.blackColor,
        NSParagraphStyleAttributeName: paragraph
    };
    NSSize size = [self.title sizeWithAttributes:attributes];
    NSRect text = NSMakeRect(NSMinX(frame) + 12, NSMidY(frame) - size.height / 2,
                            MAX(0, NSWidth(frame) - 24), size.height);
    [self.title drawInRect:text withAttributes:attributes];
    // Keyboard focus stays visible without a blue glow or an animated ring.
    if (view.window.firstResponder == view) {
        NSBezierPath *focus = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(frame, 6, 6) xRadius:3 yRadius:3];
        [(pressed ? NSColor.whiteColor : NSColor.blackColor) setStroke];
        CGFloat dash[] = {3, 3}; [focus setLineDash:dash count:2 phase:0];
        focus.lineWidth = 1; [focus stroke];
    }
}
@end

@implementation InkButton
- (BOOL)becomeFirstResponder { BOOL result = [super becomeFirstResponder]; self.needsDisplay = YES; return result; }
- (BOOL)resignFirstResponder { BOOL result = [super resignFirstResponder]; self.needsDisplay = YES; return result; }
@end

@implementation InkScroller
- (void)drawKnobSlotInRect:(NSRect)rect highlight:(BOOL)highlight {
    (void)highlight;
    [NSColor.whiteColor setFill]; NSRectFill(rect);
    [NSColor.blackColor setStroke];
    NSBezierPath *track = [NSBezierPath bezierPathWithRect:NSInsetRect(rect, 0.5, 0.5)];
    track.lineWidth = 1; [track stroke];
}
- (void)drawKnob {
    NSRect rect = NSInsetRect([self rectForPart:NSScrollerKnob], 2, 2);
    [NSColor.blackColor setFill];
    [[NSBezierPath bezierPathWithRoundedRect:rect xRadius:3 yRadius:3] fill];
}
@end
