import SwiftUI
import UIKit

struct JourneyWheel: UIViewRepresentable {
  let values: [Double]
  let unit: String
  let id: String
  @Binding var value: Double
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> UIPickerView {
    let picker = UIPickerView()
    picker.dataSource = context.coordinator
    picker.delegate = context.coordinator
    picker.accessibilityIdentifier = id
    picker.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return picker
  }
  func updateUIView(_ picker: UIPickerView, context: Context) {
    let changed =
      context.coordinator.parent.values != values || context.coordinator.parent.unit != unit
    context.coordinator.parent = self
    if changed { picker.reloadAllComponents() }
    let index = values.firstIndex(of: value) ?? 0
    if picker.selectedRow(inComponent: 0) != index {
      picker.selectRow(index, inComponent: 0, animated: false)
    }
    picker.accessibilityLabel = unit
  }
  final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    var parent: JourneyWheel
    init(_ parent: JourneyWheel) { self.parent = parent }
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
      parent.values.count
    }
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
      58
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int)
      -> String?
    {
      JourneyFormat.number(parent.values[row]) + " " + parent.unit
    }
    func pickerView(
      _ pickerView: UIPickerView, attributedTitleForRow row: Int,
      forComponent component: Int
    ) -> NSAttributedString? {
      NSAttributedString(
        string: JourneyFormat.number(parent.values[row]) + " " + parent.unit,
        attributes: [
          .font: GymType.uiFont(30, weight: 500), .foregroundColor: UIColor(GymColor.ink),
        ])
    }
    func pickerView(
      _ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int,
      reusing view: UIView?
    ) -> UIView {
      let label = (view as? UILabel) ?? UILabel()
      label.text = JourneyFormat.number(parent.values[row]) + " " + parent.unit
      label.textAlignment = .center
      label.font = UIFontMetrics(forTextStyle: .title2).scaledFont(
        for: GymType.uiFont(32, weight: 500), maximumPointSize: 42)
      label.textColor = UIColor(GymColor.ink)
      label.adjustsFontForContentSizeCategory = true
      label.adjustsFontSizeToFitWidth = true
      label.minimumScaleFactor = 0.7
      label.accessibilityLabel = label.text
      return label
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
      parent.value = parent.values[row]
      // UIPickerView provides system selection feedback. Do not double it with app haptics.
    }
  }
}


/// Native system material and discrete ticks; the binding stores whole training days.
struct TrainingDaysSlider: UIViewRepresentable {
  @Binding var value: Double
  var haptics: Bool
  var label: String
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeUIView(context: Context) -> UISlider {
    let slider = UISlider()
    slider.minimumValue = 0
    slider.maximumValue = 1
    slider.minimumTrackTintColor = UIColor(GymColor.red)
    slider.accessibilityIdentifier = "baseline.days"
    if #available(iOS 26.0, *) {
      slider.trackConfiguration = .init(numberOfTicks: 7)
    }
    slider.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
    return slider
  }
  func updateUIView(_ slider: UISlider, context: Context) {
    context.coordinator.parent = self
    let normalized = Float((value - 1) / 6)
    if abs(slider.value - normalized) > 0.001 { slider.value = normalized }
    slider.accessibilityLabel = label
    slider.accessibilityValue = "\(Int(value))"
  }
  final class Coordinator: NSObject {
    var parent: TrainingDaysSlider
    init(_ parent: TrainingDaysSlider) { self.parent = parent }
    @objc func changed(_ slider: UISlider) {
      let next = Double(min(7, max(1, (slider.value * 6).rounded() + 1)))
      if next != parent.value {
        parent.value = next
        if parent.haptics { UISelectionFeedbackGenerator().selectionChanged() }
      }
      if #unavailable(iOS 26.0) { slider.value = Float((next - 1) / 6) }
    }
  }
}

struct RestCounter: View {
  let started: Date
  var example = false
  @EnvironmentObject private var store: GymStore
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(spacing: 8) {
        Text(store.t("Rest")).font(GymType.body(15)).foregroundStyle(GymColor.dim)
        Text(clockString(max(0, Int(context.date.timeIntervalSince(started)))))
          .font(GymType.hero(64)).monospacedDigit()
          .accessibilityIdentifier(example ? "journey.rest.counter" : "rest.elapsed")
      }.frame(maxWidth: .infinity)
    }
  }
}

/// A recognizable phone, with a finite scrolling-to-phone-down sequence.
struct JourneyPhone: View {
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  @EnvironmentObject private var store: GymStore
  @State private var down = false
  @State private var scroll = false
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 32).fill(GymColor.ink)
      ZStack {
        RoundedRectangle(cornerRadius: 26).fill(GymColor.surface)
        VStack(alignment: .leading, spacing: 18) {
          ForEach(0..<4) { index in
            VStack(alignment: .leading, spacing: 8) {
              RoundedRectangle(cornerRadius: 4).fill(GymColor.dim.opacity(0.15))
                .frame(height: 42)
              Capsule().fill(GymColor.dim.opacity(0.25)).frame(width: index % 2 == 0 ? 80 : 104, height: 4)
              Capsule().fill(GymColor.dim.opacity(0.12)).frame(width: 64, height: 4)
            }
          }
        }.padding(18).offset(y: scroll ? -36 : 14)
          .frame(width: 114, height: 208).clipped()
        Capsule().fill(GymColor.ink).frame(width: 48, height: 13).frame(maxHeight: .infinity, alignment: .top).padding(.top, 8)
      }.padding(6).clipShape(RoundedRectangle(cornerRadius: 32)).opacity(down ? 0 : 1)
      if down {
        VStack {
          HStack(spacing: 5) {
            Circle().fill(GymColor.dim.opacity(0.8)).frame(width: 12, height: 12)
            Circle().fill(GymColor.dim.opacity(0.8)).frame(width: 12, height: 12)
            Spacer()
          }
          Spacer()
        }.padding(20).transition(.opacity)
      }
    }.frame(width: 126, height: 220)
      .clipShape(RoundedRectangle(cornerRadius: 28))
      .rotation3DEffect(.degrees(down ? -10 : 0), axis: (x: 1, y: 0, z: 0))
      .rotationEffect(.degrees(down ? -12 : 5))
      .accessibilityElement().accessibilityLabel(store.t(down || reduceMotion ? "Phone down" : "Phone scrolling"))
      .accessibilityIdentifier("journey.phone")
      .task {
        if reduceMotion { down = true; return }
        withAnimation(.easeInOut(duration: 0.7)) { scroll = true }
        try? await Task.sleep(for: .milliseconds(850))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.5)) { down = true }
      }
  }
}
