import Foundation
import RevenueCat
import SwiftUI

/// GymBlock Pro through RevenueCat, keyed to the Supabase account id so purchases follow the
/// account. The app's own paywall offers weekly, yearly and monthly (1 Nov 2026; RevenueCat's
/// dashboard paywall is no longer shown). Nothing here is faked: with no API key configured, the offer page shows that and the
/// (Debug-only) skip, never a pretend price.
@MainActor final class GymSubscription: ObservableObject {
  enum Period: String { case weekly, monthly, yearly }
  struct Plan: Identifiable, Equatable {
    let id: String
    let period: Period
    var yearly: Bool { period == .yearly }
    /// The billed amount for the plan's own period, in the store's currency.
    let price: String
    /// Yearly only: the same amount spread over twelve months, for comparison.
    let perMonth: String?
    /// Yearly only: the same amount a week ("US$0.67/wk" on the app's paywall, 1 Nov 2026).
    var perWeek: String? = nil
    let trialDays: Int
    /// Yearly only: twelve months at the monthly price, struck through beside the yearly one.
    var anchor: String? = nil
    /// Yearly only: how much less than twelve monthly payments, in whole percent.
    var savings: Int? = nil
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
  /// True once RevenueCat has answered for the signed-in account (not the anonymous one it starts as).
  /// The paywall gate waits for this, so a subscriber never sees the offer flash on launch.
  @Published private(set) var resolved = false
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
      resolved = false
      if !Purchases.shared.isAnonymous { _ = try? await Purchases.shared.logOut() }
      hasAccess = false
      return
    }
    guard id != userID else { return }
    userID = id
    resolved = false
    do {
      let (info, _) = try await Purchases.shared.logIn(id.uuidString.lowercased())
      apply(info)
      if userID == id { resolved = true }
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
      var amounts: [String: Decimal] = [:]
      var formatters: [String: NumberFormatter] = [:]
      packages = [:]
      for package in current.availablePackages {
        let product = package.storeProduct
        let yearly = package.packageType == .annual || product.productIdentifier == AppConfig.yearlyProductID
        let monthly = package.packageType == .monthly || product.productIdentifier == AppConfig.monthlyProductID
        let weekly = package.packageType == .weekly
        guard yearly || monthly || weekly else { continue }
        let period: Period = yearly ? .yearly : monthly ? .monthly : .weekly
        // The product's own formatter carries the store's currency; never the phone's locale.
        let perMonth = yearly ? product.pricePerMonth.flatMap { price -> String? in
          if let formatter = product.priceFormatter { return formatter.string(from: price) }
          let formatter = NumberFormatter(); formatter.numberStyle = .currency; formatter.currencyCode = product.currencyCode
          return formatter.string(from: price)
        } : nil
        // The period is a count of units (1 week, 3 days…), so it's turned into days here.
        var trial = product.introductoryDiscount.flatMap { $0.paymentMode == .freeTrial ? Self.days($0.subscriptionPeriod) : nil } ?? 0
        // Someone who has already had the trial is charged at once: never promise them free days.
        if trial > 0, await Purchases.shared.checkTrialOrIntroDiscountEligibility(product: product) == .ineligible { trial = 0 }
        // One formatter for the price and the struck-through anchor, so both read alike ("US$59.99", not "USD 59.99" beside "US$71.88").
        let price = product.priceFormatter?.string(from: product.price as NSDecimalNumber) ?? product.localizedPriceString
        var plan = Plan(id: product.productIdentifier, period: period, price: price, perMonth: perMonth, trialDays: trial)
        if yearly, let formatter = product.priceFormatter {
          // Up to the cent, so it never claims less than the yearly price works out to.
          var raw = product.price / 52, week = Decimal()
          NSDecimalRound(&week, &raw, 2, .up)
          plan.perWeek = formatter.string(from: week as NSDecimalNumber)
        }
        found.append(plan); packages[plan.id] = package
        amounts[plan.id] = product.price
        formatters[plan.id] = product.priceFormatter
      }
      // The comparison is the stores' own prices, never an invented "was" price.
      if let monthly = found.first(where: { $0.period == .monthly }), let month = amounts[monthly.id],
         let index = found.firstIndex(where: { $0.yearly }), let year = amounts[found[index].id] {
        let twelve = month * 12
        if twelve > year {
          let formatter = formatters[found[index].id] ?? formatters[monthly.id]
          found[index].anchor = formatter?.string(from: twelve as NSDecimalNumber)
          let percent = NSDecimalNumber(decimal: (twelve - year) / twelve * 100).doubleValue
          if percent >= 1 { found[index].savings = Int(percent.rounded(.down)) }
        }
      }
      // Weekly, yearly, monthly: the yearly in the middle, as the app's paywall lays them out.
      let order: [Period] = [.weekly, .yearly, .monthly]
      plans = found.sorted { (order.firstIndex(of: $0.period) ?? 9) < (order.firstIndex(of: $1.period) ?? 9) }
      if selected == nil || !plans.contains(where: { $0.id == selected }) { selected = plans.first(where: \.yearly)?.id ?? plans.first?.id }
      message = plans.isEmpty ? "The subscription is unavailable. Try again later." : nil
      Analytics.track("paywall_loaded", ["plans": plans.count])
    } catch {
      message = "Could not load the subscription. Please try again."
      Analytics.error("paywall_load", error)
    }
  }

  private static func days(_ period: SubscriptionPeriod) -> Int {
    switch period.unit {
    case .day: return period.value
    case .week: return period.value * 7
    case .month: return period.value * 30
    case .year: return period.value * 365
    @unknown default: return period.value
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
      completed(result.customerInfo, package: package)
    } catch {
      if let code = ErrorCode(rawValue: (error as NSError).code), code == .purchaseCancelledError {
        Analytics.track("purchase_cancelled", ["product": plan.id]); return
      }
      Analytics.error("purchase", error)
      message = "The purchase could not be completed. Please try again."
    }
  }

  /// After a purchase from either paywall: the analytics, the TikTok event and the trial reminder.
  private func completed(_ info: CustomerInfo, package: Package) {
    apply(info)
    let product = package.storeProduct
    // RevenueCat's answer, not the plan's advert: someone who already had a trial pays at once.
    let trial = info.entitlements[AppConfig.entitlement]?.periodType == .trial
    Analytics.track(hasAccess ? "purchase_completed" : "purchase_unverified", ["product": product.productIdentifier, "trial": trial])
    guard hasAccess else { message = "Your subscription could not be verified. Restore purchases to try again."; return }
    GymTikTok.reportPurchase(price: product.price, currency: product.currencyCode, trial: trial)
    if trial, let days = product.introductoryDiscount.flatMap({ $0.paymentMode == .freeTrial ? Self.days($0.subscriptionPeriod) : nil }),
       days > 0, let period = product.subscriptionPeriod {
      let spanish = GymStore.live?.profile.language == "es"
      let price = product.priceFormatter?.string(from: product.price as NSDecimalNumber) ?? product.localizedPriceString
      RestAlert.scheduleTrialReminder(trialDays: days, price: price + Self.per(period, spanish: spanish), spanish: spanish)
    }
  }

  /// "/week", "/month", "/year" after a price, for whichever period the plan bills.
  private static func per(_ period: SubscriptionPeriod, spanish: Bool) -> String {
    switch period.unit {
    case .day: return spanish ? "/día" : "/day"
    case .week: return spanish ? "/semana" : "/week"
    case .month: return spanish ? "/mes" : "/month"
    case .year: return spanish ? "/año" : "/year"
    @unknown default: return ""
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
