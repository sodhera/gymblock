import SwiftUI
import UIKit

enum JourneyMotion {
  static func reduced(_ system: Bool) -> Bool {
    #if DEBUG
    return system || ProcessInfo.processInfo.arguments.contains("--ui-reduced-motion")
    #else
    return system
    #endif
  }
}

/// Finite scenes use elapsed time, never loop or delay the navigation controls.
struct BenefitSequence<Content: View>: View {
  let duration: Double
  @ViewBuilder var content: (Double) -> Content
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  @Environment(\.scenePhase) private var phase
  @EnvironmentObject private var store: GymStore
  @State private var elapsed = 0.0
  @State private var replay = 0
  var body: some View {
    VStack(spacing: 12) {
      content(reduceMotion ? duration : elapsed)
      Button(store.t("Replay")) { replay += 1 }
        .font(GymType.body(13)).foregroundStyle(GymColor.dim).frame(minHeight: 44)
        .accessibilityIdentifier("journey.replay")
    }.task(id: "\(replay)-\(phase)") {
      guard phase == .active else { return }
      if reduceMotion { elapsed = duration; return }
      elapsed = 0
      let start = Date()
      while !Task.isCancelled && elapsed < duration {
        try? await Task.sleep(for: .milliseconds(33))
        guard !Task.isCancelled else { return }
        elapsed = min(duration, Date().timeIntervalSince(start))
      }
    }
  }
}

private func smooth(_ value: Double) -> Double {
  let p = min(1, max(0, value)); return p * p * (3 - 2 * p)
}

struct FocusBenefitScene: View {
  @EnvironmentObject private var store: GymStore
  @Environment(\.dynamicTypeSize) private var typeSize
  var body: some View {
    BenefitSequence(duration: 9.2) { time in
      let p = smooth((time / 9.2 - 0.12) / 0.7)
      VStack(spacing: 22) {
        Text(store.t("Scrolling can add mental fatigue."))
          .font(GymType.body(16)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
        if typeSize.isAccessibilitySize {
          VStack(spacing: 20) { brain(p, scrolling: true, time: time); brain(p, scrolling: false, time: time) }
        } else {
          HStack(spacing: 12) { brain(p, scrolling: true, time: time); brain(p, scrolling: false, time: time) }
        }
        VStack(spacing: 8) {
          if time >= 8.3 {
            Text(store.t("“Scrolling fries your nervous system which ruins your mind muscle connection.”"))
              .font(GymType.label(17)).multilineTextAlignment(.center)
            Text(store.t("Your proposed copy · Unverified health claim"))
              .font(GymType.body(12)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
          } else {
            Text(store.t("Visual metaphor · Not a nervous-system measurement."))
              .font(GymType.body(12)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
          }
        }.frame(minHeight: 94, alignment: .top)
      }
    }
  }
  private func brain(_ p: Double, scrolling: Bool, time: Double) -> some View {
    VStack(spacing: 12) {
      Text(store.t(scrolling ? "Scrolling" : "No scrolling")).font(GymType.label(15))
      HStack(spacing: 8) {
        BrainCharacter(progress: p, scrolling: scrolling, time: time).frame(width: 130, height: 120).frame(height: 158)
        BenefitMeter(value: scrolling ? 0.58 - 0.43 * p : 0.58 + 0.34 * p).frame(width: 8, height: 104)
      }.accessibilityHidden(true)
    }.frame(minWidth: 148).accessibilityElement(children: .ignore)
      .accessibilityLabel(store.t(scrolling ? "Scrolling: brain character becomes smaller and tired." : "No scrolling: brain character becomes larger and happy."))
  }
}

struct BrainCharacter: View {
  var progress: Double
  var scrolling: Bool
  var time: Double
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  var body: some View {
    Canvas { context, size in
      context.scaleBy(x: size.width / 240, y: size.height / 220)
      // Particle bursts originate behind the opaque character silhouette.
      if !reduceMotion && time < 9.2 {
        for wave in 0..<9 {
          for i in 0..<2 {
            let age = time - (1.5 + Double(wave) * 0.7)
            if age >= 0 && age < 1.8 {
              let k = age / 1.8
              let side = (wave + i) % 2 == 0 ? -1.0 : 1.0
              let point = CGPoint(x: 120 + side * (24 + 95 * k), y: 100 - 90 * k + 20 * k * k)
              var particle = context; particle.opacity = 1 - k
              if scrolling && (wave + i) % 3 == 1 {
                drawSocial(&particle, at: point, instagram: wave % 2 == 0)
              } else {
                let symbols = ["😮‍💨", "🥱", "😴"]
                particle.draw(Text(scrolling ? symbols[(wave + i) % 3] : "⚡").font(.system(size: 23)), at: point)
              }
            }
          }
        }
      }
      let scale = scrolling ? 1 - 0.12 * progress : 1 + 0.1 * progress
      context.translateBy(x: 120, y: 110); context.scaleBy(x: scale, y: scale); context.translateBy(x: -120, y: -110)
      let shape = brainOutline()
      context.fill(shape, with: .color(GymColor.surface))
      context.stroke(shape, with: .color(GymColor.ink.opacity(0.4)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
      for fold in brainFolds() {
        context.stroke(fold, with: .color(GymColor.ink.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
      }
      for x in [92.0, 148.0] {
        context.fill(Path(ellipseIn: CGRect(x: x - 4.5, y: 111, width: 9, height: 11 - progress * 2.6)), with: .color(GymColor.ink))
      }
      var mouth = Path(); mouth.move(to: CGPoint(x: 105, y: 138))
      mouth.addQuadCurve(to: CGPoint(x: 135, y: 138), control: CGPoint(x: 120, y: 138 + (scrolling ? -1 : 1) * progress * 23))
      context.stroke(mouth, with: .color(GymColor.ink), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
    }
  }
  private func drawSocial(_ context: inout GraphicsContext, at point: CGPoint, instagram: Bool) {
    let r = CGRect(x: point.x - 11, y: point.y - 11, width: 22, height: 22)
    context.fill(Path(roundedRect: r, cornerRadius: 6), with: .color(instagram ? .pink : .black))
    if instagram {
      context.stroke(Path(roundedRect: r.insetBy(dx: 4, dy: 4), cornerRadius: 4), with: .color(.white), lineWidth: 1.7)
      context.stroke(Path(ellipseIn: r.insetBy(dx: 8, dy: 8)), with: .color(.white), lineWidth: 1.5)
      context.fill(Path(ellipseIn: CGRect(x: point.x + 4, y: point.y - 6, width: 2, height: 2)), with: .color(.white))
    } else {
      context.draw(Text("♪").font(.system(size: 23, weight: .bold)).foregroundColor(.cyan), at: CGPoint(x: point.x - 1, y: point.y))
      context.draw(Text("♪").font(.system(size: 23, weight: .bold)).foregroundColor(.white), at: CGPoint(x: point.x + 1, y: point.y - 1))
    }
  }
  private func brainOutline() -> Path {
    var p = Path(); p.move(to: CGPoint(x: 119, y: 34))
    let curves: [[Double]] = [
      [109,13,86,15,76,34],[55,27,36,43,39,63],[19,76,23,96,32,107],
      [20,125,30,145,44,153],[45,176,66,192,85,184],[91,199,112,197,119,182],
      [127,198,148,199,158,184],[180,190,198,175,198,153],[216,142,217,120,206,107],
      [219,91,217,73,202,63],[205,43,185,27,164,34],[153,14,130,13,119,34]]
    for a in curves { p.addCurve(to: CGPoint(x: a[4], y: a[5]), control1: CGPoint(x: a[0], y: a[1]), control2: CGPoint(x: a[2], y: a[3])) }
    p.closeSubpath(); return p
  }
  private func brainFolds() -> [Path] {
    let lines: [[Double]] = [
      [119,35,116,60,121,79,119,94], [119,160,120,168,120,176,119,183],
      [76,35,62,49,68,67,88,70,101,72,103,84,95,92],
      [39,64,54,60,63,71,60,86,56,97,64,103,71,103],
      [32,108,43,110,49,118,47,130,45,143,57,148,68,140],
      [45,153,57,152,70,164,66,180],[86,183,96,170,90,155,96,150],
      [164,35,178,49,171,67,153,71,140,74,139,87,146,92],
      [202,64,185,61,176,72,181,85,186,99,176,105,166,104],
      [206,108,193,111,189,120,192,132,195,144,181,149,169,142],
      [198,153,185,153,173,165,178,180],[156,182,146,169,151,155,145,150]]
    return lines.map { a in
      var p = Path(); p.move(to: CGPoint(x: a[0], y: a[1]))
      for i in stride(from: 2, to: a.count, by: 6) {
        p.addCurve(to: CGPoint(x: a[i+4], y: a[i+5]), control1: CGPoint(x: a[i], y: a[i+1]), control2: CGPoint(x: a[i+2], y: a[i+3]))
      }; return p
    }
  }
}

struct BenefitMeter: View {
  let value: Double
  var body: some View {
    GeometryReader { g in
      ZStack(alignment: .bottom) {
        Capsule().fill(GymColor.dim.opacity(0.16))
        Capsule().fill(GymColor.red).frame(height: g.size.height * min(1, max(0, value)))
      }
    }
  }
}

/// Chosen animation parameters, not a physiological recovery calculation.
enum RestIllustration {
  struct Pose { var warmth: Double; var curl: Double }
  static let pumpTime = 0.6 + 4 * 1.7 + 0.65 * 0.8
  static func pose(time: Double, timed: Bool) -> Pose {
    guard time >= 0.6 else { return Pose(warmth: 0, curl: 0) }
    let period = timed ? 1.7 : 2.4
    let count = timed ? 5 : 4
    let t = time - 0.6
    let cycle = min(Int(t / period), count - 1)
    let local = t - Double(cycle) * period
    let base = timed ? Double(cycle) * 0.2 : 0
    let peak = min(1, base + 0.25)
    if cycle == count - 1 && local >= 0.65 { return Pose(warmth: peak, curl: 1) }
    if local < 0.65 { return Pose(warmth: min(1, base + 0.25 * local / 0.65), curl: smooth(local / 0.65)) }
    let rest = local - 0.65
    return Pose(warmth: max(0, peak - (timed ? 0.05 : 0.25) * min(1, rest / (period - 0.65))), curl: 1 - smooth(rest / 0.35))
  }
}

struct RestBenefitScene: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @EnvironmentObject private var store: GymStore
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  private var reduceMotion: Bool { JourneyMotion.reduced(systemReduceMotion) }
  @State private var rang = false
  var body: some View {
    BenefitSequence(duration: 10.6) { time in
      VStack(spacing: 22) {
        Group {
          if typeSize.isAccessibilitySize {
            VStack(spacing: 16) { arm(time, timed: false); arm(time, timed: true) }
          } else {
            HStack(spacing: 12) { arm(time, timed: false); arm(time, timed: true) }
          }
        }.padding(.top, 8)
        Text(store.t("Stylized model · Not measured muscle activation."))
          .font(GymType.body(12)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
      }.onChange(of: time) { old, new in
        if new < old { rang = false }
        if new >= RestIllustration.pumpTime && !rang {
          rang = true
          if !reduceMotion { OnboardingFeedback.shared.play(profile: store.profile, completion: true) }
        }
      }
    }
  }
  private func arm(_ time: Double, timed: Bool) -> some View {
    let pose = RestIllustration.pose(time: time, timed: timed)
    let pumpAge = time - RestIllustration.pumpTime
    let celebrate = timed && pumpAge >= 0
    let shake = celebrate && !reduceMotion && time < 10.6 ? sin(pumpAge * .pi * 16) * 2.5 * max(0, 1 - pumpAge / 0.85) : 0
    return VStack(spacing: 12) {
      Text(store.t(timed ? "Timed rest" : "Longer rest")).font(GymType.label(15))
      Text(celebrate ? "Perfect Pump" : " ").font(GymType.label(14)).foregroundStyle(GymColor.red)
        .accessibilityIdentifier(timed ? "journey.pump" : "journey.longer.title")
      HStack(spacing: 12) {
        ArmIllustration(warmth: pose.warmth, curl: pose.curl).frame(width: 126, height: 165)
        BenefitMeter(value: pose.warmth).frame(width: 9, height: 138)
          .shadow(color: GymColor.red.opacity(celebrate && time < 10.6 ? max(0, 1 - pumpAge / 2.4) * 0.7 : 0), radius: 12)
          .offset(x: shake)
      }.accessibilityHidden(true)
    }.frame(minWidth: 147).accessibilityElement(children: .ignore)
      .accessibilityLabel(store.t(timed ? "Timed rest: five curls fill the example meter." : "Longer rest: each curl reaches one quarter of the example meter."))
  }
}

struct RecordBenefitScene: View {
  @Environment(\.dynamicTypeSize) private var typeSize
  @EnvironmentObject private var store: GymStore
  var body: some View {
    BenefitSequence(duration: 2.6) { time in
      VStack(spacing: 18) {
        Text(store.t("Dumbbell curl · Example records")).font(GymType.body(14)).foregroundStyle(GymColor.dim)
        if typeSize.isAccessibilitySize {
          VStack(spacing: 28) { table(recorded: false, time: time); table(recorded: true, time: time) }
        } else {
          HStack(alignment: .top, spacing: 20) { table(recorded: false, time: time); table(recorded: true, time: time) }
        }
        Text(store.t("Percentages compare weight × reps with the previous record."))
          .font(GymType.body(12)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
      }
    }
  }
  private func table(recorded: Bool, time: Double) -> some View {
    let dates = ["Week 1", "Week 2", "Week 3", "Week 4", "Today"]
    let records = ["20 kg × 8", "20 kg × 10", "20 kg × 9", "22.5 kg × 10", "25 kg × 12"]
    let changes = ["Baseline", "↑ 25%", "↓ 10%", "↑ 25%", "↑ 33.3%"]
    return VStack(alignment: .leading, spacing: 0) {
      Text(store.t(recorded ? "With a record" : "Without a record")).font(GymType.label(15)).padding(.bottom, 8)
      ForEach(0..<5) { i in
        VStack(alignment: .leading, spacing: 4) {
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(store.t(dates[i])).font(GymType.body(12)).foregroundStyle(GymColor.dim)
            Spacer(minLength: 0)
            if recorded {
              Text(store.t(changes[i])).font(GymType.label(12))
                .foregroundStyle(i == 2 ? GymColor.red : i == 0 ? GymColor.dim : Color(uiColor: .systemGreen))
            }
          }
          Text(recorded || i == 4 ? records[i] : store.t("Unknown")).font(GymType.label(15)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
          .opacity(recorded ? 0.18 + 0.82 * smooth((time - Double(i) * 0.4) / 0.65) : 1)
          .overlay(alignment: .bottom) { Rectangle().fill(GymColor.dim.opacity(0.14)).frame(height: 1) }
          .accessibilityElement(children: .combine)
      }
      Text(store.t(recorded ? "This looks motivating." : "You can't tell if you're doing well or not."))
        .font(GymType.label(15)).padding(.top, 12).fixedSize(horizontal: false, vertical: true)
    }.frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
  }
}
