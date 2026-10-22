import SwiftUI

struct LockView: View {
    @EnvironmentObject private var lock: AppLockManager

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: lock.biometry.symbolName)
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text("Contas protegidas")
                    .font(.title2.bold())

                if lock.isLocked {
                    Button {
                        Task { await lock.unlock() }
                    } label: {
                        Label("Desbloquear com \(lock.biometry.name)", systemImage: lock.biometry.symbolName)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(lock.isAuthenticating)

                    if let errorMessage = lock.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            // Na abertura do app, a mudança de scenePhase pode já ter passado.
            lock.promptIfNeeded()
        }
    }
}
