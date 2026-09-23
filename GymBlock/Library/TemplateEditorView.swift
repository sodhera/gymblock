import SwiftUI

/// Create or edit a template: a name and an ordered list of exercises, each
/// with a set count, a rep target and a rest length.
struct TemplateEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var template: WorkoutTemplate
    @State private var picking = false

    private var isNew: Bool { !store.templates.contains { $0.id == template.id } }
    private var canSave: Bool {
        !template.name.trimmingCharacters(in: .whitespaces).isEmpty && !template.exercises.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Template name", text: $template.name, prompt: Text("Push day").foregroundStyle(GBColor.fog))
                        .font(GBFont.title(22))
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
                }

                Section {
                    ForEach($template.exercises) { $item in
                        TemplateExerciseRow(item: $item)
                    }
                    .onDelete { template.exercises.remove(atOffsets: $0) }
                    .onMove { template.exercises.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        picking = true
                    } label: {
                        Label("Add exercises", systemImage: "plus")
                            .font(GBFont.label(16))
                            .foregroundStyle(GBColor.orange)
                    }
                } header: {
                    Text("Exercises").kicker()
                } footer: {
                    if !template.exercises.isEmpty {
                        Text("Drag to reorder. Swipe to remove.")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .paperBackground()
            .navigationTitle(isNew ? "New template" : "Edit template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        template.name = template.name.trimmingCharacters(in: .whitespaces)
                        store.saveTemplate(template)
                        Haptics.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $picking) {
                ExercisePickerView(title: "Add exercises") { ids in
                    template.exercises += ids.map {
                        TemplateExercise(exerciseID: $0, sets: 3, reps: 10, restSeconds: store.profile.defaultRestSeconds)
                    }
                }
            }
        }
    }
}

private struct TemplateExerciseRow: View {
    @Environment(AppStore.self) private var store
    @Binding var item: TemplateExercise

    var body: some View {
        let exercise = store.exercise(item.exerciseID)
        VStack(alignment: .leading, spacing: GBSpace.xs) {
            Text(exercise?.displayName ?? "Exercise")
                .font(GBFont.headline(16))
                .foregroundStyle(GBColor.ink)
            HStack(spacing: GBSpace.md) {
                MiniStepper(label: "Sets", value: $item.sets, range: 1...10)
                if exercise?.metric != .time {
                    MiniStepper(label: "Reps", value: Binding(
                        get: { item.reps ?? 10 },
                        set: { item.reps = $0 }
                    ), range: 1...50)
                }
                Spacer()
                Menu {
                    ForEach([0, 60, 90, 120, 150, 180, 240], id: \.self) { s in
                        Button(Format.rest(s)) { item.restSeconds = s }
                    }
                } label: {
                    Label(Format.rest(item.restSeconds), systemImage: "timer")
                        .font(GBFont.label(13))
                        .foregroundStyle(GBColor.steel)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct MiniStepper: View {
    var label: String
    @Binding var value: Int
    var range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 6) {
            Text(label).font(GBFont.body(13)).foregroundStyle(GBColor.steel)
            HStack(spacing: 0) {
                button("minus") { value = max(range.lowerBound, value - 1) }
                Text("\(value)")
                    .font(GBFont.number(15, weight: .bold))
                    .frame(minWidth: 24)
                    .contentTransition(.numericText())
                button("plus") { value = min(range.upperBound, value + 1) }
            }
            .background(GBColor.paper, in: Capsule())
        }
    }

    private func button(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(GBColor.ink)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
    }
}
