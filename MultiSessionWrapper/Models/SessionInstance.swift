import Foundation

/// Uma conta/instância clonada. É o contrato persistido em disco:
/// mudanças de schema devem ser versionadas em `FileInstanceStore`.
struct SessionInstance: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var iconSystemName: String
    var baseURL: URL
    var userAgentMode: UserAgentMode
    /// Identificador do `WKWebsiteDataStore` dedicado. Nunca muda: trocá-lo
    /// faria a instância perder login e dados existentes.
    let dataStoreID: UUID
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        iconSystemName: String = "bubble.left.and.bubble.right.fill",
        baseURL: URL,
        userAgentMode: UserAgentMode = .mobile,
        dataStoreID: UUID = UUID(),
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.iconSystemName = iconSystemName
        self.baseURL = baseURL
        self.userAgentMode = userAgentMode
        self.dataStoreID = dataStoreID
        self.createdAt = createdAt
    }
}

enum UserAgentMode: String, Codable, CaseIterable, Identifiable {
    case mobile
    case desktop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mobile: "iPhone (padrão)"
        case .desktop: "Mac (desktop)"
        }
    }

    /// `nil` mantém o User-Agent padrão do WebKit.
    var customUserAgent: String? {
        switch self {
        case .mobile: nil
        case .desktop: Self.desktopSafariUserAgent
        }
    }

    // Revise periodicamente: UAs desatualizados podem disparar bloqueios.
    private static let desktopSafariUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
}
