import Foundation
import RevenueCat
import SwiftUI

/// GymBlock Pro through RevenueCat, keyed to the Supabase account id so purchases follow the
/// account. Two plans: monthly and yearly. Nothing here is faked: with no API key configured,
/// the offer page shows that and the (Debug-only) skip, never a pretend price.
@MainActor final class GymSubscription: ObservableObject {
  struct Plan: Identifiable, Equatable {
    let id: String
    let yearly: Bool
    /// The billed amount for the plan's own period, in the store's currency.
    let price: String
    /// Yearly only: the same amount spread over twelve months, for comparison.
    let perMonth: String?
    let trialDays: Int
    static func == (a: Plan, b: Plan) -> Bool { a.id == b.id }
  }
  @Published private(set) var plans: [Plan] = []
  @Published var selected: String?
  @Published var busy = false
  @Published var message: String?
  @Published private(set) var hasAccess = false
  @Published private(set) var willRenew = true
  @Published private(set) var expiration: Date?
  @Published private(set) var productID: String?
  /// Called with each entitlement change (the cloud keeps a snapshot).
  var onEntitlement: ((CustomerInfo) -> Void)?

  private var packages: [String: Package] = [:]
  private var stream: Task<Void, Never>?
  private var userID: UUID?

  var configured: Bool { !AppConfig.revenueCatKey.isEmpty && !AppConfig.offline }
  var plan: Plan? { plans.first { $0.id == selected } }

  func configure() {
    guard configured, !Purchases.isConfigured else { return }
    #if DEBUG
      Purchases.logLevel = .warn
    #endif
    Purchases.configure(withAPIKey: AppConfig.revenueCatKey)
    stream = Task { [weak self] in
      for await info in Purchases.shared.customerInfoStream { self?.apply(info) }
    }
  }

  /// Ties purchases to the account. Called whenever the signed-in user changes.
  func identify(_ id: UUID?) async {
    configure()
    guard configured else { return }
    guard let id else {
      userID = nil
      if !Purchases.shared.isAnonymous { _ = try? await Purchases.shared.logOut() }
      hasAccess = false
      return
    }
    guard id != userID else { return }
    userID = id
    do {
      let (info, _) = try await Purchases.shared.logIn(id.uuidString.lowercased())
      apply(info)
    } catch {
      AppLog.error("RevenueCat logIn failed: \(error.localizedDescription)")
      Analytics.error("purchases_login", error)
    }
  }

  private func apply(_ info: CustomerInfo) {
    let entitlement = info.entitlements[AppConfig.entitlement]
    let active = entitlement?.isActive == true
    willRenew = entitlement?.willRenew ?? true
    expiration = entitlement?.expirationDate
    productID = entitlement?.productIdentifier
    if active != hasAccess { Analytics.track(active ? "entitled" : "not_entitled", ["product": entitlement?.productIdentifier]) }
    hasAccess = active
    onEntitlement?(info)
  }

  // MARK: Plans

  func load() async {
    guard configured else { message = "Subscriptions aren’t switched on in this build yet."; return }
    busy = true; defer { busy = false }
    do {
      let offerings = try await Purchases.shared.offerings()
      guard let current = offerings.current else { message = "The subscription is unavailable. Try again later."; return }
      var found: [Plan] = []
      packages = [:]
      for package in current.availablePackages {
        let product = package.storeProduct
        let yearly = package.packageType == .annual || product.productIdentifier == AppConfig.yearlyProductID
        let monthly = package.packageType == .monthly || product.productIdentifier == AppConfig.monthlyProductID
        guard yearly || monthly else { continue }
        // The product's own formatter carries the store's currency; never the phone's locale.
        let perMonth = yearly ? product.pricePerMonth.flatMap { price -> String? in
          if let formatter = product.priceFormatter { return formatter.string(from: price) }
          let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = product.currencyCode
          return formatter.string(from: price)
        } : nil
        let trial = product.introductoryDiscount?.paymentMode == .freeTrial ? (product.introductoryDiscount?.subscriptionPeriod.value ?? 0) : 0
        let plan = Plan(id: product.productIdentifier, yearly: yearly, price: product.localizedPriceString, perMonth: perMonth, trialDays: trial)
        found.append(plan); packages[plan.id] = package
      }
      plans = found.sorted { $0.yearly && !$1.yearly }
      if selected == nil || !plans.contains(where: { $0.id == selected }) { selected = plans.first?.id }
      message = plans.isEmpty ? "The subscription is unavailable. Try again later." : nil
      Analytics.track("paywall_loaded", ["plans": plans.count])
    } catch {
      message = "Could not load the subscription. Please try again."
      Analytics.error("paywall_load", error)
    }
  }

  func buy() async {
    guard configured, !busy, let plan, let package = packages[plan.id] else { return }
    busy = true; defer { busy = false }
    Analytics.track("purchase_started", ["product": plan.id])
    do {
      let result = try await Purchases.shared.purchase(package: package)
      apply(result.customerInfo)
      if result.userCancelled { Analytics.track("purchase_cancelled", ["product": plan.id]); return }
      Analytics.track(hasAccess ? "purchase_completed" : "purchase_unverified", ["product": plan.id])
      if !hasAccess { message = "Your subscription could not be verified. Restore purchases to try again." }
    } catch {
      if let code = ErrorCode(rawValue: (error as NSError).code), code == .purchaseCancelledError {
        Analytics.track("purchase_cancelled", ["product": plan.id]); return
      }
      Analytics.error("purchase", error)
      message = "The purchase could not be completed. Please try again."
    }
  }

  func restore() async {
    guard !busy else { return }
    guard configured else { message = "Purchases aren’t switched on in this build yet."; return }
    busy = true; defer { busy = false }
    do {
      let info = try await Purchases.shared.restorePurchases()
      apply(info)
      message = hasAccess ? nil : "No active GymBlock subscription was found."
      Analytics.track("restore", ["entitled": hasAccess])
    } catch {
      Analytics.error("restore", error)
      message = "Could not restore purchases. Please try again."
    }
  }
}
