// Renders the app icon: the brand mark (a kettlebell that is a padlock: handle = shackle, bell = body,
// emerald keyhole) in paper white on an ink field with a faint top light. The same geometry as
// `BrandMark` in GymBlock/BrandMark.swift (unit square, y down, degrees counter-clockwise, 90 = up).
// Run from the repository root:
//   swift scripts/generate-app-icon.swift                 # 1024 px → the asset catalogue
//   swift scripts/generate-app-icon.swift 180 out.png     # a preview at another size
//   swift scripts/generate-app-icon.swift 180 out.png --mask   # with the iOS corner mask, for previews
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
let paper = rgb(0.961, 0.953, 0.937), signal = rgb(0.06, 0.60, 0.42)

if mask {
  let r = side * 0.2237
  c.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerWidth: r, cornerHeight: r, transform: nil)); c.clip()
}
// Ink field with a faint light from the top, so it reads as a surface rather than a hole.
let field = CGGradient(colorsSpace: space, colors: [rgb(0.17, 0.17, 0.19), rgb(0.08, 0.08, 0.09)] as CFArray, locations: [0, 1])!
c.drawLinearGradient(field, start: CGPoint(x: 0, y: side), end: CGPoint(x: 0, y: 0), options: [])

// The mark fills the central 80%, nudged up by 1% for optical centring.
let m = side * 0.80
let ox = (side - m) / 2, oy = (side - m) / 2 - side * 0.01
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x * m, y: oy + (1 - y) * m) }
func arc(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ a0: CGFloat, _ a1: CGFloat) -> [CGPoint] {
  (0...240).map { i in let a = (a0 + (a1 - a0) * CGFloat(i) / 240) * .pi / 180; return p(cx + r * cos(a), cy - r * sin(a)) }
}
func fill(_ color: CGColor, _ points: [CGPoint]) { c.addLines(between: points); c.closePath(); c.setFillColor(color); c.fillPath() }

// Keep these numbers identical to BrandMark.Geometry.
fill(paper, arc(0.5, 0.665, 0.285, 236, -56))                                            // bell
fill(paper, arc(0.5, 0.39, 0.235, 180, 0) + [p(0.735, 0.53), p(0.625, 0.47)]
            + arc(0.5, 0.39, 0.125, 0, 180) + [p(0.375, 0.47), p(0.265, 0.53)])          // handle
let head: CGFloat = 0.06
c.setFillColor(signal)
c.fillEllipse(in: CGRect(x: ox + (0.5 - head) * m, y: oy + (1 - 0.635 - head) * m, width: 2 * head * m, height: 2 * head * m))
fill(signal, [p(0.477, 0.655), p(0.523, 0.655), p(0.542, 0.80), p(0.458, 0.80)])          // slot

let image = c.makeImage()!
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(output)") }
print("wrote \(output) (\(Int(side))×\(Int(side)))")
