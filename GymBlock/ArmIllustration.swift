import SwiftUI
import UIKit

struct ArmIllustration: UIViewRepresentable {
  var warmth: Double
  var curl: Double
  func makeUIView(context: Context) -> ArmDrawingView { ArmDrawingView() }
  func updateUIView(_ view: ArmDrawingView, context: Context) {
    view.warmth = warmth; view.curl = curl; view.setNeedsDisplay()
  }
}

/// A softly blended elbow mesh preserves the approved illustration's anatomy.
final class ArmDrawingView: UIView {
  var warmth = 0.0
  var curl = 0.0
  private static let artwork = UIImage(named: "OnboardingArm")!
  private static var textures: [Int: CGImage] = [:]
  private static let mesh = makeMesh()
  override init(frame: CGRect) { super.init(frame: frame); isOpaque = false; backgroundColor = .clear }
  required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
  private static func makeMesh() -> (cells: [[CGPoint]], samples: [CGPoint]) {
    guard let image = artwork.cgImage else { return ([], []) }
    let w = 512, h = 512
    var data = [UInt8](repeating: 0, count: w * h * 4)
    data.withUnsafeMutableBytes { bytes in
      let c = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8,
        bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
      c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    var samples: [CGPoint] = []; var cells: [[CGPoint]] = []
    for y in stride(from: 0, to: h, by: 4) {
      for x in stride(from: 0, to: w, by: 4) where data[(y * w + x) * 4 + 3] > 32 {
        samples.append(CGPoint(x: x, y: y))
      }
    }
    for y in stride(from: 0, to: h, by: 16) {
      for x in stride(from: 0, to: w, by: 16) {
        var occupied = false
        for py in y..<min(y+16, h) {
          for px in x..<min(x+16, w) where data[(py*w+px)*4+3] > 8 { occupied = true; break }
          if occupied { break }
        }
        if occupied {
          cells.append([CGPoint(x: x, y: y), CGPoint(x: x+16, y: y), CGPoint(x: x+16, y: y+16), CGPoint(x: x, y: y+16)])
        }
      }
    }; return (cells, samples)
  }
  private static func texture(_ warmth: Double) -> CGImage {
    let key = Int(min(1, max(0, warmth)) * 50)
    if let cached = textures[key] { return cached }
    let t = Double(key) / 50
    func heat(_ v: Double) -> UIColor {
      let blue = [0.33, 0.62, 0.88], pale = [0.98, 0.94, 0.91], red = [0.91, 0.19, 0.24]
      let a = v < 0.5 ? blue : pale, b = v < 0.5 ? pale : red
      let p = v < 0.5 ? v * 2 : (v - 0.5) * 2
      return UIColor(red: a[0] + (b[0]-a[0])*p, green: a[1]+(b[1]-a[1])*p, blue: a[2]+(b[2]-a[2])*p, alpha: 1)
    }
    let format = UIGraphicsImageRendererFormat(); format.scale = 1
    let image = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512), format: format).image { renderer in
      artwork.draw(in: CGRect(x: 0, y: 0, width: 512, height: 512))
      let c = renderer.cgContext
      c.saveGState()
      // Multiply tints the white muscle surface, retaining the original black contour detail.
      c.setBlendMode(.multiply)
      c.translateBy(x: 0, y: 512); c.scaleBy(x: 1, y: -1)
      c.clip(to: CGRect(x: 0, y: 0, width: 512, height: 512), mask: artwork.cgImage!)
      let colors = [heat(min(1,t+0.035)).cgColor, heat(t).cgColor, heat(max(0,t-0.025)).cgColor] as CFArray
      let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1])!
      c.drawRadialGradient(gradient, startCenter: CGPoint(x: 245, y: 175), startRadius: 10,
        endCenter: CGPoint(x: 245, y: 175), endRadius: 310, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
      c.restoreGState()
    }.cgImage!
    textures[key] = image; return image
  }
  private func deform(_ p: CGPoint) -> CGPoint {
    let v = min(1, max(0, (p.x + p.y - 420) / 140))
    let theta = -(1-curl) * 0.72 * (1-v*v*(3-2*v))
    let dx = p.x-95, dy = p.y-398
    return CGPoint(x: 95+dx*cos(theta)-dy*sin(theta), y: 398+dx*sin(theta)+dy*cos(theta))
  }
  override func draw(_ rect: CGRect) {
    guard let context = UIGraphicsGetCurrentContext(), !Self.mesh.samples.isEmpty else { return }
    let image = Self.texture(warmth)
    let samples = Self.mesh.samples.map(deform)
    let minX = samples.map(\.x).min()!, maxX = samples.map(\.x).max()!
    let minY = samples.map(\.y).min()!, maxY = samples.map(\.y).max()!
    let scale = min((bounds.width-6)/(maxX-minX), (bounds.height-8)/(maxY-minY))
    func map(_ p: CGPoint) -> CGPoint {
      let q = deform(p)
      return CGPoint(x: bounds.midX+(q.x-(minX+maxX)/2)*scale, y: bounds.midY+(q.y-(minY+maxY)/2)*scale)
    }
    if curl >= 0.999 {
      context.saveGState()
      context.translateBy(x: bounds.midX-(minX+maxX)/2*scale, y: bounds.midY-(minY+maxY)/2*scale)
      context.scaleBy(x: scale, y: scale)
      UIImage(cgImage: image).draw(in: CGRect(x: 0, y: 0, width: 512, height: 512))
      context.restoreGState(); return
    }
    for cell in Self.mesh.cells {
      let p = cell.map(map)
      triangle(context, image, [cell[0],cell[1],cell[2]], [p[0],p[1],p[2]])
      triangle(context, image, [cell[0],cell[2],cell[3]], [p[0],p[2],p[3]])
    }
  }
  private func triangle(_ c: CGContext, _ image: CGImage, _ s: [CGPoint], _ d: [CGPoint]) {
    let a=s[0], b=s[1], z=s[2], p=d[0], q=d[1], r=d[2]
    let det=(b.x-a.x)*(z.y-a.y)-(z.x-a.x)*(b.y-a.y)
    let A=((q.x-p.x)*(z.y-a.y)-(r.x-p.x)*(b.y-a.y))/det
    let C=((r.x-p.x)*(b.x-a.x)-(q.x-p.x)*(z.x-a.x))/det
    let B=((q.y-p.y)*(z.y-a.y)-(r.y-p.y)*(b.y-a.y))/det
    let D=((r.y-p.y)*(b.x-a.x)-(q.y-p.y)*(z.x-a.x))/det
    let center=CGPoint(x:(p.x+q.x+r.x)/3,y:(p.y+q.y+r.y)/3)
    c.saveGState(); let clip=CGMutablePath()
    for (i,v) in d.enumerated() {
      let dx=v.x-center.x,dy=v.y-center.y,l=max(0.001,hypot(dx,dy))
      let point=CGPoint(x:v.x+dx/l*0.16,y:v.y+dy/l*0.16)
      if i == 0 { clip.move(to:point) } else { clip.addLine(to:point) }
    }
    clip.closeSubpath(); c.addPath(clip); c.clip()
    c.concatenate(CGAffineTransform(a:A,b:B,c:C,d:D,tx:p.x-A*a.x-C*a.y,ty:p.y-B*a.x-D*a.y))
    UIImage(cgImage:image).draw(in:CGRect(x:0,y:0,width:512,height:512)); c.restoreGState()
  }
}
