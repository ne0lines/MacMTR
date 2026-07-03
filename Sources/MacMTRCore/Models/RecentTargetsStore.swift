import Foundation

public struct RecentTargetsStore {
    public static let defaultTarget = "1.1.1.1"

    private let defaults: UserDefaults
    private let key: String
    private let limit: Int

    public init(
        defaults: UserDefaults = .standard,
        key: String = "recentTargets",
        limit: Int = 10
    ) {
        self.defaults = defaults
        self.key = key
        self.limit = limit
    }

    public func load() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    @discardableResult
    public func remember(_ target: String) -> [String] {
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty else {
            return load()
        }

        let recentTargets = ([trimmedTarget] + load().filter { $0 != trimmedTarget })
            .prefix(limit)
        let savedTargets = Array(recentTargets)
        defaults.set(savedTargets, forKey: key)
        return savedTargets
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}
