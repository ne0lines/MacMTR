public struct RouteHop: Equatable, Identifiable, Sendable {
    public static let noResponseHost = "No response from host"

    public var id: Int { index }

    public let index: Int
    public let address: String?
    public let hostname: String?

    public init(index: Int, address: String?, hostname: String?) {
        self.index = index
        self.address = address
        self.hostname = hostname
    }

    public var displayHost: String {
        hostname ?? address ?? Self.noResponseHost
    }

    public var displayAddress: String {
        address ?? ""
    }
}
