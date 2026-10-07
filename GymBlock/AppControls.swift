import SwiftUI

/// Small Liquid Glass controls shared by Home and the workout.
struct GlassIconButton: View {
  let symbol: String
  let label: String
  var id = ""
  let action: () -> Void
  var body: some View {
    let icon = Image(systemName: symbol).font(.system(.body, weight: .semibold)).foregroundStyle(JourneyColor.text)
      .frame(width: 44, height: 44)
    Group {
      if #available(iOS 26.0, *) {
        Button(action: action) { icon }.buttonStyle(.glass).buttonBorderShape(.circle)
      } else {
        Button(action: action) { icon.background(Circle().fill(JourneyColor.fill)) }.buttonStyle(JourneyPressStyle())
      }
    }.accessibilityLabel(label).accessibilityIdentifier(id)
  }
}

struct GlassPillButton: View {
  let title: String
  var id = ""
  let action: () -> Void
  var body: some View {
    let label = Text(title).font(JourneyType.label).foregroundStyle(JourneyColor.text)
      .padding(.horizontal, 6).frame(minHeight: 32)
    Group {
      if #available(iOS 26.0, *) {
        Button(action: action) { label }.buttonStyle(.glass).buttonBorderShape(.capsule)
      } else {
        Button(action: action) { label.padding(.horizontal, 10).frame(minHeight: 44).background(Capsule().fill(JourneyColor.fill)) }
          .buttonStyle(JourneyPressStyle())
      }
    }.accessibilityIdentifier(id)
  }
}

/// A round step button inside a glass stepper. Holding it repeats.
struct StepButton: View {
  let symbol: String
  let label: String
  let id: String
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: symbol).font(.system(.title3, weight: .semibold)).foregroundStyle(JourneyColor.text)
        .frame(width: 44, height: 44).background(Circle().fill(Color.white.opacity(0.08)))
        .contentShape(Circle())
    }.buttonStyle(JourneyPressStyle()).buttonRepeatBehavior(.enabled)
      .accessibilityLabel(label).accessibilityIdentifier(id)
  }
}

/// Time as m:ss, or h:mm:ss past an hour.
func clockText(_ seconds: Int) -> String {
  let s = max(0, seconds)
  return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : clockString(s)
}
