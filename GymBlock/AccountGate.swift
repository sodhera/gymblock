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
  @State private var reminds = false

  var body: some View {
    ZStack {
      DotGrid()
      VStack(spacing: 0) {
        GeometryReader { geo in
          ScrollView {
            VStack(alignment: .leading, spacing: 0) {
              HStack(spacing: 8) {
                BrandMark(size: 17)
                Text("GymBlock Pro").font(.app(.subheadline, weight: .semibold)).foregroundStyle(JourneyColor.text)
              }.accessibilityElement(children: .combine)
              Text(headline)
                .font(.app(size: JourneyLayout.compact ? 27 : 33, weight: .bold)).tracking(-0.6).foregroundStyle(JourneyColor.text)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 10)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
              Spacer(minLength: 18).frame(maxHeight: 26)
              if time.outcome == .full {
                TwoWays(time: time)
                Spacer(minLength: 18).frame(maxHeight: 24)
              }
              benefits
              if let plan = subscription.plan, plan.trialDays > 0 {
                TrialTimeline(days: plan.trialDays, reminds: reminds).padding(.top, 22)
              }
              Spacer(minLength: 20).frame(maxHeight: 40)
              plans
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
            .padding(.horizontal, 28).padding(.top, 36)
            .frame(minHeight: geo.size.height, alignment: .top)
          }.scrollIndicators(.hidden)
        }
        if !typeSize.isAccessibilitySize { footer }
      }
    }
    .foregroundStyle(JourneyColor.text)
    .animation(JourneyMotion.gentle, value: subscription.plans)
    .task { await subscription.load() }
    // Day 5's reminder is a local notification, so it's only promised when notifications are allowed.
    .task { reminds = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .authorized }
    .track(screen: "paywall")
  }

  // MARK: Sections

  private var time: TimeBack { TimeBack(store.profile.baseline ?? RoutineBaseline(), restSeconds: store.profile.restSeconds) }
  /// The change, sold in their own numbers (docs/ONBOARDING-V8-PLAN.md): the minutes back, never a
  /// body prediction. Rarely, or a scroll that fits the rest: every rest on time.
  private var headline: String {
    let name = store.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
    let time = self.time
    func named(_ withName: String, _ without: String, _ args: CVarArg...) -> String {
      name.isEmpty ? String(format: store.t(without), arguments: args) : String(format: store.t(withName), arguments: [name] + args)
    }
    switch time.outcome {
    case .full:
      return time.lostIsAnHour ? named("%@, get your hour back.", "Get your hour back.")
        : named("%@, get your %@ back.", "Get your %@ back.", String(format: store.t("%@ minutes"), "\(time.shownLost)"))
    case .unfit where (time.lostPerRest ?? 0) > 0:
      return named("%@, get %@ back every rest.", "Get %@ back every rest.", store.minutesWords(time.lostPerRest ?? 0))
    default:
      return named("%@, keep every rest on time.", "Keep every rest on time.")
    }
  }
  private var benefits: some View {
    VStack(alignment: .leading, spacing: 11) {
      // Short, plain words: one promise per line, readable at a glance.
      Benefit(text: store.t("Apps locked from your first set to your last"))
      Benefit(text: store.t("A buzz the moment rest is up"))
      Benefit(text: store.t("Every set saved, and what to beat next time"))
    }.accessibilityIdentifier("journey.recap")
  }

  @ViewBuilder private var plans: some View {
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
      planCards
    }
  }
  private var planCards: some View {
    VStack(spacing: 10) {
      HStack(alignment: .top, spacing: 10) {
        if subscription.plans.isEmpty {
          // Placeholders hold the cards' exact footprint, so nothing jumps when prices land.
          PricingCardPlaceholder(); PricingCardPlaceholder()
        } else {
          ForEach(subscription.plans) { plan in
            PricingCard(plan: plan, selected: subscription.selected == plan.id) {
              withAnimation(JourneyMotion.gentle) { subscription.selected = plan.id }
              JourneyHaptic.play(.selection, store.profile)
              Analytics.tap("plan." + (plan.yearly ? "yearly" : "monthly"))
            }
          }
        }
      }.padding(.top, 9)  // Room for the badge overhanging the yearly card.
      Text(terms).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
        .multilineTextAlignment(.center).frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("subscription.terms")
      if subscription.plan?.trialDays ?? 0 > 0 {
        Text(store.t("No payment due today. Cancel anytime.")).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
          .frame(maxWidth: .infinity)
      }
    }
  }

  private var footer: some View {
    // The same footprint as every onboarding page's actions: the button, then a 44-pt row.
    VStack(spacing: 4) {
      JourneyButton(title: buyTitle, symbol: nil, id: "subscription.buy",
                    enabled: subscription.plan != nil && !subscription.busy, loading: subscription.busy && subscription.plan != nil) {
        Task { await subscription.buy() }
      }
      // Price and period are on the cards; Restore and working Terms/Privacy links are required
      // on a subscription paywall (App Review 3.1.1, 3.1.2).
      HStack(spacing: 16) {
        Button(store.t("Restore")) { Task { await subscription.restore() } }.accessibilityIdentifier("subscription.restore")
        Link(store.t("Terms"), destination: AppConfig.termsURL)
        Link(store.t("Privacy"), destination: AppConfig.privacyURL)
        // The only way off a wall when signed in with the wrong account.
        if account.user != nil {
          Button(store.t("Sign out")) { signOut() }.accessibilityIdentifier("subscription.signOut")
        }
      }
      .font(.app(.footnote)).foregroundStyle(JourneyColor.secondary).buttonStyle(.plain)
      .frame(minHeight: 44)
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

/// One promise: an emerald check and a plain line.
private struct Benefit: View {
  let text: String
  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).symbolRenderingMode(.palette)
        .foregroundStyle(JourneyColor.onAccent, JourneyColor.signal).accessibilityHidden(true)
      Text(text).font(.app(.body)).foregroundStyle(JourneyColor.text).fixedSize(horizontal: false, vertical: true)
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
  var body: some View {
    let gym = time.gym ?? 60, lost = time.lost ?? 0
    VStack(alignment: .leading, spacing: 9) {
      Text(String(format: store.t("Your time at the gym: %@"), store.gymWords(gym)))
        .font(.app(.footnote)).foregroundStyle(JourneyColor.secondary)
      bar(store.t("Today"), JourneyColor.secondary, [
        (gym - lost, JourneyColor.signal, ""),
        (lost, JourneyColor.danger, String(format: store.t("%@ min scrolling"), "\(time.shownLost)")),
      ])
      bar(store.t("With GymBlock"), JourneyColor.text, [
        (gym - lost, JourneyColor.signal, store.aboutWords(time.workout).prefix(1).uppercased() + store.aboutWords(time.workout).dropFirst()),
        (lost, Color.clear, ""),
      ])
      Text(String(format: store.t("From your answers. About %@ hours back a month."), "\(time.monthHours)"))
        .font(.app(.caption)).foregroundStyle(JourneyColor.secondary).padding(.top, 2)
    }.accessibilityElement(children: .combine).accessibilityIdentifier("paywall.twoWays")
  }
  private func bar(_ label: String, _ color: Color, _ parts: [(Double, Color, String)]) -> some View {
    HStack(spacing: 10) {
      Text(label).font(.app(.subheadline, weight: .semibold)).foregroundStyle(color).frame(width: 102, alignment: .leading)
        .lineLimit(1).minimumScaleFactor(0.7)
      GeometryReader { g in
        let total = max(1, parts.reduce(0) { $0 + max(0, $1.0) })
        HStack(spacing: 2) {
          ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
            if part.0 > 0 {
              ZStack(alignment: .leading) {
                part.1
                Text(part.2).font(.app(.caption2, weight: .semibold)).lineLimit(1)
                  .foregroundStyle(part.1 == JourneyColor.danger || part.1 == JourneyColor.signal ? Color.white : JourneyColor.text.opacity(0.8)).padding(.leading, 8)
              }.frame(width: max(2, (g.size.width - 2 * CGFloat(parts.count - 1)) * part.0 / total))
            }
          }
        }
      }.frame(height: 28).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
  }
}

/// Today, the reminder, the day billing starts: nobody has to hunt for what they agree to.
private struct TrialTimeline: View {
  let days: Int
  let reminds: Bool
  @EnvironmentObject private var store: GymStore
  var body: some View {
    let steps: [(String, String, Bool)] = [(store.t("Today"), store.t("Full access, $0"), true)]
      + (reminds && days > 2 ? [(String(format: store.t("Day %@"), "\(days - 2)"), store.t("We remind you"), true)] : [])
      + [(String(format: store.t("Day %@"), "\(days)"), store.t("Plan starts"), false)]
    ZStack(alignment: .top) {
      GeometryReader { g in
        Capsule().fill(JourneyColor.ink(0.14)).frame(height: 2).offset(y: 5)
        Capsule().fill(JourneyColor.signal).frame(width: g.size.width * (steps.count == 3 ? 0.5 : 0.08), height: 2).offset(y: 5)
      }.frame(height: 12).padding(.horizontal, 6)
      HStack(alignment: .top) {
        ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
          let align: HorizontalAlignment = i == 0 ? .leading : i == steps.count - 1 ? .trailing : .center
          VStack(alignment: align, spacing: 3) {
            Circle().fill(step.2 ? JourneyColor.signal : JourneyColor.stage).frame(width: 12, height: 12)
              .overlay(Circle().strokeBorder(step.2 ? JourneyColor.signal : JourneyColor.ink(0.25), lineWidth: 2))
            Text(step.0).font(.app(.footnote, weight: .semibold)).foregroundStyle(JourneyColor.text).padding(.top, 3)
            Text(step.1).font(.app(.caption)).foregroundStyle(JourneyColor.secondary)
          }
          if i < steps.count - 1 { Spacer(minLength: 0) }
        }
      }
    }.accessibilityElement(children: .combine).accessibilityIdentifier("paywall.timeline")
  }
}

/// One plan, as a card beside the other: the period, the price a month (large), what's billed and
/// how often, and the trial or saving as a badge on the edge.
private struct PricingCard: View {
  let plan: GymSubscription.Plan
  let selected: Bool
  let action: () -> Void
  @EnvironmentObject private var store: GymStore
  private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }
  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 4) {
        Text(store.t(plan.yearly ? "Yearly" : "Monthly")).font(.app(.subheadline, weight: .semibold))
          .foregroundStyle(selected ? JourneyColor.text : JourneyColor.secondary)
        (Text(plan.perMonth ?? plan.price).font(.app(size: 26, weight: .bold))
         + Text("/" + store.t("mo")).font(.app(.subheadline)).foregroundColor(JourneyColor.secondary))
          .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5).padding(.top, 2)
        Text(footnote).font(.app(.caption)).foregroundStyle(JourneyColor.secondary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(JourneyColor.text)
      .padding(16).frame(maxWidth: .infinity, alignment: .topLeading)
      .frame(minHeight: 104, maxHeight: .infinity, alignment: .topLeading)
      .contentShape(shape)
    }
    .buttonStyle(JourneyPressStyle())
    .background(shape.fill(selected ? Color.white : .clear))
    .journeyGlass(shape, interactive: true)
    .overlay(shape.strokeBorder(selected ? JourneyColor.text : JourneyColor.hairline, lineWidth: selected ? 2 : 1).allowsHitTesting(false))
    .overlay(alignment: .topTrailing) {
      if let badge {
        Text(badge).font(.app(.caption2, weight: .bold))
          .foregroundStyle(JourneyColor.onAccent).padding(.horizontal, 9).padding(.vertical, 4)
          .background(Capsule().fill(JourneyColor.signal)).offset(x: -12, y: -10)
          .accessibilityIdentifier("plan.savings")
      }
    }
    .animation(JourneyMotion.gentle, value: selected)
    .accessibilityIdentifier("plan." + (plan.yearly ? "yearly" : "monthly")).accessibilityAddTraits(selected ? .isSelected : [])
  }
  private var badge: String? {
    if plan.trialDays > 0 { return String(format: store.t("%@ days free"), "\(plan.trialDays)") }
    return plan.savings.map { String(format: store.t("%@%% OFF"), "\($0)") }
  }
  private var footnote: String {
    plan.yearly ? String(format: store.t("%@ billed yearly"), plan.price) : store.t("Billed monthly")
  }
}

/// A pricing card's footprint while the store answers.
private struct PricingCardPlaceholder: View {
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
    VStack(alignment: .leading, spacing: 0) {
      Capsule().fill(JourneyColor.ink(0.08)).frame(width: 58, height: 12)
      Spacer(minLength: 4)
      RoundedRectangle(cornerRadius: 6).fill(JourneyColor.ink(0.08)).frame(width: 96, height: 24)
      Spacer(minLength: 4)
      Capsule().fill(JourneyColor.ink(0.08)).frame(width: 86, height: 9)
    }
    .padding(16).frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
    .journeyGlass(shape)
    .accessibilityHidden(true)
  }
}
