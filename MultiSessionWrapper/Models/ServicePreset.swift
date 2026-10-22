import Foundation

/// Serviços prontos exibidos na tela de criação. Adicione novos aqui.
struct ServicePreset: Identifiable, Hashable {
    let name: String
    let urlString: String
    let iconSystemName: String

    var id: String { urlString }

    static let all: [ServicePreset] = [
        ServicePreset(name: "WhatsApp Web", urlString: "https://web.whatsapp.com", iconSystemName: "message.fill"),
        ServicePreset(name: "Telegram Web", urlString: "https://web.telegram.org/k/", iconSystemName: "paperplane.fill"),
    ]
}
