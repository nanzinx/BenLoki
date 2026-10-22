import Foundation

enum InstanceError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Informe uma URL https:// válida."
        }
    }
}

/// Fonte da verdade da lista de contas. Persiste a cada mutação.
@MainActor
final class InstanceManager: ObservableObject {
    @Published private(set) var instances: [SessionInstance] = []
    @Published var lastError: String?

    private let store: any InstanceStoreProtocol
    private let runtime: SessionRuntime

    init(store: any InstanceStoreProtocol, runtime: SessionRuntime) {
        self.store = store
        self.runtime = runtime
        do {
            instances = try store.load()
        } catch {
            lastError = "Não foi possível carregar as contas: \(error.localizedDescription)"
        }
    }

    func add(
        name: String,
        urlString: String,
        iconSystemName: String,
        userAgentMode: UserAgentMode
    ) throws {
        guard let url = Self.validatedURL(from: urlString) else {
            throw InstanceError.invalidURL
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let instance = SessionInstance(
            name: trimmedName.isEmpty ? (url.host ?? "Conta") : trimmedName,
            iconSystemName: iconSystemName,
            baseURL: url,
            userAgentMode: userAgentMode
        )
        instances.append(instance)
        persistOrReport()
    }

    func setUserAgent(_ mode: UserAgentMode, for id: UUID) {
        guard let index = instances.firstIndex(where: { $0.id == id }) else { return }
        instances[index].userAgentMode = mode
        persistOrReport()
    }

    /// Apaga os dados da conta antes de removê-la da lista. Se a limpeza falhar,
    /// a conta permanece na lista para o usuário tentar de novo.
    func remove(_ instance: SessionInstance) async {
        do {
            try await runtime.destroy(instance)
        } catch {
            lastError = "Não foi possível apagar os dados de \(instance.name): \(error.localizedDescription)"
            return
        }
        instances.removeAll { $0.id == instance.id }
        persistOrReport()
    }

    static func validatedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "https", url.host != nil else {
            return nil
        }
        return url
    }

    private func persistOrReport() {
        do {
            try store.save(instances)
        } catch {
            lastError = "Falha ao salvar as contas: \(error.localizedDescription)"
        }
    }
}
