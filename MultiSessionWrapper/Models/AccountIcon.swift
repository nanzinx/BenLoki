import Foundation

/// Ícones (SF Symbols) oferecidos ao criar ou editar uma conta.
struct AccountIcon: Identifiable, Hashable {
    let symbolName: String
    /// Nome lido pelo VoiceOver.
    let label: String

    var id: String { symbolName }

    static let all: [AccountIcon] = [
        AccountIcon(symbolName: "bubble.left.and.bubble.right.fill", label: "Conversa"),
        AccountIcon(symbolName: "message.fill", label: "Mensagem"),
        AccountIcon(symbolName: "paperplane.fill", label: "Avião de papel"),
        AccountIcon(symbolName: "phone.fill", label: "Telefone"),
        AccountIcon(symbolName: "envelope.fill", label: "Envelope"),
        AccountIcon(symbolName: "person.fill", label: "Pessoa"),
        AccountIcon(symbolName: "person.2.fill", label: "Grupo"),
        AccountIcon(symbolName: "briefcase.fill", label: "Trabalho"),
        AccountIcon(symbolName: "house.fill", label: "Casa"),
        AccountIcon(symbolName: "heart.fill", label: "Coração"),
        AccountIcon(symbolName: "star.fill", label: "Estrela"),
        AccountIcon(symbolName: "cart.fill", label: "Compras"),
        AccountIcon(symbolName: "graduationcap.fill", label: "Estudos"),
        AccountIcon(symbolName: "gamecontroller.fill", label: "Jogos"),
        AccountIcon(symbolName: "bolt.fill", label: "Raio"),
        AccountIcon(symbolName: "globe", label: "Globo"),
    ]
}
