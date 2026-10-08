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
@MainActor final class Account: ObservableObject {
  enum State: Equatable { case loading, signedOut, signedIn }
  @Published private(set) var state: State = .loading
  @Published private(set) var user: User?
  @Published var busy = false
  @Published var message: String?
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

  // MARK: Apple

  func signInWithApple() async {
    guard !busy else { return }
    busy = true; message = nil; defer { busy = false }
    do {
      let nonce = Self.randomNonce()
      let credential = try await AppleSignInSheet.present(hashedNonce: Self.sha256(nonce))
      guard let data = credential.identityToken, let idToken = String(data: data, encoding: .utf8) else {
        throw AuthFailure.message("Apple didn’t return a sign-in token. Please try again.")
      }
      try await auth.signInWithIdToken(credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
      // Apple shares the name only on the very first authorization; keep it.
      if let given = credential.fullName?.givenName, !given.isEmpty {
        _ = try? await auth.update(user: UserAttributes(data: ["full_name": .string(given)]))
      }
      Analytics.track("sign_in", ["provider": "apple"])
    } catch {
      fail(error, provider: "apple")
    }
  }

  // MARK: Google

  func signInWithGoogle() async {
    guard !busy else { return }
    busy = true; message = nil; defer { busy = false }
    do {
      try await auth.signInWithOAuth(provider: .google, redirectTo: AppConfig.authCallback) { session in
        session.prefersEphemeralWebBrowserSession = false
      }
      Analytics.track("sign_in", ["provider": "google"])
    } catch {
      fail(error, provider: "google")
    }
  }

  /// The Google sheet returns through the app's URL scheme.
  func handle(_ url: URL) {
    guard url.scheme == AppConfig.authCallback.scheme else { return }
    auth.handle(url)
  }

  // MARK: Out

  func signOut() async {
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
  private static var current: AppleSignInSheet?

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
