import SwiftUI

/// Edita nome e ícone de uma conta. A URL fica fixa: os dados de login
/// do data store pertencem àquele site.
struct EditInstanceView: View {
    let instance: SessionInstance

    @EnvironmentObject private var manager: InstanceManager
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var iconSystemName: String
    @State private var errorMessage: String?

    init(instance: SessionInstance) {
        self.instance = instance
        _name = State(initialValue: instance.name)
        _iconSystemName = State(initialValue: instance.iconSystemName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    preview
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }

                Section("Nome") {
                    TextField("Nome da conta", text: $name)
                        .submitLabel(.done)
                }

                Section("Ícone") {
                    IconPicker(selection: $iconSystemName)
                }

                Section {
                    Text(instance.baseURL.absoluteString)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                } header: {
                    Text("Endereço")
                } footer: {
                    Text("O endereço não pode ser alterado, porque o login desta conta pertence a este site.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Editar conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var preview: some View {
        VStack(spacing: 10) {
            Image(systemName: iconSystemName)
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text(trimmedName.isEmpty ? "Sem nome" : trimmedName)
                .font(.headline)
                .foregroundStyle(trimmedName.isEmpty ? .secondary : .primary)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
            && (trimmedName != instance.name || iconSystemName != instance.iconSystemName)
    }

    private func save() {
        do {
            try manager.update(instance.id, name: name, iconSystemName: iconSystemName)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
