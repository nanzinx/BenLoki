import WebKit

/// Camada 1 de isolamento: cada instância tem um `WKWebsiteDataStore` próprio,
/// com cookies, localStorage, IndexedDB, Cache API e service workers separados.
///
/// Regra do projeto: nunca usar `WKWebsiteDataStore.default()`, pois ele é
/// compartilhado por todas as instâncias.
@MainActor
final class DataStoreProvider {
    private var stores: [UUID: WKWebsiteDataStore] = [:]

    func dataStore(for instance: SessionInstance) -> WKWebsiteDataStore {
        if let store = stores[instance.dataStoreID] {
            return store
        }
        let store = makeStore(identifier: instance.dataStoreID)
        stores[instance.dataStoreID] = store
        return store
    }

    /// Apaga todos os dados do store e remove o store do sistema.
    /// Libere antes os WKWebView que o usam, senão a remoção pode falhar.
    func wipe(_ instance: SessionInstance) async throws {
        let store = dataStore(for: instance)
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        stores[instance.dataStoreID] = nil

        if #available(iOS 17.0, *) {
            try await WKWebsiteDataStore.remove(forIdentifier: instance.dataStoreID)
        }
    }

    private func makeStore(identifier: UUID) -> WKWebsiteDataStore {
        if #available(iOS 17.0, *) {
            return WKWebsiteDataStore(forIdentifier: identifier)
        }
        // iOS 16 não oferece stores persistentes nomeados. O fallback isola a
        // instância só durante a execução do app: o login se perde ao fechar.
        return WKWebsiteDataStore.nonPersistent()
    }
}
