import AppKit
let representation = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
NSColor(calibratedRed: 0.79, green: 0.145, blue: 0.208, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 285, y: 456, width: 455, height: 112), xRadius: 32, yRadius: 32).fill()
for x in [220.0, 670.0] {
    NSBezierPath(roundedRect: NSRect(x: x, y: 338, width: 134, height: 348), xRadius: 38, yRadius: 38).fill()
}
NSGraphicsContext.restoreGraphicsState()
let data = representation.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: "GymBlock/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
