import SwiftUI

struct AddInstanceView: View {
    @EnvironmentObject private var manager: InstanceManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var urlText = ""
    @State private var iconSystemName = "bubble.left.and.bubble.right.fill"
    @State private var userAgentMode: UserAgentMode = .mobile
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Menu("Usar modelo…") {
                        ForEach(ServicePreset.all) { preset in
                            Button(preset.name) {
                                apply(preset)
                            }
                        }
                    }
                }

                Section("Conta") {
                    TextField("Nome (ex.: Pessoal, Trabalho)", text: $name)
                    TextField("https://…", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Picker("User-Agent", selection: $userAgentMode) {
                        ForEach(UserAgentMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                } footer: {
                    Text("Escolha Mac se o serviço exigir a versão desktop.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Nova conta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Criar") { create() }
                        .disabled(urlText.isEmpty)
                }
            }
        }
    }

    private func apply(_ preset: ServicePreset) {
        name = preset.name
        urlText = preset.urlString
        iconSystemName = preset.iconSystemName
    }

    private func create() {
        do {
            try manager.add(
                name: name,
                urlString: urlText,
                iconSystemName: iconSystemName,
                userAgentMode: userAgentMode
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
