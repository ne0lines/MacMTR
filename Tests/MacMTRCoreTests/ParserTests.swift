import XCTest
@testable import MacMTRCore

final class ParserTests: XCTestCase {
    func testTracerouteParserExtractsHopsAndTimeouts() {
        let output = """
        traceroute to example.com (93.184.216.34), 64 hops max, 40 byte packets
         1  192.168.1.1  1.234 ms
         2  * * *
         3  edge.example.net (203.0.113.8)  15.900 ms
        """

        let hops = TracerouteParser.parse(output)

        XCTAssertEqual(hops, [
            RouteHop(index: 1, address: "192.168.1.1", hostname: nil),
            RouteHop(index: 2, address: nil, hostname: nil),
            RouteHop(index: 3, address: "203.0.113.8", hostname: "edge.example.net")
        ])
    }

    func testPingParserExtractsLatencyAndTimeout() {
        let reply = "64 bytes from 1.1.1.1: icmp_seq=0 ttl=56 time=12.345 ms"
        let timeout = "Request timeout for icmp_seq 0"

        XCTAssertEqual(PingParser.parse(reply), PingSample(latencyMilliseconds: 12.345))
        XCTAssertEqual(PingParser.parse(timeout), PingSample(latencyMilliseconds: nil))
    }
}
