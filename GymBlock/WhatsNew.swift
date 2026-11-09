import SwiftUI

/// What's new, once per version, to people who were already past onboarding when this version
/// first launched (9 Nov 2026, at the user's request). A fresh install never sees it: the notes
/// are marked seen the first time Home shows. `-whatsNew` on a development run forces it.
enum WhatsNew {
  /// The version these notes are for. Bump it with the notes; an older "seen" shows them again.
  static let version = "1.1.0"
  private static let key = "gymblock.whatsNew.seen"
  /// Whether the phone was onboarded when this launch began: set once by the root before anything moves.
  private(set) static var onboardedAtLaunch: Bool?
  static func noteLaunch(onboarded: Bool) { if onboardedAtLaunch == nil { onboardedAtLaunch = onboarded } }
  static var forced: Bool { ProcessInfo.processInfo.arguments.contains("-whatsNew") }
  /// Show on this Home: not seen for this version, and onboarded before this launch (or forced).
  static var pending: Bool {
    if forced { return true }
    guard UserDefaults.standard.string(forKey: key) != version else { return false }
    return onboardedAtLaunch == true
  }
  static func markSeen() { UserDefaults.standard.set(version, forKey: key) }
}

/// The sheet, nearly the whole screen, one page per feature (the user, 9 Nov 2026): a picture in
/// the middle, the headline and one line under it, the page dots, and Continue, which turns the
/// page and closes on the last. Swiping turns the pages too.
struct WhatsNewSheet: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dismiss) private var dismiss
  @State private var page = 0
  private let pages = 3
  var body: some View {
    VStack(spacing: 0) {
      TabView(selection: $page) {
        introPage.tag(0)
        buddyPage.tag(1)
        widgetsPage.tag(2)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .onChange(of: page) { _, _ in JourneyHaptic.play(.selection, store.profile) }
      HStack(spacing: 6) {
        ForEach(0..<pages, id: \.self) { i in
          Capsule().fill(i == page ? JourneyColor.text : JourneyColor.ink(0.14))
            .frame(width: i == page ? 18 : 6, height: 6)
        }
      }
      .animation(.spring(duration: 0.4, bounce: 0.1), value: page)
      .padding(.bottom, 20).accessibilityHidden(true)
      JourneyButton(title: store.t(page < pages - 1 ? "Continue" : "Done"), id: "whatsNew.continue") {
        if page < pages - 1 { withAnimation(.smooth(duration: 0.35)) { page += 1 } } else { dismiss() }
      }
      .padding(.horizontal, 24).padding(.bottom, 12)
    }
    .background(JourneyColor.stage.ignoresSafeArea())
    .presentationDetents([.large]).presentationDragIndicator(.visible)
    .track(screen: "whats_new", ["version": WhatsNew.version])
  }

  /// The first page: the mark drops in from above and lands with a thud (the user, 9 Nov 2026).
  private var introPage: some View {
    pageFrame(title: store.t("New in GymBlock"), line: store.t("A few things have changed since your last update.")) {
      DroppedMark()
    }
  }

  /// GymBuddy: a hand-drawn gift, the ribbon in the app's emerald.
  private var buddyPage: some View {
    pageFrame(title: store.t("Gift your GymBuddy"),
              line: store.t("Invite your friend to be your GymBuddy by gifting them 2 weeks of GymBlock Pro for FREE."),
              highlight: store.t("gifting")) {
      HandDrawnGift().frame(width: 240, height: 270).accessibilityHidden(true)
    }
  }

  /// Widgets: the week and the streak, as they'd sit on a Home Screen.
  private var widgetsPage: some View {
    pageFrame(title: store.t("Widgets"), line: store.t("You can now add beautiful widgets on your Home Screen.")) {
      let snapshot = WidgetSnapshot.load()
      VStack(spacing: 14) {
        plate(width: 338) { WeekStripView(snapshot: snapshot, date: Date()) }
        HStack(spacing: 14) {
          plate(width: 158) { StreakView(snapshot: snapshot, date: Date(), medium: false) }
          plate(width: 158) { UpNextSmallView(snapshot: snapshot, date: Date()) }
        }
      }
      .scaleEffect(0.92)
      .accessibilityHidden(true)
    }
  }

  /// `highlight`: one word of the line in emerald (the user, 9 Nov: "gifting").
  private func pageFrame<Picture: View>(title: String, line: String, highlight: String? = nil, @ViewBuilder picture: () -> Picture) -> some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      picture()
      Spacer(minLength: 0)
      VStack(spacing: 10) {
        Text(title).font(.app(size: 28, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
          .multilineTextAlignment(.center)
        lineText(line, highlight: highlight).font(.app(.body)).foregroundStyle(JourneyColor.secondary).multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 32).padding(.bottom, 28)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func lineText(_ line: String, highlight: String?) -> Text {
    guard let word = highlight, let range = line.range(of: word) else { return Text(line) }
    return Text(String(line[..<range.lowerBound]))
      + Text(word).foregroundStyle(JourneyColor.signalText).fontWeight(.semibold)
      + Text(String(line[range.upperBound...]))
  }

  private func plate<V: View>(width: CGFloat, @ViewBuilder _ content: () -> V) -> some View {
    let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
    return content()
      .padding(16)
      .frame(width: width, height: 158)
      .environment(\.widgetTone, WidgetTone(mode: .paper, dark: colorScheme == .dark))
      .background(JourneyColor.raised, in: shape)
      .overlay(shape.strokeBorder(JourneyColor.hairline, lineWidth: 1))
      .clipShape(shape)
      .shadow(color: JourneyColor.ink(0.06), radius: 14, y: 6)
      .allowsHitTesting(false)
  }
}


/// A gift box as if drawn by hand (9 Nov 2026, after the user's reference): a white box with a
/// slightly wobbly edge, the ribbon crossing it and tied in a bow, every line in the app's emerald
/// with a loose, round-capped stroke.
struct HandDrawnGift: View {
  var body: some View {
    GeometryReader { geo in
      let w = geo.size.width, h = geo.size.height
      let box = CGRect(x: w * 0.16, y: h * 0.36, width: w * 0.68, height: h * 0.6)
      let stroke = StrokeStyle(lineWidth: max(4, w * 0.04), lineCap: .round, lineJoin: .round)
      ZStack {
        boxPath(box).fill(Color.white)
        boxPath(box).stroke(JourneyColor.ink(0.12), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        ribbon(box, h: h).stroke(JourneyColor.signal, style: stroke)
        bow(box, w: w, h: h).stroke(JourneyColor.signal, style: stroke)
      }
      .shadow(color: JourneyColor.ink(0.08), radius: 16, y: 8)
    }
  }
  /// The box: four edges, each bowed a touch so it isn't a ruler's rectangle.
  private func boxPath(_ r: CGRect) -> Path {
    var p = Path()
    let d = r.width * 0.012
    p.move(to: CGPoint(x: r.minX, y: r.minY))
    p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + d), control: CGPoint(x: r.midX, y: r.minY - d * 1.5))
    p.addQuadCurve(to: CGPoint(x: r.maxX - d, y: r.maxY), control: CGPoint(x: r.maxX + d * 1.5, y: r.midY))
    p.addQuadCurve(to: CGPoint(x: r.minX + d, y: r.maxY - d), control: CGPoint(x: r.midX, y: r.maxY + d * 1.5))
    p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY), control: CGPoint(x: r.minX - d * 1.5, y: r.midY))
    p.closeSubpath()
    return p
  }
  /// The ribbon: one line across, one down, each wandering a little.
  private func ribbon(_ r: CGRect, h: CGFloat) -> Path {
    var p = Path()
    let wob = r.width * 0.015
    p.move(to: CGPoint(x: r.minX + 4, y: r.midY + wob))
    p.addCurve(to: CGPoint(x: r.maxX - 4, y: r.midY - wob * 0.5),
               control1: CGPoint(x: r.minX + r.width * 0.35, y: r.midY - wob * 2),
               control2: CGPoint(x: r.minX + r.width * 0.65, y: r.midY + wob * 2))
    p.move(to: CGPoint(x: r.midX - wob * 0.5, y: r.minY + 2))
    p.addCurve(to: CGPoint(x: r.midX + wob, y: r.maxY - 4),
               control1: CGPoint(x: r.midX + wob * 2, y: r.minY + r.height * 0.35),
               control2: CGPoint(x: r.midX - wob * 2, y: r.minY + r.height * 0.65))
    return p
  }
  /// The bow: two loops above the box, meeting in a knot on the ribbon.
  private func bow(_ r: CGRect, w: CGFloat, h: CGFloat) -> Path {
    var p = Path()
    let knot = CGPoint(x: r.midX, y: r.minY + 2)
    let loop = r.width * 0.28, lift = h * 0.2
    p.move(to: knot)
    p.addCurve(to: knot, control1: CGPoint(x: knot.x - loop * 1.05, y: knot.y - lift * 1.1),
               control2: CGPoint(x: knot.x - loop * 0.9, y: knot.y + lift * 0.25))
    p.move(to: knot)
    p.addCurve(to: knot, control1: CGPoint(x: knot.x + loop * 1.1, y: knot.y - lift * 1.05),
               control2: CGPoint(x: knot.x + loop * 0.85, y: knot.y + lift * 0.3))
    // The two tails, short, falling from the knot.
    p.move(to: knot)
    p.addQuadCurve(to: CGPoint(x: knot.x - loop * 0.45, y: knot.y + lift * 0.55), control: CGPoint(x: knot.x - loop * 0.1, y: knot.y + lift * 0.4))
    p.move(to: knot)
    p.addQuadCurve(to: CGPoint(x: knot.x + loop * 0.4, y: knot.y + lift * 0.5), control: CGPoint(x: knot.x + loop * 0.1, y: knot.y + lift * 0.4))
    return p
  }
}


/// The kettlebell falling onto the page: it starts above the screen, drops with gravity's ease,
/// lands with a heavy haptic and a short squash, then settles. Under Reduce Motion it just sits.
private struct DroppedMark: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @State private var landed = false
  @State private var squashed = false
  var body: some View {
    let still = JourneyMotion.reduced(systemReduceMotion)
    BrandMark(size: 132)
      .scaleEffect(x: squashed ? 1.08 : 1, y: squashed ? 0.9 : 1, anchor: .bottom)
      .offset(y: landed || still ? 0 : -520)
      .onAppear {
        guard !still, !landed else { return }
        JourneyHaptic.prepare(.heavy)
        // The fall: 0.42 s, easing in as it gathers speed. The thud lands as it touches down.
        withAnimation(.easeIn(duration: 0.42)) { landed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
          JourneyHaptic.play(.heavy, store.profile, intensity: 1)
          withAnimation(.easeOut(duration: 0.08)) { squashed = true }
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            withAnimation(.spring(duration: 0.4, bounce: 0.45)) { squashed = false }
          }
        }
      }
  }
}
