import SwiftUI

// Liquid Glass building blocks. iOS 26 is the deployment target, so these use
// native `glassEffect` directly — no material fallback.
//
// The rule (DESIGN.md → "Containers"): glass is for things you touch or
// things that float. Static content sits directly on paper, separated by
// space and hairlines, never boxed for decoration.

extension View {
    /// Frosted white glass card.
    func glassCard(cornerRadius: CGFloat = GBRadius.lg, interactive: Bool = false) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self.glassEffect(
            interactive
                ? .regular.tint(GBColor.glassTint).interactive()
                : .regular.tint(GBColor.glassTint),
            in: shape
        )
    }

    /// Solid paper-white card for dense content (set tables) where glass
    /// refraction would hurt legibility. Still reads as the same family.
    func solidCard(cornerRadius: CGFloat = GBRadius.lg) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(GBColor.card)
                .shadow(color: GBColor.shadow, radius: 12, y: 4)
        )
    }
}

// MARK: - Buttons

/// The one accent action per screen: "Start Workout", "Continue", "Start
/// free trial". Orange glass capsule, 58pt, white label.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = GBColor.orange
    var foreground: Color = .white
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GBFont.headline(17))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .contentShape(Capsule())
            .glassEffect(.regular.tint(isEnabled ? tint : GBColor.mist).interactive(), in: Capsule())
            .opacity(isEnabled ? 1 : 0.7)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.press() }
            }
    }
}

/// Ink capsule — the serious action ("Hold to finish", "Back to the workout").
struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PrimaryButtonStyle(tint: GBColor.ink, foreground: GBColor.paper).makeBody(configuration: configuration)
    }
}

/// Frosted glass capsule — secondary actions ("Add exercise", "Not now").
struct GlassButtonStyle: ButtonStyle {
    var height: CGFloat = 52
    var foreground: Color = GBColor.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GBFont.label(16))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(Capsule())
            .glassEffect(.regular.tint(GBColor.glassTint).interactive(), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.press() }
            }
    }
}

/// Text-only action ("I already have an account", "Restore").
struct QuietButtonStyle: ButtonStyle {
    var color: Color = GBColor.steel
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(GBFont.label(15))
            .foregroundStyle(color)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == InkButtonStyle {
    static var ink: InkButtonStyle { InkButtonStyle() }
}
extension ButtonStyle where Self == GlassButtonStyle {
    static var glassCapsule: GlassButtonStyle { GlassButtonStyle() }
}
extension ButtonStyle where Self == QuietButtonStyle {
    static var quiet: QuietButtonStyle { QuietButtonStyle() }
}

/// 44pt round glass icon button — back chevron, close ✕, settings gear.
struct GlassIconButton: View {
    var systemName: String
    var size: CGFloat = 44
    var tint: Color = GBColor.ink
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.press()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(GBColor.glassTint).interactive(), in: Circle())
    }
}

// MARK: - Hold to confirm

/// Press-and-hold capsule for consequential actions: finishing a workout,
/// committing in onboarding. A fill sweeps across while ratchet haptics climb;
/// release early and it sighs back. Never fires from a stray tap.
struct HoldButton: View {
    var title: String
    var holdingTitle: String? = nil
    var duration: Double = 1.2
    var tint: Color = GBColor.ink
    var fill: Color = GBColor.orange
    var foreground: Color = GBColor.paper
    var onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var completed = false
    @State private var holdTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { geo in
                Capsule()
                    .fill(fill)
                    .frame(width: max(58, geo.size.width * progress))
                    .opacity(progress > 0.001 ? 1 : 0)
            }
            Text(isHolding ? (holdingTitle ?? title) : title)
                .font(GBFont.headline(17))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .contentTransition(.opacity)
        }
        .frame(height: 58)
        .clipShape(Capsule())
        .glassEffect(.regular.tint(tint).interactive(), in: Capsule())
        .scaleEffect(isHolding ? 0.98 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHolding)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isHolding && !completed { begin() } }
                .onEnded { _ in if !completed { cancel() } }
        )
        .accessibilityElement()
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { finish() }
    }

    private func begin() {
        isHolding = true
        Haptics.ratchet(0)
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            let steps = 12
            for step in 1...steps {
                try? await Task.sleep(for: .seconds(duration / Double(steps)))
                guard !Task.isCancelled, isHolding else { return }
                let p = Double(step) / Double(steps)
                withAnimation(.linear(duration: duration / Double(steps))) { progress = p }
                if step % 2 == 0 { Haptics.ratchet(p) }
            }
            finish()
        }
    }

    private func cancel() {
        holdTask?.cancel()
        isHolding = false
        if progress > 0 { Haptics.soft(0.4) }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { progress = 0 }
    }

    private func finish() {
        guard !completed else { return }
        completed = true
        isHolding = false
        withAnimation(.easeOut(duration: 0.15)) { progress = 1 }
        onComplete()
        // Allow reuse if the host keeps the button on screen.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.8))
            completed = false
            withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
        }
    }
}

// MARK: - Settings rows

/// Kicker + glass rounded rect holding hairline-divided rows.
struct GlassGroup<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: GBSpace.xs) {
            if let title {
                Text(title).kicker().padding(.leading, GBSpace.xs)
            }
            VStack(spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(Array(subviews.enumerated()), id: \.offset) { index, subview in
                        subview
                        if index < subviews.count - 1 {
                            Rectangle().fill(GBColor.hairline).frame(height: 1).padding(.leading, 56)
                        }
                    }
                }
            }
            .solidCard(cornerRadius: GBRadius.md)
        }
    }
}

struct GlassRow<Trailing: View>: View {
    var icon: String
    var iconTint: Color = GBColor.ink
    var title: String
    var titleColor: Color = GBColor.ink
    var action: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    init(
        icon: String,
        iconTint: Color = GBColor.ink,
        title: String,
        titleColor: Color = GBColor.ink,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.icon = icon
        self.iconTint = iconTint
        self.title = title
        self.titleColor = titleColor
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        let row = HStack(spacing: GBSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconTint)
                .frame(width: 32, height: 32)
                .background(iconTint.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(GBFont.body(16))
                .foregroundStyle(titleColor)
            Spacer(minLength: GBSpace.xs)
            trailing
                .font(GBFont.body(15))
                .foregroundStyle(GBColor.steel)
            if action != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(GBColor.fog)
            }
        }
        .padding(.horizontal, GBSpace.sm)
        .frame(minHeight: 54)
        .contentShape(Rectangle())

        if let action {
            Button {
                Haptics.tap()
                action()
            } label: { row }
            .buttonStyle(RowPressStyle())
        } else {
            row
        }
    }
}

struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? GBColor.paperDeep.opacity(0.7) : .clear)
    }
}

// MARK: - Chips

/// Selectable option tile used in onboarding and filters.
struct OptionTile: View {
    var title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: GBSpace.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isSelected ? GBColor.orange : GBColor.ink)
                        .frame(width: 28)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(GBFont.headline(17)).foregroundStyle(GBColor.ink)
                    if let subtitle {
                        Text(subtitle).font(GBFont.body(14)).foregroundStyle(GBColor.steel)
                    }
                }
                Spacer()
                ZStack {
                    Circle().strokeBorder(isSelected ? GBColor.orange : GBColor.mist, lineWidth: 2)
                    if isSelected {
                        Circle().fill(GBColor.orange).padding(5)
                    }
                }
                .frame(width: 22, height: 22)
            }
            .padding(.horizontal, GBSpace.md)
            .frame(minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: GBRadius.md, style: .continuous)
                    .fill(GBColor.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GBRadius.md, style: .continuous)
                    .strokeBorder(isSelected ? GBColor.orange : .clear, lineWidth: 2)
            )
            .animation(.snappy(duration: 0.2), value: isSelected)
        }
        .buttonStyle(ScaleOnPress())
    }
}

struct ScaleOnPress: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
