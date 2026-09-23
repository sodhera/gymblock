import SwiftUI
import UserNotifications

/// The hard paywall, right after sign-up — the moment of highest intent. No
/// ✕: the app's one job (locking apps while you train) is the subscription.
/// The headline hands back the number from onboarding; the trial timeline says
/// exactly when money moves, and the reminder it promises is real (a local
/// notification two days before billing).
struct PaywallView: View {
    @Environment(AppStore.self) private var store
    @State private var plans: [Plan] = []
    @State private var selectedID: String?
    @State private var loading = true
    @State private var purchasing = false
    @State private var error: String?

    private var selected: Plan? { plans.first { $0.id == selectedID } ?? plans.first }

    private var hoursBack: Int {
        let p = store.profile
        return Int((Double(p.phoneMinutes * p.weeklyTarget * 52) / 60).rounded())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GBSpace.xl) {
                header
                features
                if let plan = selected, plan.trialDays > 0 { timeline(plan) }
                plansSection
            }
            .padding(.horizontal, GBSpace.xl)
            .padding(.top, GBSpace.xl)
            .padding(.bottom, 200)
        }
        .scrollIndicators(.hidden)
        .paperBackground()
        .safeAreaInset(edge: .bottom) { footer }
        .task { await load() }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: GBSpace.sm) {
            HStack(spacing: GBSpace.xs) {
                BrandMark(size: 28)
                Text("GymBlock Pro").kicker(GBColor.orange)
            }
            Group {
                if hoursBack > 0 {
                    Text("Get your \(hoursBack) hours back.")
                } else {
                    Text("Keep it that way.")
                }
            }
            .font(GBFont.hero(34))
            .foregroundStyle(GBColor.ink)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: GBSpace.md) {
            feature("lock.fill", "Apps lock until your workout's done")
            feature("list.bullet.rectangle", "Unlimited templates, logs and records")
            feature("person.2.fill", "Train with friends — weeks, streaks, PRs")
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: GBSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(GBColor.orange)
                .frame(width: 32, height: 32)
                .background(GBColor.orangeSoft, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(text).font(GBFont.body(16)).foregroundStyle(GBColor.ink)
        }
    }

    private func timeline(_ plan: Plan) -> some View {
        let reminderDay = max(1, plan.trialDays - 2)
        return VStack(alignment: .leading, spacing: 0) {
            timelineRow("lock.open.fill", "Today", "Full access. Nothing charged.", isFirst: true)
            timelineRow("bell.fill", "Day \(reminderDay)", "We remind you before the trial ends.")
            timelineRow("creditcard.fill", "Day \(plan.trialDays)", "\(plan.priceString)/\(plan.periodUnit) starts. Cancel before and pay nothing.", isLast: true)
        }
        .padding(GBSpace.md)
        .solidCard(cornerRadius: GBRadius.md)
    }

    private func timelineRow(_ icon: String, _ title: String, _ detail: String, isFirst: Bool = false, isLast: Bool = false) -> some View {
        HStack(alignment: .top, spacing: GBSpace.sm) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isFirst ? .white : GBColor.ink)
                    .frame(width: 30, height: 30)
                    .background(isFirst ? GBColor.orange : GBColor.paper, in: Circle())
                if !isLast {
                    Rectangle().fill(GBColor.mist).frame(width: 2).frame(minHeight: 18)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(GBFont.headline(15)).foregroundStyle(GBColor.ink)
                Text(detail).font(GBFont.body(14)).foregroundStyle(GBColor.steel)
            }
            .padding(.top, 5)
            .padding(.bottom, isLast ? 0 : GBSpace.sm)
        }
    }

    @ViewBuilder
    private var plansSection: some View {
        if loading {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, GBSpace.xl)
        } else if plans.isEmpty {
            VStack(spacing: GBSpace.sm) {
                Text("Couldn't load plans.").font(GBFont.body(15)).foregroundStyle(GBColor.steel)
                Button("Try again") { Task { await load() } }
                    .buttonStyle(QuietButtonStyle(color: GBColor.orange))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GBSpace.lg)
        } else {
            VStack(spacing: GBSpace.sm) {
                ForEach(plans) { plan in planCard(plan) }
            }
        }
    }

    private func planCard(_ plan: Plan) -> some View {
        let isSelected = plan.id == selected?.id
        let savings = savingsPercent(for: plan)
        return Button {
            Haptics.tap()
            withAnimation(.snappy(duration: 0.2)) { selectedID = plan.id }
        } label: {
            HStack(spacing: GBSpace.sm) {
                ZStack {
                    Circle().strokeBorder(isSelected ? GBColor.orange : GBColor.mist, lineWidth: 2)
                    if isSelected { Circle().fill(GBColor.orange).padding(5) }
                }
                .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: GBSpace.xs) {
                        Text(plan.title).font(GBFont.headline(17)).foregroundStyle(GBColor.ink)
                        if let savings {
                            Text("Save \(savings)%")
                                .font(.system(size: 11, weight: .bold).width(.expanded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(GBColor.orange, in: Capsule())
                        }
                    }
                    Text(plan.trialDays > 0 ? "\(plan.trialDays) days free, then \(plan.priceString)/\(plan.periodUnit)" : "\(plan.priceString)/\(plan.periodUnit)")
                        .font(GBFont.body(14))
                        .foregroundStyle(GBColor.steel)
                }
                Spacer()
                if let perWeek = plan.perWeekString {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(perWeek).font(GBFont.number(16, weight: .bold)).foregroundStyle(GBColor.ink)
                        Text("/week").font(GBFont.body(12)).foregroundStyle(GBColor.fog)
                    }
                }
            }
            .padding(GBSpace.md)
            .background(RoundedRectangle(cornerRadius: GBRadius.md, style: .continuous).fill(GBColor.card))
            .overlay(
                RoundedRectangle(cornerRadius: GBRadius.md, style: .continuous)
                    .strokeBorder(isSelected ? GBColor.orange : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(ScaleOnPress(scale: 0.98))
    }

    private func savingsPercent(for plan: Plan) -> Int? {
        guard plan.isAnnual, let monthly = plans.first(where: { $0.periodUnit == "month" }) else { return nil }
        let yearAtMonthly = NSDecimalNumber(decimal: monthly.priceValue).doubleValue * 12
        let annual = NSDecimalNumber(decimal: plan.priceValue).doubleValue
        guard yearAtMonthly > 0, annual < yearAtMonthly else { return nil }
        return Int(((1 - annual / yearAtMonthly) * 100).rounded(.down))
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: GBSpace.sm) {
            if let error {
                Text(error).font(GBFont.body(14)).foregroundStyle(GBColor.danger).multilineTextAlignment(.center)
            }
            Button {
                purchase()
            } label: {
                if purchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(selected.map { $0.trialDays > 0 ? "Start \($0.trialDays)-day free trial" : "Subscribe" } ?? "Continue")
                }
            }
            .buttonStyle(.primary)
            .disabled(selected == nil || purchasing)

            HStack(spacing: GBSpace.md) {
                Button("Restore") { restore() }
                Text("·")
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("·")
                Link("Privacy", destination: URL(string: "https://gymblock.app/privacy")!)
            }
            .font(GBFont.body(13))
            .foregroundStyle(GBColor.fog)
            .tint(GBColor.fog)
        }
        .padding(.horizontal, GBSpace.xl)
        .padding(.top, GBSpace.sm)
        .padding(.bottom, GBSpace.xs)
        .background(GBColor.paper.opacity(0.92).ignoresSafeArea())
    }

    // MARK: Actions

    private func load() async {
        loading = true
        plans = await store.subscriptions.fetchPlans()
        selectedID = plans.first { $0.isAnnual }?.id ?? plans.first?.id
        loading = false
    }

    private func purchase() {
        guard let plan = selected else { return }
        purchasing = true
        error = nil
        Task {
            do {
                if let state = try await store.subscriptions.purchase(planID: plan.id) {
                    if state == .entitled {
                        Haptics.unlock()
                        if plan.trialDays > 0 { scheduleTrialReminder(plan) }
                        store.entitlement = .entitled
                    }
                }
            } catch {
                self.error = error.localizedDescription
                Haptics.warning()
            }
            purchasing = false
        }
    }

    private func restore() {
        Task {
            do {
                let state = try await store.subscriptions.restore()
                if state == .entitled {
                    Haptics.unlock()
                    store.entitlement = .entitled
                } else {
                    error = "No active subscription found for this Apple ID."
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    /// The reminder the timeline promises: two days before the trial bills.
    private func scheduleTrialReminder(_ plan: Plan) {
        let center = UNUserNotificationCenter.current()
        Task {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            let content = UNMutableNotificationContent()
            content.title = "Your trial ends in 2 days"
            content.body = "\(plan.priceString)/\(plan.periodUnit) starts then. Cancel any time in Settings → Subscriptions."
            let seconds = TimeInterval(max(1, plan.trialDays - 2) * 86_400)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: "trial-reminder", content: content, trigger: trigger))
        }
    }
}
