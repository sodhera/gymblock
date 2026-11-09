import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
// usage: pdf2png in.pdf out.png scale
let a = CommandLine.arguments
let url = URL(fileURLWithPath: a[1]) as CFURL
guard let doc = CGPDFDocument(url), let page = doc.page(at: 1) else { print("bad pdf"); exit(1) }
let scale = CGFloat(Double(a[3]) ?? 1)
let box = page.getBoxRect(.mediaBox)
let w = Int((box.width * scale).rounded()), h = Int((box.height * scale).rounded())
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.clear(CGRect(x: 0, y: 0, width: w, height: h))
ctx.scaleBy(x: scale, y: scale)
ctx.translateBy(x: -box.origin.x, y: -box.origin.y)
ctx.drawPDFPage(page)
let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
print("\(a[1].split(separator: "/").last!) \(box.width)x\(box.height) -> \(w)x\(h)")
