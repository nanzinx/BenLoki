import SwiftUI
import UIKit

/// Mostra a tela de bloqueio numa UIWindow própria, acima de tudo. Um overlay
/// comum na hierarquia SwiftUI não cobriria sheets, alerts e confirmation
/// dialogs que já estivessem abertos.
@MainActor
final class LockWindowPresenter: ObservableObject {
    private var window: UIWindow?

    func bind(to lock: AppLockManager) {
        lock.onContentHiddenChange = { [weak self, weak lock] isHidden in
            guard let self, let lock else { return }
            if isHidden {
                self.show(lock)
            } else {
                self.hide()
            }
        }
        if lock.isContentHidden {
            show(lock)
        }
    }

    private func show(_ lock: AppLockManager) {
        guard window == nil, let scene = Self.activeWindowScene() else { return }

        let hosting = UIHostingController(rootView: LockView().environmentObject(lock))
        hosting.view.accessibilityViewIsModal = true   // VoiceOver ignora o conteúdo por baixo

        let window = UIWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        window.rootViewController = hosting
        window.isHidden = false
        self.window = window
    }

    private func hide() {
        guard let window else { return }
        self.window = nil
        UIView.animate(withDuration: 0.2) {
            window.alpha = 0
        } completion: { _ in
            window.isHidden = true
        }
    }

    /// O app usa uma única cena. Com várias janelas (iPad), cada cena
    /// precisaria do próprio overlay.
    private static func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}
