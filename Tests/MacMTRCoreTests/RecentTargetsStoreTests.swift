import XCTest
@testable import MacMTRCore

final class RecentTargetsStoreTests: XCTestCase {
    private let suiteName = "MacMTRCoreTests.RecentTargetsStore"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testDefaultTargetIsCloudflareDNS() {
        XCTAssertEqual(RecentTargetsStore.defaultTarget, "1.1.1.1")
    }

    func testRememberedTargetsAreRecentUniqueAndPersistent() {
        let store = RecentTargetsStore(defaults: defaults, limit: 3)

        XCTAssertEqual(store.load(), [])

        XCTAssertEqual(store.remember(" github.com "), ["github.com"])
        XCTAssertEqual(store.remember("1.1.1.1"), ["1.1.1.1", "github.com"])
        XCTAssertEqual(store.remember("github.com"), ["github.com", "1.1.1.1"])
        XCTAssertEqual(store.remember("cloudflare.com"), ["cloudflare.com", "github.com", "1.1.1.1"])
        XCTAssertEqual(store.remember("apple.com"), ["apple.com", "cloudflare.com", "github.com"])
        XCTAssertEqual(store.load(), ["apple.com", "cloudflare.com", "github.com"])
    }

    func testClearRemovesRememberedTargets() {
        let store = RecentTargetsStore(defaults: defaults, limit: 3)

        _ = store.remember("1.1.1.1")
        store.clear()

        XCTAssertEqual(store.load(), [])
    }
}
