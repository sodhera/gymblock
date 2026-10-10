import SwiftUI

/// The screens around onboarding that aren't questions: the launch hold, the standalone sign-in,
/// the two account notices, and the offer. RootView decides which one shows; each is one idea on
/// the paper stage with its action in the thumb zone, like every onboarding page.

/// Shown while the saved session (and, for a subscriber, the entitlement) is being restored, so a
/// returning user never sees the welcome page or the offer flash first.
struct LaunchView: View {
  var body: some View {
    ZStack {
      DotGrid()
      BrandMark(size: 72)
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
            Text(store.t(message)).font(.body).foregroundStyle(JourneyColor.secondary)
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
              Text(store.t("Your workouts, back under your control."))
                .font(JourneyType.headline).tracking(-0.3).foregroundStyle(JourneyColor.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier("onboarding.question")
              Spacer(minLength: 24).frame(maxHeight: 52)
              benefits
              Spacer(minLength: 24).frame(maxHeight: 64)
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
    .track(screen: "paywall")
  }

  // MARK: Sections

  private var benefits: some View {
    VStack(alignment: .leading, spacing: 18) {
      // Short, plain words: one idea per line, readable at a glance.
      Benefit(lead: store.t("No distractions"), detail: store.t("Your apps stay locked while you work out."))
      Benefit(lead: store.t("Rest timer"), detail: store.t("Your phone buzzes when rest is over."))
      Benefit(lead: store.t("Track progress"), detail: store.t("Every set you do is saved."))
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
      Text(store.t("Select a plan that fits you")).font(.system(.subheadline, weight: .semibold))
        .frame(maxWidth: .infinity)
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
      // The same line for both plans; a trial's length and price are on its card and the button.
      Text(store.t("Change plans or cancel anytime.")).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
        .multilineTextAlignment(.center).frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("subscription.terms")
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
      .font(.footnote).foregroundStyle(JourneyColor.secondary).buttonStyle(.plain)
      .frame(minHeight: 44)
    }
    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 6)
    .background(alignment: .top) {
      LinearGradient(colors: [JourneyColor.stage.opacity(0), JourneyColor.stage], startPoint: .top, endPoint: .bottom)
        .frame(height: 28).offset(y: -28).allowsHitTesting(false)
    }
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
      (Text(lead + ": ").font(.system(.body, weight: .semibold)).foregroundColor(JourneyColor.text)
       + Text(detail).font(.body).foregroundColor(JourneyColor.secondary))
        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }.accessibilityElement(children: .combine)
  }
}

/// One plan, as a card beside the other: period, a check, the price, the yearly anchor struck
/// through, and how it's billed. The saving overhangs the top edge like a sticker.
private struct PricingCard: View {
  let plan: GymSubscription.Plan
  let selected: Bool
  let action: () -> Void
  @EnvironmentObject private var store: GymStore
  private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 20, style: .continuous) }
  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .firstTextBaseline) {
          Text(store.t(plan.yearly ? "Yearly" : "Monthly")).font(.system(.subheadline, weight: .semibold))
            .textCase(.uppercase).tracking(0.4).lineLimit(1).minimumScaleFactor(0.6)
          Spacer(minLength: 4)
          Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.system(size: 17))
            .symbolRenderingMode(.palette)
            .foregroundStyle(selected ? JourneyColor.onAccent : JourneyColor.ink(0.25), selected ? JourneyColor.signal : JourneyColor.ink(0.25))
            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
            .accessibilityHidden(true)
        }
        Spacer(minLength: 4)
        Text(plan.price).font(.system(size: 25, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
        // Reserved when absent, so both prices sit on the same line.
        Text(plan.anchor ?? " ").font(.footnote).foregroundStyle(JourneyColor.tertiary)
          .strikethrough(plan.anchor != nil, color: JourneyColor.tertiary).lineLimit(1).minimumScaleFactor(0.6).padding(.top, 2)
        Spacer(minLength: 4)
        if plan.trialDays > 0 {
          Text(String(format: store.t("%@ days free"), "\(plan.trialDays)")).font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(JourneyColor.signal).padding(.bottom, 2).accessibilityIdentifier("plan.trial")
        }
        Text(store.t(footnote)).font(.caption).foregroundStyle(JourneyColor.secondary).fixedSize(horizontal: false, vertical: true)
      }
      .foregroundStyle(JourneyColor.text)
      .padding(15).frame(maxWidth: .infinity, alignment: .topLeading)
      .frame(minHeight: 148, maxHeight: .infinity, alignment: .topLeading)
      .contentShape(shape)
    }
    .buttonStyle(JourneyPressStyle())
    .journeyGlass(shape, tint: selected ? JourneyColor.signal.opacity(0.10) : nil, interactive: true)
    .overlay(shape.strokeBorder(selected ? JourneyColor.signal.opacity(0.6) : JourneyColor.hairline, lineWidth: selected ? 1.8 : 1).allowsHitTesting(false))
    .overlay(alignment: .top) {
      if let savings = plan.savings {
        Text(String(format: store.t("%@%% OFF"), "\(savings)")).font(.system(.caption2, weight: .bold)).tracking(0.3)
          .foregroundStyle(JourneyColor.onAccent).padding(.horizontal, 9).padding(.vertical, 4)
          .background(Capsule().fill(JourneyColor.signal)).offset(y: -9)
          .accessibilityIdentifier("plan.savings")
      }
    }
    .animation(JourneyMotion.gentle, value: selected)
    .accessibilityIdentifier("plan." + (plan.yearly ? "yearly" : "monthly")).accessibilityAddTraits(selected ? .isSelected : [])
  }
  private var footnote: String {
    plan.trialDays > 0 ? (plan.yearly ? "Then billed yearly." : "Then billed monthly.")
      : (plan.yearly ? "Billed yearly." : "Billed monthly.")
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
    .padding(15).frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
    .journeyGlass(shape)
    .accessibilityHidden(true)
  }
}
