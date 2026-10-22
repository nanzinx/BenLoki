import XCTest
@testable import MultiSessionWrapper

final class InstanceStoreTests: XCTestCase {
    func testInMemoryStoreRoundTripsInstances() throws {
        let store = InMemoryInstanceStore()
        let instance = SessionInstance(name: "Teste", baseURL: URL(string: "https://example.com")!)

        try store.save([instance])

        XCTAssertEqual(try store.load(), [instance])
    }

    func testEachInstanceGetsItsOwnDataStoreID() {
        let first = SessionInstance(name: "A", baseURL: URL(string: "https://a.com")!)
        let second = SessionInstance(name: "B", baseURL: URL(string: "https://b.com")!)

        XCTAssertNotEqual(first.dataStoreID, second.dataStoreID)
    }

    func testSameSiteIgnoresSubdomains() {
        XCTAssertTrue(SiteMatcher.isSameSite("web.whatsapp.com", "whatsapp.com"))
        XCTAssertFalse(SiteMatcher.isSameSite("static.whatsapp.net", "whatsapp.com"))
    }

    func testMediaPermissionHostMatchRejectsLookalikeDomains() {
        XCTAssertTrue(SiteMatcher.isHost("web.whatsapp.com", within: "whatsapp.com"))
        XCTAssertTrue(SiteMatcher.isHost("whatsapp.com", within: "whatsapp.com"))
        XCTAssertFalse(SiteMatcher.isHost("evilwhatsapp.com", within: "whatsapp.com"))
    }

    func testValidatedURLRequiresHTTPS() {
        XCTAssertNotNil(InstanceManager.validatedURL(from: "https://web.telegram.org/k/"))
        XCTAssertNil(InstanceManager.validatedURL(from: "http://example.com"))
        XCTAssertNil(InstanceManager.validatedURL(from: "javascript:alert(1)"))
    }
}
