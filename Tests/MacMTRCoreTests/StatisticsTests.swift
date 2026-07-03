import XCTest
@testable import MacMTRCore

final class StatisticsTests: XCTestCase {
    func testHopReportCalculatesLossAndLatencyStats() {
        var report = HopReport(hop: RouteHop(index: 4, address: "203.0.113.10", hostname: nil))

        report.record(PingSample(latencyMilliseconds: 20))
        report.record(PingSample(latencyMilliseconds: nil))
        report.record(PingSample(latencyMilliseconds: 10))

        XCTAssertEqual(report.sent, 3)
        XCTAssertEqual(report.received, 2)
        XCTAssertEqual(report.lossPercent, 33.333333333333336, accuracy: 0.000001)
        XCTAssertEqual(report.lastMilliseconds, 10)
        XCTAssertEqual(report.averageMilliseconds, 15)
        XCTAssertEqual(report.bestMilliseconds, 10)
        XCTAssertEqual(report.worstMilliseconds, 20)
    }
}
