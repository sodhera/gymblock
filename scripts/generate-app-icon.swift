// Renders GymBlock's app icon (1024×1024 PNG): a bold white padlock on a
// safety-orange field. Full-bleed square — iOS applies the mask.
// Run: swiftc scripts/generate-app-icon.swift -framework AppKit -o /tmp/genicon && /tmp/genicon
import AppKit

let size: CGFloat = 1024
let out = "GymBlock/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Field: safety orange with a whisper of vertical light (top a touch warmer).
let top = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.16, alpha: 1)
let bottom = NSColor(srgbRed: 0.96, green: 0.33, blue: 0.08, alpha: 1)
NSGradient(starting: top, ending: bottom)!.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -90)

// Lock glyph.
let config = NSImage.SymbolConfiguration(pointSize: 520, weight: .bold)
    .applying(.init(paletteColors: [.white]))
if let lock = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
    let s = lock.size
    let rect = NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2 - 10, width: s.width, height: s.height)
    // Soft contact shadow so the lock sits on the field.
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = 30
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    lock.draw(in: rect)
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
