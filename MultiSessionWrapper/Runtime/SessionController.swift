import UIKit
import WebKit

enum SessionStatus: Equatable {
    /// Sem WKWebView em memória. Os dados continuam no data store.
    case unloaded
    case loading
    case ready
    case failed(String)
}

/// Dono do WKWebView de uma instância. Fica fora da camada de View para que o
/// WebView sobreviva a trocas de tela e possa ser descarregado sob demanda.
@MainActor
final class SessionController: NSObject, WKNavigationDelegate, WKUIDelegate {
    private(set) var instance: SessionInstance
    private(set) var webView: WKWebView?
    private(set) var status: SessionStatus = .unloaded {
        didSet { onStatusChange?(instance.id, status) }
    }
    /// Usado pelo runtime para escolher quem despejar (LRU).
    private(set) var lastActiveAt: Date = .distantPast
    var onStatusChange: (@MainActor (UUID, SessionStatus) -> Void)?

    private let dataStore: WKWebsiteDataStore

    var isLive: Bool { webView != nil }

    init(instance: SessionInstance, dataStore: WKWebsiteDataStore) {
        self.instance = instance
        self.dataStore = dataStore
    }

    /// Cria o WKWebView na primeira chamada e devolve o mesmo nas seguintes.
    /// Não publica estado, porque pode ser chamado durante a atualização da View.
    func activate() -> WKWebView {
        lastActiveAt = .now
        if let webView { return webView }

        let view = makeWebView()
        webView = view
        view.load(URLRequest(url: instance.baseURL))
        return view
    }

    /// Libera o WKWebView e o processo de renderização. O data store permanece:
    /// reativar a instância restaura login e cache.
    func unload() {
        guard let webView else { return }
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()
        self.webView = nil
        status = .unloaded
    }

    func reload() {
        guard let webView else {
            _ = activate()
            return
        }
        webView.reload()
    }

    /// Aplica mudanças de configuração. Recarrega só quando algo relevante muda.
    func apply(_ updated: SessionInstance) {
        let userAgentChanged = updated.userAgentMode != instance.userAgentMode
        instance = updated
        guard userAgentChanged, let webView else { return }
        webView.customUserAgent = updated.userAgentMode.customUserAgent
        webView.reload()
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore          // isolamento por instância
        configuration.allowsInlineMediaPlayback = true      // áudio/vídeo dentro da página
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.customUserAgent = instance.userAgentMode.customUserAgent
        view.allowsBackForwardNavigationGestures = true
        view.navigationDelegate = self
        view.uiDelegate = self
        return view
    }
}

// MARK: - WKNavigationDelegate

extension SessionController {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        status = .loading
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        status = .ready
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        status = .failed(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        // Cancelamentos (-999) são comuns em redirecionamentos e não são erro.
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        status = .failed(error.localizedDescription)
    }

    /// O iOS encerra o processo de renderização sob pressão de memória.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        status = .failed("Página encerrada pelo sistema. Recarregando…")
        webView.reload()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        // Links tocados que saem do site da instância abrem no Safari.
        // Redirecionamentos e subrecursos continuam no WebView para não quebrar logins.
        if navigationAction.navigationType == .linkActivated,
           let url = navigationAction.request.url,
           !SiteMatcher.isSameSite(url.host, instance.baseURL.host) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate

extension SessionController {
    /// Câmera e microfone só para o site da instância. O iOS ainda exibe o
    /// prompt do sistema na primeira vez (chaves em Info.plist).
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let allowed = SiteMatcher.isHost(origin.host, within: instance.baseURL.host)
        decisionHandler(allowed ? .grant : .deny)
    }

    /// `target="_blank"` e `window.open` carregam no mesmo WKWebView, portanto
    /// no mesmo data store, em vez de criar janelas paralelas.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}
