// Renders the app icon: the brand mark, a dumbbell with a small padlock on the middle of its bar, in
// emerald on a black field. One pill plate each side, a heavy bar, the lock straddling the bar with
// its shackle above, the keyhole showing the field through.
// Mirror-symmetric about the centre. Same geometry as `BrandMark.Geometry` in GymBlock/BrandMark.swift.
// Run from the repository root:
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
let mask = args.contains("--mask"), tone = "emerald", concept = "B"
let c = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: (mask ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue)!
if mask { let rr = side * 0.2237; c.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerWidth: rr, cornerHeight: rr, transform: nil)); c.clip() }
// Field: black with the faintest lift at the top so it reads as a surface.
c.drawLinearGradient(CGGradient(colorsSpace: space, colors: [rgba(0.11, 0.11, 0.12), rgba(0.04, 0.04, 0.05)] as CFArray, locations: [0, 1])!, start: CGPoint(x: 0, y: side), end: .zero, options: [])

let m = side * 0.80, ox = (side - m) / 2, oy = (side - m) / 2
func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: ox + x * m, y: oy + (1 - y - h) * m, width: w * m, height: h * m) }
func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath { CGPath(roundedRect: rect(x, y, w, h), cornerWidth: r * m, cornerHeight: r * m, transform: nil) }
func mirrored(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath { let p = CGMutablePath(); p.addPath(rrect(x, y, w, h, r)); p.addPath(rrect(1 - x - w, y, w, h, r)); return p }
func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: ox + (cx - r) * m, y: oy + (1 - cy - r) * m, width: 2 * r * m, height: 2 * r * m), transform: nil) }
func ring(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ w: CGFloat) -> CGPath { let p = CGMutablePath(); p.addPath(circle(cx, cy, r + w / 2)); p.addPath(circle(cx, cy, r - w / 2)); return p }
func keyhole(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath {
  let k = CGMutablePath(); k.addPath(circle(cx, cy, r))
  k.move(to: CGPoint(x: ox + (cx - r * 0.42) * m, y: oy + (1 - (cy + r * 0.35)) * m))
  k.addLine(to: CGPoint(x: ox + (cx + r * 0.42) * m, y: oy + (1 - (cy + r * 0.35)) * m))
  k.addLine(to: CGPoint(x: ox + (cx + r * 0.78) * m, y: oy + (1 - (cy + r * 2.7)) * m))
  k.addLine(to: CGPoint(x: ox + (cx - r * 0.78) * m, y: oy + (1 - (cy + r * 2.7)) * m)); k.closeSubpath()
  return k
}
/// Fill a path in the mark tone: a soft vertical gradient so it is crafted, not flat-white; even-odd for holes.
func fill(_ path: CGPath, dim: CGFloat = 1) {
  c.saveGState(); c.addPath(path); c.clip(using: .evenOdd)
  let top = tone == "emerald" ? rgba(0.16, 0.74, 0.54) : rgba(0.99 * dim, 0.985 * dim, 0.975 * dim)
  let bottom = tone == "emerald" ? rgba(0.03, 0.52, 0.37) : rgba(0.86 * dim, 0.85 * dim, 0.83 * dim)
  c.drawLinearGradient(CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1])!, start: CGPoint(x: 0, y: side), end: .zero, options: [])
  c.restoreGState()
}
func accent(_ path: CGPath) { c.addPath(path); c.setFillColor(tone == "emerald" ? rgba(0.04, 0.04, 0.05) : rgba(0.06, 0.60, 0.42)); c.fillPath(using: .evenOdd) }

let barY: CGFloat = 0.5
switch concept {
case "B":
  // Keep these numbers identical to BrandMark.Geometry. One tier: a single pill plate each side.
  let lockW: CGFloat = 0.22, lockH: CGFloat = 0.20, top = barY - lockH * 0.5
  fill(rrect(0.05, barY - 0.05, 0.90, 0.10, 0.05), dim: 0.94)
  fill(mirrored(0.0, 0.22, 0.24, 0.56, 0.10))
  fill(ring(0.5, top, lockW * 0.30, lockW * 0.20), dim: 0.94)
  fill(rrect(0.5 - lockW / 2, top, lockW, lockH, 0.065))
  // The keyhole is the field showing through (the bar runs behind the lock, so it is painted, not cut).
  accent(keyhole(0.5, top + lockH * 0.40, 0.021))
default: fatalError()
}
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, c.makeImage()!, nil); CGImageDestinationFinalize(d)
print("wrote \(out) (\(Int(side))×\(Int(side)))")
