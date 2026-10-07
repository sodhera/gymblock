import SwiftUI

/// Brain outline and folds in a 240 × 220 design space.
enum BrainShape {
  static let size = CGSize(width: 240, height: 220)
  static let outline: Path = {
    var p = Path(); p.move(to: CGPoint(x: 119, y: 34))
    let curves: [[Double]] = [
      [109,13,86,15,76,34],[55,27,36,43,39,63],[19,76,23,96,32,107],
      [20,125,30,145,44,153],[45,176,66,192,85,184],[91,199,112,197,119,182],
      [127,198,148,199,158,184],[180,190,198,175,198,153],[216,142,217,120,206,107],
      [219,91,217,73,202,63],[205,43,185,27,164,34],[153,14,130,13,119,34]]
    for a in curves { p.addCurve(to: CGPoint(x: a[4], y: a[5]), control1: CGPoint(x: a[0], y: a[1]), control2: CGPoint(x: a[2], y: a[3])) }
    p.closeSubpath(); return p
  }()
  static let folds: Path = {
    let lines: [[Double]] = [
      [119,35,116,60,121,79,119,94], [119,160,120,168,120,176,119,183],
      [76,35,62,49,68,67,88,70,101,72,103,84,95,92],
      [39,64,54,60,63,71,60,86,56,97,64,103,71,103],
      [32,108,43,110,49,118,47,130,45,143,57,148,68,140],
      [45,153,57,152,70,164,66,180],[86,183,96,170,90,155,96,150],
      [164,35,178,49,171,67,153,71,140,74,139,87,146,92],
      [202,64,185,61,176,72,181,85,186,99,176,105,166,104],
      [206,108,193,111,189,120,192,132,195,144,181,149,169,142],
      [198,153,185,153,173,165,178,180],[156,182,146,169,151,155,145,150]]
    var p = Path()
    for a in lines {
      p.move(to: CGPoint(x: a[0], y: a[1]))
      for i in stride(from: 2, to: a.count, by: 6) {
        p.addCurve(to: CGPoint(x: a[i+4], y: a[i+5]), control1: CGPoint(x: a[i], y: a[i+1]), control2: CGPoint(x: a[i+2], y: a[i+3]))
      }
    }
    return p
  }()
  static func fit(_ path: Path, in rect: CGRect) -> Path {
    let s = min(rect.width / size.width, rect.height / size.height)
    return path.applying(CGAffineTransform(translationX: rect.midX - size.width * s / 2, y: rect.midY - size.height * s / 2).scaledBy(x: s, y: s))
  }
}

struct BrainOutline: Shape {
  func path(in rect: CGRect) -> Path { BrainShape.fit(BrainShape.outline, in: rect) }
}
struct BrainFolds: Shape {
  func path(in rect: CGRect) -> Path { BrainShape.fit(BrainShape.folds, in: rect) }
}
/// `mood` runs from −1 (drained) to +1 (bright) and animates smoothly.
struct BrainMouth: Shape {
  var mood: Double
  var animatableData: Double { get { mood } set { mood = newValue } }
  func path(in rect: CGRect) -> Path {
    var p = Path()
    p.move(to: CGPoint(x: 104, y: 141))
    p.addQuadCurve(to: CGPoint(x: 136, y: 141), control: CGPoint(x: 120, y: 141 + mood * 20))
    return BrainShape.fit(p, in: rect)
  }
}
struct BrainEyes: Shape {
  var mood: Double
  var animatableData: Double { get { mood } set { mood = newValue } }
  func path(in rect: CGRect) -> Path {
    var p = Path()
    let eye = 10 - max(0, -mood) * 5
    for x in [92.0, 148.0] {
      p.addRoundedRect(in: CGRect(x: x - 4.5, y: 117 - eye / 2, width: 9, height: eye), cornerSize: CGSize(width: 4.5, height: min(4.5, eye / 2)))
    }
    return BrainShape.fit(p, in: rect)
  }
}
