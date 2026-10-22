import Foundation

/// Persistência dos metadados das contas. Nunca guarda cookies ou tokens:
/// os dados de sessão ficam nos `WKWebsiteDataStore` isolados.
protocol InstanceStoreProtocol {
    func load() throws -> [SessionInstance]
    func save(_ instances: [SessionInstance]) throws
}

/// JSON versionado no Application Support, gravado de forma atômica.
final class FileInstanceStore: InstanceStoreProtocol {
    private struct Envelope: Codable {
        static let currentVersion = 1

        let version: Int
        let instances: [SessionInstance]
    }

    private let fileURL: URL

    init() throws {
        let fileManager = FileManager.default
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("MultiSession", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("instances.json")
    }

    func load() throws -> [SessionInstance] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        // Migrações futuras entram aqui, comparando `envelope.version`.
        return envelope.instances
    }

    func save(_ instances: [SessionInstance]) throws {
        let envelope = Envelope(version: Envelope.currentVersion, instances: instances)
        let data = try JSONEncoder().encode(envelope)
        // "Até a primeira autenticação": o app pode ser lançado em background
        // após reinício do aparelho, antes de o usuário desbloquear.
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

/// Usada em testes e como fallback se o disco não puder ser aberto.
final class InMemoryInstanceStore: InstanceStoreProtocol {
    private var instances: [SessionInstance] = []

    func load() throws -> [SessionInstance] { instances }

    func save(_ instances: [SessionInstance]) throws {
        self.instances = instances
    }
}
