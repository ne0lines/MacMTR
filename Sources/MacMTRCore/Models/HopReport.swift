public struct HopReport: Equatable, Identifiable, Sendable {
    public var id: Int { hop.index }

    public let hop: RouteHop
    public private(set) var sent: Int
    public private(set) var received: Int
    public private(set) var lastMilliseconds: Double?
    public private(set) var bestMilliseconds: Double?
    public private(set) var worstMilliseconds: Double?

    private var latencyTotalMilliseconds: Double

    public init(hop: RouteHop) {
        self.hop = hop
        self.sent = 0
        self.received = 0
        self.lastMilliseconds = nil
        self.bestMilliseconds = nil
        self.worstMilliseconds = nil
        self.latencyTotalMilliseconds = 0
    }

    public var lossPercent: Double {
        guard sent > 0 else { return 0 }
        return Double(sent - received) / Double(sent) * 100
    }

    public var averageMilliseconds: Double? {
        guard received > 0 else { return nil }
        return latencyTotalMilliseconds / Double(received)
    }

    public mutating func record(_ sample: PingSample) {
        sent += 1

        guard let latency = sample.latencyMilliseconds else {
            lastMilliseconds = nil
            return
        }

        received += 1
        lastMilliseconds = latency
        latencyTotalMilliseconds += latency
        bestMilliseconds = min(bestMilliseconds ?? latency, latency)
        worstMilliseconds = max(worstMilliseconds ?? latency, latency)
    }
}
