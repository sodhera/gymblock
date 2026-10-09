// Renders the app icon: the brand mark, a dumbbell with a small padlock on the middle of its bar, in
// its real materials on the app's paper: black rubber plates, a knurled steel bar, a brass padlock
// with a steel shackle. One plate each side, the lock straddling the bar with its shackle above,
// mirror-symmetric. Same geometry as `BrandMark.Geometry` in GymBlock/BrandMark.swift.
// Run from the repository root:
//   swift scripts/generate-app-icon.swift                        # 1024 px → the asset catalogue
//   swift scripts/generate-app-icon.swift 180 out.png --mask     # a preview with the iOS corner mask
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let space = CGColorSpaceCreateDeviceRGB()
func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: a) }
typealias RGB = (r: CGFloat, g: CGFloat, b: CGFloat)
func mix(_ a: RGB, _ b: RGB, _ t: CGFloat) -> CGColor { rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t) }
struct Material { let hi: RGB; let mid: RGB; let lo: RGB; let gloss: CGFloat }   // gloss: how sharp the highlight is
let rubber = Material(hi: (0.36, 0.37, 0.39), mid: (0.19, 0.20, 0.22), lo: (0.07, 0.07, 0.08), gloss: 0.25)
let iron = Material(hi: (0.62, 0.64, 0.68), mid: (0.33, 0.35, 0.38), lo: (0.10, 0.11, 0.12), gloss: 0.6)
let steel = Material(hi: (0.96, 0.97, 0.98), mid: (0.68, 0.70, 0.73), lo: (0.28, 0.30, 0.33), gloss: 0.9)
let brass = Material(hi: (1.00, 0.90, 0.58), mid: (0.80, 0.62, 0.26), lo: (0.42, 0.29, 0.08), gloss: 0.8)
let silverLock = Material(hi: (0.98, 0.98, 0.99), mid: (0.74, 0.76, 0.79), lo: (0.36, 0.38, 0.42), gloss: 0.85)

let args = CommandLine.arguments
let side: CGFloat = args.count > 1 ? CGFloat(Double(args[1]) ?? 1024) : 1024
let out = args.count > 2 ? args[2] : "GymBlock/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let mask = args.contains("--mask"), variant = "rubber"   // chosen by the user on 9 Oct 2026
// Coloured bumper plates, as in a gym: competition red, blue, or green.
let redPlate = Material(hi: (0.98, 0.45, 0.40), mid: (0.82, 0.16, 0.14), lo: (0.40, 0.05, 0.05), gloss: 0.45)
let bluePlate = Material(hi: (0.45, 0.62, 1.00), mid: (0.13, 0.33, 0.85), lo: (0.04, 0.12, 0.40), gloss: 0.45)
let greenPlate = Material(hi: (0.30, 0.86, 0.60), mid: (0.06, 0.60, 0.42), lo: (0.02, 0.27, 0.19), gloss: 0.45)
let plateM = variant == "iron" ? iron : variant == "red" ? redPlate : variant == "blue" ? bluePlate : variant == "green" ? greenPlate : rubber
let lockM = variant == "silver" ? silverLock : brass
let c = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: (mask ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue)!
if mask { let rr = side * 0.2237; c.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerWidth: rr, cornerHeight: rr, transform: nil)); c.clip() }
// Field: the app's paper, with its warm light in the middle (the same stage the onboarding uses).
let paper = args.contains("--black") ? false : true
if paper {
  c.setFillColor(rgba(0.961, 0.953, 0.937)); c.fill(CGRect(x: 0, y: 0, width: side, height: side))
  let centre = CGPoint(x: side / 2, y: side * 0.5)
  c.drawRadialGradient(CGGradient(colorsSpace: space, colors: [rgba(1, 0.93, 0.80, 0.8), rgba(1, 0.93, 0.80, 0.28), rgba(1, 0.93, 0.80, 0)] as CFArray, locations: [0, 0.45, 1])!, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: side * 0.9, options: [])
} else {
  c.drawLinearGradient(CGGradient(colorsSpace: space, colors: [rgba(0.13, 0.13, 0.14), rgba(0.02, 0.02, 0.03)] as CFArray, locations: [0, 1])!, start: CGPoint(x: 0, y: side), end: .zero, options: [])
}

let m = side * 0.80, ox = (side - m) / 2, oy = (side - m) / 2
func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: ox + x * m, y: oy + (1 - y - h) * m, width: w * m, height: h * m) }
func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath { CGPath(roundedRect: rect(x, y, w, h), cornerWidth: r * m, cornerHeight: r * m, transform: nil) }
func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: ox + (cx - r) * m, y: oy + (1 - cy - r) * m, width: 2 * r * m, height: 2 * r * m), transform: nil) }
func ring(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ w: CGFloat) -> CGPath { let p = CGMutablePath(); p.addPath(circle(cx, cy, r + w / 2)); p.addPath(circle(cx, cy, r - w / 2)); return p }
func keyhole(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
  let k = CGMutablePath(); k.addPath(circle(cx, cy, r))
  k.move(to: CGPoint(x: ox + (cx - r * 0.42) * m, y: oy + (1 - (cy + r * 0.35)) * m))
  k.addLine(to: CGPoint(x: ox + (cx + r * 0.42) * m, y: oy + (1 - (cy + r * 0.35)) * m))
  k.addLine(to: CGPoint(x: ox + (cx + r * 0.78) * m, y: oy + (1 - (cy + r * 2.7)) * m))
  k.addLine(to: CGPoint(x: ox + (cx - r * 0.78) * m, y: oy + (1 - (cy + r * 2.7)) * m)); k.closeSubpath(); return k
}
enum Axis { case vertical, horizontal }
func shade(_ path: CGPath, _ mat: Material, axis: Axis, shadow: CGFloat = 1) {
  let box = path.boundingBoxOfPath
  c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -side * 0.012 * shadow), blur: side * 0.035 * shadow, color: rgba(0.15, 0.10, 0.02, paper ? 0.38 : 0.6))
  c.addPath(path); c.setFillColor(rgba(mat.mid.r, mat.mid.g, mat.mid.b)); c.fillPath(using: .evenOdd); c.restoreGState()
  c.saveGState(); c.addPath(path); c.clip(using: .evenOdd)
  // Cylinder: highlight band near the lit edge, falling to the shadow side; glossier materials have a tighter band.
  let g = mat.gloss
  let colors = [mix(mat.mid, mat.hi, 0.55), mix(mat.mid, mat.hi, 1.0), mix(mat.mid, mat.hi, 0.35), rgba(mat.mid.r, mat.mid.g, mat.mid.b), mix(mat.mid, mat.lo, 0.6), mix(mat.mid, mat.lo, 1.0)] as CFArray
  let locs: [CGFloat] = [0, 0.10 + 0.08 * (1 - g), 0.30, 0.52, 0.82, 1]
  let grad = CGGradient(colorsSpace: space, colors: colors, locations: locs)!
  switch axis {
  case .vertical: c.drawLinearGradient(grad, start: CGPoint(x: 0, y: box.maxY), end: CGPoint(x: 0, y: box.minY), options: [])
  case .horizontal: c.drawLinearGradient(grad, start: CGPoint(x: box.minX, y: 0), end: CGPoint(x: box.maxX, y: 0), options: [])
  }
  // Rim light on the top edge, inner shadow on the bottom edge.
  let inverse = CGMutablePath(); inverse.addRect(CGRect(x: -side, y: -side, width: side * 3, height: side * 3)); inverse.addPath(path)
  c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: -side * 0.004), blur: side * 0.006, color: rgba(1, 1, 1, 0.5 * g + 0.2))
  c.addPath(inverse); c.setFillColor(rgba(0, 0, 0)); c.fillPath(using: .evenOdd); c.restoreGState()
  c.saveGState(); c.setShadow(offset: CGSize(width: 0, height: side * 0.006), blur: side * 0.012, color: rgba(0, 0, 0, 0.5))
  c.addPath(inverse); c.setFillColor(rgba(0, 0, 0)); c.fillPath(using: .evenOdd); c.restoreGState()
  c.restoreGState()
}

// Keep these numbers identical to BrandMark.Geometry.
let barY: CGFloat = 0.5, lockW: CGFloat = 0.22, lockH: CGFloat = 0.20, top = barY - lockH * 0.5
shade(rrect(0.05, barY - 0.05, 0.90, 0.10, 0.05), steel, axis: .vertical, shadow: 0.6)
// Knurl: fine vertical lines on the grip either side of the lock.
c.saveGState(); c.addPath(rrect(0.05, barY - 0.05, 0.90, 0.10, 0.05)); c.clip()
c.setStrokeColor(rgba(0, 0, 0, 0.18)); c.setLineWidth(side * 0.0025)
for i in stride(from: 0.26, through: 0.74, by: 0.012) where abs(i - 0.5) > 0.14 {
  c.move(to: CGPoint(x: ox + CGFloat(i) * m, y: oy + (1 - (barY - 0.05)) * m)); c.addLine(to: CGPoint(x: ox + CGFloat(i) * m, y: oy + (1 - (barY + 0.05)) * m))
}
c.strokePath(); c.restoreGState()
shade(rrect(0.0, 0.22, 0.24, 0.56, 0.10), plateM, axis: .horizontal)
shade(rrect(0.76, 0.22, 0.24, 0.56, 0.10), plateM, axis: .horizontal)
shade(ring(0.5, top, lockW * 0.30, lockW * 0.20), steel, axis: .vertical, shadow: 0.5)
shade(rrect(0.5 - lockW / 2, top, lockW, lockH, 0.065), lockM, axis: .vertical, shadow: 1.2)
c.saveGState(); c.addPath(keyhole(0.5, top + lockH * 0.40, 0.021)); c.clip(using: .evenOdd)
c.setFillColor(rgba(0.03, 0.03, 0.03)); c.fill(CGRect(x: 0, y: 0, width: side, height: side))
c.setShadow(offset: CGSize(width: 0, height: -side * 0.004), blur: side * 0.01, color: rgba(0, 0, 0, 0.9))
let inv = CGMutablePath(); inv.addRect(CGRect(x: -side, y: -side, width: side * 3, height: side * 3)); inv.addPath(keyhole(0.5, top + lockH * 0.40, 0.021))
c.addPath(inv); c.setFillColor(rgba(0, 0, 0)); c.fillPath(using: .evenOdd); c.restoreGState()

let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, c.makeImage()!, nil); CGImageDestinationFinalize(d)
print("wrote \(out) (\(Int(side))×\(Int(side)))")
