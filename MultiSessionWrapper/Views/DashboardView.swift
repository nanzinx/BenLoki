import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var manager: InstanceManager
    @EnvironmentObject private var runtime: SessionRuntime

    @State private var isAddingInstance = false
    @State private var instancePendingRemoval: SessionInstance?

    var body: some View {
        NavigationStack {
            Group {
                if manager.instances.isEmpty {
                    emptyState
                } else {
                    instanceList
                }
            }
            .navigationTitle("Contas")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isAddingInstance = true
                    } label: {
                        Label("Nova conta", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: SessionInstance.self) { instance in
                SessionDetailView(instanceID: instance.id)
            }
            .sheet(isPresented: $isAddingInstance) {
                AddInstanceView()
            }
            .confirmationDialog(
                "Remover conta?",
                isPresented: isConfirmingRemoval,
                presenting: instancePendingRemoval
            ) { instance in
                Button("Remover e apagar dados", role: .destructive) {
                    Task { await manager.remove(instance) }
                }
            } message: { instance in
                Text("Login, cookies e cache de \(instance.name) serão apagados permanentemente.")
            }
            .alert("Erro", isPresented: hasError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(manager.lastError ?? "")
            }
        }
    }

    private var instanceList: some View {
        List {
            ForEach(manager.instances) { instance in
                NavigationLink(value: instance) {
                    InstanceRow(
                        instance: instance,
                        status: runtime.statuses[instance.id] ?? .unloaded
                    )
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        instancePendingRemoval = instance
                    } label: {
                        Label("Remover", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.crop.square.stack")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Nenhuma conta criada")
                .font(.headline)
            Text("Cada conta tem login, cookies e cache isolados.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Criar primeira conta") {
                isAddingInstance = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var isConfirmingRemoval: Binding<Bool> {
        Binding(
            get: { instancePendingRemoval != nil },
            set: { if !$0 { instancePendingRemoval = nil } }
        )
    }

    private var hasError: Binding<Bool> {
        Binding(
            get: { manager.lastError != nil },
            set: { if !$0 { manager.lastError = nil } }
        )
    }
}

struct InstanceRow: View {
    let instance: SessionInstance
    let status: SessionStatus

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: instance.iconSystemName)
                .font(.title2)
                .frame(width: 40, height: 40)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(instance.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    Circle()
                        .fill(status.indicatorColor)
                        .frame(width: 8, height: 8)
                    Text(status.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
