import SwiftUI

/// Development only: App Store screenshot states the simulator can't reach on its own.
/// `-storeShots YES` fills the blocking page with six sample apps (the icons iOS would draw from
/// Screen Time tokens once someone chooses them) and drops Home's "Sample data" line.
/// `-shieldPreview Instagram` shows a SwiftUI rebuild of the shield iOS draws over a blocked app
/// (`GymBlockShield/WorkoutShield.swift`), which only exists on a real iPhone. `-pickerPreview YES`
/// shows a rebuild of Apple's app picker with the feeds ticked and Spotify left open (2 Nov 2026:
/// people read "blocks your apps" as all of them, music too). `-calendarMonthsBack 1` shows Profile's
/// calendar a month back, so a screenshot taken early in a month still has a full one, and
/// `-denseDemo YES` makes the sample history six days a week for seven weeks (the streak slide). The icons live in
/// `StoreShots.xcassets`, which Release builds exclude; in Release everything here is off.
enum StoreShots {
  struct App: Hashable { let asset: String; let name: String }
  #if DEBUG
    static var on: Bool { UserDefaults.standard.bool(forKey: "storeShots") }
    static var shieldApp: String? { UserDefaults.standard.string(forKey: "shieldPreview") }
    static var picker: Bool { UserDefaults.standard.bool(forKey: "pickerPreview") }
    static var monthsBack: Int { UserDefaults.standard.integer(forKey: "calendarMonthsBack") }
    static var dense: Bool { UserDefaults.standard.bool(forKey: "denseDemo") }
    static var apps: [App] {
      guard on else { return [] }
      return [App(asset: "shot.tiktok", name: "TikTok"), App(asset: "shot.instagram", name: "Instagram"),
              App(asset: "shot.snapchat", name: "Snapchat"), App(asset: "shot.youtube", name: "YouTube"),
              App(asset: "shot.x", name: "X"), App(asset: "shot.reddit", name: "Reddit")]
    }
  #else
    static let on = false
    static let shieldApp: String? = nil
    static let picker = false
    static let monthsBack = 0
    static let dense = false
    static let apps: [App] = []
  #endif
}

#if DEBUG
  /// Apple's app picker as Blocked apps opens it (`familyActivityPicker`): the header line, Screen
  /// Time's categories with Social and Entertainment open, the feeds ticked and Spotify not. A
  /// rebuild, not a capture: the real picker only lists a real iPhone's own apps.
  struct AppPickerShot: View {
    private let ticked: Set<String> = ["Instagram", "TikTok", "YouTube"]
    var body: some View {
      NavigationStack {
        List {
          Section {
            category("All Apps & Categories", symbol: "square.stack.3d.up.fill", tint: .gray, opens: false)
            category("Social", symbol: "bubble.left.and.bubble.right.fill", tint: .blue, open: true)
            app("shot.instagram", "Instagram")
            app("shot.tiktok", "TikTok")
            category("Entertainment", symbol: "popcorn.fill", tint: .pink, open: true)
            app("shot.spotify", "Spotify")
            app("shot.youtube", "YouTube")
            category("Games", symbol: "gamecontroller.fill", tint: .purple)
            category("Creativity", symbol: "paintbrush.pointed.fill", tint: .orange)
            category("Education", symbol: "globe.americas.fill", tint: .teal)
            category("Health & Fitness", symbol: "figure.run", tint: .red)
            category("Information & Reading", symbol: "book.fill", tint: .brown)
            category("Productivity & Finance", symbol: "paperplane.fill", tint: .indigo)
          } header: {
            Text("Choose what to block from Start workout to Finish.").textCase(nil)
              .font(.subheadline).foregroundStyle(.secondary)
          }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Choose Activities")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: .constant(""), placement: .navigationBarDrawer(displayMode: .always))
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") {} }
          ToolbarItem(placement: .confirmationAction) { Button("Done") {} }
        }
      }
      .preferredColorScheme(.light)
    }

    private func mark(_ on: Bool) -> some View {
      Image(systemName: on ? "checkmark.circle.fill" : "circle")
        .font(.system(size: 22)).foregroundStyle(on ? Color.blue : Color(.tertiaryLabel))
    }
    private func category(_ name: String, symbol: String, tint: Color, open: Bool = false, opens: Bool = true) -> some View {
      HStack(spacing: 12) {
        mark(false)
        Image(systemName: symbol).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
          .frame(width: 30, height: 30)
          .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint))
        Text(name)
        Spacer(minLength: 8)
        if opens {
          Image(systemName: open ? "chevron.down" : "chevron.right")
            .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(.tertiaryLabel))
        }
      }.frame(minHeight: 36)
    }
    private func app(_ asset: String, _ name: String) -> some View {
      HStack(spacing: 12) {
        mark(ticked.contains(name))
        Image(asset).resizable().frame(width: 30, height: 30)
          .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        Text(name)
        Spacer(minLength: 0)
      }.padding(.leading, 34).frame(minHeight: 36)
    }
  }
#endif

#if DEBUG
  /// The shield as `WorkoutShield` configures it: white, the brand mark, "You're mid-workout.",
  /// the app's name in the subtitle and one ink button. A rebuild, not a capture, laid out as iOS
  /// draws a shield: the mark and the words a little above the middle, the buttons at the foot.
  struct ShieldPreview: View {
    let app: String
    private let paper = Color.white
    private let ink = Color(red: 0.08, green: 0.08, blue: 0.09)
    private let secondary = Color(red: 0.40, green: 0.40, blue: 0.42)
    var body: some View {
      VStack(spacing: 0) {
        Spacer(minLength: 0)
        VStack(spacing: 18) {
          BrandMark(size: 90)
          VStack(spacing: 10) {
            Text("You’re mid-workout.").font(.app(.title2, weight: .bold)).foregroundStyle(ink)
            Text("\(app) opens when you finish your workout in GymBlock.")
              .font(.app(.body)).foregroundStyle(secondary).multilineTextAlignment(.center)
              .fixedSize(horizontal: false, vertical: true)
          }.padding(.horizontal, 12)
        }.padding(.horizontal, 24)
        Spacer(minLength: 0)
        Spacer(minLength: 0)
        VStack(spacing: 12) {
          Text("Back to training").font(.app(.headline)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(Capsule().fill(ink))
          // Strict mode off: the once-per-exercise minute, as iOS draws the second button (a white pill).
          if !BlockingPass.strict {
            Text("Give me 1 minute").font(.app(.body)).foregroundStyle(ink)
              .frame(maxWidth: .infinity).frame(height: 54)
              .background(Capsule().fill(.white))
          }
        }.padding(.horizontal, 24).padding(.bottom, 24)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(paper.ignoresSafeArea())
      .preferredColorScheme(.light)
    }
  }
#endif
