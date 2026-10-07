import SwiftUI

/// Home is one decision: what you're training today, and Start. Splits rotate, so the next
/// one is already chosen. The week sits in the middle; History and Settings are one tap away.
struct HomeView: View {
  @EnvironmentObject private var store: GymStore
  @State private var choosing = false
  @State private var settings = false
  @State private var history = false
  private var split: Workout? { store.data.workouts.first { $0.id == store.profile.preferredSplitID } }
  var body: some View {
    NavigationStack {
      ZStack {
        DotGrid()
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 10) {
            if store.data.demoLoaded == true {
              Text(store.t("Sample data")).font(JourneyType.caption).foregroundStyle(JourneyColor.secondary)
                .padding(.horizontal, 12).padding(.vertical, 6).journeyGlass(Capsule())
                .accessibilityIdentifier("home.sample")
            }
            Spacer()
            GlassIconButton(symbol: "clock.arrow.circlepath", label: store.t("History"), id: "home.history") { history = true }
            GlassIconButton(symbol: "gearshape", label: store.t("Settings"), id: "home.preferences") { settings = true }
          }.frame(minHeight: 52).padding(.top, 6)
          VStack(alignment: .leading, spacing: 10) {
            Text(store.t(split == nil ? "Today" : "Up next")).font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
            Button { choosing = true } label: {
              HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(split?.name ?? store.t("Free workout")).font(.system(.largeTitle, weight: .bold))
                  .foregroundStyle(JourneyColor.text).lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.leading)
                Image(systemName: "chevron.down").font(.system(.title3, weight: .bold)).foregroundStyle(JourneyColor.secondary)
                  .accessibilityHidden(true)
                Spacer(minLength: 0)
              }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("home.workout")
              .accessibilityLabel(store.t("Workout") + ", " + (split?.name ?? store.t("Free workout")))
              .accessibilityHint(store.t("Choose another workout"))
            Text(preview).font(.subheadline).foregroundStyle(JourneyColor.secondary).lineLimit(2)
          }.padding(.top, 18)
          Spacer(minLength: 24)
          WeekCard { history = true }
          Spacer(minLength: 24)
          VStack(spacing: 10) {
            Color.clear.frame(height: 20)
            JourneyButton(title: store.t("Start workout"), id: "home.start") {
              JourneyHaptic.play(.medium, store.profile, intensity: 0.8)
              store.startSession(workout: split)
            }
            Color.clear.frame(height: 44)
          }.padding(.top, 8)
        }.padding(.horizontal, 24).padding(.bottom, 4)
      }
      .toolbar(.hidden, for: .navigationBar)
      .navigationDestination(isPresented: $history) { HistoryHubView() }
      .sheet(isPresented: $settings) { PreferencesView() }
      .sheet(isPresented: $choosing) { WorkoutChoiceView() }
    }
  }
  private var preview: String {
    guard let split else { return store.t("Pick exercises as you go.") }
    return split.exercises.map { store.t($0.name) }.joined(separator: " · ")
  }
}

/// This week at a glance: a dot per day, today in red. Opens History.
struct WeekCard: View {
  @EnvironmentObject private var store: GymStore
  let action: () -> Void
  private var goal: Int { min(7, max(1, store.profile.baseline?.trainingDays ?? 5)) }
  private var last: Session? { store.data.history.filter { !$0.completedSets.isEmpty }.max { ($0.ended ?? $0.started) < ($1.ended ?? $1.started) } }
  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .firstTextBaseline) {
          Text(store.t("This week")).font(JourneyType.label).foregroundStyle(JourneyColor.secondary)
          Spacer()
          Text("\(store.weekCount) " + store.t("of") + " \(goal)").font(.system(.headline, weight: .semibold))
            .monospacedDigit().foregroundStyle(JourneyColor.text)
        }
        HStack(spacing: 0) {
          ForEach(store.weekDays, id: \.self) { day in
            VStack(spacing: 8) {
              Text(day.formatted(.dateTime.weekday(.narrow))).font(JourneyType.caption).foregroundStyle(JourneyColor.tertiary)
              dot(day)
            }.frame(maxWidth: .infinity)
          }
        }
        if let last {
          Rectangle().fill(JourneyColor.hairline).frame(height: 1)
          HStack(alignment: .firstTextBaseline) {
            Text(store.t("Last workout")).foregroundStyle(JourneyColor.secondary)
            Spacer()
            Text(store.t(last.name) + " · " + relative(last.ended ?? last.started)).foregroundStyle(JourneyColor.text)
              .lineLimit(1)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(JourneyColor.tertiary)
          }.font(.subheadline)
        }
      }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .journeyGlass(RoundedRectangle(cornerRadius: 26, style: .continuous), interactive: true)
    }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("home.week")
      .accessibilityLabel(store.t("This week") + ", \(store.weekCount) " + store.t("of") + " \(goal). " + store.t("Opens History"))
  }
  private func dot(_ day: Date) -> some View {
    let calendar = Calendar.current
    let today = calendar.isDateInToday(day)
    let trained = store.trained(on: day)
    let future = day > Date() && !today
    return Circle()
      .fill(trained ? (today ? JourneyColor.signalRed : JourneyColor.text) : Color.white.opacity(future ? 0 : 0.06))
      .overlay(Circle().strokeBorder(today && !trained ? JourneyColor.signalRed : Color.white.opacity(future ? 0.16 : 0), lineWidth: 1.5))
      .overlay {
        if trained {
          Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
            .foregroundStyle(today ? JourneyColor.onAccent : JourneyColor.onButton)
        }
      }
      .frame(width: 26, height: 26)
  }
  private func relative(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return store.t("today") }
    if calendar.isDateInYesterday(date) { return store.t("yesterday") }
    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: Date())).day ?? 0
    return days < 7 ? date.formatted(.dateTime.weekday(.wide)) : date.formatted(.dateTime.day().month(.abbreviated))
  }
}

/// Choose today's workout. Choosing is one tap; splits are created and edited here too.
struct WorkoutChoiceView: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dismiss) private var dismiss
  @State private var creating = false
  @State private var editing: Workout?
  @State private var deleting: Workout?
  var body: some View {
    NavigationStack {
      ScrollView {
        JourneyGlassGroup(spacing: 10) {
          VStack(spacing: 10) {
            row(store.t("Free workout"), detail: store.t("Pick exercises as you go."), id: nil)
            ForEach(store.data.workouts) { split in
              row(split.name, detail: split.exercises.map { store.t($0.name) }.joined(separator: " · "), id: split.id, split: split)
            }
            Button { creating = true } label: {
              Label(store.t("New split"), systemImage: "plus").font(JourneyType.option).foregroundStyle(JourneyColor.text)
                .frame(maxWidth: .infinity, minHeight: 60)
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                  .strokeBorder(JourneyColor.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])))
            }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("split.add")
          }
        }.padding(.horizontal, 20).padding(.vertical, 12)
      }.gymPage().navigationTitle(store.t("Choose workout")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button(store.t("Cancel")) { dismiss() } } }
        .navigationDestination(isPresented: $creating) {
          SplitEditorContent(workout: Workout(name: "", exercises: [])) { split in
            store.updateProfile { $0.preferredSplitID = split.id }; dismiss()
          }
        }
        .navigationDestination(item: $editing) { split in
          SplitEditorContent(workout: split) { _ in editing = nil }
        }
        .confirmationDialog(store.t("Delete this split?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { split in
          Button(store.t("Delete split"), role: .destructive) { store.deleteSplit(split.id) }
          Button(store.t("Cancel"), role: .cancel) {}
        } message: { _ in Text(store.t("Past workouts stay in History.")) }
    }.presentationDetents([.medium, .large])
  }
  private func row(_ name: String, detail: String, id: UUID?, split: Workout? = nil) -> some View {
    let selected = store.profile.preferredSplitID == id
    return HStack(spacing: 12) {
      Button {
        JourneyHaptic.play(.selection, store.profile)
        store.updateProfile { $0.preferredSplitID = id }; dismiss()
      } label: {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text(name).font(JourneyType.option).foregroundStyle(JourneyColor.text).lineLimit(1)
            Text(detail).font(.subheadline).foregroundStyle(JourneyColor.secondary).lineLimit(1)
          }
          Spacer(minLength: 8)
          Image(systemName: "checkmark.circle.fill").font(.system(.title3, weight: .semibold))
            .symbolRenderingMode(.palette).foregroundStyle(JourneyColor.onAccent, JourneyColor.accent)
            .opacity(selected ? 1 : 0).accessibilityHidden(true)
        }.frame(maxWidth: .infinity, minHeight: 52, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityIdentifier(split.map { "choice.\($0.name)" } ?? "choice.free")
        .accessibilityAddTraits(selected ? .isSelected : [])
      if let split {
        Menu {
          Button(store.t("Edit split"), systemImage: "pencil") { editing = split }
          Button(store.t("Delete split"), systemImage: "trash", role: .destructive) { deleting = split }
        } label: {
          Image(systemName: "ellipsis").font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
            .frame(width: 44, height: 44).contentShape(Rectangle())
        }.accessibilityLabel(store.t("Edit") + " " + name).accessibilityIdentifier("split.menu.\(split.name)")
      }
    }.padding(.leading, 20).padding(.trailing, split == nil ? 20 : 8).padding(.vertical, 6)
      .journeyGlass(RoundedRectangle(cornerRadius: 20, style: .continuous),
                    tint: selected ? JourneyColor.accent.opacity(0.22) : nil, interactive: true)
      .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
        .strokeBorder(JourneyColor.accent.opacity(selected ? 0.7 : 0), lineWidth: 1.5))
  }
}
