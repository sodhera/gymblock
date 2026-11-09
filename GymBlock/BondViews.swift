import MessageUI
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
            PageLabel(text: "GymBuddy")
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
    let n = friend.thisWeek(), streak = friend.dayStreak()
    if streak > 1 { return "\(streak) " + t("day streak") }
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
  var body: some View {
    ZStack {
      DotGrid()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          // Cut down on 9 Nov 2026 (the user: "too much text"): no intro (the gift is on the invite
          // page and the Streak page), no label over the code, "Have a code?" as the field's own
          // prompt, no gift line under a friend, one short footer.
          Text("GymBuddy").font(.app(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
            .accessibilityAddTraits(.isHeader)
          codeCard.padding(.top, 20)
          codeField.padding(.top, 16)
          if !bond.friends.isEmpty {
            HStack(alignment: .center, spacing: 8) {
              PageLabel(text: store.t("Friends"))
              // Friend-workout pushes: every, rarely or none, beside the label (9 Nov 2026).
              Menu { BuddyAlertsPicker(id: "bond.alerts") } label: {
                HStack(spacing: 5) {
                  Image(systemName: "bell").font(.system(size: 13, weight: .semibold))
                  Text(store.t(BuddyAlerts.current(store.profile).title)).font(.app(.subheadline, weight: .medium))
                  Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(JourneyColor.signal).frame(minHeight: 28).contentShape(Rectangle())
              }
              .simultaneousGesture(TapGesture().onEnded { JourneyHaptic.pressLight() })
              .accessibilityIdentifier("bond.alerts")
            }.padding(.top, 32)
            VStack(spacing: 12) { ForEach(bond.friends) { friendRow($0) } }.padding(.top, 12)
          }
          Text(store.t("Friends see your first name and your week."))
            .font(.app(.footnote)).foregroundStyle(JourneyColor.tertiary).fixedSize(horizontal: false, vertical: true).padding(.top, 28)
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
            // The gift, said once on this page (9 Nov 2026), in the brand colour; "Copied" takes its place for a moment.
            ZStack {
              Text(store.t("A friend joins with it and you both get two weeks of Pro.")).opacity(copied ? 0 : 1)
              Text(store.t("Copied")).opacity(copied ? 1 : 0)
            }
            .font(.app(.footnote, weight: .medium)).foregroundStyle(JourneyColor.signalText).multilineTextAlignment(.center)
            .animation(.smooth(duration: 0.25), value: copied)
          }.frame(maxWidth: .infinity).contentShape(Rectangle())
        }.buttonStyle(.hapticPlain).accessibilityIdentifier("bond.code.copy")
          .accessibilityLabel(store.t("Your code") + ", " + code.map(String.init).joined(separator: " "))
        if bond.code != nil { BondShareButton(title: store.t("Share your code"), id: "bond.share") }
      } else if bond.live {
        ProgressView().tint(JourneyColor.secondary).frame(maxWidth: .infinity, minHeight: 60)
      } else {
        Text(store.t("Sign in to get your code.")).font(.app(.body)).foregroundStyle(JourneyColor.secondary)
          .frame(maxWidth: .infinity, minHeight: 60)
      }
    }.padding(18).frame(maxWidth: .infinity).journeySurface(cornerRadius: 20)
  }
  // MARK: A friend's code

  private var canAdd: Bool { GymBond.normalize(draft).count == 6 && !bond.busy }
  private var codeField: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 12) {
        TextField("", text: $draft, prompt: Text(store.t("Have a code?")).foregroundColor(JourneyColor.tertiary))
          .font(.app(.title3, weight: .semibold)).tracking(draft.isEmpty ? 0 : 3).foregroundStyle(JourneyColor.text)
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
}

/// The share sheet as the ink primary button (the GymBond page and onboarding's invite page). With
/// no code yet (it's being fetched, or there's no account) it stays grey.
struct BondShareButton: View {
  let title: String
  var id = "bond.share"
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var bond = GymBond.shared
  var body: some View {
    let text = bond.shareText(spanish: store.profile.language == "es")
    let label = HStack(spacing: 8) {
      Image(systemName: "square.and.arrow.up").font(.system(.headline, weight: .semibold)).accessibilityHidden(true)
      Text(title).font(JourneyType.button).lineLimit(1).minimumScaleFactor(0.8)
    }.foregroundStyle(JourneyColor.onButton).frame(maxWidth: .infinity, minHeight: 22)
    Group {
      if let text {
        let link = ShareLink(item: text) { label }
          .simultaneousGesture(TapGesture().onEnded { JourneyHaptic.press(); Analytics.tap(id) })
        if #available(iOS 26.0, *) {
          link.buttonStyle(.glassProminent).tint(JourneyColor.button).controlSize(.large).buttonBorderShape(.capsule)
        } else {
          ShareLink(item: text) { label.frame(minHeight: 50).background(Capsule().fill(JourneyColor.button)) }
            .buttonStyle(JourneyPressStyle())
        }
      } else {
        label.frame(minHeight: 50).background(Capsule().fill(JourneyColor.disabledButton))
      }
    }
    .animation(.smooth(duration: 0.3), value: text == nil)
    .accessibilityIdentifier(id)
  }
}

// MARK: - Onboarding

/// The GymBuddy invite, the setup page after the split is chosen (9 Nov 2026, at the user's
/// request): the gift in the middle of the page, their code under it, Invite a friend as the
/// button, Skip below. The code is fetched here if the GymBond page hasn't yet.
struct BondInviteStage: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var bond = GymBond.shared
  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      VStack(spacing: 18) {
        Image(systemName: "gift.fill").font(.system(size: 30, weight: .semibold)).foregroundStyle(JourneyColor.signal)
          .frame(width: 64, height: 64).background(Circle().fill(JourneyColor.signal.opacity(0.12))).accessibilityHidden(true)
        VStack(spacing: 4) {
          Text(store.t("2 weeks of Pro")).font(.app(size: 28, weight: .bold)).tracking(-0.5).foregroundStyle(JourneyColor.text)
          Text(store.t("For your friend, free.")).font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary)
        }
        VStack(spacing: 6) {
          Text(store.t("Your code")).font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary)
          if let code = bond.code {
            Text(code).font(.app(size: 26, weight: .bold)).tracking(6).monospacedDigit().foregroundStyle(JourneyColor.text).padding(.leading, 6)
              .accessibilityLabel(store.t("Your code") + ", " + code.map(String.init).joined(separator: " "))
          } else if bond.live {
            ProgressView().tint(JourneyColor.secondary).frame(height: 32)
          } else {
            Text(store.t("Sign in to get your code.")).font(.app(.subheadline)).foregroundStyle(JourneyColor.secondary).frame(height: 32)
          }
        }
        .padding(.horizontal, 24).padding(.vertical, 14).frame(maxWidth: .infinity)
        .journeyGlass(RoundedRectangle(cornerRadius: 18, style: .continuous))
      }
      .padding(22).frame(maxWidth: .infinity).journeySurface(cornerRadius: 24)
      Spacer(minLength: 0)
    }
    .accessibilityIdentifier("onboarding.bondInvite")
    .task { await bond.fetchCode() }
  }
}


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


// MARK: - The streak page

/// Opened from Home's streak pill (9 Nov 2026, at the user's request): the flame and the week streak
/// in the middle, then friends ranked by their streaks (you among them), or, with no friend yet, the
/// invite as the button. Plain rows on the paper, no cards.
struct StreakPage: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var bond = GymBond.shared
  var body: some View {
    let stats = store.homeStats()
    let mine = stats.streakDays
    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 14) {
          StreakFlame(count: mine, size: 120)
          Text(store.t("day streak")).font(.app(.title3, weight: .medium)).foregroundStyle(JourneyColor.secondary)
          Text(store.t("Miss two days in a row and it starts over.")).font(.app(.subheadline)).foregroundStyle(JourneyColor.tertiary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.top, 36).padding(.bottom, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(mine) " + store.t("day streak"))

        if bond.friends.isEmpty {
          VStack(spacing: 14) {
            Text(store.t("Train with a friend and see who keeps the longer streak.")).font(.app(.body))
              .foregroundStyle(JourneyColor.secondary).multilineTextAlignment(.center)
            BondShareButton(title: store.t("Invite a friend"), id: "streak.invite")
            Text(store.t("Gift them two weeks of Pro.")).font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary)
          }
          .padding(.top, 8)
        } else {
          HStack(alignment: .center) {
            PageLabel(text: store.t("Friends"))
            // Rank by the streak, or by workouts over the last ten weeks (as far back as a friend's
            // list goes), 9 Nov 2026, at the user's request.
            Picker("", selection: $byWorkouts.ticking) {
              Text(store.t("Streak")).tag(false)
              Text(store.t("Workouts")).tag(true)
            }
            .pickerStyle(.segmented).fixedSize().accessibilityIdentifier("streak.rank")
          }
          ForEach(Array(ranked(mine).enumerated()), id: \.element.id) { i, row in
            HStack(alignment: .firstTextBaseline, spacing: 14) {
              Text("\(i + 1)").font(.app(.subheadline, weight: .medium)).monospacedDigit()
                .foregroundStyle(JourneyColor.tertiary).frame(width: 20, alignment: .leading)
              Text(row.name).font(.app(.body, weight: row.me ? .semibold : .regular)).foregroundStyle(JourneyColor.text).lineLimit(1)
              Spacer(minLength: 8)
              HStack(spacing: 5) {
                if byWorkouts {
                  Image(systemName: "dumbbell.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(JourneyColor.signal).accessibilityHidden(true)
                  Text("\(row.workouts)").font(.app(.body, weight: .semibold)).monospacedDigit().foregroundStyle(JourneyColor.text)
                } else {
                  StreakFlame(size: 15)
                  Text("\(row.streak)").font(.app(.body, weight: .semibold)).monospacedDigit().foregroundStyle(JourneyColor.text)
                }
              }
            }
            .frame(minHeight: 52)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(i + 1), " + row.name + ", " + (byWorkouts ? "\(row.workouts) " + store.t("workouts") : "\(row.streak) " + store.t("day streak")))
            SettingsDivider()
          }
          NavigationLink { BondView() } label: {
            HStack(spacing: 8) {
              Image(systemName: "plus").font(.system(.subheadline, weight: .semibold))
              Text(store.t("Invite a friend")).font(.app(.body, weight: .medium))
            }.foregroundStyle(JourneyColor.signal).frame(minHeight: 44).contentShape(Rectangle())
          }.buttonStyle(.hapticPlain).padding(.top, 8).accessibilityIdentifier("streak.bond")
        }
      }
      .padding(.horizontal, 24).padding(.bottom, 32)
    }
    .scrollIndicators(.hidden)
    .background(DotGrid().ignoresSafeArea())
    .navigationTitle(store.t("Streak")).navigationBarTitleDisplayMode(.inline)
    // Share: the streak as a card (the flame, WEEK STREAK, "Get focused with GymBlock"), as Cal AI's.
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          JourneyHaptic.pressLight(); Analytics.tap("streak.share")
          if let image = card ?? shareImage(mine) { sharing = ShareCard(image: image) }
        } label: {
          Image(systemName: "square.and.arrow.up").accessibilityLabel(store.t("Share"))
        }.accessibilityIdentifier("streak.share")
      }
    }
    // The card on its own sheet with Messages, Save, More and Copy under it, as Cal AI's (9 Nov 2026).
    // The image rides on the sheet's item: a `card` read inside the sheet's closure stayed nil.
    .sheet(item: $sharing) { StreakShareSheet(card: $0.image) }
    .track(screen: "streak", ["friends": bond.friends.count])
    .task(id: mine) { card = shareImage(mine) }
    .task { await bond.fetchCode(); await bond.refresh() }
  }

  @State private var byWorkouts = false
  private struct ShareCard: Identifiable { let id = UUID(); let image: UIImage }
  @State private var sharing: ShareCard?
  /// The card, 1080 x 1920, rendered once per streak value.
  @State private var card: UIImage?
  @MainActor private func shareImage(_ streak: Int) -> UIImage? {
    let renderer = ImageRenderer(content: StreakShareCard(streak: streak, label: store.t("day streak"), tagline: store.t("Focused workouts with")))
    renderer.scale = 3
    return renderer.uiImage
  }

  private struct Row: Identifiable { let id: String; let name: String; let streak: Int; let workouts: Int; let thisWeek: Int; let me: Bool }
  /// You and your friends, by the longest streak (or the most workouts over the last ten weeks, the
  /// window a friend's list covers), then the most workouts this week, then by name.
  private func ranked(_ mine: Int) -> [Row] {
    let stats = store.homeStats()
    let since = Calendar.current.date(byAdding: .day, value: -70, to: Date()) ?? Date()
    let myWorkouts = store.data.history.filter { !$0.completedSets.isEmpty && $0.started >= since }.count
    var rows = bond.friends.map { Row(id: $0.id.uuidString, name: $0.name, streak: $0.dayStreak(), workouts: $0.workouts.count, thisWeek: $0.thisWeek(), me: false) }
    rows.append(Row(id: "me", name: store.t("You"), streak: mine, workouts: myWorkouts, thisWeek: stats.thisWeek, me: true))
    return rows.sorted { a, b in
      let (x, y) = byWorkouts ? (a.workouts, b.workouts) : (a.streak, b.streak)
      if x != y { return x > y }
      if a.thisWeek != b.thisWeek { return a.thisWeek > b.thisWeek }
      return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
  }
}

/// The shareable streak card (9 Nov 2026, after Cal AI's): orange from the top right fading to white
/// at the foot, the flame with the count, the label in orange capitals, and the app's name at the
/// bottom with its mark. 360 x 640 pt, rendered at 3x.
struct StreakShareCard: View {
  let streak: Int
  let label: String
  let tagline: String
  var body: some View {
    ZStack {
      LinearGradient(stops: [.init(color: StreakFlame.orange, location: 0), .init(color: Color(red: 0.99, green: 0.86, blue: 0.62), location: 0.35),
                             .init(color: .white, location: 0.72)], startPoint: .topTrailing, endPoint: .bottomLeading)
      VStack(spacing: 28) {
        StreakFlame(count: streak, size: 150)
        Text(label.uppercased()).font(.system(size: 44, weight: .bold, design: .rounded)).tracking(1)
          .foregroundStyle(StreakFlame.deep)
      }
      .offset(y: -40)
      VStack {
        Spacer()
        HStack(spacing: 8) {
          Text(tagline).font(.system(size: 20, weight: .medium))
          BrandMark(size: 22)
          Text("GymBlock").font(.system(size: 22, weight: .bold)).tracking(-0.4)
        }.foregroundStyle(Color(white: 0.1)).padding(.bottom, 120)
      }
    }
    .frame(width: 360, height: 640)
    .environment(\.colorScheme, .light)
  }
}


/// The streak card on its own sheet, laid out as Cal AI's (9 Nov 2026, from the user's screenshot):
/// the card edge to edge from the sheet's top down to a hairline, and under it a row of targets that
/// scrolls sideways: Instagram (Stories, through Instagram's own share scheme), Messages, Save (to
/// Photos, add-only), More (the system share sheet) and Copy. X and Snapchat take only their SDKs
/// for an image, and the app takes no other SDKs, so they are not here.
struct StreakShareSheet: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  let card: UIImage
  @State private var messaging = false
  @State private var saved = false
  @State private var copied = false
  private static let instagramStories = URL(string: "instagram-stories://share?source_application=com.sodhera.gymblock")!
  var body: some View {
    VStack(spacing: 0) {
      Image(uiImage: card).resizable().scaledToFill()
        .frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        .accessibilityLabel(store.t("Streak"))
      Divider()
      ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: 22) {
          if UIApplication.shared.canOpenURL(Self.instagramStories) {
            target(id: "streak.share.instagram", title: "Instagram") { Image("app.instagram").resizable().scaledToFill() } action: {
              // Instagram reads the image off the pasteboard; it stays there five minutes at most.
              UIPasteboard.general.setItems([["com.instagram.sharedSticker.backgroundImage": card.pngData() ?? Data()]],
                                            options: [.expirationDate: Date().addingTimeInterval(300)])
              UIApplication.shared.open(Self.instagramStories)
            }
          }
          if MessageComposer.canSend {
            target(id: "streak.share.messages", title: store.t("Messages")) { Image("app.messages").resizable().scaledToFill() } action: { messaging = true }
          }
          target(id: "streak.share.save", title: store.t(saved ? "Saved" : "Save")) { glyph(saved ? "checkmark" : "square.and.arrow.down") } action: {
            UIImageWriteToSavedPhotosAlbum(card, nil, nil, nil)
            withAnimation(.smooth(duration: 0.25)) { saved = true }
          }
          ShareLink(item: Image(uiImage: card), preview: SharePreview(store.t("Streak"), image: Image(uiImage: card))) {
            targetLabel(title: store.t("More")) { glyph("ellipsis") }
          }
          .buttonStyle(JourneyPressStyle())
          .simultaneousGesture(TapGesture().onEnded { Analytics.tap("streak.share.more") })
          .accessibilityIdentifier("streak.share.more")
          target(id: "streak.share.copy", title: store.t(copied ? "Copied" : "Copy")) { glyph(copied ? "checkmark" : "doc.on.doc") } action: {
            UIPasteboard.general.image = card
            withAnimation(.smooth(duration: 0.25)) { copied = true }
          }
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 8)
      }
      .scrollIndicators(.hidden)
      .background(JourneyColor.stage)
    }
    .background(JourneyColor.stage.ignoresSafeArea())
    .presentationDragIndicator(.visible)
    .sheet(isPresented: $messaging) { MessageComposer(image: card, text: nil) }
    .track(screen: "streak_share")
  }

  private func target<Icon: View>(id: String, title: String, @ViewBuilder icon: @escaping () -> Icon, action: @escaping () -> Void) -> some View {
    Button { Analytics.tap(id); action() } label: { targetLabel(title: title, icon: icon) }
      .buttonStyle(JourneyPressStyle()).accessibilityIdentifier(id)
  }
  private func targetLabel<Icon: View>(title: String, @ViewBuilder icon: () -> Icon) -> some View {
    VStack(spacing: 8) {
      icon().frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      Text(title).font(.app(.footnote)).foregroundStyle(JourneyColor.secondary).lineLimit(1)
    }
    .frame(width: 72)
  }
  /// Save, More and Copy: a symbol on a white square with a hairline, as Cal AI draws them.
  private func glyph(_ symbol: String) -> some View {
    Image(systemName: symbol).font(.system(size: 22, weight: .medium)).foregroundStyle(JourneyColor.text)
      .frame(width: 60, height: 60)
      .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(JourneyColor.raised))
      .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(JourneyColor.hairline, lineWidth: 1))
  }
}

/// Apple's Messages composer with the card attached. Nothing is sent until they tap Send.
struct MessageComposer: UIViewControllerRepresentable {
  let image: UIImage
  let text: String?
  @Environment(\.dismiss) private var dismiss
  static var canSend: Bool { MFMessageComposeViewController.canSendText() && MFMessageComposeViewController.canSendAttachments() }
  func makeUIViewController(context: Context) -> MFMessageComposeViewController {
    let vc = MFMessageComposeViewController()
    vc.messageComposeDelegate = context.coordinator
    if let text { vc.body = text }
    if let data = image.pngData() { vc.addAttachmentData(data, typeIdentifier: "public.png", filename: "streak.png") }
    return vc
  }
  func updateUIViewController(_ vc: MFMessageComposeViewController, context: Context) {}
  func makeCoordinator() -> Coordinator { Coordinator(dismiss: { dismiss() }) }
  @MainActor final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
    let dismiss: () -> Void
    init(dismiss: @escaping () -> Void) { self.dismiss = dismiss }
    nonisolated func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
      let outcome = result == .sent ? "sent" : result == .cancelled ? "cancelled" : "failed"
      Task { @MainActor in
        Analytics.track("streak_share_messages", ["result": outcome])
        dismiss()
      }
    }
  }
}


/// How often a GymBuddy's finished workout reaches you (9 Nov 2026, at the user's request): every
/// workout, rarely (a random one in three, decided by the server), or none. The same menu sits
/// beside Friends on the GymBuddy page and in Settings under Notifications.
enum BuddyAlerts: String, CaseIterable {
  case every, rarely, none
  var title: String {
    switch self {
    case .every: "Every workout"
    case .rarely: "Rarely"
    case .none: "None"
    }
  }
  static func current(_ profile: Profile) -> BuddyAlerts { BuddyAlerts(rawValue: profile.buddyAlerts ?? "") ?? .every }
}

/// The menu's choices, for a `Picker` inside a `Menu`.
struct BuddyAlertsPicker: View {
  @EnvironmentObject private var store: GymStore
  let id: String
  var body: some View {
    Picker(store.t("Buddy workouts"), selection: Binding(get: { BuddyAlerts.current(store.profile) }, set: { choice in
      store.updateProfile { $0.buddyAlerts = choice.rawValue }
      Analytics.tap(id, ["value": choice.rawValue])
    }).ticking) {
      ForEach(BuddyAlerts.allCases, id: \.self) { Text(store.t($0.title)).tag($0) }
    }
  }
}
