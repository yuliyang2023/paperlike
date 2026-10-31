#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            fprintf(stderr, "Usage: make-app-icon source.png output.png\n");
            return 1;
        }
        NSImage *source = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        if (!source) { fprintf(stderr, "Cannot load icon source\n"); return 1; }
        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL pixelsWide:1024 pixelsHigh:1024
            bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
            colorSpaceName:NSCalibratedRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:bitmap]];
        NSRectFillUsingOperation(NSMakeRect(0, 0, 1024, 1024), NSCompositingOperationClear);

        // Native macOS icons leave room around their rounded-square artwork.
        // A full-bleed App Store image otherwise appears larger in Launchpad.
        NSRect artwork = NSMakeRect(100, 100, 824, 824);
        NSBezierPath *shape = [NSBezierPath bezierPathWithRoundedRect:artwork xRadius:184 yRadius:184];
        [NSGraphicsContext saveGraphicsState];
        NSShadow *shadow = [[NSShadow alloc] init];
        shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.16];
        shadow.shadowBlurRadius = 14;
        shadow.shadowOffset = NSMakeSize(0, -10);
        [shadow set];
        [NSColor.whiteColor setFill];
        [shape fill];
        [NSGraphicsContext restoreGraphicsState];

        [shape addClip];
        [source drawInRect:artwork fromRect:NSZeroRect operation:NSCompositingOperationSourceOver
            fraction:1 respectFlipped:NO hints:@{NSImageHintInterpolation: @(NSImageInterpolationHigh)}];
        [NSGraphicsContext restoreGraphicsState];
        NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSError *error = nil;
        if (![png writeToFile:[NSString stringWithUTF8String:argv[2]] options:NSDataWritingAtomic error:&error]) {
            fprintf(stderr, "Cannot write app icon: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
    }
    return 0;
}
