// Renders the app icon: the paper stage (warm glow, quiet ink dots) with the brand mark, a padlock
// whose shackle is a barbell. Ink geometry with the emerald signal dot as the keyhole; the same
// shapes as `BrandMark` in GymBlock/BrandMark.swift (unit square, y down). Run from the repository root:
//   swift scripts/generate-app-icon.swift                 # 1024 px → the asset catalogue
//   swift scripts/generate-app-icon.swift 180 out.png     # a preview at another size
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
let side: CGFloat = arguments.count > 1 ? CGFloat(Double(arguments[1]) ?? 1024) : 1024
let output = arguments.count > 2 ? arguments[2] : "GymBlock/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

// Opaque RGB (no alpha channel): App Store icons must be opaque.
let space = CGColorSpaceCreateDeviceRGB()
let c = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let ink = CGColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
let signal = CGColor(red: 0.06, green: 0.60, blue: 0.42, alpha: 1)

// Stage.
c.setFillColor(CGColor(red: 0.961, green: 0.953, blue: 0.937, alpha: 1))
c.fill(CGRect(x: 0, y: 0, width: side, height: side))
func radial(_ alpha: CGFloat, _ radius: CGFloat, at p: CGPoint) {
  let colors = [CGColor(red: 1, green: 0.93, blue: 0.80, alpha: alpha),
                CGColor(red: 1, green: 0.93, blue: 0.80, alpha: alpha * 0.35),
                CGColor(red: 1, green: 0.93, blue: 0.80, alpha: 0)] as CFArray
  let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.45, 1])!
  c.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: radius, options: [])
}
let centre = CGPoint(x: side / 2, y: side * 0.53)
radial(0.9, side * 0.95, at: centre)
radial(0.8, side * 0.46, at: centre)
// Dots.
let step = side * 52 / 1024, r = side * 2.6 / 1024
var y = step / 2
while y < side {
  var x = step / 2
  while x < side {
    let d = min(1, hypot(x - centre.x, y - centre.y) / (side * 0.72))
    c.setFillColor(CGColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 0.03 + 0.09 * pow(1 - d, 1.6)))
    c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    x += step
  }
  y += step
}

// The mark, in a unit square (y down) filling the central 64% of the icon, centred on the glow.
// Keep these numbers identical to `BrandMark.ink` / `BrandMark.keyhole` in GymBlock/BrandMark.swift.
let markSide = side * 0.64
c.saveGState()
c.translateBy(x: centre.x - markSide / 2, y: centre.y + markSide / 2)
c.scaleBy(x: markSide, y: -markSide)
let inkShapes: [(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, radius: CGFloat)] = [
  (0.08, 0.50, 0.84, 0.50, 0.17),   // lock body
  (0.00, 0.14, 1.00, 0.10, 0.05),   // bar
  (0.16, 0.00, 0.22, 0.38, 0.08),   // left plate
  (0.62, 0.00, 0.22, 0.38, 0.08),   // right plate
  (0.20, 0.36, 0.14, 0.22, 0.00),   // left shackle post
  (0.66, 0.36, 0.14, 0.22, 0.00),   // right shackle post
]
c.setFillColor(ink)
for s in inkShapes {
  c.addPath(CGPath(roundedRect: CGRect(x: s.x, y: s.y, width: s.w, height: s.h),
                   cornerWidth: s.radius, cornerHeight: s.radius, transform: nil))
}
c.fillPath()
// The keyhole: the one signal.
let keyhole = (cx: CGFloat(0.5), cy: CGFloat(0.75), d: CGFloat(0.17))
c.setFillColor(signal)
c.fillEllipse(in: CGRect(x: keyhole.cx - keyhole.d / 2, y: keyhole.cy - keyhole.d / 2, width: keyhole.d, height: keyhole.d))
c.restoreGState()

let image = c.makeImage()!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(output)") }
print("wrote \(output) (\(Int(side))×\(Int(side)))")
