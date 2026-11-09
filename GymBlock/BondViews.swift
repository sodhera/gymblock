import SwiftUI

// GymBond's screens (8 Nov 2026, docs/GYMBOND-PLAN.md): the Profile section and its page, Home's
// friend lines under the week, and onboarding's code page. Paper, ink, glass; emerald stays the
// user's own signal, so a friend's trained days are ink.

// MARK: - Profile

/// GymBond on Profile: before there's a bond, one glass card like the blocking card ("Train with a
/// friend"); with bonds, the friends as cards (name, how their week is going, their seven dots),
/// each opening the GymBond page. Development runs with no account show nothing.
struct BondSection: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var bond = GymBond.shared
  var body: some View {
    if bond.live || bond.preview {
      if bond.friends.isEmpty {
        NavigationLink { BondView() } label: { BondInviteCard() }
          .buttonStyle(JourneyPressStyle()).accessibilityIdentifier("profile.bond")
      } else {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .firstTextBaseline) {
            PageLabel(text: "GymBond")
            Spacer(minLength: 8)
            NavigationLink { BondView() } label: {
              Text(store.t("Invite")).font(.app(.caption, weight: .semibold)).foregroundStyle(JourneyColor.signal)
                .frame(minHeight: 28).contentShape(Rectangle())
            }.tapHaptic().accessibilityIdentifier("profile.bond.invite")
          }
          ForEach(bond.friends) { friend in
            NavigationLink { BondView() } label: { BondFriendCard(friend: friend) }
              .buttonStyle(JourneyPressStyle()).accessibilityIdentifier("profile.bond." + friend.id.uuidString)
          }
        }
      }
    }
  }
}

/// "Train with a friend", on glass, in the blocking card's shape.
struct BondInviteCard: View {
  @EnvironmentObject private var store: GymStore
  var body: some View {
    HStack(spacing: 14) {
      HStack(spacing: 12) {
        Image(systemName: "person.2.fill").font(.system(size: 15, weight: .semibold)).foregroundStyle(JourneyColor.signal)
          .frame(width: 36, height: 36).background(Circle().fill(JourneyColor.signal.opacity(0.12))).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(store.t("Train with a friend")).font(.app(.body, weight: .medium)).foregroundStyle(JourneyColor.text)
          Text(store.t("Two weeks of Pro, for both of you.")).font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary)
        }
      }
      Spacer(minLength: 8)
      Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
    }
    .padding(18).frame(maxWidth: .infinity, alignment: .leading)
    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .journeyGlass(RoundedRectangle(cornerRadius: 20, style: .continuous), interactive: true)
    .accessibilityElement(children: .combine)
  }
}

/// A friend as a card, in the workout cards' shape: their name, how their week is going, their dots.
struct BondFriendCard: View {
  @EnvironmentObject private var store: GymStore
  let friend: GymBond.Friend
  var body: some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        Text(friend.name).font(.app(.title3, weight: .semibold)).foregroundStyle(JourneyColor.text).lineLimit(1)
        Text(store.bondWeekLine(friend)).font(.app(.subheadline)).monospacedDigit().foregroundStyle(JourneyColor.tertiary).lineLimit(1)
      }.frame(maxWidth: .infinity, alignment: .leading)
      BondDots(week: friend.week())
      Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(JourneyColor.tertiary).accessibilityHidden(true)
    }
    .padding(.horizontal, 20).padding(.vertical, 16)
    .journeySurface(cornerRadius: 20)
    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .accessibilityElement(children: .combine)
    .accessibilityLabel(friend.name + ", " + store.bondWeekLine(friend))
  }
}

/// A friend's week as seven dots, Monday first: ink where they trained (emerald is the user's own),
/// faint where they didn't, fainter still for the days to come. `slot` pads each dot to a wider
/// column, so smaller dots line up under Home's.
struct BondDots: View {
  let week: [Bool]
  var size: CGFloat = 9
  var spacing: CGFloat = 6
  var slot: CGFloat? = nil
  var body: some View {
    let today = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    HStack(spacing: spacing) {
      ForEach(0..<7, id: \.self) { d in
        let on = d < week.count && week[d]
        Circle().fill(on ? JourneyColor.ink(0.55) : JourneyColor.ink(d > today ? 0.05 : 0.12))
          .frame(width: size, height: size)
          .frame(width: slot ?? size, height: slot ?? size)
      }
    }.accessibilityHidden(true)
  }
}

extension GymStore {
  /// A friend's week in one short line: their streak once it's more than a week (the dots beside it
  /// show this week), else "2 this week", else "Nothing yet this week".
  func bondWeekLine(_ friend: GymBond.Friend) -> String {
    let n = friend.thisWeek(), streak = friend.streak()
    if streak > 1 { return "\(streak) " + t("week streak") }
    if n == 0 { return t("Nothing yet this week") }
    return "\(n) " + t("this week")
  }
}

// MARK: - Home

/// Under Home's week line: each friend's week as smaller ink dots in the same columns, with their
/// name, so the page shows who's showing up this week without a card. Two at most.
struct BondWeekLines: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var bond = GymBond.shared
  var body: some View {
    if !bond.friends.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(bond.friends.prefix(2)) { friend in
          HStack(spacing: 14) {
            BondDots(week: friend.week(), size: 6, spacing: 7, slot: 9)
            Text(friend.name).font(.app(.subheadline, weight: .medium)).foregroundStyle(JourneyColor.tertiary).lineLimit(1)
          }
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(friend.name + ", " + store.bondWeekLine(friend))
        }
      }.accessibilityIdentifier("home.bond")
    }
  }
}

// MARK: - The page

/// GymBond: your code (tap to copy, Share), a friend's code to join with, your friends with a nudge
/// each (one a day; a long press removes one), and what friends see. Reached from Profile.
struct BondView: View {
  @EnvironmentObject private var store: GymStore
  @EnvironmentObject private var subscription: GymSubscription
  @ObservedObject private var bond = GymBond.shared
  @State private var draft = ""
  @State private var status: String?
  @State private var good = false
  @State private var copied = false
  @State private var removing: GymBond.Friend?
  @State private var nudging: UUID?
  private var spanish: Bool { store.profile.language == "es" }
  var body: some View {
    ZStack {
      DotGrid()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text("GymBond").font(.app(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
            .accessibilityAddTraits(.isHeader)
          Text(store.t("Train with a friend. When they join with your code, you both get two weeks of GymBlock Pro."))
            .font(.app(.body)).foregroundStyle(JourneyColor.secondary).fixedSize(horizontal: false, vertical: true).padding(.top, 8)
          PageLabel(text: store.t("Your code")).padding(.top, 32)
          codeCard.padding(.top, 12)
          PageLabel(text: store.t("Have a code?")).padding(.top, 32)
          codeField.padding(.top, 12)
          if !bond.friends.isEmpty {
            PageLabel(text: store.t("Your friends")).padding(.top, 32)
            VStack(spacing: 12) { ForEach(bond.friends) { friendRow($0) } }.padding(.top, 12)
          }
          Text(store.t("Friends see your first name, your week and when you finish a workout. Nothing else."))
            .font(.app(.footnote)).foregroundStyle(JourneyColor.tertiary).fixedSize(horizontal: false, vertical: true).padding(.top, 32)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 40)
      }.scrollIndicators(.hidden).scrollDismissesKeyboard(.interactively)
    }
    .navigationBarTitleDisplayMode(.inline)
    .task { await bond.fetchCode(); await bond.refresh() }
    .confirmationDialog(String(format: store.t("Remove %@?"), removing?.name ?? ""),
                        isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
      Button(store.t("Remove"), role: .destructive) { JourneyHaptic.pressLight()
        if let friend = removing { Task { await bond.end(friend) } }
        removing = nil
      }
      Button(store.t("Cancel"), role: .cancel) { JourneyHaptic.pressLight() }
    } message: { Text(store.t("You stop seeing each other’s weeks. The two weeks of Pro stay.")) }
    .track(screen: "profile.bond", ["friends": bond.friends.count])
  }

  // MARK: Your code

  private var codeCard: some View {
    VStack(spacing: 16) {
      if let code = bond.code {
        Button {
          UIPasteboard.general.string = code
          copied = true
          JourneyHaptic.play(.success, store.profile)
          Analytics.tap("bond.copy")
          Task { try? await Task.sleep(for: .seconds(2)); copied = false }
        } label: {
          VStack(spacing: 6) {
            // The tracking adds its space after the last letter; nudged right so the code sits centred.
            Text(code).font(.app(size: 40, weight: .bold)).tracking(8).monospacedDigit().foregroundStyle(JourneyColor.text).padding(.leading, 8)
            Text(store.t(copied ? "Copied" : "Tap to copy")).font(.app(.footnote)).foregroundStyle(copied ? JourneyColor.signalText : JourneyColor.tertiary)
              .animation(.smooth(duration: 0.25), value: copied)
          }.frame(maxWidth: .infinity).contentShape(Rectangle())
        }.buttonStyle(.hapticPlain).accessibilityIdentifier("bond.code.copy")
          .accessibilityLabel(store.t("Your code") + ", " + code.map(String.init).joined(separator: " "))
        if let text = bond.shareText(spanish: spanish) { share(text) }
      } else if bond.live {
        ProgressView().tint(JourneyColor.secondary).frame(maxWidth: .infinity, minHeight: 60)
      } else {
        Text(store.t("Sign in to get your code.")).font(.app(.body)).foregroundStyle(JourneyColor.secondary)
          .frame(maxWidth: .infinity, minHeight: 60)
      }
    }.padding(18).frame(maxWidth: .infinity).journeySurface(cornerRadius: 20)
  }
  /// The share sheet, as the primary button.
  @ViewBuilder private func share(_ text: String) -> some View {
    let label = HStack(spacing: 8) {
      Image(systemName: "square.and.arrow.up").font(.system(.headline, weight: .semibold)).accessibilityHidden(true)
      Text(store.t("Share your code")).font(JourneyType.button).lineLimit(1).minimumScaleFactor(0.8)
    }.foregroundStyle(JourneyColor.onButton).frame(maxWidth: .infinity, minHeight: 22)
    let link = ShareLink(item: text) { label }
      .simultaneousGesture(TapGesture().onEnded { JourneyHaptic.press(); Analytics.tap("bond.share") })
      .accessibilityIdentifier("bond.share")
    if #available(iOS 26.0, *) {
      link.buttonStyle(.glassProminent).tint(JourneyColor.button).controlSize(.large).buttonBorderShape(.capsule)
    } else {
      ShareLink(item: text) { label.frame(minHeight: 50).background(Capsule().fill(JourneyColor.button)) }
        .buttonStyle(JourneyPressStyle()).accessibilityIdentifier("bond.share")
    }
  }

  // MARK: A friend's code

  private var canAdd: Bool { GymBond.normalize(draft).count == 6 && !bond.busy }
  private var codeField: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        TextField("", text: $draft, prompt: Text("ABC123").foregroundColor(JourneyColor.tertiary))
          .font(.app(.title3, weight: .semibold)).tracking(3).foregroundStyle(JourneyColor.text)
          .textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable).submitLabel(.join)
          .onSubmit(add).tint(JourneyColor.accent)
          .onChange(of: draft) { _, new in if new.count > 8 { draft = String(new.prefix(8)) } }
          .accessibilityIdentifier("bond.code.field")
        Button(action: add) {
          Text(store.t("Add")).font(.app(.body, weight: .semibold)).foregroundStyle(canAdd ? JourneyColor.signal : JourneyColor.tertiary)
            .frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.hapticPlain).disabled(!canAdd).accessibilityIdentifier("bond.code.add")
      }
      .padding(.horizontal, 18).frame(minHeight: 52)
      .journeyGlass(RoundedRectangle(cornerRadius: 18, style: .continuous))
      if let status {
        Text(status).font(.app(.footnote)).foregroundStyle(good ? JourneyColor.signalText : JourneyColor.secondary)
          .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4).accessibilityIdentifier("bond.code.status")
      }
    }
  }
  private func add() {
    guard canAdd else { return }
    Analytics.tap("bond.code.add")
    dismissKeyboard()
    Task { @MainActor in
      switch await bond.redeem(draft, from: "profile", t: store.t) {
      case .bonded(let name, _):
        good = true
        status = String(format: store.t("You’re bonded with %@."), name)
        draft = ""
        JourneyHaptic.play(.success, store.profile)
        await subscription.refresh()
      case .failed(let message):
        good = false
        status = message
      }
    }
  }

  // MARK: Friends

  private func friendRow(_ friend: GymBond.Friend) -> some View {
    HStack(alignment: .center, spacing: 14) {
      VStack(alignment: .leading, spacing: 3) {
        Text(friend.name).font(.app(.title3, weight: .semibold)).foregroundStyle(JourneyColor.text).lineLimit(1)
        Text(store.bondWeekLine(friend)).font(.app(.subheadline)).monospacedDigit().foregroundStyle(JourneyColor.tertiary).lineLimit(1)
        if let gift = giftLine(friend) {
          Text(gift).font(.app(.footnote)).foregroundStyle(JourneyColor.tertiary).fixedSize(horizontal: false, vertical: true)
        }
      }.frame(maxWidth: .infinity, alignment: .leading)
      VStack(alignment: .trailing, spacing: 6) {
        BondDots(week: friend.week())
        nudgeButton(friend)
      }
    }
    .padding(.horizontal, 20).padding(.vertical, 14)
    .journeySurface(cornerRadius: 20)
    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .contextMenu {
      Button(role: .destructive) { removing = friend } label: { Label(store.t("Remove"), systemImage: "person.badge.minus") }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(friend.name + ", " + store.bondWeekLine(friend))
  }
  private func nudgeButton(_ friend: GymBond.Friend) -> some View {
    let can = friend.canNudge() && nudging != friend.id && bond.live
    return Button {
      guard can else { return }
      Analytics.tap("bond.nudge")
      nudging = friend.id
      Task { @MainActor in
        let sent = await bond.nudge(friend)
        nudging = nil
        if sent { JourneyHaptic.play(.success, store.profile) }
      }
    } label: {
      Text(store.t(friend.canNudge() ? "Nudge" : "Nudged")).font(.app(.subheadline, weight: .semibold))
        .foregroundStyle(can ? JourneyColor.signal : JourneyColor.tertiary).frame(minHeight: 32).contentShape(Rectangle())
    }.buttonStyle(.hapticPlain).disabled(!can).accessibilityIdentifier("bond.nudge." + friend.id.uuidString)
      .accessibilityHint(friend.canNudge() ? "" : store.t("One nudge a day."))
  }
  /// Your gift on this bond, while it waits for your plan to end. Once granted it shows as the
  /// subscription in Settings.
  private func giftLine(_ friend: GymBond.Friend) -> String? {
    guard friend.giftGrantedAt == nil, let due = friend.giftDueAt, due > Date().addingTimeInterval(3600) else { return nil }
    return store.t("Two weeks of Pro for you, when your plan ends.")
  }
}

// MARK: - Onboarding

/// The code page's field (after the commit, before the wall), as Cal AI's referral page (8 Nov 2026,
/// at the user's request): one glass row with the field on the left and Submit on the right, in the
/// middle of the page (9 Nov 2026); the keyboard waits for a tap. What came back from the server sits under it.
struct BondCodeStage: View {
  @Binding var code: String
  let status: String?
  let good: Bool
  let busy: Bool
  let submit: () -> Void
  @EnvironmentObject private var store: GymStore
  private var ready: Bool { GymBond.normalize(code).count == 6 && !busy }
  var body: some View {
    VStack(spacing: 12) {
      Spacer(minLength: 0)
      HStack(spacing: 12) {
        TextField("", text: $code, prompt: Text(store.t("Referral code")).foregroundColor(JourneyColor.tertiary))
          .font(.app(.body, weight: .medium)).foregroundStyle(JourneyColor.text)
          .textInputAutocapitalization(.characters).autocorrectionDisabled().keyboardType(.asciiCapable)
          .submitLabel(.done).onSubmit { if ready { submit() } }.tint(JourneyColor.accent)
          // Kept as typed (rewriting it on every keystroke lost letters typed fast) and read normalised;
          // only capped, so a pasted code with a dash still fits.
          .onChange(of: code) { _, new in if new.count > 8 { code = String(new.prefix(8)) } }
          .accessibilityIdentifier("bond.code")
        Button(action: { JourneyHaptic.press(); Analytics.tap("bond.submit"); submit() }) {
          ZStack {
            Text(store.t("Submit")).font(.app(.body, weight: .semibold)).opacity(busy ? 0 : 1)
            if busy { ProgressView().tint(JourneyColor.onButton) }
          }
          .foregroundStyle(JourneyColor.onButton).padding(.horizontal, 18).frame(minHeight: 44)
          .background(Capsule().fill(ready ? JourneyColor.button : JourneyColor.disabledButton))
        }.buttonStyle(JourneyPressStyle()).disabled(!ready).animation(.smooth(duration: 0.3), value: ready)
          .accessibilityIdentifier("bond.submit")
      }
      .padding(.leading, 18).padding(.trailing, 8).padding(.vertical, 8)
      .journeyGlass(RoundedRectangle(cornerRadius: 22, style: .continuous))
      Text(status ?? " ").font(JourneyType.caption).foregroundStyle(good ? JourneyColor.signalText : JourneyColor.secondary)
        .multilineTextAlignment(.center).frame(minHeight: 20).padding(.horizontal, 8)
        .accessibilityHidden(status == nil).accessibilityIdentifier("bond.status")
      Spacer(minLength: 0)
    }
  }
}
