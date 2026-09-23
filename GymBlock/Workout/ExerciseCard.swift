import SwiftUI

struct SetField: Hashable {
    enum Column: Hashable { case weight, reps, seconds }
    var setID: UUID
    var column: Column
}

/// One exercise in the logger: name, note, rest length, the set table and
/// "Add set". Reads a snapshot of the log; every edit goes through the store.
struct ExerciseCard: View {
    @Environment(AppStore.self) private var store
    var log: ExerciseLog
    @Binding var recordSets: Set<UUID>
    var focusedField: FocusState<SetField?>.Binding
    @State private var showingNote = false
    @State private var replacing = false

    private var exercise: Exercise? { store.exercise(log.exerciseID) }
    private var metric: MetricKind { exercise?.metric ?? .weightReps }
    private var previous: [SetEntry] { store.previousSets(for: log.exerciseID) }

    var body: some View {
        VStack(alignment: .leading, spacing: GBSpace.sm) {
            header
            if showingNote || !log.note.isEmpty { noteField }
            restButton
            columnHeader
            VStack(spacing: 2) {
                ForEach(Array(log.sets.enumerated()), id: \.element.id) { index, set in
                    SetRow(
                        set: set,
                        number: workingNumber(at: index),
                        previous: index < previous.count ? previous[index] : nil,
                        placeholderWeight: placeholderWeight(at: index),
                        placeholderReps: placeholderReps(at: index),
                        metric: metric,
                        unit: store.profile.unit,
                        isRecord: recordSets.contains(set.id),
                        focusedField: focusedField,
                        onChange: { store.updateSet($0, in: log.id) },
                        onToggle: { toggle(set, at: index) },
                        onDelete: {
                            withAnimation(.snappy) { store.removeSet(set.id, from: log.id) }
                        }
                    )
                }
            }
            .padding(.horizontal, -GBSpace.sm)

            Button {
                withAnimation(.snappy) { store.addSet(to: log.id) }
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(GBFont.label(15))
            }
            .buttonStyle(GlassButtonStyle(height: 42))
        }
        .padding(GBSpace.md)
        .solidCard()
        .sheet(isPresented: $replacing) {
            ExercisePickerView(title: "Replace exercise", allowsMultiple: false) { ids in
                guard let id = ids.first else { return }
                var updated = log
                updated.exerciseID = id
                updated.sets = updated.sets.map { var s = $0; s.weight = nil; s.reps = nil; s.isDone = false; return s }
                store.updateLog(updated)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: GBSpace.xs) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise?.displayName ?? "Exercise")
                    .font(GBFont.headline(18))
                    .foregroundStyle(GBColor.ink)
                Text(Format.muscles(exercise))
                    .font(GBFont.body(13))
                    .foregroundStyle(GBColor.steel)
            }
            Spacer()
            Menu {
                Button(log.note.isEmpty ? "Add note" : "Edit note", systemImage: "note.text") {
                    showingNote = true
                }
                Button("Replace exercise", systemImage: "arrow.left.arrow.right") { replacing = true }
                Divider()
                Button("Remove exercise", systemImage: "trash", role: .destructive) {
                    Haptics.warning()
                    withAnimation(.snappy) { store.removeExercise(log.id) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GBColor.steel)
                    .frame(width: 36, height: 30)
                    .contentShape(Rectangle())
            }
        }
    }

    private var noteField: some View {
        TextField("Add a note — seat height, grip, how it felt", text: Binding(
            get: { log.note },
            set: { var l = log; l.note = $0; store.updateLog(l) }
        ), axis: .vertical)
        .font(GBFont.body(15))
        .foregroundStyle(GBColor.ink2)
        .lineLimit(1...4)
    }

    private var restButton: some View {
        Menu {
            ForEach([0, 30, 45, 60, 90, 120, 150, 180, 240, 300], id: \.self) { seconds in
                Button {
                    var l = log
                    l.restSeconds = seconds
                    store.updateLog(l)
                    Haptics.tap()
                } label: {
                    if seconds == log.restSeconds {
                        Label(Format.rest(seconds), systemImage: "checkmark")
                    } else {
                        Text(Format.rest(seconds))
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "timer")
                Text("Rest \(Format.rest(log.restSeconds))")
            }
            .font(GBFont.label(13))
            .foregroundStyle(log.restSeconds > 0 ? GBColor.orange : GBColor.fog)
        }
    }

    private var columnHeader: some View {
        HStack(spacing: GBSpace.xs) {
            Text("Set").frame(width: 30)
            Text("Previous").frame(maxWidth: .infinity)
            switch metric {
            case .weightReps:
                Text(store.profile.unit.rawValue).frame(width: SetRow.fieldWidth)
                Text("Reps").frame(width: SetRow.fieldWidth)
            case .reps:
                Text("Reps").frame(width: SetRow.fieldWidth)
            case .time, .distanceTime:
                Text("Secs").frame(width: SetRow.fieldWidth)
            }
            Image(systemName: "checkmark").frame(width: 36)
        }
        .font(GBFont.kicker(11))
        .tracking(0.8)
        .textCase(.uppercase)
        .foregroundStyle(GBColor.fog)
    }

    // MARK: Logic

    /// Working-set number, skipping warm-ups ("W, 1, 2, 3").
    private func workingNumber(at index: Int) -> Int {
        log.sets.prefix(index + 1).filter { $0.kind != .warmup }.count
    }

    private func placeholderWeight(at index: Int) -> Double? {
        if index < previous.count, let w = previous[index].weight { return w }
        return log.sets.prefix(index).last { $0.weight != nil }?.weight
    }

    private func placeholderReps(at index: Int) -> Int? {
        if index < previous.count, let r = previous[index].reps { return r }
        if let target = log.sets[index].targetReps { return target }
        return log.sets.prefix(index).last { $0.reps != nil }?.reps
    }

    private func toggle(_ set: SetEntry, at index: Int) {
        focusedField.wrappedValue = nil
        let isPR = store.toggleSetDone(
            set.id, in: log.id,
            placeholderWeight: placeholderWeight(at: index),
            placeholderReps: placeholderReps(at: index)
        )
        if isPR {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { _ = recordSets.insert(set.id) }
        } else if set.isDone {
            recordSets.remove(set.id)
        }
    }
}

// MARK: - Set row

struct SetRow: View {
    static let fieldWidth: CGFloat = 64

    var set: SetEntry
    var number: Int
    var previous: SetEntry?
    var placeholderWeight: Double?
    var placeholderReps: Int?
    var metric: MetricKind
    var unit: WeightUnit
    var isRecord: Bool
    var focusedField: FocusState<SetField?>.Binding
    var onChange: (SetEntry) -> Void
    var onToggle: () -> Void
    var onDelete: () -> Void

    @State private var weightText = ""
    @State private var repsText = ""
    @State private var secondsText = ""

    var body: some View {
        HStack(spacing: GBSpace.xs) {
            marker
            previousColumn
            fields
            checkButton
        }
        .padding(.horizontal, GBSpace.sm)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(set.isDone ? GBColor.orangeSoft : .clear)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: set.isDone)
        .onAppear(perform: syncText)
        .onChange(of: set) { _, _ in syncText() }
    }

    // MARK: Columns

    private var marker: some View {
        Menu {
            ForEach(SetKind.allCases, id: \.self) { kind in
                Button {
                    var s = set
                    s.kind = kind
                    onChange(s)
                    Haptics.tap()
                } label: {
                    if kind == set.kind { Label(kind.name, systemImage: "checkmark") } else { Text(kind.name) }
                }
            }
            Divider()
            Button("Delete set", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Text(set.kind.marker ?? "\(number)")
                .font(GBFont.number(16, weight: .bold))
                .foregroundStyle(markerColor)
                .frame(width: 30, height: 34)
                .background(GBColor.paper.opacity(set.isDone ? 0 : 1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var markerColor: Color {
        switch set.kind {
        case .warmup: GBColor.warmup
        case .drop, .failure: GBColor.danger
        case .normal: GBColor.ink
        }
    }

    @ViewBuilder
    private var previousColumn: some View {
        Group {
            if isRecord {
                Text("PR")
                    .font(.system(size: 12, weight: .heavy).width(.expanded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(GBColor.orange, in: Capsule())
                    .transition(.scale.combined(with: .opacity))
            } else if let previous {
                Button {
                    var s = set
                    s.weight = previous.weight
                    s.reps = previous.reps
                    s.seconds = previous.seconds
                    onChange(s)
                    Haptics.tap()
                } label: {
                    Text(Format.set(previous, unit: unit, metric: metric).replacingOccurrences(of: " \(unit.rawValue)", with: ""))
                        .font(GBFont.number(14, weight: .medium))
                        .foregroundStyle(GBColor.fog)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.plain)
            } else {
                Text("—").foregroundStyle(GBColor.mist)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var fields: some View {
        switch metric {
        case .weightReps:
            numberField($weightText, placeholder: placeholderWeight.map { Format.weight($0, unit: unit) } ?? unit.rawValue,
                        column: .weight, decimal: true)
            numberField($repsText, placeholder: placeholderReps.map(String.init) ?? "0", column: .reps, decimal: false)
        case .reps:
            numberField($repsText, placeholder: placeholderReps.map(String.init) ?? "0", column: .reps, decimal: false)
        case .time, .distanceTime:
            numberField($secondsText, placeholder: previous?.seconds.map(String.init) ?? "60", column: .seconds, decimal: false)
        }
    }

    private func numberField(_ text: Binding<String>, placeholder: String, column: SetField.Column, decimal: Bool) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundStyle(GBColor.fog))
            .keyboardType(decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center)
            .font(GBFont.number(17, weight: .bold))
            .foregroundStyle(GBColor.ink)
            .frame(width: Self.fieldWidth, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(set.isDone ? Color.clear : GBColor.paper)
            )
            .focused(focusedField, equals: SetField(setID: set.id, column: column))
            .onChange(of: text.wrappedValue) { _, new in commit(new, column: column) }
    }

    private var checkButton: some View {
        Button(action: onToggle) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(set.isDone ? GBColor.orange : GBColor.paper)
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(set.isDone ? .white : GBColor.fog)
                    .symbolEffect(.bounce, value: set.isDone)
            }
            .frame(width: 36, height: 34)
            .scaleEffect(set.isDone ? 1 : 0.96)
        }
        .buttonStyle(ScaleOnPress(scale: 0.88))
        .accessibilityLabel(set.isDone ? "Set done" : "Mark set done")
    }

    // MARK: Text sync

    private func syncText() {
        let w = Format.weight(set.weight, unit: unit)
        if parseDouble(weightText).map({ unit.storage($0) }) != set.weight { weightText = w }
        if Int(repsText) != set.reps { repsText = set.reps.map(String.init) ?? "" }
        if Int(secondsText) != set.seconds { secondsText = set.seconds.map(String.init) ?? "" }
    }

    private func commit(_ text: String, column: SetField.Column) {
        var s = set
        switch column {
        case .weight: s.weight = parseDouble(text).map { unit.storage($0) }
        case .reps: s.reps = Int(text)
        case .seconds: s.seconds = Int(text)
        }
        if s != set { onChange(s) }
    }

    private func parseDouble(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }
}
