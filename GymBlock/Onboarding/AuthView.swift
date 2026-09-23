import AuthenticationServices
import SwiftUI

/// Account creation after commitment (sign-up), or the returning-user path
/// from Welcome (sign-in). Sign in with Apple leads; email is the quiet
/// alternative. Errors are red; notices (confirmation email) are calm steel.
struct AuthView: View {
    enum Mode { case signUp, signIn }

    @Environment(AppStore.self) private var store
    var mode: Mode
    var draft: OnboardingDraft
    var onComplete: (AuthResult) async -> Void
    var onSkip: () -> Void

    @State private var showingEmail = false
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var error: AuthError?
    @State private var nonce = ""
    @State private var emailMode: Mode = .signUp

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: GBSpace.sm) {
                Text(mode == .signUp ? "Save your progress." : "Welcome back.")
                    .font(GBFont.hero(32))
                    .foregroundStyle(GBColor.ink)
                Text(mode == .signUp
                     ? "An account keeps your workouts, streak and friends safe across phones."
                     : "Sign in to pick up your streak where you left it.")
                    .font(GBFont.body(17))
                    .foregroundStyle(GBColor.steel)
            }
            .padding(.top, GBSpace.xl)

            Spacer()

            if showingEmail { emailForm } else { Spacer() }

            if let error {
                Text(error.message)
                    .font(GBFont.body(14))
                    .foregroundStyle(error.isNotice ? GBColor.steel : GBColor.danger)
                    .padding(.bottom, GBSpace.sm)
                    .transition(.opacity)
            }

            VStack(spacing: GBSpace.sm) {
                SignInWithAppleButton(mode == .signUp ? .signUp : .signIn) { request in
                    nonce = AppleSignInNonce.random()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignInNonce.sha256(nonce)
                } onCompletion: { result in
                    handleApple(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 58)
                .clipShape(Capsule())
                .disabled(busy)

                if !showingEmail {
                    Button("Continue with email") {
                        emailMode = mode
                        withAnimation(.snappy) { showingEmail = true }
                    }
                    .buttonStyle(GlassButtonStyle(height: 58))
                }

                #if DEBUG
                if !store.auth.isConfigured {
                    Button("Skip — dev build, no Supabase") {
                        Haptics.tap()
                        onSkip()
                    }
                    .buttonStyle(QuietButtonStyle(color: GBColor.orange))
                    .padding(.top, GBSpace.xs)
                }
                #endif

                Text("By continuing you agree to the Terms and Privacy Policy.")
                    .font(GBFont.body(12))
                    .foregroundStyle(GBColor.fog)
                    .multilineTextAlignment(.center)
                    .padding(.top, GBSpace.xs)
            }
            .padding(.bottom, GBSpace.xs)
        }
        .padding(.horizontal, GBSpace.xl)
        .animation(.snappy, value: error)
        .overlay {
            if busy {
                ProgressView().controlSize(.large).tint(GBColor.ink)
            }
        }
    }

    private var emailForm: some View {
        VStack(spacing: GBSpace.sm) {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .authField()
            SecureField("Password", text: $password)
                .textContentType(emailMode == .signUp ? .newPassword : .password)
                .authField()
            Button(emailMode == .signUp ? "Create account" : "Sign in") { submitEmail() }
                .buttonStyle(.ink)
                .disabled(busy || !email.contains("@") || password.count < 6)
            Button(emailMode == .signUp ? "I have an account — sign in" : "New here — create an account") {
                emailMode = emailMode == .signUp ? .signIn : .signUp
                error = nil
            }
            .buttonStyle(.quiet)
            .font(GBFont.body(14))
            .padding(.vertical, GBSpace.xs)
        }
        .padding(.bottom, GBSpace.md)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let err):
            if (err as? ASAuthorizationError)?.code == .canceled { return }
            error = .unknown(err.localizedDescription)
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8)
            else {
                error = .unknown("Apple didn't return a sign-in token. Try again.")
                return
            }
            run { try await store.auth.signInWithApple(idToken: token, nonce: nonce) }
        }
    }

    private func submitEmail() {
        let e = email.trimmingCharacters(in: .whitespaces)
        let p = password
        run {
            emailMode == .signUp
                ? try await store.auth.signUp(email: e, password: p)
                : try await store.auth.signIn(email: e, password: p)
        }
    }

    private func run(_ work: @escaping () async throws -> AuthResult) {
        busy = true
        error = nil
        Task {
            do {
                let result = try await work()
                Haptics.success()
                await onComplete(result)
            } catch let e as AuthError {
                error = e
                if !e.isNotice { Haptics.warning() }
            } catch {
                self.error = .unknown(error.localizedDescription)
                Haptics.warning()
            }
            busy = false
        }
    }
}

private extension View {
    func authField() -> some View {
        self
            .font(GBFont.body(17))
            .padding(.horizontal, GBSpace.md)
            .frame(height: 54)
            .solidCard(cornerRadius: GBRadius.sm)
    }
}
