import RevenueCat
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
/// it. The app's own page, laid out as Cal AI's (1 Nov 2026, at the user's request): the product at
/// the top fading into the page (the phone logging a set, then the shield landing on TikTok), "Start
/// your 7-day FREE trial to continue", the plans stacked as rows with the yearly first under a
/// "7 DAYS FREE" strip, one Continue, the selected plan's terms under it, and Terms, Privacy, Restore
/// and Sign out. A wall by design: subscribing, restoring or signing out are the ways off it (Debug
/// builds with no product configured get a labelled skip, never Release). Every price comes from the store.
struct PaywallView: View {
  @ObservedObject var subscription: GymSubscription
  let skip: () -> Void
  /// Shown as a page of onboarding (under its top bar, with its Back and dots; 1 Nov 2026), or as
  /// the root's gate for an onboarded account without Pro.
  var inOnboarding = false
  /// False for onboarding's hidden warm-up copy, so only the price page they see counts as a view.
  var tracked = true
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var account: Account
  @Environment(\.dynamicTypeSize) private var typeSize
  /// The terms keep two lines' height, so a plan with a trial and one without never move the page.
  @ScaledMetric(relativeTo: .footnote) private var termsHeight: CGFloat = 48
  /// Which card is in the middle, counted without end so the row loops (…2, 0, 1, 2, 0…); the
  /// review shown is this modulo the count (1 Nov 2026, at the user's request).
  @State private var position = 0
  private var review: Int { ((position % Self.reviews.count) + Self.reviews.count) % Self.reviews.count }
  /// The review row's drag, while a finger is on it.
  @State private var drag: CGFloat = 0
  /// The carousel turns by itself every few seconds; only a swipe of theirs ticks.
  @State private var autoTurn = false

  var body: some View {
    ZStack {
      // In onboarding the stage behind the whole flow is already there; a second one, starting under the
      // top bar, drew a visible seam where it began (1 Nov 2026).
      if !inOnboarding { DotGrid() }
      VStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 0) {
            // The headline, the reviews, then the plans (1 Nov 2026, at the user's request: no logo; the
            // version with it is the git tag paywall-checkpoint-1).
            Text(headlineText)
              .font(.app(size: 28, weight: .bold)).tracking(-0.3).foregroundStyle(JourneyColor.text)
              .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
              .padding(.horizontal, 28).padding(.top, inOnboarding ? 44 : 32)
              .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
            // More air between the three parts (1 Nov 2026, at the user's request).
            reviews.padding(.top, 34)
            plans.padding(.top, 34).padding(.horizontal, 24)
            if typeSize.isAccessibilitySize { footer.padding(.top, 16) }
            // As tall as the fade above Continue, so scrolled to the end the last plan sits clear of it
            // (1 Nov 2026: Weekly was never seen whole).
            Color.clear.frame(height: 80)
          }
        }.scrollIndicators(.hidden)
        // No bar at the top (1 Nov 2026, at the user's request): in onboarding the page runs up under
        // the Back button, and whatever scrolls up there fades out softly instead of meeting an edge.
        .mask {
          VStack(spacing: 0) {
            // Content is whole from where the bar used to end (44 pt) and fades out above it, behind
            // the Back button.
            Color.clear.frame(height: inOnboarding ? 20 : 0)
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: 24)
            Color.black
          }
        }
        if !typeSize.isAccessibilitySize { footer }
      }
    }
    .foregroundStyle(JourneyColor.text)
    .animation(JourneyMotion.gentle, value: subscription.plans)
    .task { await subscription.load() }
    // What Restore or a purchase found, when it didn't open the app: said, never silent (a silent
    // Restore reads as broken to App Review). Before any plan loads, the plans' slot says it instead.
    .alert(store.t("GymBlock Pro"), isPresented: Binding(get: { subscription.message != nil && !subscription.plans.isEmpty },
                                                         set: { if !$0 { subscription.message = nil } })) {
      Button(store.t("OK"), role: .cancel) { JourneyHaptic.pressLight() }
    } message: { Text(store.t(subscription.message ?? "")) }
    .onAppear { if tracked { Analytics.enter("paywall") } }
    .onDisappear { if tracked { Analytics.leave("paywall") } }
  }

  // MARK: Reviews

  /// Reviews, on a carousel with its own dots: the user's own, from their App Store reviews (copied
  /// from the dashboard paywall on 1 Nov 2026). Add to the list, never invent one.
  static let reviews: [PaywallReview] = [
    PaywallReview(title: "Actually helps me focus at the gym", text: "I used to waste half my rest time scrolling. Now I open this, log my sets, and get back to lifting. My workouts are shorter and I get more done.", name: "Sirish Joshi"),
    PaywallReview(title: "Best app for gym goers", text: "I spend less time on my phone and more on my workouts thanks to this app.", name: "Manjil Gurung"),
    PaywallReview(title: "Easy to use and it works", text: "This app is super easy to use… I stay focused during my sets, and I finish my workouts about 15 minutes faster.", name: "David Benavidez"),
  ]
  private var reviews: some View {
    VStack(spacing: 8) {
      // The card in the middle, the ones before and after peeking in at the sides (1 Nov 2026, at the
      // user's request). A row slid by hand, not a scroll view: a scroll view's turn also scrolled the
      // page it sits in, so the paywall opened at its bottom.
      GeometryReader { g in
        let inset: CGFloat = 26, gap: CGFloat = 12
        let card = g.size.width - inset * 2
        // The middle card and two on each side, each placed by its distance from the middle, so the row
        // never runs out in either direction.
        ZStack(alignment: .leading) {
          ForEach((position - 2)...(position + 2), id: \.self) { k in
            ReviewCard(review: Self.reviews[((k % Self.reviews.count) + Self.reviews.count) % Self.reviews.count])
              .frame(width: card)
              .offset(x: inset + CGFloat(k - position) * (card + gap) + drag)
          }
        }
        .frame(width: g.size.width, height: g.size.height, alignment: .leading)
        .contentShape(Rectangle())
        // Alongside the page's scroll, and only sideways: a swipe up or down on the reviews scrolls the page.
        .simultaneousGesture(DragGesture(minimumDistance: 12)
          .onChanged { v in if abs(v.translation.width) > abs(v.translation.height) { drag = v.translation.width } }
          .onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) else { withAnimation(.smooth(duration: 0.3)) { drag = 0 }; return }
            let move = v.predictedEndTranslation.width
            var i = position
            if move < -card / 3 { i += 1 } else if move > card / 3 { i -= 1 }
            withAnimation(.smooth(duration: 0.35)) { position = i; drag = 0 }
          })
      }
      .frame(height: typeSize.isAccessibilitySize ? 300 : (JourneyLayout.compact ? 140 : 148))
      .onChange(of: position) { _, _ in if autoTurn { autoTurn = false } else { JourneyHaptic.tick() } }
      // Turns every 4 seconds; a swipe restarts the wait.
      .task(id: position) {
        try? await Task.sleep(for: .seconds(4))
        guard !Task.isCancelled, Self.reviews.count > 1 else { return }
        autoTurn = true
        withAnimation(.smooth(duration: 0.5)) { position += 1 }
      }
      HStack(spacing: 7) {
        ForEach(Self.reviews.indices, id: \.self) { i in
          Circle().fill(i == review ? JourneyColor.text : JourneyColor.ink(0.2)).frame(width: 6, height: 6)
        }
      }.animation(.smooth(duration: 0.3), value: review).accessibilityHidden(true)
    }
    .accessibilityElement(children: .contain)
  }

  /// The trial's length when the yearly has one they can still take; otherwise the promise.
  /// The headline with its key words in emerald, the app's colour: "FREE", or "get back".
  private var headlineText: AttributedString {
    var text = AttributedString(headline)
    for word in [store.t("FREE"), store.t("get back")] {
      if let r = text.range(of: word) { text[r].foregroundColor = JourneyColor.signalText }
    }
    return text
  }
  /// The selected plan's offer: its free trial when it has one they can still take, otherwise the
  /// unlock (1 Nov 2026, at the user's request).
  private var headline: String {
    if let days = subscription.plan?.trialDays, days > 0 {
      return String(format: store.t("Start your %@-day FREE trial to continue"), "\(days)")
    }
    return store.t("Unlock GymBlock to get back your gym time")
  }


  // MARK: Plans

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
        JourneyTextButton(title: "Continue without subscribing · Debug", id: "subscription.debugSkip", action: skip).padding(.top, 8)
      #endif
    } else {
      VStack(spacing: 10) {
        if subscription.plans.isEmpty {
          ForEach(0..<3, id: \.self) { _ in PlanRowPlaceholder() }
        } else {
          // The yearly first, as Cal AI leads with theirs, then monthly and weekly.
          ForEach(subscription.plans.sorted { Self.rank($0) < Self.rank($1) }) { plan in
            PlanRow(plan: plan, selected: subscription.selected == plan.id) {
              withAnimation(JourneyMotion.gentle) { subscription.selected = plan.id }
              JourneyHaptic.play(.selection, store.profile)
              Analytics.tap("plan." + plan.period.rawValue)
            }
          }
        }
      }
    }
  }
  private static func rank(_ p: GymSubscription.Plan) -> Int { p.period == .yearly ? 0 : p.period == .monthly ? 1 : 2 }

  // MARK: Footer

  private var footer: some View {
    VStack(spacing: 6) {
      JourneyButton(title: store.t("Continue"), symbol: nil, id: "subscription.buy",
                    enabled: subscription.plan != nil && !subscription.busy, loading: subscription.busy && subscription.plan != nil) {
        Task { await subscription.buy() }
      }
      // What's charged and that it renews, right under the button that charges (App Review 3.1.2).
      if !subscription.plans.isEmpty {
        Text(terms).font(.app(size: 12, relativeTo: .footnote)).foregroundStyle(JourneyColor.secondary)
          .multilineTextAlignment(.center).lineLimit(typeSize.isAccessibilitySize ? nil : 3).minimumScaleFactor(0.8)
          .frame(maxWidth: .infinity).frame(minHeight: typeSize.isAccessibilitySize ? nil : termsHeight, alignment: .top)
          .padding(.top, 6).padding(.horizontal, 8)
          .accessibilityIdentifier("subscription.terms")
      }
      // Working Terms and Privacy links and Restore are required on a subscription paywall (App
      // Review 3.1.1, 3.1.2); each link is a full 44-pt target.
      HStack(spacing: 2) {
        Link(destination: AppConfig.termsURL) { footerLink(store.t("Terms")) }
        Link(destination: AppConfig.privacyURL) { footerLink(store.t("Privacy")) }
        Button { Task { await subscription.restore() } } label: { footerLink(store.t("Restore")) }.accessibilityIdentifier("subscription.restore")
        // The only way off a wall when signed in with the wrong account.
        if account.user != nil {
          Button { signOut() } label: { footerLink(store.t("Sign out")) }.accessibilityIdentifier("subscription.signOut")
        }
      }
      .font(.app(size: 12, relativeTo: .footnote)).foregroundStyle(JourneyColor.secondary).buttonStyle(.hapticPlain)
    }
    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 2)
    .background(alignment: .top) {
      // A short fade: the last plan shows above Continue, its lower edge fading into it (1 Nov 2026: at 72 pt
      // Weekly was barely visible).
      LinearGradient(stops: [.init(color: JourneyColor.stage.opacity(0), location: 0), .init(color: JourneyColor.stage.opacity(0.85), location: 0.7),
                             .init(color: JourneyColor.stage, location: 1)], startPoint: .top, endPoint: .bottom)
        .frame(height: 36).offset(y: -36).allowsHitTesting(false)
    }
  }
  private func footerLink(_ title: String) -> some View {
    Text(title).padding(.horizontal, 6).frame(minWidth: 44, minHeight: 32).contentShape(Rectangle())
  }

  /// The selected plan's terms: the trial's length, what is charged after it, and that it renews by
  /// itself unless cancelled (App Review 3.1.2(c)).
  private var terms: String {
    guard let plan = subscription.plan else { return store.t("Charged automatically. Cancel anytime.") }
    // Worded as Cal AI's (1 Nov 2026, at the user's request): the price, then how it's billed and that it
    // renews until cancelled.
    let per = store.t(plan.period == .yearly ? "year" : plan.period == .monthly ? "month" : "week")
    let billed = store.t(plan.period == .yearly ? "Billed annually and renews automatically unless canceled in the App Store."
                         : plan.period == .monthly ? "Billed monthly and renews automatically unless canceled in the App Store."
                         : "Billed weekly and renews automatically unless canceled in the App Store.")
    if plan.trialDays > 0 {
      return String(format: store.t("%@ days free, then %@ per %@."), "\(plan.trialDays)", plan.price, per) + "\n" + billed
    }
    return String(format: store.t("Just %@ per %@"), plan.price, per) + "\n" + billed
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

struct PaywallReview {
  let title: String
  let text: String
  let name: String
}

/// One review: the title, five stars, the words, the name in light grey, on a white card.
private struct ReviewCard: View {
  let review: PaywallReview
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(review.title).font(.app(size: 16, weight: .semibold, relativeTo: .headline)).foregroundStyle(JourneyColor.text).lineLimit(1).minimumScaleFactor(0.8)
      HStack(spacing: 3) {
        ForEach(0..<5, id: \.self) { _ in Image(systemName: "star.fill").font(.system(size: 13)).foregroundStyle(Color(red: 0.98, green: 0.66, blue: 0.15)) }
      }.accessibilityLabel("5 stars")
      Text(review.text).font(.app(size: 14, relativeTo: .subheadline)).foregroundStyle(JourneyColor.text).lineLimit(4).minimumScaleFactor(0.85)
        .fixedSize(horizontal: false, vertical: true)
      Text(review.name).font(.app(size: 12, relativeTo: .footnote)).foregroundStyle(JourneyColor.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.92)))
    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(JourneyColor.hairline, lineWidth: 1))
    .accessibilityElement(children: .combine)
  }
}

/// A plan as a row, as Cal AI's: a round check, the plan's line and what's billed under it, the price
/// a month (or week) on the right in grey. The yearly carries an ink strip on top ("7 DAYS FREE", or
/// its saving when there's no trial). The chosen row takes an ink edge.
private struct PlanRow: View {
  let plan: GymSubscription.Plan
  let selected: Bool
  let action: () -> Void
  @EnvironmentObject private var store: GymStore
  private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 16, style: .continuous) }
  var body: some View {
    Button(action: action) {
      VStack(spacing: 0) {
        if let strip {
          Text(strip).font(.app(size: 12, weight: .bold, relativeTo: .caption2)).tracking(0.6)
            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 6)
            .background(JourneyColor.signal)
            .accessibilityIdentifier("plan.savings")
        }
        HStack(spacing: 14) {
          ZStack {
            Circle().strokeBorder(selected ? JourneyColor.signal : JourneyColor.ink(0.25), lineWidth: 1.5)
            if selected {
              Circle().fill(JourneyColor.signal)
              Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
            }
          }.frame(width: 26, height: 26)
          VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.app(size: 18, weight: .semibold, relativeTo: .headline)).foregroundStyle(JourneyColor.text)
              .lineLimit(1).minimumScaleFactor(0.7)
            if let subtitle {
              Text(subtitle).font(.app(size: 14, relativeTo: .subheadline)).foregroundStyle(JourneyColor.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
          }
          Spacer(minLength: 8)
          Text(rate).font(.app(size: 14, relativeTo: .subheadline)).monospacedDigit().foregroundStyle(JourneyColor.secondary)
            .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 18).frame(minHeight: 72)
        // The rows not chosen fade back, as Cal AI's do (1 Nov 2026, at the user's request).
        .opacity(selected ? 1 : 0.6)
      }
      .contentShape(shape)
    }
    .buttonStyle(JourneyPressStyle())
    .background(shape.fill(Color.white.opacity(selected ? 0.95 : 0.6)))
    .clipShape(shape)
    // Emerald, the app's colour, marks the chosen plan (1 Nov 2026, at the user's request).
    .overlay(shape.strokeBorder(selected ? JourneyColor.signal : JourneyColor.hairline, lineWidth: selected ? 2 : 1).allowsHitTesting(false))
    .animation(JourneyMotion.gentle, value: selected)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("plan." + plan.period.rawValue).accessibilityAddTraits(selected ? .isSelected : [])
  }
  private var strip: String? {
    guard plan.yearly else { return nil }
    if plan.trialDays > 0 { return String(format: store.t("%@ DAYS FREE"), "\(plan.trialDays)") }
    return plan.savings.map { String(format: store.t("SAVE %@%%"), "\($0)") } ?? store.t("BEST VALUE")
  }
  private var title: String {
    switch plan.period {
    case .yearly:
      let free = plan.trialDays > 0
      if let save = plan.savings {
        return String(format: store.t(free ? "Start for free & save %@%%" : "Yearly · save %@%%"), "\(save)")
      }
      return store.t(free ? "Start for free" : "Yearly")
    case .monthly: return store.t("Monthly")
    case .weekly: return store.t("Weekly")
    }
  }
  private var subtitle: String? { plan.yearly ? String(format: store.t("%@ billed annually"), plan.price) : nil }
  private var rate: String {
    switch plan.period {
    case .yearly: return (plan.perMonth ?? plan.price) + "/" + store.t("mo")
    case .monthly: return plan.price + "/" + store.t("mo")
    case .weekly: return plan.price + "/" + store.t("wk")
    }
  }
}

/// A plan row's footprint while the store answers.
private struct PlanRowPlaceholder: View {
  var body: some View {
    let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
    HStack(spacing: 14) {
      Circle().fill(JourneyColor.ink(0.08)).frame(width: 26, height: 26)
      Capsule().fill(JourneyColor.ink(0.08)).frame(width: 120, height: 12)
      Spacer()
      Capsule().fill(JourneyColor.ink(0.08)).frame(width: 52, height: 10)
    }
    .padding(.horizontal, 18).frame(minHeight: 72)
    .background(shape.fill(Color.white.opacity(0.6)))
    .accessibilityHidden(true)
  }
}
