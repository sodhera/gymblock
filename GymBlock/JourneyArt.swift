import SwiftUI
import UIKit

struct JourneyTrace: View, Animatable {
  let value: String
  var progress: Double
  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }
  var body: some View {
    ZStack {
      Text(value).font(GymType.hero(40)).foregroundStyle(GymColor.red)
        .opacity(max(0, 1 - progress * 2)).scaleEffect(1 - progress * 0.6)
      Capsule().fill(GymColor.red).frame(width: 36 + progress * 120, height: 8)
        .opacity(sin(progress * .pi))
    }.offset(y: -12)
  }
}

/// The picker owns the only visible value; there is no mirrored number or editor sheet.
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

/// One recurring vocabulary of set marks, never an earned achievement.
struct JourneyMarks: View {
  var count = 3
  var outlined = false
  var progress = 1.0
  var width: CGFloat = 36
  var body: some View {
    HStack(spacing: 12) {
      ForEach(0..<min(count, 7), id: \.self) { i in
        Capsule().fill(outlined ? GymColor.red.opacity(0.06) : GymColor.red)
          .overlay { Capsule().strokeBorder(GymColor.red.opacity(0.65), lineWidth: 1) }
          .frame(width: width, height: 12)
          .opacity(progress > Double(i) / Double(max(count, 1)) ? 1 : 0.1)
      }
    }.accessibilityHidden(true)
  }
}

struct JourneyVisit: View {
  let duration: Int
  let scrolling: Double
  var phoneFree = false
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    VStack(spacing: 16) {
      Text("\(duration) " + store.t("minute visit")).font(GymType.body(14)).foregroundStyle(
        GymColor.dim)
      GeometryReader { g in
        let fraction = max(0, min(1, scrolling / Double(max(duration, 1))))
        HStack(spacing: 4) {
          RoundedRectangle(cornerRadius: 14).fill(GymColor.red.opacity(0.16))
            .overlay(alignment: .leading) {
              JourneyMarks(count: 3, outlined: true, width: 24).padding(.leading, 16)
            }.frame(width: max(0, (g.size.width - 4) * (1 - fraction))).clipped()
          RoundedRectangle(cornerRadius: 14)
            .fill(phoneFree ? GymColor.red.opacity(0.16) : GymColor.ink.opacity(0.12))
            .overlay {
              HStack(spacing: 7) {
                ForEach(0..<4, id: \.self) { _ in
                  Capsule().fill(GymColor.ink.opacity(0.18)).frame(width: 6, height: 24)
                }
              }.opacity(phoneFree ? 0 : 1)
            }.frame(maxWidth: .infinity).clipped()
        }.animation(reduceMotion ? nil : .easeInOut(duration: 1.8), value: phoneFree)
      }.frame(height: 72)
      HStack {
        Label(store.t("Phone-free"), systemImage: "circle.fill").foregroundStyle(GymColor.red)
        Spacer()
        Text(store.t(phoneFree ? "Rest stays" : "Scrolling")).foregroundStyle(GymColor.dim)
      }.font(GymType.body(13))
    }.accessibilityElement(children: .ignore)
      .accessibilityLabel(
        "\(duration) " + store.t("minute visit") + ". "
          + store.t(phoneFree ? "Rest stays. Scrolling goes." : "Estimated scrolling per visit")
          + ": " + JourneyFormat.number(scrolling))
  }
}

struct JourneyMonth: View {
  var days: Int?
  var reveal = true
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var appeared = false
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      ForEach(0..<4, id: \.self) { week in
        VStack(spacing: 12) {
          Text("\(week + 1)").font(GymType.body(13)).foregroundStyle(GymColor.dim)
          ForEach(0..<min(days ?? 3, 7), id: \.self) { day in
            RoundedRectangle(cornerRadius: 9).fill(GymColor.red.opacity(0.045))
              .overlay {
                RoundedRectangle(cornerRadius: 9).strokeBorder(
                  GymColor.red.opacity(0.5), lineWidth: 1)
              }
              .overlay {
                Capsule().fill(GymColor.red.opacity(0.28)).frame(width: 24, height: 4)
              }.frame(height: 27)
              .opacity(appeared || reduceMotion || !reveal ? 1 : 0)
              .offset(y: appeared || reduceMotion || !reveal ? 0 : 12)
              .animation(
                reduceMotion || !reveal
                  ? nil : .easeOut(duration: 0.4).delay(Double(week) * 0.2 + Double(day) * 0.06),
                value: appeared)
          }
        }.frame(maxWidth: .infinity)
      }
    }.onAppear { appeared = true }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(
        store.t(days == nil ? "Example: four weeks" : "Four weeks at your current routine"))
  }
}

struct JourneyRest: View, Animatable {
  var progress: Double
  @EnvironmentObject private var store: GymStore
  var animatableData: Double {
    get { progress }
    set { progress = newValue }
  }
  var body: some View {
    VStack(spacing: 26) {
      Text(JourneyFormat.time(120 * progress)).font(GymType.hero(64)).monospacedDigit()
        .foregroundStyle(GymColor.ink).accessibilityHidden(true)
      HStack(spacing: 16) {
        Capsule().fill(GymColor.red).frame(width: 38, height: 12)
        Capsule().fill(GymColor.red.opacity(0.15)).frame(height: 2)
        Capsule().strokeBorder(GymColor.red, lineWidth: 1.5).frame(width: 38, height: 12)
      }.padding(.horizontal, 28).accessibilityHidden(true)
      Text(store.t("Example rest · 2:00")).font(GymType.body(14)).foregroundStyle(GymColor.dim)
    }.accessibilityElement(children: .ignore).accessibilityLabel(store.t("Example rest · 2:00"))
  }
}

struct JourneyComparison: View {
  var showChange: Bool
  @EnvironmentObject private var store: GymStore
  var body: some View {
    VStack(spacing: 28) {
      Text(store.t("Example")).font(GymType.body(14)).foregroundStyle(GymColor.dim)
      HStack(alignment: .firstTextBaseline, spacing: 20) {
        VStack(spacing: 12) {
          Text("10").font(GymType.hero(52)).foregroundStyle(GymColor.dim)
          Text(store.t("Last time")).font(GymType.body(14)).foregroundStyle(GymColor.dim)
        }
        Image(systemName: "arrow.right").font(.system(size: 16)).foregroundStyle(GymColor.dim)
          .accessibilityHidden(true)
        VStack(spacing: 12) {
          Text(showChange ? "11" : "10").font(GymType.hero(52)).foregroundStyle(GymColor.red)
            .contentTransition(.numericText())
          Text(store.t("Next time")).font(GymType.body(14)).foregroundStyle(GymColor.dim)
        }
      }
      Text("20 kg · " + store.t("same weight")).font(GymType.body(16))
      Text(store.t("Example set · 35 sec")).font(GymType.body(14)).foregroundStyle(GymColor.dim)
      Text(store.t("+1 rep at the same weight")).font(GymType.label(16))
        .opacity(showChange ? 1 : 0)
    }.accessibilityElement(children: .combine).accessibilityIdentifier("journey.comparison")
  }
}
