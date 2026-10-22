import SwiftUI

@main
struct MultiSessionApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var runtime: SessionRuntime
    @StateObject private var manager: InstanceManager

    init() {
        let runtime = SessionRuntime()

        let store: any InstanceStoreProtocol
        do {
            store = try FileInstanceStore()
        } catch {
            // Só ocorre se o diretório de Application Support estiver inacessível.
            // Registre em telemetria: nesse caso as contas não serão persistidas.
            store = InMemoryInstanceStore()
        }

        _runtime = StateObject(wrappedValue: runtime)
        _manager = StateObject(wrappedValue: InstanceManager(store: store, runtime: runtime))
    }

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(runtime)
                .environmentObject(manager)
                .onChange(of: scenePhase) { phase in
                    runtime.handleScenePhase(phase)
                }
        }
    }
}
