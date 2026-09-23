import Charts
import SwiftUI

/// You: who you are, how consistent you've been, your best lifts. Settings
/// live behind the gear.
struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: GBSpace.xxl) {
                    header
                    statsBand
                    weeksChart
                    topLifts
                }
                .padding(.horizontal, GBSpace.margin)
                .padding(.bottom, 120)
            }
            .paperBackground()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
            }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.profile.name.isEmpty ? "You" : store.profile.name)
                .font(GBFont.hero(34))
                .foregroundStyle(GBColor.ink)
            if let username = store.myPublicProfile?.username {
                Text("@\(username)").font(GBFont.body(16)).foregroundStyle(GBColor.steel)
            }
        }
        .padding(.top, GBSpace.xs)
    }

    private var statsBand: some View {
        HStack(spacing: 0) {
            stat("Workouts", "\(store.workouts.count)")
            stat("Streak", store.streakWeeks == 1 ? "1 wk" : "\(store.streakWeeks) wk", accent: store.streakWeeks > 0)
            stat("Consistency", store.consistency.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
        }
    }

    private func stat(_ label: String, _ value: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).kicker()
            Text(value)
                .font(GBFont.stat(26))
                .foregroundStyle(accent ? GBColor.orange : GBColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Chart

    private struct WeekBar: Identifiable {
        var start: Date
        var count: Int
        var id: Date { start }
    }

    private var weeks: [WeekBar] {
        let cal = TrainingCalendar.calendar
        let thisWeek = TrainingCalendar.startOfWeek(for: .now)
        let days = Streak.trainingDays(store.workouts)
        return (0..<12).reversed().compactMap { offset in
            guard let start = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeek) else { return nil }
            let count = days.filter { TrainingCalendar.startOfWeek(for: $0) == start }.count
            return WeekBar(start: start, count: count)
        }
    }

    private var weeksChart: some View {
        let target = store.profile.weeklyTarget
        return VStack(alignment: .leading, spacing: GBSpace.md) {
            HStack {
                Text("Last 12 weeks").kicker()
                Spacer()
                Text("Target \(target)/wk").font(GBFont.label(13)).foregroundStyle(GBColor.steel)
            }
            Chart {
                ForEach(weeks) { week in
                    BarMark(
                        x: .value("Week", week.start, unit: .weekOfYear),
                        y: .value("Days", week.count),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(week.count >= target ? GBColor.orange : GBColor.mist)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                RuleMark(y: .value("Target", target))
                    .foregroundStyle(GBColor.ink.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
            .chartYScale(domain: 0...7)
            .chartYAxis {
                AxisMarks(values: [0, target, 7]) { _ in
                    AxisValueLabel().font(GBFont.number(11, weight: .medium)).foregroundStyle(GBColor.fog)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 3)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                        .font(GBFont.body(11))
                        .foregroundStyle(GBColor.fog)
                }
            }
            .frame(height: 160)
        }
        .padding(GBSpace.lg)
        .solidCard()
    }

    // MARK: Top lifts

    @ViewBuilder
    private var topLifts: some View {
        let big = ["squat-bb", "bench-press-bb", "deadlift-bb", "ohp-bb"]
        let records = store.records
        let shown = big.compactMap { records[$0] } + records.values
            .filter { !big.contains($0.exerciseID) }
            .sorted { $0.estimatedOneRepMax > $1.estimatedOneRepMax }
        if !shown.isEmpty {
            VStack(alignment: .leading, spacing: GBSpace.sm) {
                Text("Best lifts").kicker()
                VStack(spacing: 0) {
                    ForEach(Array(shown.prefix(5).enumerated()), id: \.element.id) { index, record in
                        HStack {
                            Text(store.exercise(record.exerciseID)?.displayName ?? "")
                                .font(GBFont.headline(16)).foregroundStyle(GBColor.ink)
                            Spacer()
                            Text("\(Format.weight(record.weight, unit: store.profile.unit)) \(store.profile.unit.rawValue) × \(record.reps)")
                                .font(GBFont.number(15, weight: .semibold)).foregroundStyle(GBColor.ink2)
                        }
                        .padding(GBSpace.md)
                        if index < min(shown.count, 5) - 1 {
                            Rectangle().fill(GBColor.hairline).frame(height: 1).padding(.leading, GBSpace.md)
                        }
                    }
                }
                .solidCard(cornerRadius: GBRadius.md)
            }
        }
    }
}
