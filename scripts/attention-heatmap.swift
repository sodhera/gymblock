// Predicted-attention heatmaps for screenshots, using Apple's on-device
// attention-based saliency model (Vision). Usage:
//   swift scripts/attention-heatmap.swift <input-dir> <output-dir>
// Writes <name>-heat.png overlays and prints, per image, the attention peak and
// the share of attention in the top, middle and bottom thirds of the screen.
import AppKit
import CoreImage
import Foundation
import Vision

let args = CommandLine.arguments
guard args.count == 3 else { print("usage: attention-heatmap.swift <in> <out>"); exit(1) }
let input = URL(fileURLWithPath: args[1]), output = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func heatColor(_ v: Float) -> (UInt8, UInt8, UInt8) {
  // Transparent-ish blue → cyan → yellow → red.
  let stops: [(Float, (Float, Float, Float))] = [(0, (0, 0, 0.6)), (0.35, (0, 0.8, 1)), (0.65, (1, 0.9, 0)), (1, (1, 0.1, 0))]
  for i in 1..<stops.count where v <= stops[i].0 {
    let (a, ca) = stops[i - 1], (b, cb) = stops[i]
    let t = (v - a) / (b - a)
    return (UInt8((ca.0 + (cb.0 - ca.0) * t) * 255), UInt8((ca.1 + (cb.1 - ca.1) * t) * 255), UInt8((ca.2 + (cb.2 - ca.2) * t) * 255))
  }
  return (255, 26, 0)
}

let files = (try FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: nil))
  .filter { $0.pathExtension == "png" && $0.lastPathComponent.first?.isNumber == true }.sorted { $0.path < $1.path }
print("page\tpeak_y%\ttop%\tmiddle%\tbottom%")
for file in files {
  guard let image = NSImage(contentsOf: file), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
  let request = VNGenerateAttentionBasedSaliencyImageRequest()
  try VNImageRequestHandler(cgImage: cg).perform([request])
  guard let obs = request.results?.first as? VNSaliencyImageObservation else { continue }
  let buffer = obs.pixelBuffer
  CVPixelBufferLockBaseAddress(buffer, .readOnly)
  let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer)
  let stride = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float>.size
  let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: Float.self)
  var values = [Float](repeating: 0, count: w * h)
  for y in 0..<h { for x in 0..<w { values[y * w + x] = base[y * stride + x] } }
  CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
  let maxV = max(values.max() ?? 1, 0.0001)
  var thirds = [Float](repeating: 0, count: 3), peak = (0, 0, Float(0))
  for y in 0..<h { for x in 0..<w {
    let v = values[y * w + x]
    thirds[min(2, y * 3 / h)] += v
    if v > peak.2 { peak = (x, y, v) }
  } }
  let total = max(thirds.reduce(0, +), 0.0001)
  // Overlay: upscale the heat grid with bilinear sampling.
  let W = cg.width, H = cg.height
  var rgba = [UInt8](repeating: 0, count: W * H * 4)
  for py in 0..<H { for px in 0..<W {
    let fx = Float(px) / Float(W) * Float(w - 1), fy = Float(py) / Float(H) * Float(h - 1)
    let x0 = Int(fx), y0 = Int(fy), x1 = min(w - 1, x0 + 1), y1 = min(h - 1, y0 + 1)
    let tx = fx - Float(x0), ty = fy - Float(y0)
    let v = (values[y0 * w + x0] * (1 - tx) + values[y0 * w + x1] * tx) * (1 - ty)
      + (values[y1 * w + x0] * (1 - tx) + values[y1 * w + x1] * tx) * ty
    let n = v / maxV
    let (r, g, b) = heatColor(n)
    let i = (py * W + px) * 4
    rgba[i] = r; rgba[i + 1] = g; rgba[i + 2] = b; rgba[i + 3] = UInt8(min(1, n * 1.4) * 170)
  } }
  let heat = CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
                     space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                     provider: CGDataProvider(data: Data(rgba) as CFData)!, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
  let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
  ctx.draw(heat, in: CGRect(x: 0, y: 0, width: W, height: H))
  let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
  let name = file.deletingPathExtension().lastPathComponent
  try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + "-heat.png"))
  print("\(name)\t\(Int(Double(peak.1) / Double(h) * 100))\t\(Int(thirds[0] / total * 100))\t\(Int(thirds[1] / total * 100))\t\(Int(thirds[2] / total * 100))")
}
