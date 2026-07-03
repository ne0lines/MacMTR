import XCTest
@testable import MacMTRCore

final class RouteHopTests: XCTestCase {
    func testDisplayHostUsesWinMTRNoResponseTextForTimeoutHops() {
        let hop = RouteHop(index: 2, address: nil, hostname: nil)

        XCTAssertEqual(hop.displayHost, "No response from host")
    }
}
