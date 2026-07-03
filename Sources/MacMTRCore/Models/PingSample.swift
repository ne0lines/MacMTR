public struct PingSample: Equatable, Sendable {
    public let latencyMilliseconds: Double?

    public init(latencyMilliseconds: Double?) {
        self.latencyMilliseconds = latencyMilliseconds
    }
}
