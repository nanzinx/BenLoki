import Foundation

/// Comparações de host usadas para navegação e permissões.
enum SiteMatcher {
    /// Heurística de "mesmo site": compara os dois últimos rótulos do host.
    /// Limitação conhecida: sufixos compostos (ex.: `.com.br`) podem ser
    /// considerados iguais. Por isso NÃO use esta função para permissões.
    static func isSameSite(_ hostA: String?, _ hostB: String?) -> Bool {
        guard let hostA, let hostB else { return false }
        return rootLabels(of: hostA) == rootLabels(of: hostB)
    }

    /// Estrito: `host` é exatamente `domain` ou um subdomínio dele.
    /// Use esta função para decidir permissões de câmera/microfone.
    static func isHost(_ host: String, within domain: String?) -> Bool {
        guard let domain else { return false }
        return host == domain || host.hasSuffix("." + domain)
    }

    private static func rootLabels(of host: String) -> ArraySlice<Substring> {
        host.split(separator: ".").suffix(2)
    }
}
