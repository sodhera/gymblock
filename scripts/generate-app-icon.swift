// Renders the app icon: the brand mark, a cast-iron kettlebell with an emerald keyhole, in ink on the
// paper stage. The same geometry as `BrandMark` in GymBlock/BrandMark.swift (unit square, y down).
// Run from the repository root:
//   swift scripts/generate-app-icon.swift                       # 1024 px → the asset catalogue
//   swift scripts/generate-app-icon.swift 180 out.png --mask    # a preview with the iOS corner mask
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
let side: CGFloat = arguments.count > 1 ? CGFloat(Double(arguments[1]) ?? 1024) : 1024
let output = arguments.count > 2 ? arguments[2] : "GymBlock/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let mask = arguments.contains("--mask")

let space = CGColorSpaceCreateDeviceRGB()
// The asset is opaque RGB (App Store icons must be opaque); masked previews keep alpha for the corners.
let c = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: (mask ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue)!
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(red: r, green: g, blue: b, alpha: 1) }
let paper = rgb(0.961, 0.953, 0.937), ink = rgb(0.08, 0.08, 0.09), signal = rgb(0.06, 0.60, 0.42)

if mask {
  let r = side * 0.2237
  c.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerWidth: r, cornerHeight: r, transform: nil)); c.clip()
}
c.setFillColor(paper); c.fill(CGRect(x: 0, y: 0, width: side, height: side))

// The mark fills the central 78%.
let m = side * 0.78, ox = (side - m) / 2, oy = (side - m) / 2
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * m, y: oy + (1 - y) * m) }
func outline(_ pts: [(CGFloat, CGFloat, CGFloat)]) -> CGMutablePath {
  let path = CGMutablePath()
  path.move(to: p(pts[0].0, pts[0].1))
  for i in 1..<(pts.count - 1) {
    if pts[i].2 > 0 { path.addArc(tangent1End: p(pts[i].0, pts[i].1), tangent2End: p(pts[i + 1].0, pts[i + 1].1), radius: pts[i].2 * m) }
    else { path.addLine(to: p(pts[i].0, pts[i].1)) }
  }
  path.addLine(to: p(pts[pts.count - 1].0, pts[pts.count - 1].1)); path.closeSubpath()
  return path
}
// Keep these numbers identical to BrandMark.Geometry.
let handle: [(CGFloat, CGFloat, CGFloat)] = [(0.30, 0.66, 0), (0.19, 0.49, 0.05), (0.265, 0.07, 0.11), (0.735, 0.07, 0.11), (0.81, 0.49, 0.05), (0.70, 0.66, 0)]
let window: [(CGFloat, CGFloat, CGFloat)] = [(0.30, 0.52, 0), (0.275, 0.49, 0.02), (0.325, 0.15, 0.055), (0.675, 0.15, 0.055), (0.725, 0.49, 0.02), (0.70, 0.52, 0)]
let bell = (cx: CGFloat(0.5), cy: CGFloat(0.67), r: CGFloat(0.32), base: CGFloat(0.965))
let key = (cy: CGFloat(0.645), r: CGFloat(0.055), length: CGFloat(0.15))

let h = outline(handle); h.addPath(outline(window))
c.addPath(h); c.setFillColor(ink); c.fillPath(using: .evenOdd)
c.saveGState()
c.clip(to: CGRect(x: 0, y: p(0, bell.base).y, width: side, height: side))
c.fillEllipse(in: CGRect(x: ox + (bell.cx - bell.r) * m, y: oy + (1 - bell.cy - bell.r) * m, width: 2 * bell.r * m, height: 2 * bell.r * m))
c.restoreGState()
c.setFillColor(signal)
c.fillEllipse(in: CGRect(x: ox + (0.5 - key.r) * m, y: oy + (1 - key.cy - key.r) * m, width: 2 * key.r * m, height: 2 * key.r * m))
c.addLines(between: [p(0.5 - key.r * 0.4, key.cy + 0.02), p(0.5 + key.r * 0.4, key.cy + 0.02),
                     p(0.5 + key.r * 0.72, key.cy + key.length), p(0.5 - key.r * 0.72, key.cy + key.length)])
c.closePath(); c.fillPath()

let image = c.makeImage()!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(output)") }
print("wrote \(output) (\(Int(side))×\(Int(side)))")
