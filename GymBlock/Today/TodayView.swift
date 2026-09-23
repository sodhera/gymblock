import SwiftUI

/// Today: where you are this week, and one button. The headline is the
/// week's count, the strip shows which days, the streak sits under it, and
/// Start Workout is pinned at the thumb. Templates live below the fold for
/// when the suggestion isn't what you want today.
struct TodayView: View {
    @Environment(AppStore.self) private var store
    @Environment(ScreenTimeController.self) private var screenTime
    @State private var selectedTemplateID: UUID?
    @State private var previewTemplate: WorkoutTemplate?
    @State private var editingTemplate: WorkoutTemplate?
    @State private var showingPicker = false

    private var selectedTemplate: WorkoutTemplate? {
        store.templates.first { $0.id == selectedTemplateID } ?? store.suggestedTemplate
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GBSpace.xxl) {
                    header
                    weekCard
                    templatesSection
                }
                .padding(.horizontal, GBSpace.margin)
                .padding(.top, GBSpace.xs)
                .padding(.bottom, 140)
            }
            .scrollIndicators(.hidden)
            .paperBackground()
            .safeAreaInset(edge: .bottom) { startBar }
            .sheet(item: $previewTemplate) { template in
                TemplatePreviewSheet(template: template) {
                    previewTemplate = nil
                    editingTemplate = template
                }
            }
            .sheet(item: $editingTemplate) { template in
                TemplateEditorView(template: template)
            }
            .sheet(isPresented: $showingPicker) { BlockedAppsPicker() }
        }
    }

    // MARK: Header

    private var header: some View {
        let week = store.week
        return VStack(alignment: .leading, spacing: GBSpace.xs) {
            Text("\(Date.now.formatted(.dateTime.weekday(.wide))) · Week \(TrainingCalendar.weekNumber(.now))")
                .kicker()
            Group {
                if week.isComplete {
                    Text("\(week.count) of \(week.target).\n") + Text("Week's done.").foregroundStyle(GBColor.orange)
                } else {
                    Text("\(week.count) of \(week.target)\n") + Text("this week.").foregroundStyle(GBColor.fog)
                }
            }
            .font(GBFont.hero(40))
            .foregroundStyle(GBColor.ink)
            .lineSpacing(-4)
            .contentTransition(.numericText())
        }
        .padding(.top, GBSpace.md)
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: GBSpace.lg) {
            WeekStrip(week: store.week)
            Rectangle().fill(GBColor.hairline).frame(height: 1)
            HStack(spacing: GBSpace.xs) {
                Image(systemName: store.streakWeeks > 0 ? "lock.fill" : "lock.open")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(store.streakWeeks > 0 ? GBColor.orange : GBColor.fog)
                    .frame(width: 20)
                streakText
                    .font(GBFont.body(15))
                Spacer()
            }
        }
        .padding(GBSpace.lg)
        .solidCard()
    }

    @ViewBuilder
    private var streakText: some View {
        let weeks = store.streakWeeks
        let week = store.week
        if weeks > 0 {
            (Text(weeks == 1 ? "1 week" : "\(weeks) weeks").fontWeight(.semibold).foregroundStyle(GBColor.ink)
                + Text(" locked in").foregroundStyle(GBColor.steel))
        } else if week.remaining > 0 {
            Text("Hit \(week.target) this week to start a streak.").foregroundStyle(GBColor.steel)
        } else {
            Text("First week locked in.").foregroundStyle(GBColor.steel)
        }
    }

    // MARK: Templates

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: GBSpace.sm) {
            HStack {
                Text("Templates").kicker()
                Spacer()
                Button {
                    Haptics.tap()
                    editingTemplate = WorkoutTemplate(name: "", exercises: [])
                } label: {
                    Label("New", systemImage: "plus")
                        .font(GBFont.label(14))
                        .foregroundStyle(GBColor.ink)
                }
            }
            .padding(.horizontal, GBSpace.xxs)

            if store.templates.isEmpty {
                Text("Save a routine once, start it in one tap.")
                    .font(GBFont.body(15))
                    .foregroundStyle(GBColor.steel)
                    .padding(.vertical, GBSpace.sm)
            }

            VStack(spacing: GBSpace.xs) {
                ForEach(store.templates) { template in
                    TemplateRow(
                        template: template,
                        isSelected: template.id == selectedTemplate?.id,
                        onSelect: {
                            Haptics.tap()
                            withAnimation(.snappy) { selectedTemplateID = template.id }
                        },
                        onOpen: { previewTemplate = template }
                    )
                }
            }
        }
    }

    // MARK: Start

    private var startBar: some View {
        VStack(spacing: GBSpace.xs) {
            if store.activeWorkout != nil {
                Button {
                    store.isWorkoutPresented = true
                } label: {
                    Label("Resume workout", systemImage: "lock.fill")
                }
                .buttonStyle(.primary)
            } else {
                Button {
                    store.startWorkout(from: selectedTemplate)
                } label: {
                    Text(selectedTemplate.map { "Start \($0.name)" } ?? "Start Workout")
                        .contentTransition(.opacity)
                }
                .buttonStyle(.primary)

                HStack(spacing: GBSpace.md) {
                    blockingLine
                    Spacer()
                    Button("Empty workout") { store.startWorkout(from: nil) }
                        .buttonStyle(.quiet)
                        .font(GBFont.label(14))
                }
                .padding(.horizontal, GBSpace.xs)
            }
        }
        .padding(.horizontal, GBSpace.margin)
        .padding(.bottom, GBSpace.xs)
    }

    @ViewBuilder
    private var blockingLine: some View {
        let label: String = {
            if !store.profile.blockingEnabled { return "App blocking is off" }
            if !screenTime.isSupported { return "Blocking needs a real iPhone" }
            if screenTime.state != .approved { return "Allow Screen Time to lock apps" }
            if !screenTime.hasSelection { return "Choose apps to lock" }
            return "\(screenTime.selectionSummary) lock when you start"
        }()
        let actionable = store.profile.blockingEnabled && screenTime.isSupported && !screenTime.willBlock
        Button {
            guard actionable else { return }
            Task {
                if screenTime.state != .approved { await screenTime.requestAuthorization() }
                if screenTime.state == .approved { showingPicker = true }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: screenTime.willBlock && store.profile.blockingEnabled ? "lock.fill" : "lock.open")
                    .font(.system(size: 11, weight: .bold))
                Text(label)
            }
            .font(GBFont.label(13))
            .foregroundStyle(actionable ? GBColor.orange : GBColor.steel)
        }
        .buttonStyle(.plain)
        .disabled(!actionable)
    }
}

// MARK: - Template row

struct TemplateRow: View {
    @Environment(AppStore.self) private var store
    var template: WorkoutTemplate
    var isSelected: Bool
    var onSelect: () -> Void
    var onOpen: () -> Void

    var body: some View {
        HStack(spacing: GBSpace.sm) {
            Button(action: onSelect) {
                HStack(spacing: GBSpace.sm) {
                    ZStack {
                        Circle().strokeBorder(isSelected ? GBColor.orange : GBColor.mist, lineWidth: 2)
                        if isSelected { Circle().fill(GBColor.orange).padding(5) }
                    }
                    .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(template.name.isEmpty ? "Untitled" : template.name)
                            .font(GBFont.headline(17))
                            .foregroundStyle(GBColor.ink)
                        Text(summary)
                            .font(GBFont.body(14))
                            .foregroundStyle(GBColor.steel)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                Haptics.tap()
                onOpen()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GBColor.steel)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Template details")
        }
        .padding(.leading, GBSpace.md)
        .padding(.trailing, GBSpace.xs)
        .padding(.vertical, GBSpace.sm)
        .solidCard(cornerRadius: GBRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: GBRadius.md, style: .continuous)
                .strokeBorder(isSelected ? GBColor.orange.opacity(0.9) : .clear, lineWidth: 1.5)
        )
    }

    private var summary: String {
        let names = template.exercises.compactMap { store.exercise($0.exerciseID)?.name }
        if names.isEmpty { return "No exercises yet" }
        return names.joined(separator: ", ")
    }
}

// MARK: - Template preview

struct TemplatePreviewSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var template: WorkoutTemplate
    var onEdit: () -> Void
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GBSpace.lg) {
                    Text("\(template.exercises.count) exercises · \(template.exercises.reduce(0) { $0 + $1.sets }) sets")
                        .font(GBFont.body(15))
                        .foregroundStyle(GBColor.steel)

                    VStack(spacing: 0) {
                        ForEach(Array(template.exercises.enumerated()), id: \.element.id) { index, item in
                            let exercise = store.exercise(item.exerciseID)
                            HStack(spacing: GBSpace.sm) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise?.displayName ?? "Unknown exercise")
                                        .font(GBFont.headline(16))
                                        .foregroundStyle(GBColor.ink)
                                    Text(Format.muscles(exercise))
                                        .font(GBFont.body(13))
                                        .foregroundStyle(GBColor.steel)
                                }
                                Spacer()
                                Text("\(item.sets) × \(item.reps.map(String.init) ?? "—")")
                                    .font(GBFont.number(15, weight: .medium))
                                    .foregroundStyle(GBColor.ink2)
                            }
                            .padding(.horizontal, GBSpace.md)
                            .padding(.vertical, GBSpace.sm)
                            if index < template.exercises.count - 1 {
                                Rectangle().fill(GBColor.hairline).frame(height: 1).padding(.leading, GBSpace.md)
                            }
                        }
                    }
                    .solidCard(cornerRadius: GBRadius.md)

                    Button("Delete template", role: .destructive) { confirmDelete = true }
                        .buttonStyle(.quiet)
                        .foregroundStyle(GBColor.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.top, GBSpace.xs)
                }
                .padding(GBSpace.margin)
                .padding(.bottom, 100)
            }
            .paperBackground()
            .navigationTitle(template.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { onEdit() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Start \(template.name)") {
                    dismiss()
                    store.startWorkout(from: template)
                }
                .buttonStyle(.primary)
                .disabled(store.activeWorkout != nil || template.exercises.isEmpty)
                .padding(.horizontal, GBSpace.margin)
                .padding(.bottom, GBSpace.xs)
            }
            .confirmationDialog("Delete \(template.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete template", role: .destructive) {
                    store.deleteTemplate(template.id)
                    dismiss()
                }
            } message: {
                Text("Past workouts stay in your history.")
            }
        }
        .presentationDetents([.medium, .large])
    }
}
