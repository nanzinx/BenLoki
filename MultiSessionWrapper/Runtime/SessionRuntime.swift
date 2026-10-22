import Combine
import SwiftUI
import UIKit
import WebKit

/// O que fazer com os WKWebView quando o app vai para background.
enum BackgroundPolicy {
    /// Descarrega tudo: libera RAM e bateria. Ao voltar, a página recarrega
    /// com a sessão preservada no data store.
    case unloadAll
    /// Mantém os WKWebView. O iOS os suspende em poucos segundos de qualquer
    /// forma; útil só para retorno rápido pelo app switcher.
    case keepAlive
}

/// Orquestra os `SessionController`: cria, reaproveita, despeja (LRU) e reage
/// ao ciclo de vida. É o único ponto que decide quantos WKWebView existem.
@MainActor
final class SessionRuntime: ObservableObject {
    /// Máximo de WKWebView vivos ao mesmo tempo (ativo + aquecidos).
    /// Cada um pode custar dezenas a centenas de MB de RAM.
    var maxLiveSessions = 2
    var backgroundPolicy: BackgroundPolicy = .unloadAll

    @Published private(set) var statuses: [UUID: SessionStatus] = [:]
    @Published private(set) var activeID: UUID?

    private let dataStores = DataStoreProvider()
    private var controllers: [UUID: SessionController] = [:]
    private var memoryWarningObserver: AnyCancellable?

    init() {
        memoryWarningObserver = NotificationCenter.default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.handleMemoryWarning() }
            }
    }

    // MARK: - Acesso aos WebViews

    /// Devolve o WKWebView da instância, criando-o se preciso.
    /// Use só em `makeUIView`; em `updateUIView` use `liveWebView(for:)`.
    func webView(for instance: SessionInstance) -> WKWebView {
        session(for: instance).activate()
    }

    /// WebView já existente, sem criar um novo. Evita reviver uma sessão
    /// que acabou de ser descarregada durante uma atualização de tela.
    func liveWebView(for id: UUID) -> WKWebView? {
        controllers[id]?.webView
    }

    /// Aplica mudanças de configuração (ex.: User-Agent) a uma instância viva.
    func update(_ instance: SessionInstance) {
        controllers[instance.id]?.apply(instance)
    }

    func reload(_ id: UUID) {
        controllers[id]?.reload()
    }

    // MARK: - Visibilidade

    /// Chamado quando a tela da instância aparece ou o app volta ao primeiro plano.
    func didActivate(_ instance: SessionInstance) {
        _ = webView(for: instance)   // garante o WebView vivo (ex.: após background)
        activeID = instance.id
        enforceLiveLimit()
    }

    func didDeactivate(_ id: UUID) {
        guard activeID == id else { return }
        activeID = nil
        enforceLiveLimit()
    }

    // MARK: - Ciclo de vida

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Sem JS e sem sockets em background, WebViews só consomem RAM e bateria.
            // Push nativo não é possível via WKWebView (ver README).
            if backgroundPolicy == .unloadAll {
                unloadAll()
            }
        case .inactive, .active:
            break
        @unknown default:
            break
        }
    }

    /// Remove a instância da memória e apaga todos os seus dados.
    func destroy(_ instance: SessionInstance) async throws {
        controllers[instance.id]?.unload()
        controllers[instance.id] = nil
        statuses[instance.id] = nil
        if activeID == instance.id {
            activeID = nil
        }
        try await dataStores.wipe(instance)
    }

    // MARK: - Internos

    private func session(for instance: SessionInstance) -> SessionController {
        if let existing = controllers[instance.id] {
            existing.apply(instance)
            return existing
        }
        let controller = SessionController(
            instance: instance,
            dataStore: dataStores.dataStore(for: instance)
        )
        controller.onStatusChange = { [weak self] id, status in
            self?.statuses[id] = status
        }
        controllers[instance.id] = controller
        return controller
    }

    /// Mantém no máximo `maxLiveSessions` WebViews vivos, despejando os menos
    /// usados recentemente. A instância ativa nunca é despejada aqui.
    private func enforceLiveLimit() {
        let activeIsLive = activeID.flatMap { controllers[$0] }?.isLive ?? false
        let warmBudget = max(maxLiveSessions - (activeIsLive ? 1 : 0), 0)

        let warm = controllers.values
            .filter { $0.isLive && $0.instance.id != activeID }
            .sorted { $0.lastActiveAt > $1.lastActiveAt }   // mais recente primeiro

        for controller in warm.dropFirst(warmBudget) {
            controller.unload()
        }
    }

    private func handleMemoryWarning() {
        unloadAll(except: activeID)
    }

    private func unloadAll(except keepID: UUID? = nil) {
        for controller in controllers.values where controller.instance.id != keepID {
            controller.unload()
        }
    }
}
