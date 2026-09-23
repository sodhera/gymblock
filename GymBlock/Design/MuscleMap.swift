import SwiftUI

// The exercise icon: a front + back body pictogram with the worked muscles
// lit — primary in safety orange, secondary in a tint of it, everything else
// a 10% ink silhouette. One vector template covers every exercise, including
// custom ones, and the icon says the useful thing at a glance: what this
// works. See DESIGN.md → "Exercise icons".
//
// Geometry is a stylized pictogram in a 40×100 unit box per figure (front at
// x 0, back at x 48). Shapes are deliberately simple — capsules, rounded
// rects, a few polygons — so the figure reads cleanly from 36pt up to 180pt.

struct MuscleMapIcon: View {
    var primary: Set<Muscle>
    var secondary: Set<Muscle> = []
    var size: CGFloat = 44
    var background: Bool = true

    init(exercise: Exercise?, size: CGFloat = 44, background: Bool = true) {
        self.primary = Set(exercise?.primary ?? [])
        self.secondary = Set(exercise?.secondary ?? [])
        self.size = size
        self.background = background
    }

    init(primary: Set<Muscle>, secondary: Set<Muscle> = [], size: CGFloat = 44, background: Bool = true) {
        self.primary = primary
        self.secondary = secondary
        self.size = size
        self.background = background
    }

    var body: some View {
        Canvas { context, canvasSize in
            let inset = canvasSize.height * (background ? 0.12 : 0.02)
            let available = canvasSize.height - inset * 2
            let scale = available / MuscleGeometry.height
            let width = MuscleGeometry.totalWidth * scale
            let origin = CGPoint(x: (canvasSize.width - width) / 2, y: inset)

            for part in MuscleGeometry.front {
                draw(part, in: &context, origin: origin, scale: scale)
            }
            let backOrigin = CGPoint(x: origin.x + MuscleGeometry.backOffset * scale, y: origin.y)
            for part in MuscleGeometry.back {
                draw(part, in: &context, origin: backOrigin, scale: scale)
            }
        }
        .frame(width: size, height: size)
        .background {
            if background {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(Color.white)
            }
        }
        .accessibilityHidden(true)
    }

    private func draw(_ part: MuscleGeometry.Part, in context: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        let transform = CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: scale, y: scale)
        context.fill(part.path.applying(transform), with: .color(color(for: part.muscle)))
    }

    private func color(for muscle: Muscle?) -> Color {
        guard let muscle else { return GBColor.bodyBase }
        if primary.contains(.fullBody) { return GBColor.orange }
        if primary.contains(muscle) { return GBColor.orange }
        if secondary.contains(muscle) || primary.contains(.cardio) { return GBColor.muscleSecondary }
        return GBColor.bodyBase
    }
}

enum MuscleGeometry {
    struct Part {
        var path: Path
        var muscle: Muscle?
    }

    static let height: CGFloat = 100
    static let backOffset: CGFloat = 48
    static let totalWidth: CGFloat = 88

    // MARK: Primitives (figure-local units)

    private static func capsule(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: min(w, h) / 2, style: .continuous)
    }

    private static func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> Path {
        Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r, style: .continuous)
    }

    private static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    private static func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        guard let first = points.first else { return p }
        p.move(to: CGPoint(x: first.0, y: first.1))
        for pt in points.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        p.closeSubpath()
        return p
    }

    /// Left/right pair mirrored around the figure's centre line (x = 20).
    private static func pair(_ muscle: Muscle?, _ make: (Bool) -> Path) -> [Part] {
        [Part(path: make(false), muscle: muscle), Part(path: make(true), muscle: muscle)]
    }

    private static func mirrorX(_ x: CGFloat, _ w: CGFloat, _ mirrored: Bool) -> CGFloat {
        mirrored ? 40 - x - w : x
    }

    // MARK: Shared silhouette pieces

    private static let common: [Part] = [
        Part(path: ellipse(20, 6.8, 5, 5.8), muscle: nil),               // head
        Part(path: rounded(17.6, 12, 4.8, 4, 1.5), muscle: nil),         // neck
    ]
        + pair(nil) { m in circle(m ? 35.6 : 4.4, 49.5, 2.1) }           // hands
        + pair(nil) { m in ellipse(m ? 23.6 : 16.4, 96, 3, 2.2) }       // feet

    // MARK: Front

    static let front: [Part] = common + [
        Part(path: rounded(13.4, 39.5, 13.2, 7.5, 3), muscle: nil),     // hips
        Part(path: rounded(15.4, 25, 9.2, 14, 2.6), muscle: .abs),
    ]
        + pair(.shoulders) { m in circle(m ? 30.3 : 9.7, 19.4, 4.6) }
        + pair(.chest) { m in rounded(mirrorX(12.3, 7.5, m), 15.2, 7.5, 8.8, 3.2) }
        + pair(.biceps) { m in capsule(mirrorX(4.5, 4.7, m), 23.8, 4.7, 11) }
        + pair(.forearms) { m in capsule(mirrorX(3, 4.3, m), 35.6, 4.3, 12) }
        + pair(.obliques) { m in capsule(mirrorX(12.4, 2.7, m), 25.6, 2.7, 12.5) }
        + pair(.quads) { m in capsule(mirrorX(12.8, 6.4, m), 46, 6.4, 23.5) }
        + pair(.adductors) { m in capsule(mirrorX(18.4, 1.9, m), 47.5, 1.9, 11) }
        + pair(nil) { m in capsule(mirrorX(13.7, 5, m), 70.5, 5, 23) } // shins

    // MARK: Back

    static let back: [Part] = common
        + pair(.lats) { m in
            let pts: [(CGFloat, CGFloat)] = [(12.2, 21), (16, 22.5), (16.6, 32), (14.6, 36.5), (12.6, 29)]
            return polygon(m ? pts.map { (40 - $0.0, $0.1) } : pts)
        }
        + [
            Part(path: rounded(16.2, 21, 7.6, 9.5, 2.2), muscle: .upperBack),
            Part(path: rounded(16.2, 31, 7.6, 8.5, 2.4), muscle: .lowerBack),
            Part(path: polygon([(13.8, 14.6), (26.2, 14.6), (23, 21.5), (20, 26), (17, 21.5)]), muscle: .traps),
        ]
        + pair(.shoulders) { m in circle(m ? 30.3 : 9.7, 19.4, 4.6) }
        + pair(.triceps) { m in capsule(mirrorX(4.5, 4.7, m), 23.8, 4.7, 11) }
        + pair(.forearms) { m in capsule(mirrorX(3, 4.3, m), 35.6, 4.3, 12) }
        + pair(.glutes) { m in rounded(mirrorX(13.1, 6.8, m), 40, 6.8, 8.8, 3.4) }
        + pair(.abductors) { m in capsule(mirrorX(11.4, 2, m), 40.8, 2, 7.5) }
        + pair(.hamstrings) { m in capsule(mirrorX(13, 6.3, m), 49.6, 6.3, 20) }
        + pair(.calves) { m in capsule(mirrorX(13.5, 5.6, m), 70.4, 5.6, 15.5) }
        + pair(nil) { m in capsule(mirrorX(14.3, 4, m), 84.5, 4, 9.5) } // ankles
}

#Preview {
    let samples = ["bench-press-bb", "squat-bb", "deadlift-bb", "pull-up", "lateral-raise-db", "hip-thrust-bb", "plank", "treadmill"]
    return ScrollView {
        LazyVGrid(columns: [.init(), .init()], spacing: 16) {
            ForEach(samples, id: \.self) { id in
                VStack {
                    MuscleMapIcon(exercise: ExerciseCatalog.byID[id], size: 140)
                    Text(ExerciseCatalog.byID[id]?.displayName ?? id).font(.caption)
                }
            }
        }
        .padding()
    }
    .background(GBColor.paper)
}
