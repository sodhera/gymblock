import SwiftUI
import UIKit

/// The approved arm artwork, bent at the elbow by a softly blended mesh.
/// Frames are rendered once, off the main thread, and then played back as a flipbook:
/// animation costs one image swap plus a GPU colour multiply per frame.
enum ArmRenderer {
  static let artwork = UIImage(named: "OnboardingArm")!
  private static let artworkImage = UIImage(cgImage: artwork.cgImage!)
  private static let mesh = makeMesh()

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
        for py in y..<min(y + 16, h) {
          for px in x..<min(x + 16, w) where data[(py * w + px) * 4 + 3] > 8 { occupied = true; break }
          if occupied { break }
        }
        if occupied {
          cells.append([CGPoint(x: x, y: y), CGPoint(x: x + 16, y: y), CGPoint(x: x + 16, y: y + 16), CGPoint(x: x, y: y + 16)])
        }
      }
    }
    return (cells, samples)
  }

  private static func deform(_ p: CGPoint, curl: Double) -> CGPoint {
    let v = min(1, max(0, (p.x + p.y - 420) / 140))
    let theta = -(1 - curl) * 0.72 * (1 - v * v * (3 - 2 * v))
    let dx = p.x - 95, dy = p.y - 398
    return CGPoint(x: 95 + dx * cos(theta) - dy * sin(theta), y: 398 + dx * sin(theta) + dy * cos(theta))
  }

  /// Renders one untinted pose. Safe to call off the main thread.
  static func render(curl: Double, side: CGFloat) -> UIImage {
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = false
    // A fixed frame keeps every pose in the same place, so playback never jitters.
    let all = mesh.samples.map { deform($0, curl: 0) } + mesh.samples
    let minX = all.map(\.x).min()!, maxX = all.map(\.x).max()!
    let minY = all.map(\.y).min()!, maxY = all.map(\.y).max()!
    let scale = min((side - 8) / (maxX - minX), (side - 8) / (maxY - minY))
    let bounds = CGRect(x: 0, y: 0, width: side, height: side)
    func map(_ p: CGPoint) -> CGPoint {
      let q = deform(p, curl: curl)
      return CGPoint(x: bounds.midX + (q.x - (minX + maxX) / 2) * scale, y: bounds.midY + (q.y - (minY + maxY) / 2) * scale)
    }
    return UIGraphicsImageRenderer(size: bounds.size, format: format).image { renderer in
      let context = renderer.cgContext
      guard let image = artwork.cgImage else { return }
      if curl >= 0.999 {
        context.saveGState()
        context.translateBy(x: bounds.midX - (minX + maxX) / 2 * scale, y: bounds.midY - (minY + maxY) / 2 * scale)
        context.scaleBy(x: scale, y: scale)
        artwork.draw(in: CGRect(x: 0, y: 0, width: 512, height: 512))
        context.restoreGState(); return
      }
      for cell in mesh.cells {
        let p = cell.map(map)
        triangle(context, image, [cell[0], cell[1], cell[2]], [p[0], p[1], p[2]])
        triangle(context, image, [cell[0], cell[2], cell[3]], [p[0], p[2], p[3]])
      }
    }
  }

  private static func triangle(_ c: CGContext, _ image: CGImage, _ s: [CGPoint], _ d: [CGPoint]) {
    let a = s[0], b = s[1], z = s[2], p = d[0], q = d[1], r = d[2]
    let det = (b.x - a.x) * (z.y - a.y) - (z.x - a.x) * (b.y - a.y)
    let A = ((q.x - p.x) * (z.y - a.y) - (r.x - p.x) * (b.y - a.y)) / det
    let C = ((r.x - p.x) * (b.x - a.x) - (q.x - p.x) * (z.x - a.x)) / det
    let B = ((q.y - p.y) * (z.y - a.y) - (r.y - p.y) * (b.y - a.y)) / det
    let D = ((r.y - p.y) * (b.x - a.x) - (q.y - p.y) * (z.x - a.x)) / det
    let center = CGPoint(x: (p.x + q.x + r.x) / 3, y: (p.y + q.y + r.y) / 3)
    c.saveGState(); let clip = CGMutablePath()
    for (i, v) in d.enumerated() {
      let dx = v.x - center.x, dy = v.y - center.y, l = max(0.001, hypot(dx, dy))
      let point = CGPoint(x: v.x + dx / l * 0.16, y: v.y + dy / l * 0.16)
      if i == 0 { clip.move(to: point) } else { clip.addLine(to: point) }
    }
    clip.closeSubpath(); c.addPath(clip); c.clip()
    c.concatenate(CGAffineTransform(a: A, b: B, c: C, d: D, tx: p.x - A * a.x - C * a.y, ty: p.y - B * a.x - D * a.y))
    artworkImage.draw(in: CGRect(x: 0, y: 0, width: 512, height: 512))
    c.restoreGState()
  }
}

/// Pre-rendered relaxed → flexed poses.
@MainActor final class ArmFrames: ObservableObject {
  static let shared = ArmFrames()
  static let count = 24
  static let side: CGFloat = 420
  @Published private(set) var frames: [UIImage] = []
  private var loading = false
  func prepare() {
    guard frames.isEmpty, !loading else { return }
    loading = true
    let count = Self.count, side = Self.side
    Task.detached(priority: .userInitiated) {
      let start = Date()
      // Poses are independent: render them across all cores.
      let lock = NSLock()
      var rendered = [UIImage?](repeating: nil, count: count)
      DispatchQueue.concurrentPerform(iterations: count) { i in
        let image = ArmRenderer.render(curl: Double(i) / Double(count - 1), side: side)
        lock.lock(); rendered[i] = image; lock.unlock()
      }
      let frames = rendered.compactMap { $0 }
      #if DEBUG
      NSLog("GymBlock arm frames: %d in %.2f s", frames.count, Date().timeIntervalSince(start))
      #endif
      await MainActor.run { self.frames = frames; self.loading = false }
    }
  }
}

/// Animatable, so SwiftUI interpolates curl and warmth and the flipbook plays smoothly.
struct ArmView: View, Animatable {
  var curl: Double
  var warmth: Double
  @ObservedObject private var store = ArmFrames.shared
  init(curl: Double, warmth: Double) { self.curl = curl; self.warmth = warmth }
  var animatableData: AnimatablePair<Double, Double> {
    get { AnimatablePair(curl, warmth) }
    set { curl = newValue.first; warmth = newValue.second }
  }
  var body: some View {
    Group {
      if store.frames.isEmpty {
        Color.clear
      } else {
        let index = Int((min(1, max(0, curl)) * Double(ArmFrames.count - 1)).rounded())
        Image(uiImage: store.frames[index]).resizable().interpolation(.high).scaledToFit()
          .colorMultiply(JourneyColor.heat(warmth))
      }
    }.onAppear { store.prepare() }.accessibilityHidden(true)
  }
}
