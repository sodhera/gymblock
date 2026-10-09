// Renders the fallback app icon (iOS 17–25 and the App Store listing): the brand mark, a dumbbell with a
// small padlock on its bar, in a pre-rendered frosted-glass finish on an emerald field. On iOS 26 the
// system renders the layered Liquid Glass icon from GymBlock/AppIcon.icon instead. Same geometry as
// `BrandMark`. Run from the repository root:
//   swift scripts/generate-app-icon.swift                        # 1024 px → the asset catalogue
//   swift scripts/generate-app-icon.swift 180 out.png --mask     # a preview with the iOS corner mask
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpaceCreateDeviceRGB()
func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }

let args = CommandLine.arguments
let side: CGFloat = args.count > 1 ? CGFloat(Double(args[1]) ?? 1024) : 1024
let out = args.count > 2 ? args[2] : "GymBlock/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let mask = args.contains("--mask"), concept = "final", field = "emerald"
let c = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: (mask ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue)!
if mask { let rr = side * 0.2237; c.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerWidth: rr, cornerHeight: rr, transform: nil)); c.clip() }
// Field.
let fieldColors: [CGColor] = field == "emerald" ? [rgba(0.16, 0.72, 0.52), rgba(0.03, 0.47, 0.33)]
  : field == "ink" ? [rgba(0.24, 0.25, 0.28), rgba(0.07, 0.07, 0.09)] : [rgba(0.985, 0.98, 0.97), rgba(0.93, 0.92, 0.90)]
c.drawLinearGradient(CGGradient(colorsSpace: space, colors: fieldColors as CFArray, locations: [0, 1])!, start: CGPoint(x: 0, y: side), end: CGPoint(x: 0, y: 0), options: [])
// A soft light in the upper left of the field.
c.drawRadialGradient(CGGradient(colorsSpace: space, colors: [rgba(1, 1, 1, 0.22), rgba(1, 1, 1, 0)] as CFArray, locations: [0, 1])!,
                     startCenter: CGPoint(x: side * 0.3, y: side * 0.85), startRadius: 0, endCenter: CGPoint(x: side * 0.3, y: side * 0.85), endRadius: side * 0.9, options: [])

// Unit-square helpers (y down).
let m = side * 0.76, ox = (side - m) / 2, oy = (side - m) / 2
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * m, y: oy + (1 - y) * m) }
func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: ox + (cx - r) * m, y: oy + (1 - cy - r) * m, width: 2 * r * m, height: 2 * r * m), transform: nil) }
func ring(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ w: CGFloat) -> CGPath {
  let path = CGMutablePath(); path.addPath(circle(cx, cy, r + w / 2)); path.addPath(circle(cx, cy, r - w / 2)); return path
}
func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
  CGPath(roundedRect: CGRect(x: ox + x * m, y: oy + (1 - y - h) * m, width: w * m, height: h * m), cornerWidth: r * m, cornerHeight: r * m, transform: nil)
}
func rounded(_ pts: [(CGFloat, CGFloat, CGFloat)]) -> CGMutablePath {
  let path = CGMutablePath(); path.move(to: p(pts[0].0, pts[0].1))
  for i in 1..<(pts.count - 1) {
    if pts[i].2 > 0 { path.addArc(tangent1End: p(pts[i].0, pts[i].1), tangent2End: p(pts[i + 1].0, pts[i + 1].1), radius: pts[i].2 * m) } else { path.addLine(to: p(pts[i].0, pts[i].1)) }
  }
  path.addLine(to: p(pts[pts.count - 1].0, pts[pts.count - 1].1)); path.closeSubpath(); return path
}
func flatDisc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, base: CGFloat) -> CGPath {
  // Built as a polyline so the arc never flips direction in the flipped coordinate space.
  let path = CGMutablePath(); let half = asin((base - cy) / r)
  let a0 = .pi - half, a1 = 2 * .pi + half   // y-down: skip the arc below the base
  let pts = (0...180).map { i -> CGPoint in let a = a0 + (a1 - a0) * CGFloat(i) / 180; return p(cx + r * cos(a), cy + r * sin(a)) }
  path.addLines(between: pts); path.closeSubpath(); return path
}

/// One glass piece: `solid` is filled; `holes` are cut out (even-odd) so the field shows through.
struct Piece { var solid: CGPath; var holes: [CGPath] = []; var depth: CGFloat = 1 }
func render(_ piece: Piece) {
  let shape = CGMutablePath(); shape.addPath(piece.solid); for h in piece.holes { shape.addPath(h) }
  // Drop shadow.
  c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -side * 0.02 * piece.depth), blur: side * 0.05 * piece.depth, color: rgba(0, 0, 0, 0.28))
  c.addPath(shape); c.setFillColor(rgba(1, 1, 1, 0.92)); c.fillPath(using: .evenOdd); c.restoreGState()
  c.saveGState(); c.addPath(shape); c.clip(using: .evenOdd)
  // Frost: slightly warm white body with a top light and a cool shade at the bottom.
  c.drawLinearGradient(CGGradient(colorsSpace: space, colors: [rgba(1, 1, 1, 0.55), rgba(1, 1, 1, 0.0), rgba(0.75, 0.8, 0.8, 0.22)] as CFArray, locations: [0, 0.45, 1])!,
                       start: CGPoint(x: 0, y: side), end: CGPoint(x: 0, y: 0), options: [])
  // Specular sweep from the upper left.
  c.drawLinearGradient(CGGradient(colorsSpace: space, colors: [rgba(1, 1, 1, 0.35), rgba(1, 1, 1, 0)] as CFArray, locations: [0, 1])!,
                       start: CGPoint(x: side * 0.25, y: side * 0.85), end: CGPoint(x: side * 0.6, y: side * 0.45), options: [])
  // Inner shadow along the bottom edge: stroke the inverse, blurred, inside the clip.
  c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: side * 0.012), blur: side * 0.03, color: rgba(0.1, 0.2, 0.2, 0.45))
  let inverse = CGMutablePath(); inverse.addRect(CGRect(x: -side, y: -side, width: side * 3, height: side * 3)); inverse.addPath(shape)
  c.addPath(inverse); c.setFillColor(rgba(0, 0, 0, 1)); c.fillPath(using: .evenOdd); c.restoreGState()
  // Rim light along the top edge.
  c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -side * 0.006), blur: side * 0.008, color: rgba(1, 1, 1, 0.9))
  c.addPath(inverse); c.setFillColor(rgba(0, 0, 0, 1)); c.fillPath(using: .evenOdd); c.restoreGState()
  c.restoreGState()
}

func keyhole(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
  let k = CGMutablePath(); k.addPath(circle(cx, cy, r))
  k.addPath(rounded([(cx - r * 0.4, cy + r * 0.4, 0), (cx - r * 0.85, cy + r * 3.0, r * 0.4), (cx + r * 0.85, cy + r * 3.0, r * 0.4), (cx + r * 0.4, cy + r * 0.4, 0)]))
  return k
}
switch concept {
case "final":
  // Keep these numbers identical to BrandMark.Geometry and GymBlock/AppIcon.icon.
  let plateW: CGFloat = 0.26, plateH: CGFloat = 0.56, barY: CGFloat = 0.50, barH: CGFloat = 0.10
  let lockW: CGFloat = 0.24, lockH = lockW * 0.92, shackleR = lockW * 0.33, shackleW = lockW * 0.22
  render(Piece(solid: rrect(0.04, barY - barH / 2, 0.92, barH, barH / 2), depth: 0.7))
  render(Piece(solid: rrect(0.0, 0.5 - plateH / 2, plateW, plateH, plateW * 0.42), depth: 0.9))
  render(Piece(solid: rrect(1 - plateW, 0.5 - plateH / 2, plateW, plateH, plateW * 0.42), depth: 0.9))
  let top = barY - lockH * 0.45
  render(Piece(solid: ring(0.5, top, shackleR, shackleW), depth: 0.4))
  render(Piece(solid: rrect(0.5 - lockW / 2, top, lockW, lockH, lockW * 0.3), holes: [keyhole(0.5, top + lockH * 0.42, lockW * 0.09)], depth: 0.6))
default: fatalError()
}
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, c.makeImage()!, nil); CGImageDestinationFinalize(d)
print("wrote \(out) (\(Int(side))×\(Int(side)))")
