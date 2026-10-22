import SwiftUI

extension SessionStatus {
    var title: String {
        switch self {
        case .unloaded: "Inativa"
        case .loading: "Carregando…"
        case .ready: "Ativa"
        case .failed: "Erro"
        }
    }

    var indicatorColor: Color {
        switch self {
        case .unloaded: .gray
        case .loading: .orange
        case .ready: .green
        case .failed: .red
        }
    }
}
