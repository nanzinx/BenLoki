import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var lock: AppLockManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Exigir \(lock.biometry.name)", isOn: lockBinding)
                        .disabled(!lock.isAvailable || lock.isAuthenticating)
                } header: {
                    Text("Segurança")
                } footer: {
                    Text(footerText)
                }

                if let errorMessage = lock.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private var footerText: String {
        lock.isAvailable
            ? "O app bloqueia ao ir para segundo plano e esconde o conteúdo no alternador de apps."
            : "Defina um código no iPhone para usar o bloqueio."
    }

    /// O toggle volta sozinho à posição anterior se a autenticação falhar,
    /// porque o valor exibido sempre vem de `lock.isEnabled`.
    private var lockBinding: Binding<Bool> {
        Binding(
            get: { lock.isEnabled },
            set: { newValue in Task { await lock.setEnabled(newValue) } }
        )
    }
}
