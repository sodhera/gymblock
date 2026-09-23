import AuthenticationServices
import CryptoKit
import Foundation
import Supabase

// Account auth via Supabase: Sign in with Apple (primary) and email. Ported
// from SleepBlock's `SupabaseAuthClient`, trimmed to what GymBlock needs.
// Behind a protocol so the store never touches the SDK directly and a
// no-op client keeps unconfigured builds running. See docs/development.md.

enum AuthProvider: String, Codable { case apple, email }

struct AppAccount: Codable, Equatable {
    var id: String
    var email: String?
    var provider: AuthProvider
}

struct AuthResult {
    var account: AppAccount
    var isNewAccount: Bool
}

enum AuthError: Error, Equatable {
    case invalidCredentials
    case emailAlreadyRegistered
    case confirmationEmailSent
    case weakPassword(String)
    case rateLimited
    case network
    case cancelled
    case notConfigured
    case unknown(String)

    var message: String {
        switch self {
        case .invalidCredentials: "That email or password isn't right."
        case .emailAlreadyRegistered: "That email already has an account. Sign in instead."
        case .confirmationEmailSent: "Check your inbox — tap the confirmation link, then sign in."
        case .weakPassword(let detail): detail.isEmpty ? "That password is too weak. Try a longer one." : detail
        case .rateLimited: "Too many attempts. Wait a moment and try again."
        case .network: "Couldn't reach the network. Try again."
        case .cancelled: "Sign-in was cancelled."
        case .notConfigured: "Sign-in isn't set up in this build yet."
        case .unknown(let detail): detail
        }
    }

    var isNotice: Bool { self == .confirmationEmailSent }
}

protocol AuthProviding {
    var isConfigured: Bool { get }
    var currentAccount: AppAccount? { get async }
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthResult
    func signUp(email: String, password: String) async throws -> AuthResult
    func signIn(email: String, password: String) async throws -> AuthResult
    func signOut() async
    func deleteAccount() async throws
}

enum SupabaseConfig {
    static var url: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              raw.hasPrefix("http"), !raw.contains("your-project")
        else { return nil }
        return URL(string: raw)
    }

    static var anonKey: String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !raw.isEmpty, !raw.hasPrefix("your-")
        else { return nil }
        return raw
    }

    /// The shared client (auth + PostgREST), nil when unconfigured.
    static let client: SupabaseClient? = {
        guard let url, let anonKey else { return nil }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
        )
    }()
}

enum AuthService {
    static func makeDefault() -> AuthProviding {
        guard let client = SupabaseConfig.client, let url = SupabaseConfig.url, let key = SupabaseConfig.anonKey else {
            AppLog.auth.notice("Supabase not configured — auth disabled")
            return DisabledAuthClient()
        }
        return SupabaseAuthClient(client: client, baseURL: url, anonKey: key)
    }
}

struct DisabledAuthClient: AuthProviding {
    var isConfigured: Bool { false }
    var currentAccount: AppAccount? { get async { nil } }
    func signInWithApple(idToken: String, nonce: String) async throws -> AuthResult { throw AuthError.notConfigured }
    func signUp(email: String, password: String) async throws -> AuthResult { throw AuthError.notConfigured }
    func signIn(email: String, password: String) async throws -> AuthResult { throw AuthError.notConfigured }
    func signOut() async {}
    func deleteAccount() async throws { throw AuthError.notConfigured }
}

final class SupabaseAuthClient: AuthProviding {
    private let client: SupabaseClient
    private let baseURL: URL
    private let anonKey: String

    init(client: SupabaseClient, baseURL: URL, anonKey: String) {
        self.client = client
        self.baseURL = baseURL
        self.anonKey = anonKey
    }

    var isConfigured: Bool { true }

    var currentAccount: AppAccount? {
        get async {
            // Local-first: identity from the Keychain session, never a network
            // round-trip at launch. The SDK refreshes tokens on the next call.
            guard let session = client.auth.currentSession else { return nil }
            return Self.account(from: session)
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthResult {
        do {
            let session = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
            )
            return AuthResult(account: Self.account(from: session), isNewAccount: Self.isNew(session.user))
        } catch {
            throw Self.map(error)
        }
    }

    func signUp(email: String, password: String) async throws -> AuthResult {
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            guard let session = response.session else { throw AuthError.confirmationEmailSent }
            return AuthResult(account: Self.account(from: session), isNewAccount: true)
        } catch let error as AuthError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func signIn(email: String, password: String) async throws -> AuthResult {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return AuthResult(account: Self.account(from: session), isNewAccount: false)
        } catch {
            throw Self.map(error)
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    /// Calls the `delete-account` Edge Function with the user's own token; the
    /// function deletes exactly that user with the service role (never shipped
    /// in the app), cascading to every table keyed on auth.users.
    func deleteAccount() async throws {
        guard let session = try? await client.auth.session else { throw AuthError.unknown("You're not signed in.") }
        var request = URLRequest(url: baseURL.appendingPathComponent("functions/v1/delete-account"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.unknown("Couldn't delete your account. Try again.")
        }
        try? await client.auth.signOut(scope: .local)
    }

    private static func account(from session: Session) -> AppAccount {
        let provider = session.user.appMetadata["provider"]?.stringValue
        // Lowercased: Postgres serves ids lowercase and RevenueCat's app user
        // id is case-sensitive (SleepBlock learned this the hard way).
        return AppAccount(
            id: session.user.id.uuidString.lowercased(),
            email: session.user.email,
            provider: AuthProvider(rawValue: provider ?? "email") ?? .email
        )
    }

    private static func isNew(_ user: User) -> Bool {
        guard let last = user.lastSignInAt else { return true }
        return abs(last.timeIntervalSince(user.createdAt)) < 5
    }

    private static func map(_ error: Error) -> AuthError {
        if let urlError = error as? URLError { return urlError.code == .cancelled ? .cancelled : .network }
        if let authError = error as? Supabase.AuthError {
            switch authError.errorCode {
            case .invalidCredentials: return .invalidCredentials
            case .userAlreadyExists, .emailExists: return .emailAlreadyRegistered
            case .weakPassword: return .weakPassword(authError.message)
            case .overRequestRateLimit, .overEmailSendRateLimit: return .rateLimited
            default: return .unknown(authError.message)
            }
        }
        return .unknown(error.localizedDescription)
    }
}

enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
