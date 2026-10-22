import SwiftUI
import UIKit
import WebKit

/// Hospeda o WKWebView da instância. A View não é dona do WebView: ele pertence
/// ao `SessionRuntime` e é apenas reanexado quando a tela é atualizada.
struct SessionWebView: UIViewRepresentable {
    let instance: SessionInstance
    let runtime: SessionRuntime

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground
        attach(runtime.webView(for: instance), to: container)
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        // Não cria WebView aqui: a atualização pode ocorrer enquanto o app
        // está indo para background, e recriar anularia o descarregamento.
        runtime.update(instance)
        guard let webView = runtime.liveWebView(for: instance.id) else { return }
        attach(webView, to: container)
    }

    private func attach(_ webView: WKWebView, to container: UIView) {
        guard webView.superview !== container else { return }
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(webView)
    }
}
