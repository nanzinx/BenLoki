import XCTest
@testable import MultiSessionWrapper

@MainActor
final class InstanceManagerTests: XCTestCase {
    private func makeManager(with instances: [SessionInstance]) throws -> (InstanceManager, InMemoryInstanceStore) {
        let store = InMemoryInstanceStore()
        try store.save(instances)
        return (InstanceManager(store: store, runtime: SessionRuntime()), store)
    }

    func testUpdateRenamesTrimsAndPersists() throws {
        let instance = SessionInstance(name: "Antigo", baseURL: URL(string: "https://web.whatsapp.com")!)
        let (manager, store) = try makeManager(with: [instance])

        try manager.update(instance.id, name: "  Trabalho  ", iconSystemName: "briefcase.fill")

        let saved = try XCTUnwrap(store.load().first)
        XCTAssertEqual(saved.name, "Trabalho")
        XCTAssertEqual(saved.iconSystemName, "briefcase.fill")
        XCTAssertEqual(saved.dataStoreID, instance.dataStoreID, "Editar não pode trocar o data store")
    }

    func testUpdateRejectsEmptyName() throws {
        let instance = SessionInstance(name: "Pessoal", baseURL: URL(string: "https://web.whatsapp.com")!)
        let (manager, _) = try makeManager(with: [instance])

        XCTAssertThrowsError(try manager.update(instance.id, name: "   ", iconSystemName: "star.fill"))
        XCTAssertEqual(manager.instances.first?.name, "Pessoal")
    }

    func testNameIsLimitedToMaxLength() {
        let long = String(repeating: "a", count: 60)

        XCTAssertEqual(InstanceManager.normalizedName(long).count, InstanceManager.maxNameLength)
    }
}
