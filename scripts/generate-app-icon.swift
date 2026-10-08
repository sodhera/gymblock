// Renders the app icon: the paper stage (warm glow, quiet ink dots) with the brand mark, a padlock
// whose keyhole is a barbell. Ink body and shackle; the emerald barbell is the only colour. The same
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
let centre = CGPoint(x: side / 2, y: side * 0.50)
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

// The mark, in a unit square (y down) filling the central 62% of the icon, centred on the glow.
// Keep these tables identical to `BrandMark.ink` / `BrandMark.keyhole` in GymBlock/BrandMark.swift.
enum Piece {
  case arc(cx: CGFloat, cy: CGFloat, r: CGFloat, w: CGFloat)
  case rect(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, r: CGFloat)
}
let inkPieces: [Piece] = [
  .arc(cx: 0.5, cy: 0.43, r: 0.21, w: 0.11),
  .rect(x: 0.235, y: 0.43, w: 0.11, h: 0.08, r: 0),
  .rect(x: 0.655, y: 0.43, w: 0.11, h: 0.08, r: 0),
  .rect(x: 0.12, y: 0.45, w: 0.76, h: 0.52, r: 0.185),
]
let keyholePieces: [Piece] = [
  .rect(x: 0.26, y: 0.675, w: 0.48, h: 0.07, r: 0.035),
  .rect(x: 0.28, y: 0.585, w: 0.085, h: 0.25, r: 0.034),
  .rect(x: 0.635, y: 0.585, w: 0.085, h: 0.25, r: 0.034),
]
let markSide = side * 0.62
c.saveGState()
c.translateBy(x: centre.x - markSide / 2, y: centre.y + markSide / 2)
c.scaleBy(x: markSide, y: -markSide)
func draw(_ pieces: [Piece], _ color: CGColor) {
  c.setFillColor(color)
  for piece in pieces {
    switch piece {
    case .rect(let x, let y, let w, let h, let r):
      c.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil))
    case .arc(let cx, let cy, let r, let w):
      // Half-annulus over the top (y-down space): outer arc 180→360, back along the inner arc.
      c.move(to: CGPoint(x: cx - (r + w / 2), y: cy))
      c.addArc(center: CGPoint(x: cx, y: cy), radius: r + w / 2, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
      c.addLine(to: CGPoint(x: cx + (r - w / 2), y: cy))
      c.addArc(center: CGPoint(x: cx, y: cy), radius: r - w / 2, startAngle: 2 * .pi, endAngle: .pi, clockwise: true)
      c.closePath()
    }
  }
  c.fillPath()
}
draw(inkPieces, ink)
draw(keyholePieces, signal)
c.restoreGState()

let image = c.makeImage()!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(output)") }
print("wrote \(output) (\(Int(side))×\(Int(side)))")
