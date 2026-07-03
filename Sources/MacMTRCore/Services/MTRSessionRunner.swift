import Foundation

public enum MTRSessionEvent: Equatable, Sendable {
    case hopDiscovered(RouteHop)
    case sampleRecorded(hopID: Int, sample: PingSample)
    case routeCompleted(discoveredHopCount: Int)
}

public struct MTRSessionRunner: Sendable {
    private let client: any NetworkToolClient

    public init(client: any NetworkToolClient) {
        self.client = client
    }

    public func events(
        target: String,
        maxHops: Int,
        intervalMilliseconds: Int
    ) -> AsyncThrowingStream<MTRSessionEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await withTaskGroup(of: Void.self) { group in
                    var discoveredHopIDs = Set<Int>()

                    do {
                        for try await hop in client.traceRouteHops(to: target, maxHops: maxHops) {
                            guard !Task.isCancelled else { return }
                            guard discoveredHopIDs.insert(hop.id).inserted else { continue }

                            continuation.yield(.hopDiscovered(hop))
                            group.addTask {
                                await sample(
                                    target: target,
                                    hop: hop,
                                    intervalMilliseconds: intervalMilliseconds,
                                    client: client,
                                    continuation: continuation
                                )
                            }
                        }

                        continuation.yield(.routeCompleted(discoveredHopCount: discoveredHopIDs.count))
                        await group.waitForAll()
                        continuation.finish()
                    } catch {
                        group.cancelAll()
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

private func sample(
    target: String,
    hop: RouteHop,
    intervalMilliseconds: Int,
    client: any NetworkToolClient,
    continuation: AsyncThrowingStream<MTRSessionEvent, Error>.Continuation
) async {
    while !Task.isCancelled {
        let sample = (try? await client.sampleHop(
            target: target,
            ttl: hop.index,
            timeoutMilliseconds: intervalMilliseconds
        )) ?? PingSample(latencyMilliseconds: nil)

        continuation.yield(.sampleRecorded(hopID: hop.id, sample: sample))

        do {
            try await Task.sleep(nanoseconds: UInt64(intervalMilliseconds) * 1_000_000)
        } catch {
            return
        }
    }
}
