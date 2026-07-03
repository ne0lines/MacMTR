import XCTest
@testable import MacMTRCore

final class SessionRunnerTests: XCTestCase {
    func testSamplesHopBeforeTraceRouteStreamCompletes() async throws {
        var traceContinuation: AsyncThrowingStream<RouteHop, Error>.Continuation!
        let traceStream = AsyncThrowingStream<RouteHop, Error> { continuation in
            traceContinuation = continuation
        }
        let client = FakeNetworkToolClient(
            traceStream: traceStream,
            pingSample: PingSample(latencyMilliseconds: 7.5)
        )
        let runner = MTRSessionRunner(client: client)
        var iterator = runner.events(
            target: "example.com",
            maxHops: 30,
            intervalMilliseconds: 1_000
        ).makeAsyncIterator()

        traceContinuation.yield(RouteHop(index: 1, address: "192.0.2.1", hostname: nil))

        let firstEvent = try await iterator.next()
        let secondEvent = try await iterator.next()

        XCTAssertEqual(firstEvent, .hopDiscovered(RouteHop(index: 1, address: "192.0.2.1", hostname: nil)))
        XCTAssertEqual(secondEvent, .sampleRecorded(hopID: 1, sample: PingSample(latencyMilliseconds: 7.5)))

        traceContinuation.finish()
    }
}

private struct FakeNetworkToolClient: NetworkToolClient {
    let traceStream: AsyncThrowingStream<RouteHop, Error>
    let pingSample: PingSample

    func traceRoute(to target: String, maxHops: Int) async throws -> [RouteHop] {
        var hops: [RouteHop] = []
        for try await hop in traceRouteHops(to: target, maxHops: maxHops) {
            hops.append(hop)
        }
        return hops
    }

    func traceRouteHops(to target: String, maxHops: Int) -> AsyncThrowingStream<RouteHop, Error> {
        traceStream
    }

    func sampleHop(target: String, ttl: Int, timeoutMilliseconds: Int) async throws -> PingSample {
        pingSample
    }

    func ping(address: String, timeoutMilliseconds: Int) async throws -> PingSample {
        pingSample
    }
}
