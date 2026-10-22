import LocalAuthentication
import SwiftUI
import UIKit

/// Tipo de autenticação disponível no aparelho, para textos e ícones.
struct BiometryKind {
    let name: String
    let symbolName: String

    static func current() -> BiometryKind {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID: return BiometryKind(name: "Face ID", symbolName: "faceid")
        case .touchID: return BiometryKind(name: "Touch ID", symbolName: "touchid")
        default: return BiometryKind(name: "código do iPhone", symbolName: "lock.fill")
        }
    }
}

/// Bloqueio do app por Face ID/Touch ID, com fallback para o código do aparelho.
///
/// É uma barreira de interface: protege contra quem pega o aparelho já
/// desbloqueado. Em disco, os dados continuam protegidos pelo Data Protection
/// do iOS, não por esta classe.
@MainActor
final class AppLockManager: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isLocked: Bool {
        didSet { notifyVisibility() }
    }
    /// Cobre o conteúdo sem exigir autenticação (ex.: app switcher).
    @Published private(set) var isObscured = false {
        didSet { notifyVisibility() }
    }
    @Published private(set) var isAuthenticating = false
    @Published private(set) var errorMessage: String?

    let biometry = BiometryKind.current()
    /// Chamado de forma síncrona para que a capa apareça antes do snapshot
    /// que o iOS tira para o app switcher.
    var onContentHiddenChange: (@MainActor (Bool) -> Void)?

    var isContentHidden: Bool { isLocked || isObscured }
    var isAvailable: Bool { Self.canAuthenticate() }

    private let defaults: UserDefaults
    private var hasPromptedForCurrentLock = false

    private static let enabledKey = "appLock.enabled"
    private static let cancellationCodes: Set<LAError.Code> = [.userCancel, .appCancel, .systemCancel]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        isEnabled = enabled
        isLocked = enabled && Self.canAuthenticate()
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            isObscured = false
            promptIfNeeded()
        case .inactive:
            if isEnabled { isObscured = true }
        case .background:
            if isEnabled { isObscured = true }
            lock()
        @unknown default:
            break
        }
    }

    /// Abre o prompt automaticamente uma única vez por bloqueio. O próprio
    /// prompt deixa o app inativo e ativo de novo; repetir sozinho após um
    /// cancelamento criaria um loop. Depois disso, o usuário usa o botão.
    func promptIfNeeded() {
        guard isLocked,
              !hasPromptedForCurrentLock,
              !isAuthenticating,
              UIApplication.shared.applicationState == .active else { return }
        hasPromptedForCurrentLock = true
        Task { await unlock() }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        if await authenticate(reason: "Desbloqueie para acessar suas contas.") {
            isLocked = false
        }
    }

    /// Ativar e desativar exigem autenticação: ativar confirma que o usuário
    /// consegue desbloquear; desativar impede que terceiros removam a proteção.
    func setEnabled(_ enabled: Bool) async {
        guard enabled != isEnabled else { return }
        let reason = enabled ? "Confirme para ativar o bloqueio." : "Confirme para desativar o bloqueio."
        guard await authenticate(reason: reason) else { return }
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
    }

    private func lock() {
        guard isEnabled, Self.canAuthenticate() else { return }
        hasPromptedForCurrentLock = false
        errorMessage = nil
        isLocked = true
    }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var availabilityError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &availabilityError) else {
            errorMessage = availabilityError?.localizedDescription ?? "Autenticação indisponível."
            return false
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            errorMessage = nil
            return success
        } catch let error as LAError where Self.cancellationCodes.contains(error.code) {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func notifyVisibility() {
        onContentHiddenChange?(isContentHidden)
    }

    /// `.deviceOwnerAuthentication` aceita biometria ou código. Sem código
    /// configurado no aparelho, não há como autenticar e o app não bloqueia.
    private static func canAuthenticate() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }
}
