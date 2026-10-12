import FamilyControls
import SwiftUI

/// Blocked apps, after SleepBlock's (11 Oct 2026): the title and one line of what it does, then one
/// glass card: the switch and the apps (Apple's picker). The chosen apps sit under the card as their
/// real icons. Opened from the Profile card and from Settings.
struct BlockedAppsView: View {
  @EnvironmentObject private var store: GymStore
  @ObservedObject private var blocking = AppBlocking.shared
  @State private var picking = false
  @State private var pickDraft = FamilyActivitySelection()
  @State private var denied = false
  var body: some View {
    ZStack {
      DotGrid()
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          BlockingHeader(title: store.t("Blocked apps"), detail: store.t("Locked from Start workout until you finish."))
          card.padding(.top, 24)
          if denied && !blocking.authorized {
            Text(store.t("Screen Time access is off for GymBlock. Allow it in iOS Settings."))
              .font(.app(.footnote)).foregroundStyle(JourneyColor.secondary).padding(.top, 12)
          }
          if !blocking.isEmpty { icons.padding(.top, 28) }
        }.frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 32)
      }.scrollIndicators(.hidden)
    }
    .navigationBarTitleDisplayMode(.inline)
    .familyActivityPicker(headerText: store.t("Choose what to block from Start workout to Finish."), isPresented: $picking, selection: $pickDraft)
    .onChange(of: pickDraft) { _, chosen in
      // Choosing the first apps is the commitment, so it turns blocking on.
      let first = blocking.isEmpty
      blocking.choose(chosen)
      if first, !blocking.isEmpty, store.profile.focusEnabled != true { store.updateProfile { $0.focusEnabled = true } }
    }
    .onAppear { blocking.refresh() }
    .track(screen: "blocked_apps")
  }

  private var card: some View {
    VStack(spacing: 0) {
      HStack(spacing: 14) {
        BlockingIcon(symbol: "lock.fill")
        Toggle(isOn: Binding(get: { store.profile.focusEnabled == true }, set: setBlocking)) {
          Text(store.t("Block while you train")).font(.app(.body)).foregroundStyle(JourneyColor.text)
        }.tint(JourneyColor.signal).accessibilityIdentifier("focus.enabled")
      }.frame(minHeight: 60)
      SettingsDivider()
      Button(action: chooseApps) {
        BlockingRow(symbol: "square.grid.2x2.fill", title: store.t("Apps"), value: blocking.isEmpty ? store.t("None") : blocking.summary(store.t))
      }.buttonStyle(.plain).accessibilityIdentifier("blocking.apps")
    }
    .padding(.horizontal, 16)
    .journeySurface(cornerRadius: 20)
  }

  /// What locks, as iOS draws it: the tokens are opaque, so the icons are the only list there is.
  private var icons: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 14)], alignment: .leading, spacing: 14) {
      ForEach(Array(blocking.selection.applicationTokens), id: \.self) { Label($0).labelStyle(.iconOnly).font(.app(size: 34)).frame(width: 44, height: 44) }
      ForEach(Array(blocking.selection.categoryTokens), id: \.self) { Label($0).labelStyle(.iconOnly).font(.app(size: 34)).frame(width: 44, height: 44) }
      ForEach(Array(blocking.selection.webDomainTokens), id: \.self) { Label($0).labelStyle(.iconOnly).font(.app(size: 34)).frame(width: 44, height: 44) }
    }.accessibilityHidden(true)
  }

  /// Turning blocking on asks for Screen Time access, then for the apps if none are chosen yet.
  private func setBlocking(_ on: Bool) {
    guard on else { store.updateProfile { $0.focusEnabled = false }; return }
    Task { @MainActor in
      let granted = await blocking.requestAccess()
      denied = !granted
      store.updateProfile { $0.focusEnabled = granted }
      if granted && blocking.isEmpty { pickDraft = blocking.selection; picking = true }
    }
  }
  private func chooseApps() {
    Task { @MainActor in
      guard await blocking.requestAccess() else { denied = true; return }
      denied = false
      pickDraft = blocking.selection
      picking = true
    }
  }
}

/// The page's title, large, with one line of what it does under it.
private struct BlockingHeader: View {
  let title: String
  let detail: String
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.app(.largeTitle, weight: .bold)).tracking(-0.4).foregroundStyle(JourneyColor.text)
        .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
      Text(detail).font(.app(.body)).foregroundStyle(JourneyColor.secondary).fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// A row of the card: its symbol, the title, the current value and a chevron.
private struct BlockingRow: View {
  let symbol: String
  let title: String
  let value: String
  var body: some View {
    HStack(spacing: 14) {
      BlockingIcon(symbol: symbol)
      Text(title).font(.app(.body)).foregroundStyle(JourneyColor.text).multilineTextAlignment(.leading)
      Spacer(minLength: 12)
      Text(value).font(.app(.body)).foregroundStyle(JourneyColor.secondary).lineLimit(1)
      Image(systemName: "chevron.right").font(.system(.footnote, weight: .semibold)).foregroundStyle(JourneyColor.tertiary)
    }.frame(minHeight: 60).contentShape(Rectangle())
  }
}

/// An emerald symbol on a faint emerald tile, the card's only colour.
private struct BlockingIcon: View {
  let symbol: String
  var body: some View {
    Image(systemName: symbol).font(.system(size: 15, weight: .semibold)).foregroundStyle(JourneyColor.signal)
      .frame(width: 34, height: 34)
      .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(JourneyColor.signal.opacity(0.12)))
      .accessibilityHidden(true)
  }
}
