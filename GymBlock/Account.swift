import AuthenticationServices
import CryptoKit
import Foundation
import Supabase
import SwiftUI

enum AuthFailure: LocalizedError, Equatable {
  case cancelled
  case message(String)
  var errorDescription: String? {
    switch self {
    case .cancelled: return nil
    case .message(let text): return text
    }
  }
}

/// The signed-in account. Sign in with Apple (native sheet) or Google (web sheet through Supabase)
/// are the only two ways in; every path ends in a Supabase session, which the rest of the app
/// observes. Development runs (`--demo`, UI tests, page jumps) stay offline with no account at all.
///
/// Signing up and signing in are separate screens, but Apple and Google are find-or-create: the
/// grant is the same either way. What differs is what the account turns out to hold, so every
/// sign-in waits for the account's data and reports it, and a surprise becomes a `notice`.
@MainActor final class Account: ObservableObject {
  enum State: Equatable { case loading, signedOut, signedIn }
  enum Provider: String { case apple, google }
  /// Which screen asked: the last step of sign-up, the standalone sign-in, or Settings attaching
  /// an account to a phone that already has its workouts.
  enum Intent: String { case signUp = "sign_up", signIn = "sign_in", link }
  /// A sign-in that didn't do what the screen promised, shown on its own page before anything else.
  enum Notice: Equatable {
    /// Sign-up reached an account that already finished onboarding: we signed them in instead.
    case existingAccount
    /// Sign-in reached no GymBlock account: nothing to restore, so they sign up instead.
    case notFound
  }
  @Published private(set) var state: State = .loading
  @Published private(set) var user: User?
  /// The provider whose button was tapped, until the account's data has arrived.
  @Published private(set) var loading: Provider?
  @Published var message: String?
  @Published var notice: Notice?
  var busy: Bool { loading != nil }
  /// Fires whenever the signed-in user changes (sync, subscriptions and analytics follow it).
  var onUserChange: ((User?) -> Void)?
  private var observer: Task<Void, Never>?
  private var auth: AuthClient { Backend.supabase.auth }

  var userID: UUID? { user?.id }
  var email: String? { user?.email }
  var displayName: String? {
    let meta = user?.userMetadata ?? [:]
    for key in ["full_name", "name", "given_name"] {
      if case .string(let value)? = meta[key], !value.trimmingCharacters(in: .whitespaces).isEmpty { return value }
    }
    return nil
  }
  var provider: String? {
    if case .string(let value)? = user?.appMetadata["provider"] { return value }
    return nil
  }

  func start() {
    guard observer == nil else { return }
    if AppConfig.offline { state = .signedOut; return }
    observer = Task { [weak self] in
      for await (_, session) in Backend.supabase.auth.authStateChanges {
        guard let self else { return }
        await self.apply(session)
      }
    }
  }

  private func apply(_ session: Auth.Session?) async {
    guard var session else { set(nil); return }
    // The stored session is emitted as it was saved; refresh it before trusting it.
    if session.isExpired {
      do { session = try await auth.session } catch {
        AppLog.error("Session refresh failed: \(error.localizedDescription)")
        set(nil); return
      }
    }
    set(session.user)
  }

  private func set(_ newUser: User?) {
    let changed = newUser?.id != user?.id
    user = newUser
    state = newUser == nil ? .signedOut : .signedIn
    if changed { onUserChange?(newUser) }
  }

  // MARK: In

  /// Signs in with the provider, then waits for the account's data, so the button keeps its
  /// spinner until there is somewhere to go. Returns what the account held, or nil when the
  /// sign-in was cancelled or failed (the reason is in `message`).
  @discardableResult
  func signIn(_ provider: Provider, intent: Intent) async -> CloudSync.Found? {
    guard loading == nil else { return nil }
    loading = provider; message = nil; notice = nil
    defer { loading = nil }
    Analytics.track("sign_in_started", ["provider": provider.rawValue, "intent": intent.rawValue])
    do {
      let session = provider == .apple ? try await apple() : try await google()
      // Adopt the session now rather than waiting for the auth event, so the pull starts at once.
      set(session.user)
      let found = await CloudSync.shared.awaitPull() ?? .failed
      if found == .failed {
        // Without the account's data there is no telling a new account from an old one, and
        // pushing this phone's answers could overwrite it. Step back out and let them retry.
        await signOut()
        message = "Couldn’t reach your account. Check your connection and try again."
        return nil
      }
      switch (intent, found) {
      case (.signUp, .profile(onboarded: true)): notice = .existingAccount
      case (.signIn, .none): notice = .notFound
      default: break
      }
      Analytics.track("sign_in", ["provider": provider.rawValue, "intent": intent.rawValue, "found": found.label])
      return found
    } catch {
      fail(error, provider: provider.rawValue)
      return nil
    }
  }

  private func apple() async throws -> Auth.Session {
    let nonce = Self.randomNonce()
    let credential = try await AppleSignInSheet.present(hashedNonce: Self.sha256(nonce))
    guard let data = credential.identityToken, let idToken = String(data: data, encoding: .utf8) else {
      throw AuthFailure.message("Apple didn’t return a sign-in token. Please try again.")
    }
    var session = try await auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
    // Apple shares the name only on the very first authorization; keep it.
    if let given = credential.fullName?.givenName, !given.isEmpty,
       let updated = try? await auth.update(user: UserAttributes(data: ["full_name": .string(given)])) {
      session.user = updated
    }
    return session
  }

  private func google() async throws -> Auth.Session {
    try await auth.signInWithOAuth(provider: .google, redirectTo: AppConfig.authCallback) { session in
      session.prefersEphemeralWebBrowserSession = false
    }
  }

  /// The Google sheet returns through the app's URL scheme.
  func handle(_ url: URL) {
    guard url.scheme == AppConfig.authCallback.scheme else { return }
    auth.handle(url)
  }

  // MARK: Out

  func signOut() async {
    notice = nil
    guard !AppConfig.offline else { set(nil); return }
    do {
      try await auth.signOut(scope: .local)
    } catch {
      // The SDK drops the local Keychain session before asking the server; if only that remote
      // call failed, this device is still signed out.
      if (try? await auth.session) != nil { AppLog.error("Sign out failed: \(error.localizedDescription)") }
    }
    set(nil)
  }

  /// Deletes the server account and everything in it, then signs this device out.
  func deleteAccount() async -> Bool {
    guard !AppConfig.offline else { set(nil); return true }
    do {
      try await Backend.supabase.rpc("gb_delete_account").execute()
      Analytics.track("account_deleted")
      await Analytics.flushNow()
    } catch {
      AppLog.error("Delete account failed: \(error.localizedDescription)")
      message = "Could not delete the account. Check your connection and try again."
      return false
    }
    try? await auth.signOut(scope: .local)
    notice = nil
    set(nil)
    return true
  }

  // MARK: Errors

  private func fail(_ error: Error, provider: String) {
    let failure = Self.map(error)
    if failure == .cancelled { Analytics.track("sign_in_cancelled", ["provider": provider]); return }
    Analytics.error("sign_in", error)
    message = failure.errorDescription
  }
  private static func map(_ error: Error) -> AuthFailure {
    if let failure = error as? AuthFailure { return failure }
    if let web = error as? ASWebAuthenticationSessionError, web.code == .canceledLogin { return .cancelled }
    if let apple = error as? ASAuthorizationError, apple.code == .canceled { return .cancelled }
    if let api = error as? AuthError {
      switch api.errorCode {
      case .overRequestRateLimit: return .message("Too many tries. Wait a minute and try again.")
      default: return .message(api.message)
      }
    }
    if (error as? URLError) != nil { return .message("You’re offline. Check your connection and try again.") }
    return .message("Something went wrong. Please try again.")
  }

  // MARK: Nonce

  private static func randomNonce(length: Int = 32) -> String {
    let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var generator = SystemRandomNumberGenerator()
    return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
  }
  private static func sha256(_ input: String) -> String {
    SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}

/// Presents the native Sign in with Apple sheet and bridges it to async.
@MainActor private final class AppleSignInSheet: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
  /// The sheet and its controller are held until the delegate answers: the controller does not
  /// keep itself alive, and a fast, already-authorized Apple ID can otherwise lose its callback.
  private static var current: AppleSignInSheet?
  private var controller: ASAuthorizationController?

  static func present(hashedNonce: String) async throws -> ASAuthorizationAppleIDCredential {
    let sheet = AppleSignInSheet()
    current = sheet
    defer { current = nil }
    return try await withCheckedThrowingContinuation { continuation in
      sheet.continuation = continuation
      let request = ASAuthorizationAppleIDProvider().createRequest()
      request.requestedScopes = [.fullName, .email]
      request.nonce = hashedNonce
      let controller = ASAuthorizationController(authorizationRequests: [request])
      controller.delegate = sheet
      controller.presentationContextProvider = sheet
      sheet.controller = controller
      controller.performRequests()
    }
  }
  nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    MainActor.assumeIsolated {
      if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
        continuation?.resume(returning: credential)
      } else {
        continuation?.resume(throwing: AuthFailure.message("Apple sign-in returned an unexpected credential."))
      }
      continuation = nil
    }
  }
  nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    MainActor.assumeIsolated {
      let cancelled = (error as? ASAuthorizationError)?.code == .canceled
      if !cancelled { AppLog.error("Apple authorization failed: \((error as NSError).domain) (\((error as NSError).code))") }
      continuation?.resume(throwing: cancelled ? AuthFailure.cancelled : AuthFailure.message("Apple sign-in didn’t finish. Please try again."))
      continuation = nil
    }
  }
  nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    MainActor.assumeIsolated {
      UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first ?? ASPresentationAnchor()
    }
  }
}
