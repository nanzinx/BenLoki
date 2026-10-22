import SwiftUI

struct SessionDetailView: View {
    let instanceID: UUID

    @EnvironmentObject private var manager: InstanceManager
    @EnvironmentObject private var runtime: SessionRuntime
    @Environment(\.scenePhase) private var scenePhase

    @State private var isEditing = false

    var body: some View {
        Group {
            if let instance = currentInstance {
                ZStack(alignment: .top) {
                    SessionWebView(instance: instance, runtime: runtime)

                    if runtime.statuses[instance.id] == .loading {
                        ProgressView()
                            .padding(8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.top, 8)
                    }
                }
                .navigationTitle(instance.name)
                .toolbar {
                    toolbarContent(for: instance)
                }
                .sheet(isPresented: $isEditing) {
                    EditInstanceView(instance: instance)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: activate)
        .onDisappear {
            runtime.didDeactivate(instanceID)
        }
        .onChange(of: scenePhase) { phase in
            // Ao voltar do background, o WebView pode ter sido descarregado.
            if phase == .active {
                activate()
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent(for instance: SessionInstance) -> some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button {
                runtime.reload(instance.id)
            } label: {
                Image(systemName: "arrow.clockwise")
            }

            Menu {
                Button {
                    isEditing = true
                } label: {
                    Label("Editar nome e ícone", systemImage: "pencil")
                }

                Divider()

                Picker("User-Agent", selection: userAgentBinding(for: instance)) {
                    ForEach(UserAgentMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var currentInstance: SessionInstance? {
        manager.instances.first { $0.id == instanceID }
    }

    private func activate() {
        guard let instance = currentInstance else { return }
        runtime.didActivate(instance)
    }

    private func userAgentBinding(for instance: SessionInstance) -> Binding<UserAgentMode> {
        Binding(
            get: { instance.userAgentMode },
            set: { manager.setUserAgent($0, for: instance.id) }
        )
    }
}
