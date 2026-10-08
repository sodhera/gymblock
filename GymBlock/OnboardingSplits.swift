import SwiftUI

/// The last onboarding page: set up the splits you repeat. Each split is a name and its exercises;
/// Home lines the next one up with last time's weights. Splits stay optional: Skip goes to a free
/// workout, and the chooser on Home can add them later.
struct SplitsStage: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var creating = false
  @State private var editing: Workout?
  @State private var deleting: Workout?
  var body: some View {
    VStack(spacing: 12) {
      if store.data.workouts.isEmpty {
        Spacer(minLength: 0)
        VStack(spacing: 10) {
          Image(systemName: "rectangle.stack.badge.plus").font(.title).foregroundStyle(JourneyColor.secondary)
            .accessibilityHidden(true)
          Text(store.t("A split is a workout you repeat: Push, Pull, Legs. Name one, add its exercises, and each workout starts with last time’s weights ready."))
            .font(.subheadline).foregroundStyle(JourneyColor.secondary).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true).padding(.horizontal, 12)
        }
        Spacer(minLength: 0)
      } else {
        ScrollView {
          VStack(spacing: 10) {
            ForEach(store.data.workouts) { split in
              row(split).transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
          }.padding(.vertical, 2)
        }.scrollIndicators(.hidden).scrollBounceBehavior(.basedOnSize)
          .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0.15), value: store.data.workouts.map(\.id))
      }
      Button { creating = true } label: {
        Label(store.t(store.data.workouts.isEmpty ? "Add your first split" : "Add another split"), systemImage: "plus")
          .font(JourneyType.option).foregroundStyle(JourneyColor.text)
          .frame(maxWidth: .infinity, minHeight: 52)
          .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
          .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(JourneyColor.ink(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5])))
      }.buttonStyle(JourneyPressStyle()).accessibilityIdentifier("splits.add")
    }
    .sheet(isPresented: $creating) {
      NavigationStack {
        SplitEditorContent(workout: Workout(name: "", exercises: [])) { split in
          store.updateProfile { if $0.preferredSplitID == nil { $0.preferredSplitID = split.id } }
          JourneyHaptic.play(.success, store.profile)
          creating = false
        }
      }.presentationDetents([.large]).tint(JourneyColor.text)
    }
    .sheet(item: $editing) { split in
      NavigationStack { SplitEditorContent(workout: split) { _ in editing = nil } }.presentationDetents([.large]).tint(JourneyColor.text)
    }
    .confirmationDialog(store.t("Delete this split?"), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                        titleVisibility: .visible, presenting: deleting) { split in
      Button(store.t("Delete split"), role: .destructive) { store.deleteSplit(split.id) }
      Button(store.t("Cancel"), role: .cancel) {}
    } message: { _ in Text(store.t("You can add it again any time.")) }
  }
  private func row(_ split: Workout) -> some View {
    HStack(spacing: 10) {
      Button { editing = split } label: {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 3) {
            Text(split.name).font(JourneyType.option).foregroundStyle(JourneyColor.text).lineLimit(1)
            Text(split.exercises.map { store.t($0.name) }.joined(separator: " · ")).font(JourneyType.caption)
              .foregroundStyle(JourneyColor.secondary).lineLimit(2)
          }
          Spacer(minLength: 8)
          Text("\(split.exercises.count)").font(JourneyType.label).monospacedDigit().foregroundStyle(JourneyColor.tertiary)
            .accessibilityLabel("\(split.exercises.count) " + store.t("exercises"))
          Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(JourneyColor.tertiary).accessibilityHidden(true)
        }.frame(maxWidth: .infinity, minHeight: 46, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityIdentifier("splits.row." + split.name)
      Menu {
        Button(store.t("Edit split"), systemImage: "pencil") { editing = split }
        Button(store.t("Delete split"), systemImage: "trash", role: .destructive) { deleting = split }
      } label: {
        Image(systemName: "ellipsis").font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.secondary)
          .frame(width: 40, height: 40).contentShape(Rectangle())
      }.accessibilityLabel(store.t("Edit") + " " + split.name)
    }.padding(.leading, 18).padding(.trailing, 6).padding(.vertical, 6)
      .journeyGlass(RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
  }
}
