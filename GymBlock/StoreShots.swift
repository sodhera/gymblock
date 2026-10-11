import SwiftUI

/// Development only: App Store screenshot states the simulator can't reach on its own.
/// `-storeShots YES` fills the blocking page with six sample apps (the icons iOS would draw from
/// Screen Time tokens once someone chooses them) and drops Home's "Sample data" line.
/// `-shieldPreview Instagram` shows a SwiftUI rebuild of the shield iOS draws over a blocked app
/// (`GymBlockShield/WorkoutShield.swift`), which only exists on a real iPhone. The icons live in
/// `StoreShots.xcassets`, which Release builds exclude; in Release everything here is off.
enum StoreShots {
  struct App: Hashable { let asset: String; let name: String }
  #if DEBUG
    static var on: Bool { UserDefaults.standard.bool(forKey: "storeShots") }
    static var shieldApp: String? { UserDefaults.standard.string(forKey: "shieldPreview") }
    static var apps: [App] {
      guard on else { return [] }
      return [App(asset: "shot.tiktok", name: "TikTok"), App(asset: "shot.instagram", name: "Instagram"),
              App(asset: "shot.snapchat", name: "Snapchat"), App(asset: "shot.youtube", name: "YouTube"),
              App(asset: "shot.x", name: "X"), App(asset: "shot.reddit", name: "Reddit")]
    }
  #else
    static let on = false
    static let shieldApp: String? = nil
    static let apps: [App] = []
  #endif
}

#if DEBUG
  /// The shield as `WorkoutShield` configures it: paper, the brand mark, "You're mid-workout.",
  /// the app's name in the subtitle and one ink button. A rebuild, not a capture. For store
  /// screenshots the button sits right under the words, so the top half of the screen carries it all.
  struct ShieldPreview: View {
    let app: String
    private let paper = Color(red: 0.961, green: 0.953, blue: 0.937)
    private let ink = Color(red: 0.08, green: 0.08, blue: 0.09)
    private let secondary = Color(red: 0.40, green: 0.40, blue: 0.42)
    var body: some View {
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        VStack(spacing: 18) {
          BrandMark(size: 90)
          VStack(spacing: 10) {
            Text("You’re mid-workout.").font(.title2.weight(.bold)).foregroundStyle(ink)
            Text("\(app) opens when you finish or pause your workout in GymBlock.")
              .font(.body).foregroundStyle(secondary).multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }.padding(.horizontal, 12)
          Text("Back to training").font(.headline).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(Capsule().fill(ink))
            .padding(.top, 18)
        }.padding(.horizontal, 24)
        Spacer(minLength: 0)
        Spacer(minLength: 0)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(paper.ignoresSafeArea())
      .preferredColorScheme(.light)
    }
  }
#endif
