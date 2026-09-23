import SwiftUI

/// The signature element: Monday → Sunday as seven circles. Trained days are
/// filled orange, today is outlined in ink, everything else is quiet mist.
/// Reads in half a second, no legend needed. Used on Today (large, labelled)
/// and on friend rows (compact).
struct WeekStrip: View {
    var week: WeekProgress
    var compact = false
    var now: Date = .now

    private let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(week.days.enumerated()), id: \.offset) { index, day in
                let trained = week.trained.contains(index)
                let isToday = Calendar.current.isDate(day, inSameDayAs: now)
                VStack(spacing: compact ? 0 : 7) {
                    dot(trained: trained, isToday: isToday)
                    if !compact {
                        Text(letters[index])
                            .font(.system(size: 12, weight: isToday ? .bold : .medium))
                            .foregroundStyle(isToday ? GBColor.ink : GBColor.fog)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement()
                .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide)))\(trained ? ", trained" : "")\(isToday ? ", today" : "")")
            }
        }
    }

    @ViewBuilder
    private func dot(trained: Bool, isToday: Bool) -> some View {
        let size: CGFloat = compact ? 14 : 30
        ZStack {
            Circle()
                .fill(trained ? GBColor.orange : GBColor.mist.opacity(compact ? 0.8 : 0.6))
            if isToday && !trained {
                Circle().strokeBorder(GBColor.ink, lineWidth: compact ? 1.5 : 2)
            }
            if trained && !compact {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: trained)
    }
}
