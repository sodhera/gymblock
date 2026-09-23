import Foundation
import RevenueCat

// Subscriptions via RevenueCat — a hard paywall with a free trial, ported
// from SleepBlock. One entitlement gates the app: `GymBlock Pro`.
//
// `REVENUECAT_API_KEY` empty = dev mode: `isConfigured` is false and the store
// treats the user as entitled, so fresh clones and the Simulator run with
// zero setup. DEBUG builds can force the real paywall UI with the launch
// argument `-preview-paywall` (fake plans, purchases no-op).

enum EntitlementState: Equatable { case unknown, entitled, notEntitled }

struct SubscriptionStatus: Equatable {
    enum Tier: Equatable { case trial, pro, expired }
    var tier: Tier
    var willRenew: Bool
    var expiration: Date?
}

struct Plan: Identifiable, Equatable {
    var id: String
    var title: String
    var priceString: String
    var periodUnit: String
    var perMonthString: String?
    var perWeekString: String?
    var trialDays: Int
    var isAnnual: Bool
    var priceValue: Decimal
}

struct SubscriptionError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

protocol SubscriptionProviding {
    var isConfigured: Bool { get }
    func start(onChange: @escaping @MainActor (EntitlementState, SubscriptionStatus?) -> Void)
    func logIn(accountID: String) async
    func logOut() async
    func fetchPlans() async -> [Plan]
    /// nil = user cancelled.
    func purchase(planID: String) async throws -> EntitlementState?
    func restore() async throws -> EntitlementState
    func manageSubscriptions() async
}

enum Subscription {
    static let entitlementID = "GymBlock Pro"

    static func makeDefault() -> SubscriptionProviding {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-preview-paywall") {
            return PreviewSubscriptionService()
        }
        #endif
        return RevenueCatSubscriptionService()
    }
}

#if DEBUG
/// Stages the real paywall with believable plans before App Store Connect
/// products exist. Debug-only; Release can't compile it.
final class PreviewSubscriptionService: SubscriptionProviding {
    var isConfigured: Bool { true }
    func start(onChange: @escaping @MainActor (EntitlementState, SubscriptionStatus?) -> Void) {
        Task { @MainActor in onChange(.notEntitled, nil) }
    }
    func logIn(accountID: String) async {}
    func logOut() async {}
    func manageSubscriptions() async {}
    func fetchPlans() async -> [Plan] {
        [
            Plan(id: "$rc_annual", title: "Yearly", priceString: "$39.99", periodUnit: "year",
                 perMonthString: "$3.33", perWeekString: "$0.77", trialDays: 7, isAnnual: true, priceValue: 39.99),
            Plan(id: "$rc_monthly", title: "Monthly", priceString: "$7.99", periodUnit: "month",
                 perMonthString: nil, perWeekString: "$1.84", trialDays: 0, isAnnual: false, priceValue: 7.99),
        ]
    }
    func purchase(planID: String) async throws -> EntitlementState? {
        try? await Task.sleep(for: .seconds(1))
        return .entitled
    }
    func restore() async throws -> EntitlementState { .notEntitled }
}
#endif

final class RevenueCatSubscriptionService: SubscriptionProviding {
    private static var isSDKConfigured = false
    private let apiKey: String

    init() {
        let raw = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String
        apiKey = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var isConfigured: Bool { !apiKey.isEmpty && !apiKey.hasPrefix("appl_your") }

    func start(onChange: @escaping @MainActor (EntitlementState, SubscriptionStatus?) -> Void) {
        guard isConfigured else {
            AppLog.paywall.notice("REVENUECAT_API_KEY empty — paywall disabled (dev mode)")
            return
        }
        if !Self.isSDKConfigured {
            Purchases.logLevel = .warn
            Purchases.configure(withAPIKey: apiKey)
            Self.isSDKConfigured = true
        }
        Task { @MainActor in
            for await info in Purchases.shared.customerInfoStream {
                onChange(Self.state(of: info), Self.status(of: info))
            }
        }
    }

    func logIn(accountID: String) async {
        guard isConfigured else { return }
        _ = try? await Purchases.shared.logIn(accountID)
    }

    func logOut() async {
        guard isConfigured, !Purchases.shared.isAnonymous else { return }
        _ = try? await Purchases.shared.logOut()
    }

    func manageSubscriptions() async {
        guard isConfigured else { return }
        try? await Purchases.shared.showManageSubscriptions()
    }

    func fetchPlans() async -> [Plan] {
        guard isConfigured else { return [] }
        do {
            guard let offering = try await Purchases.shared.offerings().current else { return [] }
            return offering.availablePackages.compactMap(Self.plan(from:)).sorted { $0.isAnnual && !$1.isAnnual }
        } catch {
            AppLog.paywall.error("Offerings fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func purchase(planID: String) async throws -> EntitlementState? {
        guard isConfigured else { return .entitled }
        guard let package = try? await Purchases.shared.offerings().current?
            .availablePackages.first(where: { $0.identifier == planID })
        else { throw SubscriptionError(message: "That plan isn't available right now. Try again.") }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return nil }
            return Self.state(of: result.customerInfo)
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            return nil
        } catch {
            throw SubscriptionError(message: "The purchase didn't go through. You haven't been charged — try again.")
        }
    }

    func restore() async throws -> EntitlementState {
        guard isConfigured else { return .entitled }
        do {
            return Self.state(of: try await Purchases.shared.restorePurchases())
        } catch {
            throw SubscriptionError(message: "Couldn't reach the App Store to restore. Try again.")
        }
    }

    private static func state(of info: CustomerInfo) -> EntitlementState {
        info.entitlements[Subscription.entitlementID]?.isActive == true ? .entitled : .notEntitled
    }

    private static func status(of info: CustomerInfo) -> SubscriptionStatus? {
        guard let e = info.entitlements[Subscription.entitlementID] else { return nil }
        let tier: SubscriptionStatus.Tier = !e.isActive ? .expired : (e.periodType == .trial || e.periodType == .intro ? .trial : .pro)
        return SubscriptionStatus(tier: tier, willRenew: e.willRenew, expiration: e.expirationDate)
    }

    private static func plan(from package: Package) -> Plan? {
        let product = package.storeProduct
        guard let period = product.subscriptionPeriod else { return nil }
        let isAnnual = period.unit == .year
        let (title, unit): (String, String) = switch period.unit {
        case .year: ("Yearly", "year")
        case .month: ("Monthly", "month")
        case .week: ("Weekly", "week")
        case .day: ("Daily", "day")
        }
        var trialDays = 0
        if let intro = product.introductoryDiscount, intro.paymentMode == .freeTrial {
            let p = intro.subscriptionPeriod
            trialDays = switch p.unit {
            case .day: p.value
            case .week: p.value * 7
            case .month: p.value * 30
            case .year: p.value * 365
            }
        }
        let formatter = product.priceFormatter
        let price = product.price as NSDecimalNumber
        let weeks: Double = switch period.unit {
        case .year: 52
        case .month: 52.0 / 12
        case .week: 1
        case .day: 1.0 / 7
        }
        let perWeek = formatter?.string(from: price.dividing(by: NSDecimalNumber(value: weeks * Double(period.value))))
        let perMonth = isAnnual ? formatter?.string(from: price.dividing(by: 12)) : nil
        return Plan(
            id: package.identifier, title: title, priceString: product.localizedPriceString, periodUnit: unit,
            perMonthString: perMonth, perWeekString: perWeek, trialDays: trialDays, isAnnual: isAnnual,
            priceValue: product.price
        )
    }
}
