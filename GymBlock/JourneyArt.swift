import SwiftUI
import UIKit

private func journeyWheelFont(_ size: CGFloat) -> UIFont {
  let base = UIFont.systemFont(ofSize: size, weight: .semibold)
  let mono = base.fontDescriptor.addingAttributes([
    .featureSettings: [[UIFontDescriptor.FeatureKey.type: kNumberSpacingType, UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector]]
  ])
  return UIFontMetrics(forTextStyle: .title2).scaledFont(for: UIFont(descriptor: mono, size: size), maximumPointSize: size * 1.4)
}

/// One native haptic wheel.
struct JourneyWheel: UIViewRepresentable {
  let values: [Double]
  let unit: String
  let id: String
  @Binding var value: Double
  var format: ((Double) -> String)? = nil
  func text(_ v: Double) -> String { format?(v) ?? JourneyFormat.number(v) + " " + unit }
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
    let changed = context.coordinator.parent.values != values || context.coordinator.parent.unit != unit
      || context.coordinator.parent.text(values.first ?? 0) != text(values.first ?? 0)
    context.coordinator.parent = self
    if changed { picker.reloadAllComponents() }
    let index = values.firstIndex(of: value) ?? 0
    if picker.selectedRow(inComponent: 0) != index { picker.selectRow(index, inComponent: 0, animated: false) }
    picker.accessibilityLabel = unit
  }
  final class Coordinator: NSObject, UIPickerViewDataSource, UIPickerViewDelegate {
    var parent: JourneyWheel
    init(_ parent: JourneyWheel) { self.parent = parent }
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { parent.values.count }
    func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat { 52 }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
      parent.text(parent.values[row])
    }
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
      let label = (view as? UILabel) ?? UILabel()
      label.text = parent.text(parent.values[row])
      label.textAlignment = .center
      label.font = journeyWheelFont(30)
      label.textColor = .white
      label.adjustsFontForContentSizeCategory = true
      label.adjustsFontSizeToFitWidth = true
      label.minimumScaleFactor = 0.6
      return label
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
      parent.value = parent.values[row]
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
