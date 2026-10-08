// Renders a macOS-style app icon set from a Windows .ico: the art clipped to the
// Big Sur icon grid (824/1024 tile, ~22.5% corner radius) with a soft drop shadow.
// NSImage picks the closest native .ico size for each tile, so small sizes stay crisp.
// Usage: osascript -l JavaScript compose-icon.js game.ico out.iconset
ObjC.import('AppKit');

function run(argv) {
    const [icoPath, outDir] = argv;
    const art = $.NSImage.alloc.initWithContentsOfFile(icoPath);
    if (art.isNil()) throw new Error('could not read ' + icoPath);

    const sizes = [[16, '16x16'], [32, '16x16@2x'], [32, '32x32'], [64, '32x32@2x'],
        [128, '128x128'], [256, '128x128@2x'], [256, '256x256'], [512, '256x256@2x'],
        [512, '512x512'], [1024, '512x512@2x']];

    for (const [px, name] of sizes) {
        const rep = $.NSBitmapImageRep.alloc
            .initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(
                null, px, px, 8, 4, true, false, $.NSDeviceRGBColorSpace, 0, 0);
        rep.size = $.NSMakeSize(px, px);
        const ctx = $.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep);
        $.NSGraphicsContext.saveGraphicsState;
        $.NSGraphicsContext.setCurrentContext(ctx);
        ctx.imageInterpolation = $.NSImageInterpolationHigh;

        const tile = Math.round(px * 824 / 1024);
        const off = Math.floor((px - tile) / 2);
        const rect = $.NSMakeRect(off, off, tile, tile);
        const shape = $.NSBezierPath.bezierPathWithRoundedRectXRadiusYRadius(rect, tile * 0.225, tile * 0.225);

        if (px >= 64) {
            $.NSGraphicsContext.saveGraphicsState;
            const shadow = $.NSShadow.alloc.init;
            shadow.shadowColor = $.NSColor.colorWithCalibratedWhiteAlpha(0, 0.3);
            shadow.shadowBlurRadius = px * 0.024;
            shadow.shadowOffset = $.NSMakeSize(0, -px * 0.012);
            shadow.set;
            $.NSColor.blackColor.setFill;
            shape.fill;
            $.NSGraphicsContext.restoreGraphicsState;
        }

        $.NSGraphicsContext.saveGraphicsState;
        shape.addClip;
        art.drawInRectFromRectOperationFraction(rect, $.NSZeroRect, $.NSCompositingOperationSourceOver, 1.0);
        $.NSGraphicsContext.restoreGraphicsState;

        ctx.flushGraphics;
        $.NSGraphicsContext.restoreGraphicsState;
        const png = rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $.NSDictionary.dictionary);
        if (!png.writeToFileAtomically(outDir + '/icon_' + name + '.png', true)) {
            throw new Error('could not write icon_' + name + '.png');
        }
    }
}
