import SwiftUI

/// The streak flame after Cal AI's (shared with the widgets since 9 Nov 2026) (9 Nov 2026, at the user's request): an orange gradient flame, a
/// paler inner flame, the count in white inside its foot with an orange edge, and three sparkles.
/// No circle behind it. Orange is this flame's own colour, the one warm colour outside the phone's
/// red; `size` is the flame's height.
struct StreakFlame: View {
  var count: Int? = nil
  var size: CGFloat = 96
  static let orange = Color(red: 0.95, green: 0.60, blue: 0.22)
  static let deep = Color(red: 0.91, green: 0.52, blue: 0.22)
  static let pale = Color(red: 0.99, green: 0.85, blue: 0.55)
  var body: some View {
    ZStack {
      Image(systemName: "flame.fill").font(.system(size: size, weight: .regular))
        .foregroundStyle(LinearGradient(colors: [Color(red: 0.97, green: 0.66, blue: 0.25), Self.deep], startPoint: .top, endPoint: .bottom))
      Image(systemName: "flame.fill").font(.system(size: size * 0.48, weight: .regular))
        .foregroundStyle(Self.pale).offset(y: size * 0.2)
      if let count {
        // A thick orange edge (the user, 9 Nov: "bigger outline stroke"): the number in the edge
        // colour drawn at sixteen offsets around it and eight closer in (eight alone scalloped),
        // the white on top.
        let edge = max(1.5, size * 0.045)
        ZStack {
          ForEach(0..<24, id: \.self) { i in
            let a = Double(i % 16) * .pi / 8 + (i >= 16 ? .pi / 16 : 0)
            let r = i >= 16 ? edge * 0.5 : edge
            Text("\(count)").font(.system(size: size * 0.42, weight: .heavy, design: .rounded)).monospacedDigit()
              .foregroundStyle(Self.deep).offset(x: cos(a) * r, y: sin(a) * r)
          }
          Text("\(count)").font(.system(size: size * 0.42, weight: .heavy, design: .rounded)).monospacedDigit()
            .foregroundStyle(.white)
        }
        .offset(y: size * 0.22)
      }
      if size >= 48 {
        Image(systemName: "sparkle").font(.system(size: size * 0.14, weight: .bold)).foregroundStyle(Self.pale).offset(x: -size * 0.46, y: -size * 0.28)
        Image(systemName: "sparkle").font(.system(size: size * 0.2, weight: .bold)).foregroundStyle(Color(red: 0.85, green: 0.60, blue: 0.42)).offset(x: size * 0.5, y: -size * 0.4)
        Image(systemName: "sparkle").font(.system(size: size * 0.09, weight: .bold)).foregroundStyle(Self.orange).offset(x: -size * 0.52, y: 0)
      }
    }
    .frame(width: size * 1.3, height: size * 1.15)
    .accessibilityHidden(true)
  }
}

