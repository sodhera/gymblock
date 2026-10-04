import SwiftUI
import StoreKit

/// Configuration is intentionally absent until the real product and shielding are ready.
@MainActor final class GymSubscription: ObservableObject {
  @Published var product: Product?
  @Published var busy = false
  @Published var message: String?
  @Published var hasAccess = false
  private var updates: Task<Void, Never>?
  var configured: Bool {
    Bundle.main.object(forInfoDictionaryKey: "GymBlockPurchasesEnabled") as? Bool == true
      && productID != nil
  }
  private var productID: String? { Bundle.main.object(forInfoDictionaryKey: "GymBlockMonthlyProductID") as? String }
  init() {
    updates = Task { [weak self] in
      for await result in Transaction.updates {
        guard !Task.isCancelled else { return }
        guard let self else { return }
        if case .verified(let transaction) = result, transaction.productID == self.productID {
          await self.checkAccess(); await transaction.finish()
        }
      }
    }
  }
  deinit { updates?.cancel() }
  func load() async {
    guard configured, let id = productID else { message = "Subscriptions are not available in this review build."; return }
    busy = true; defer { busy = false }
    await checkAccess()
    do {
      product = try await Product.products(for: [id]).first
      message = product == nil ? "The subscription is unavailable. Try again later." : nil
    } catch { message = "Could not load the subscription. Please try again." }
  }
  func checkAccess() async {
    guard configured else { return }
    var verified = false
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result,
        transaction.productID == productID, transaction.revocationDate == nil,
        transaction.expirationDate.map({ $0 > Date() }) ?? false { verified = true }
    }
    hasAccess = verified
  }
  func buy() async {
    guard configured, !busy, let product else { return }
    busy = true; defer { busy = false }
    do {
      switch try await product.purchase() {
      case .success(.verified(let transaction)):
        await checkAccess(); await transaction.finish()
        if !hasAccess { message = "Your subscription could not be verified. Restore purchases to try again." }
      case .success(.unverified): message = "Your purchase could not be verified. Please try restoring it."
      case .pending: message = "Purchase approval is pending. You can return here later."
      case .userCancelled: break
      @unknown default: message = "The purchase could not be completed."
      }
    } catch { message = "The purchase could not be completed. Please try again." }
  }
  func restore() async {
    guard !busy else { return }
    guard configured else { message = "No live purchases are configured in this review build."; return }
    busy = true; defer { busy = false }
    do {
      try await AppStore.sync(); await checkAccess()
      message = hasAccess ? nil : "No active GymBlock subscription was found."
    } catch { message = "Could not restore purchases. Please try again." }
  }
}

struct SubscriptionOffer: View {
  let enter: () -> Void
  @EnvironmentObject private var store: GymStore
  @StateObject private var subscription = GymSubscription()
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      VStack(alignment: .leading, spacing: 16) {
        Text(store.t("Measure your set and rest time.")).font(GymType.body(18))
        Text(store.t("See your workout progress.")).font(GymType.body(18))
        Text(store.t("Focus blocking is simulated in this build."))
          .font(GymType.body(14)).foregroundStyle(GymColor.dim)
      }
      Divider()
      if let product = subscription.product {
        VStack(alignment: .leading, spacing: 8) {
          Text(store.t("GymBlock Monthly")).font(GymType.label(20))
          Text(product.displayPrice + " " + store.t("per month")).font(GymType.title(28))
          Text(store.t("Renews monthly until cancelled.")).font(GymType.body(13)).foregroundStyle(GymColor.dim)
        }
        GymButton(title: store.t("Subscribe") + " · " + product.displayPrice,
          enabled: !subscription.busy, id: "subscription.buy") { Task { await subscription.buy() } }
      }
      if subscription.busy { ProgressView().frame(maxWidth: .infinity) }
      if let message = subscription.message {
        Text(store.t(message)).font(GymType.body(15)).foregroundStyle(GymColor.dim)
          .accessibilityIdentifier("subscription.status")
      }
      HStack {
        Button(store.t("Try again")) { Task { await subscription.load() } }
        Spacer()
        Button(store.t("Restore purchases")) { Task { await subscription.restore() } }
      }.font(GymType.body(14)).frame(minHeight: 44).disabled(subscription.busy)
      #if DEBUG
      if !subscription.configured {
        VStack(spacing: 8) {
          GymButton(title: store.t("Preview workout"), id: "subscription.preview", action: enter)
          Text(store.t("Simulator preview · No payment or subscription"))
            .font(GymType.body(12)).foregroundStyle(GymColor.dim).multilineTextAlignment(.center)
        }
      }
      #endif
      // No fabricated legal links: only configured destinations become tappable.
      HStack {
        legal("Terms of Use", key: "GymBlockTermsURL")
        Spacer()
        legal("Privacy Policy", key: "GymBlockPrivacyURL")
      }.font(GymType.body(12)).foregroundStyle(GymColor.dim)
    }.task { await subscription.load() }
      .onChange(of: subscription.hasAccess) { _, access in if access { enter() } }

  }
  @ViewBuilder private func legal(_ title: String, key: String) -> some View {
    if let text = Bundle.main.object(forInfoDictionaryKey: key) as? String,
      let url = URL(string: text), url.scheme == "https" { Link(store.t(title), destination: url) }
    else { EmptyView() }
  }
}
