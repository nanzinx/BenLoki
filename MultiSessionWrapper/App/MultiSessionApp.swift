import SwiftUI

@main
struct MultiSessionApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var runtime: SessionRuntime
    @StateObject private var manager: InstanceManager
    @StateObject private var appLock = AppLockManager()
    @StateObject private var lockPresenter = LockWindowPresenter()

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
                .environmentObject(appLock)
                .onAppear {
                    // A cena só existe depois do primeiro onAppear, não no init.
                    lockPresenter.bind(to: appLock)
                }
                .onChange(of: scenePhase) { phase in
                    // O bloqueio vem primeiro para cobrir a tela antes do snapshot.
                    appLock.handleScenePhase(phase)
                    runtime.handleScenePhase(phase)
                }
        }
    }
}
