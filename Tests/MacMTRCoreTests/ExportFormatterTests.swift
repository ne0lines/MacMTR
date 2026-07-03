import XCTest
@testable import MacMTRCore

final class ExportFormatterTests: XCTestCase {
    func testTextExportContainsWinMTRStyleColumns() {
        var report = HopReport(hop: RouteHop(index: 1, address: "192.168.1.1", hostname: "router.local"))
        report.record(PingSample(latencyMilliseconds: 1.2))

        let text = ExportFormatter.text(target: "example.com", reports: [report])

        XCTAssertTrue(text.contains("Target: example.com"))
        XCTAssertTrue(text.contains("Hop"))
        XCTAssertTrue(text.contains("Loss%"))
        XCTAssertTrue(text.contains("router.local"))
        XCTAssertTrue(text.contains("192.168.1.1"))
        XCTAssertTrue(text.contains("1.2"))
    }

    func testHTMLExportContainsTableRows() {
        let report = HopReport(hop: RouteHop(index: 2, address: nil, hostname: nil))

        let html = ExportFormatter.html(target: "example.com", reports: [report])

        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("<td>2</td>"))
        XCTAssertTrue(html.contains("No response from host"))
        XCTAssertFalse(html.contains("&ast;"))
    }
}
