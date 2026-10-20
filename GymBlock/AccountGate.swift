import SwiftUI
import UserNotifications

/// The screens around onboarding that aren't questions: the launch hold, the standalone sign-in,
/// the two account notices, and the offer. RootView decides which one shows; each is one idea on
/// the paper stage with its action in the thumb zone, like every onboarding page.

/// Shown while the saved session (and, for a subscriber, the entitlement) is being restored, so a
/// returning user never sees the welcome page or the offer flash first.
/// The splash: the kettlebell locks (see `KettlebellLock`), then the app appears.
struct LaunchView: View {
  var done: () -> Void = {}
  var body: some View {
    ZStack {
      DotGrid()
      KettlebellLock(size: 96, done: done).offset(y: -24)
    }.accessibilityHidden(true)
  }
}

/// A mark, a title, a line and the actions: the shape every page here shares.
private struct GateLayout<Actions: View>: View {
  var back: (() -> Void)? = nil
  let title: String
  let message: String
  var note: String? = nil
  var id = ""
  @ViewBuilder var actions: Actions
  @EnvironmentObject private var store: GymStore
  var body: some View {
    ZStack {
      DotGrid()
      VStack(spacing: 0) {
        HStack {
          if let back { JourneyBackButton(label: store.t("Back"), action: back) }
          Spacer()
        }.frame(height: 44).padding(.horizontal, 12)
        Spacer(minLength: 0)
        VStack(spacing: 20) {
          BrandMark(size: 72)
          VStack(spacing: 10) {
            Text(store.t(title)).font(JourneyType.headline).tracking(-0.3)
              .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
            Text(store.t(message)).font(.app(.body)).foregroundStyle(JourneyColor.secondary)
          }.multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 32)
        Spacer(minLength: 0)
        Text(note.map(store.t) ?? " ").font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
          .multilineTextAlignment(.center).lineLimit(2).frame(minHeight: 20).padding(.horizontal, 32)
        VStack(spacing: 4) { actions }.padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 6)
      }
    }
    .foregroundStyle(JourneyColor.text)
    .track(screen: id)
  }
}

/// The returning path, reached from "I already have an account" on the welcome page. It stands
/// apart from sign-up's account step: no progress line, its own words, "Sign in with…".
struct SignInView: View {
  let back: () -> Void
  let signedIn: (CloudSync.Found) -> Void
  @EnvironmentObject private var account: Account
  var body: some View {
    GateLayout(back: account.busy ? nil : back, title: "Welcome back", message: "Sign in to pick up where you left off.",
               note: account.message, id: "signin") {
      AccountButtons(intent: .signIn, signedIn: signedIn)
    }
  }
}

/// A sign-in that went somewhere other than where its screen pointed. Said plainly, with one way on.
struct AccountNoticeView: View {
  let notice: Account.Notice
  let primary: () -> Void
  var secondary: (() -> Void)? = nil
  @EnvironmentObject private var store: GymStore
  var body: some View {
    switch notice {
    case .existingAccount:
      GateLayout(title: "You already have an account",
                 message: "We signed you in instead. Your workouts are just as you left them.", id: "notice.existing") {
        JourneyButton(title: store.t("Continue to my account"), id: "notice.continue", action: primary)
        Color.clear.frame(height: 44)
      }
    case .notFound:
      GateLayout(title: "We couldn’t find your account",
                 message: "No GymBlock account uses this login yet. Sign up to make one.", id: "notice.notFound") {
        JourneyButton(title: store.t("Sign up"), id: "notice.signUp", action: primary)
        if let secondary {
          JourneyTextButton(title: store.t("Try another account"), id: "notice.retry", action: secondary)
        } else { Color.clear.frame(height: 44) }
      }
    }
  }
}

/// GymBlock Pro: the close of onboarding and the gate in front of the app for an account without
/// it. Laid out like JournalBlock's: the claim, three reasons, both plans side by side, one button,
/// and a quiet row for Restore, the documents and Sign out. A wall by design — subscribing,
/// restoring or signing out are the ways off it (Debug builds with no product configured get a
/// labelled skip, never Release). Prices, the struck-through anchor and the saving all come from
/// the store; nothing here is a pretend price.
struct PaywallView: View {
  @ObservedObject var subscription: GymSubscription
  let skip: () -> Void
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var account: Account
  @Environment(\.dynamicTypeSize) private var typeSize

  var body: some View {
    ZStack {
      DotGrid()
      VStack(spacing: 0) {
        GeometryReader { geo in
          ScrollView {
            VStack(alignment: .leading, spacing: 0) {
              // The pre-V7 paywall (crowns, plan cards with a check), restored 20 Oct 2026 at the user's
              // request, with today's headline from their numbers and their time at the gym under it.
              Text(headline)
                .font(JourneyType.headline).tracking(-0.3).foregroundStyle(JourneyColor.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
              Spacer(minLength: 20).frame(maxHeight: 32)
              if time.outcome == .full {
                TwoWays(time: time)
                Spacer(minLength: 20).frame(maxHeight: 32)
              }
              benefits
              Spacer(minLength: 18).frame(maxHeight: 22)
              // Cards are sized from the page's width, not by aspect ratio: .aspectRatio inside this row
              // squeezed them into tall strips (20 Oct 2026). Accessibility sizes keep their own height.
              plans(side: typeSize.isAccessibilitySize ? nil : (geo.size.width - 56 - 10) / 2)
              if let message = subscription.message, !subscription.plans.isEmpty {
                Text(store.t(message)).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
                  .frame(maxWidth: .infinity).multilineTextAlignment(.center).padding(.top, 14)
                  .accessibilityIdentifier("subscription.message")
              }
              // At accessibility sizes the footer needs more than half the screen; it scrolls instead.
              if typeSize.isAccessibilitySize { footer.padding(.top, 16) }
              // Clears the fade above the footer.
              Color.clear.frame(height: 28)
            }
            // The title sits just under the status bar (20 Oct 2026: 36 pt left a dead band over it).
            .padding(.horizontal, 28).padding(.top, 6)
            .frame(minHeight: geo.size.height, alignment: .top)
          }.scrollIndicators(.hidden)
        }
        if !typeSize.isAccessibilitySize { footer }
      }
    }
    .foregroundStyle(JourneyColor.text)
    .animation(JourneyMotion.gentle, value: subscription.plans)
    .task { await subscription.load() }
    .track(screen: "paywall")
  }

  // MARK: Sections

  private var time: TimeBack { TimeBack(store.profile.baseline ?? RoutineBaseline(), restSeconds: store.profile.restSeconds) }
  private func footerLink(_ title: String) -> some View {
    Text(title).padding(.horizontal, 6).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
  }
  /// The change, never a body prediction: "{Name}, get your time back." for anyone whose phone runs
  /// past their rest (20 Oct 2026, at the user's request: "get your 10 minutes back" undersold it; the
  /// bars under it carry their own minutes). Rarely, or a phone that fits the rest: every rest on time.
  private var headline: String {
    let name = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let loses = (time.lostPerRest ?? 0) > 0
    let line = loses ? "Get your time back." : "Keep every rest on time."
    let named = loses ? "%@, get your time back." : "%@, keep every rest on time."
    return name.isEmpty ? store.t(line) : String(format: store.t(named), name)
  }
  private var benefits: some View {
    VStack(alignment: .leading, spacing: 18) {
      // Short, plain words: one idea per line, readable at a glance.
      Benefit(lead: store.t("No distractions"), detail: store.t("Your apps stay locked while you work out."))
      Benefit(lead: store.t("Rest timer"), detail: store.t("Your phone buzzes when rest is over."))
      Benefit(lead: store.t("Track progress"), detail: store.t("Every set you do is saved."))
    }.accessibilityIdentifier("journey.recap")
  }

  @ViewBuilder private func plans(side: CGFloat?) -> some View {
    if subscription.plans.isEmpty && !subscription.busy && subscription.message != nil {
      // Nothing to choose from: say why, and offer another try when the store is configured.
      VStack(spacing: 8) {
        Text(store.t(subscription.message ?? ""))
          .font(JourneyType.caption).foregroundStyle(JourneyColor.secondary).multilineTextAlignment(.center)
          .accessibilityIdentifier("subscription.message")
        if subscription.configured {
          JourneyTextButton(title: store.t("Try again"), id: "subscription.retry") { Task { await subscription.load() } }
        }
      }.frame(maxWidth: .infinity).padding(18).journeySurface()
      #if DEBUG
        // Simulator use only: with no product configured, step past the offer. Never in Release.
        // Here rather than in the footer, so the primary button keeps its place.
        JourneyTextButton(title: "Continue without subscribing · Debug", id: "subscription.debugSkip", action: skip).padding(.top, 8)
      #endif
    } else {
      planCards(side: side)
    }
  }
  private func planCards(side: CGFloat?) -> some View {
    VStack(spacing: 10) {
      Text(store.t("Select a plan that fits you")).font(.app(.subheadline, weight: .semibold))
        .frame(maxWidth: .infinity)
      HStack(alignment: .top, spacing: 10) {
        if subscription.plans.isEmpty {
          // Placeholders hold the cards' exact footprint, so nothing jumps when prices land.
          PricingCardPlaceholder(side: side); PricingCardPlaceholder(side: side)
        } else {
          ForEach(subscription.plans) { plan in
            PricingCard(plan: plan, selected: subscription.selected == plan.id, side: side) {
              withAnimation(JourneyMotion.gentle) { subscription.selected = plan.id }
              JourneyHaptic.play(.selection, store.profile)
              Analytics.tap("plan." + (plan.yearly ? "yearly" : "monthly"))
            }
          }
        }
      }.padding(.top, 9)  // Room for the badge overhanging the yearly card.
    }
  }

  private var footer: some View {
    // The same footprint as every onboarding page's actions: the button, then a 44-pt row.
    VStack(spacing: 4) {
      // What's charged and that it renews, always in full view right above the button that charges
      // (App Review 3.1.2): under the cards it sat beneath the footer's fade, washed out until scrolled.
      if !subscription.plans.isEmpty {
        Text(terms).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
          .multilineTextAlignment(.center).frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
          .padding(.bottom, 8)
          .accessibilityIdentifier("subscription.terms")
      }
      JourneyButton(title: buyTitle, symbol: nil, id: "subscription.buy",
                    enabled: subscription.plan != nil && !subscription.busy, loading: subscription.busy && subscription.plan != nil) {
        Task { await subscription.buy() }
      }
      // Price and period are on the cards; Restore and working Terms/Privacy links are required
      // on a subscription paywall (App Review 3.1.1, 3.1.2).
      // Each link is a full 44-pt target, not just its words (they were about 18 pt tall).
      HStack(spacing: 4) {
        Button { Task { await subscription.restore() } } label: { footerLink(store.t("Restore")) }.accessibilityIdentifier("subscription.restore")
        Link(destination: AppConfig.termsURL) { footerLink(store.t("Terms")) }
        Link(destination: AppConfig.privacyURL) { footerLink(store.t("Privacy")) }
        // The only way off a wall when signed in with the wrong account.
        if account.user != nil {
          Button { signOut() } label: { footerLink(store.t("Sign out")) }.accessibilityIdentifier("subscription.signOut")
        }
      }
      .font(.app(.footnote)).foregroundStyle(JourneyColor.secondary).buttonStyle(.hapticPlain)
    }
    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 6)
    .background(alignment: .top) {
      LinearGradient(colors: [JourneyColor.stage.opacity(0), JourneyColor.stage], startPoint: .top, endPoint: .bottom)
        .frame(height: 28).offset(y: -28).allowsHitTesting(false)
    }
  }

  /// The selected plan's terms on one line: the trial's length, what is charged after it, and that
  /// it renews by itself (App Review 3.1.2(c), 15 Oct 2026).
  private var terms: String {
    guard let plan = subscription.plan else { return store.t("Charged automatically. Cancel anytime.") }
    let price = plan.price + "/" + store.t(plan.yearly ? "year" : "month")
    if plan.trialDays > 0 { return String(format: store.t("%@ days free, then %@, charged automatically."), "\(plan.trialDays)", price) }
    return String(format: store.t("%@, charged automatically. Cancel anytime."), price)
  }

  /// Naming the trial's length beats "Start free trial": nobody has to hunt for what they agree to.
  private var buyTitle: String {
    guard let plan = subscription.plan else { return store.t("Continue") }
    if plan.trialDays > 0 { return String(format: store.t("Start %@-day free trial"), "\(plan.trialDays)") }
    return store.t("Continue") + "  →"
  }

  /// Signing out here clears this iPhone, as Settings' Log out does; the account keeps everything.
  private func signOut() {
    Task { @MainActor in
      await account.signOut()
      await subscription.identify(nil)
      store.deleteAccount()
    }
  }
}

/// A reason to subscribe: a crown (JournalBlock's, in the app's emerald), a bold lead, then the plain detail on the same line.
private struct Benefit: View {
  let lead: String
  let detail: String
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "crown.fill").font(.system(size: 17))
        .foregroundStyle(LinearGradient(colors: [JourneyColor.signal.opacity(0.75), JourneyColor.signal], startPoint: .top, endPoint: .bottom))
        .frame(width: 24, alignment: .leading).padding(.top, 1).accessibilityHidden(true)
      (Text(lead + ": ").font(.app(.body, weight: .semibold)).foregroundColor(JourneyColor.text)
       + Text(detail).font(.app(.body)).foregroundColor(JourneyColor.secondary))
        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }.accessibilityElement(children: .combine)
  }
}

/// Their time at the gym, two ways, from their own answers (docs/ONBOARDING-V8-PLAN.md): today the
/// workout and then the red minutes scrolling runs past their rests; with GymBlock only the workout,
/// a shorter bar. Never a claim that the rests become lifting.
private struct TwoWays: View {
  let time: TimeBack
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    let gym = time.gym ?? 60, lost = Double(time.shownLost)
    VStack(alignment: .leading, spacing: 9) {
      // The darker shades keep the white labels at AA (5.3:1 and 5.7:1; the plain ones were 3.6 and 4.4).
      bar(store.t("Today"), JourneyColor.secondary, [
        (gym - lost, JourneyColor.signalText, "", false),
        (lost, JourneyColor.dangerText, String(format: store.t("%@ min"), "\(time.shownLost)"), true),
      ])
      bar(store.t("With GymBlock"), JourneyColor.text, [
        (gym - lost, JourneyColor.signalText, store.aboutLine(time.workout), false),
        (lost, Color.clear, "", false),
      ])
      // Just the two bars (20 Oct 2026, at the user's request): no "Your time at the gym" or "From your answers" lines.
    }
    .accessibilityElement(children: .ignore).accessibilityIdentifier("paywall.twoWays")
    .accessibilityLabel([String(format: store.t("Your time at the gym: %@"), store.gymWords(gym)),
                         store.t("Today") + ": " + String(format: store.t("%@ min on your phone"), "\(time.shownLost)"),
                         store.t("With GymBlock") + ": " + store.aboutLine(time.workout)].joined(separator: ". "))
  }
  /// A labelled bar of parts: minutes, fill, the words inside, and whether it's the red one. The red
  /// part says it inside itself, a phone and the minutes (20 Oct 2026, at the user's request: no line
  /// of its own under the bar); at large text the label sits above the bar instead of in a 102-pt column.
  @ViewBuilder private func bar(_ label: String, _ color: Color, _ parts: [(Double, Color, String, Bool)]) -> some View {
    let total = max(1, parts.reduce(0) { $0 + max(0, $1.0) })
    let title = Text(label).font(.app(.subheadline, weight: .semibold)).foregroundStyle(color)
    if typeSize >= .xxLarge {
      VStack(alignment: .leading, spacing: 4) { title; strip(parts, total: total) }
    } else {
      HStack(spacing: 10) {
        title.frame(width: 102, alignment: .leading).lineLimit(1).minimumScaleFactor(0.7)
        strip(parts, total: total)
      }
    }
  }
  private func strip(_ parts: [(Double, Color, String, Bool)], total: Double) -> some View {
    GeometryReader { g in
      let usable = g.size.width - 2 * CGFloat(parts.count - 1)
      HStack(spacing: 2) {
        ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
          if part.0 > 0 {
            let width = max(2, usable * part.0 / total)
            ZStack(alignment: .leading) {
              part.1
              // Words only where they fit. The red part: a phone and the minutes, the phone alone when
              // that's too wide, nothing when even the phone isn't.
              if part.3 {
                let words = Self.fits(part.2, in: width - Self.phone)
                if words || width >= Self.phone + 14 {
                  HStack(spacing: 4) {
                    Image(systemName: "iphone").font(.system(size: 11, weight: .semibold))
                    if words { Text(part.2).font(.app(.caption2, weight: .semibold)).lineLimit(1) }
                  }.foregroundStyle(Color.white).padding(.leading, 7)
                }
              } else if Self.fits(part.2, in: width) {
                Text(part.2).font(.app(.caption2, weight: .semibold)).lineLimit(1).foregroundStyle(Color.white).padding(.leading, 8)
              }
            }.frame(width: width)
          }
        }
      }
    }.frame(height: 28).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
  }
  /// The phone glyph and its gap, beside the red part's minutes.
  private static let phone: CGFloat = 14
  /// Whether a bar label fits in a part this wide, with its padding.
  private static func fits(_ text: String, in width: CGFloat) -> Bool {
    guard !text.isEmpty else { return true }
    let font = AppFont.uiFont(size: UIFontMetrics(forTextStyle: .caption2).scaledValue(for: 11), weight: .semibold) ?? .preferredFont(forTextStyle: .caption2)
    return (text as NSString).size(withAttributes: [.font: font]).width + 16 <= width
  }
}

/// One plan, as a card beside the other: period, a check, the price, the yearly anchor struck
/// through, and how it's billed. The saving overhangs the top edge like a sticker.
private struct PricingCard: View {
  let plan: GymSubscription.Plan
  let selected: Bool
  /// The square's side, from the page width; nil at accessibility sizes, where the card grows instead.
  var side: CGFloat? = nil
  let action: () -> Void
  @EnvironmentObject private var store: GymStore
  private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }
  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .firstTextBaseline) {
          Text(store.t(plan.yearly ? "Yearly" : "Monthly")).font(.app(.subheadline, weight: .semibold))
            .textCase(.uppercase).tracking(0.4).lineLimit(1).minimumScaleFactor(0.6)
          Spacer(minLength: 4)
          Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 17))
            .symbolRenderingMode(.palette)
            .foregroundStyle(selected ? JourneyColor.onAccent : JourneyColor.ink(0.25), selected ? JourneyColor.signal : JourneyColor.ink(0.25))
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
            .accessibilityHidden(true)
        }
        Spacer(minLength: 4)
        Text(plan.price).font(.app(size: 25, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
        // Reserved when absent, so both prices sit on the same line.
        Text(plan.anchor ?? " ").font(.app(.footnote)).foregroundStyle(JourneyColor.tertiary)
          .strikethrough(plan.anchor != nil, color: JourneyColor.tertiary).lineLimit(1).minimumScaleFactor(0.6).padding(.top, 2)
        Spacer(minLength: 4)
        Text(footnote).font(.app(.caption)).foregroundStyle(JourneyColor.secondary).fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(JourneyColor.text)
      .padding(15).frame(maxWidth: .infinity, alignment: .topLeading)
      // Square: as tall as the card is wide (20 Oct 2026; a 148-pt minimum left them wider than tall).
      .frame(minHeight: side == nil ? 148 : nil, alignment: .topLeading)
      .frame(height: side, alignment: .topLeading)
      .contentShape(shape)
    }
    .buttonStyle(JourneyPressStyle())
    .journeyGlass(shape, tint: selected ? JourneyColor.signal.opacity(0.10) : nil, interactive: true)
    .overlay(shape.strokeBorder(selected ? JourneyColor.signal.opacity(0.6) : JourneyColor.hairline, lineWidth: selected ? 1.8 : 1).allowsHitTesting(false))
    .overlay(alignment: .top) {
      if let savings = plan.savings {
        Text(String(format: store.t("%@%% OFF"), "\(savings)")).font(.app(.caption2, weight: .bold)).tracking(0.3)
          .foregroundStyle(JourneyColor.onAccent).padding(.horizontal, 9).padding(.vertical, 4)
          .background(Capsule().fill(JourneyColor.signal)).offset(y: -9)
          .accessibilityIdentifier("plan.savings")
      }
    }
    .animation(JourneyMotion.gentle, value: selected)
    .accessibilityIdentifier("plan." + (plan.yearly ? "yearly" : "monthly")).accessibilityAddTraits(selected ? .isSelected : [])
  }
  private var footnote: String {
    store.t(plan.trialDays > 0 ? (plan.yearly ? "Billed yearly after free trial." : "Billed monthly after free trial.")
      : (plan.yearly ? "Billed yearly." : "Billed monthly."))
  }
}

/// A pricing card's footprint while the store answers.
private struct PricingCardPlaceholder: View {
  var side: CGFloat? = nil
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
    VStack(alignment: .leading, spacing: 0) {
      Capsule().fill(JourneyColor.ink(0.08)).frame(width: 58, height: 12)
      Spacer(minLength: 4)
      RoundedRectangle(cornerRadius: 6).fill(JourneyColor.ink(0.08)).frame(width: 96, height: 24)
      Spacer(minLength: 4)
      Capsule().fill(JourneyColor.ink(0.08)).frame(width: 86, height: 9)
    }
    .padding(15).frame(maxWidth: .infinity, alignment: .topLeading)
    .frame(minHeight: side == nil ? 148 : nil, alignment: .topLeading)
    .frame(height: side, alignment: .topLeading)
    .journeyGlass(shape)
    .accessibilityHidden(true)
  }
}
