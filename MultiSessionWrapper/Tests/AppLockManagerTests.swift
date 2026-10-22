import XCTest
@testable import MultiSessionWrapper

@MainActor
final class AppLockManagerTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AppLockManagerTests")
        defaults.removePersistentDomain(forName: "AppLockManagerTests")
    }

    func testDisabledLockStartsUnlocked() {
        defaults.set(false, forKey: "appLock.enabled")

        let lock = AppLockManager(defaults: defaults)

        XCTAssertFalse(lock.isLocked)
        XCTAssertFalse(lock.isContentHidden)
    }

    func testDisabledLockDoesNotObscureOnInactive() {
        defaults.set(false, forKey: "appLock.enabled")
        let lock = AppLockManager(defaults: defaults)

        lock.handleScenePhase(.inactive)

        XCTAssertFalse(lock.isContentHidden)
    }

    func testLockIsEnabledByDefault() {
        let lock = AppLockManager(defaults: defaults)

        XCTAssertTrue(lock.isEnabled)
    }
}
