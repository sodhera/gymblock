import SwiftUI

/// The logger. Full-screen while you train; the chevron collapses it into the
/// tab bar accessory without ending anything. Layout follows the grammar
/// lifters already know from Hevy — SET · PREVIOUS · KG · REPS · ✓ — in
/// GymBlock's type and color: finished rows tint soft orange, PRs flash an
/// orange tag, and the only way out is holding Finish.
struct ActiveWorkoutView: View {
    @Environment(AppStore.self) private var store
    @Environment(RestTimer.self) private var rest
    @Environment(ScreenTimeController.self) private var screenTime
    @State private var showingPicker = false
    @State private var renaming = false
    @State private var titleDraft = ""
    @State private var confirmEarly = false
    @State private var confirmDiscard = false
    @State private var recordSets: Set<UUID> = []
    @FocusState private var focusedField: SetField?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: GBSpace.lg) {
                    statsHeader
                    if let workout = store.activeWorkout {
                        ForEach(workout.exercises) { log in
                            ExerciseCard(
                                log: log,
                                recordSets: $recordSets,
                                focusedField: $focusedField
                            )
                        }
                    }
                    addExerciseButton
                }
                .padding(.horizontal, GBSpace.margin)
                .padding(.bottom, 200)
            }
            .scrollDismissesKeyboard(.interactively)
            .paperBackground()
            .toolbar { toolbar }
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView(title: "Add exercises") { ids in store.addExercises(ids) }
            }
            .alert("Rename workout", isPresented: $renaming) {
                TextField("Workout name", text: $titleDraft)
                Button("Save") {
                    let t = titleDraft.trimmingCharacters(in: .whitespaces)
                    if !t.isEmpty { store.activeWorkout?.title = String(t.prefix(40)) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Finish early?", isPresented: $confirmEarly) {
                Button("Keep going", role: .cancel) {}
                Button("Finish anyway") { store.finishWorkout() }
            } message: {
                Text("Fewer than \(Workout.minimumSetsToCount) sets done — this one won't count toward your week.")
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) {
                    Haptics.warning()
                    store.discardWorkout()
                }
            } message: {
                Text("Nothing is saved and your apps unlock.")
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                Haptics.tap()
                store.isWorkoutPresented = false
            } label: {
                Image(systemName: "chevron.down")
            }
            .accessibilityLabel("Minimize workout")
        }
        ToolbarItem(placement: .principal) {
            Button {
                titleDraft = store.activeWorkout?.title ?? ""
                renaming = true
            } label: {
                HStack(spacing: 4) {
                    Text(store.activeWorkout?.title ?? "Workout")
                        .font(GBFont.headline(16))
                        .foregroundStyle(GBColor.ink)
                        .lineLimit(1)
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(GBColor.fog)
                }
            }
            .buttonStyle(.plain)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                if let workout = store.activeWorkout {
                    Toggle(isOn: Binding(
                        get: { workout.isShared },
                        set: { store.activeWorkout?.isShared = $0 }
                    )) {
                        Label("Share with friends", systemImage: "person.2")
                    }
                }
                Button("Rename", systemImage: "pencil") {
                    titleDraft = store.activeWorkout?.title ?? ""
                    renaming = true
                }
                Divider()
                Button("Discard workout", systemImage: "trash", role: .destructive) { confirmDiscard = true }
            } label: {
                Image(systemName: "ellipsis")
            }
        }
    }

    // MARK: Header

    private var statsHeader: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let workout = store.activeWorkout
            HStack(alignment: .top, spacing: 0) {
                stat("Time", Format.clock(context.date.timeIntervalSince(workout?.start ?? .now)), accent: false)
                stat("Volume", Format.volume(workout?.volume ?? 0, unit: store.profile.unit), accent: false)
                stat("Sets", "\(workout?.completedSetCount ?? 0)", accent: false)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Locked").kicker()
                    HStack(spacing: 4) {
                        Image(systemName: screenTime.isLocked ? "lock.fill" : "lock.open")
                            .font(.system(size: 12, weight: .bold))
                        Text(screenTime.isLocked ? "\(screenTime.appCount + screenTime.categoryCount)" : "Off")
                    }
                    .font(GBFont.number(17))
                    .foregroundStyle(screenTime.isLocked ? GBColor.orange : GBColor.fog)
                }
            }
        }
        .padding(.top, GBSpace.xs)
        .padding(.bottom, GBSpace.xxs)
    }

    private func stat(_ label: String, _ value: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).kicker()
            Text(value)
                .font(GBFont.number(17))
                .foregroundStyle(accent ? GBColor.orange : GBColor.ink)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addExerciseButton: some View {
        Button {
            showingPicker = true
        } label: {
            Label("Add exercise", systemImage: "plus")
        }
        .buttonStyle(GlassButtonStyle())
        .padding(.top, GBSpace.xs)
    }

    // MARK: Bottom

    private var bottomBar: some View {
        VStack(spacing: GBSpace.sm) {
            if rest.isRunning {
                RestTimerPill()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if focusedField == nil {
                HoldButton(title: "Hold to finish", holdingTitle: "Keep holding…") {
                    finish()
                }
            }
        }
        .padding(.horizontal, GBSpace.margin)
        .padding(.bottom, GBSpace.xs)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rest.isRunning)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
                    .fontWeight(.semibold)
            }
        }
    }

    private func finish() {
        guard let workout = store.activeWorkout else { return }
        if workout.completedSetCount == 0 {
            confirmDiscard = true
        } else if workout.completedSetCount < Workout.minimumSetsToCount {
            confirmEarly = true
        } else {
            store.finishWorkout()
        }
    }
}

// MARK: - Rest timer pill

struct RestTimerPill: View {
    @Environment(RestTimer.self) private var rest

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = rest.remaining(at: context.date)
            let progress = rest.total > 0 ? Double(remaining) / Double(rest.total) : 0
            HStack(spacing: GBSpace.sm) {
                Button { rest.add(-15) } label: {
                    Text("−15").font(GBFont.number(15, weight: .semibold)).frame(width: 52, height: 40)
                }
                .buttonStyle(.plain)

                VStack(spacing: 5) {
                    Text(Format.clock(TimeInterval(remaining)))
                        .font(GBFont.number(22, weight: .bold))
                        .foregroundStyle(GBColor.ink)
                        .contentTransition(.numericText(countsDown: true))
                    GeometryReader { geo in
                        Capsule().fill(GBColor.mist.opacity(0.6))
                            .overlay(alignment: .leading) {
                                Capsule().fill(GBColor.orange)
                                    .frame(width: geo.size.width * progress)
                            }
                    }
                    .frame(height: 4)
                }
                .frame(maxWidth: .infinity)

                Button { rest.add(15) } label: {
                    Text("+15").font(GBFont.number(15, weight: .semibold)).frame(width: 52, height: 40)
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.tap()
                    rest.stop()
                } label: {
                    Text("Skip").font(GBFont.label(15)).frame(height: 40).padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(GBColor.ink)
            .padding(.horizontal, GBSpace.sm)
            .padding(.vertical, GBSpace.xs)
            .glassEffect(.regular.tint(.white.opacity(0.6)), in: Capsule())
            .animation(.snappy, value: remaining)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rest timer")
    }
}
