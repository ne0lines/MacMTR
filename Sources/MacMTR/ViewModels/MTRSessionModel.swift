import AppKit
import Foundation
import MacMTRCore

@MainActor
final class MTRSessionModel: ObservableObject {
    @Published var target: String
    @Published var maxHops = 30
    @Published var intervalMilliseconds = 1_000
    @Published private(set) var isRunning = false
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var reports: [HopReport] = []
    @Published private(set) var recentTargets: [String]

    private let runner: MTRSessionRunner
    private let recentTargetsStore: RecentTargetsStore
    private var runTask: Task<Void, Never>?

    init(
        client: any NetworkToolClient = MacNetworkToolClient(),
        recentTargetsStore: RecentTargetsStore = RecentTargetsStore()
    ) {
        self.runner = MTRSessionRunner(client: client)
        self.recentTargetsStore = recentTargetsStore
        let rememberedTargets = recentTargetsStore.load()
        self.recentTargets = rememberedTargets
        self.target = rememberedTargets.first ?? RecentTargetsStore.defaultTarget
    }

    var canExport: Bool {
        !reports.isEmpty
    }

    func start() {
        let trimmedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTarget.isEmpty else {
            statusMessage = "Enter a host or IP address."
            return
        }

        stop()
        target = trimmedTarget
        recentTargets = recentTargetsStore.remember(trimmedTarget)
        isRunning = true
        statusMessage = "Tracing route to \(trimmedTarget)..."
        reports = []

        runTask = Task { [weak self] in
            await self?.run(target: trimmedTarget)
        }
    }

    func stop() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
        if !reports.isEmpty {
            statusMessage = "Stopped."
        }
    }

    func clear() {
        stop()
        reports = []
        statusMessage = "Ready"
    }

    func selectRecentTarget(_ target: String) {
        guard !isRunning else { return }
        self.target = target
    }

    func clearRecentTargets() {
        guard !isRunning else { return }
        recentTargetsStore.clear()
        recentTargets = []
    }

    func copyTextReport() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(ExportFormatter.text(target: target, reports: reports), forType: .string)
        statusMessage = "Copied text report."
    }

    func saveTextReport() {
        saveReport(extension: "txt", contents: ExportFormatter.text(target: target, reports: reports))
    }

    func saveHTMLReport() {
        saveReport(extension: "html", contents: ExportFormatter.html(target: target, reports: reports))
    }

    private func run(target: String) async {
        do {
            for try await event in runner.events(
                target: target,
                maxHops: maxHops,
                intervalMilliseconds: intervalMilliseconds
            ) {
                guard !Task.isCancelled else { return }

                switch event {
                case let .hopDiscovered(hop):
                    appendHopIfNeeded(hop)
                    statusMessage = "Discovered \(reports.count) hops to \(target)..."
                case let .sampleRecorded(hopID, sample):
                    record(sample, forHopID: hopID)
                case let .routeCompleted(discoveredHopCount):
                    if discoveredHopCount == 0 {
                        statusMessage = "No route found for \(target)."
                        isRunning = false
                    } else {
                        statusMessage = "Running \(discoveredHopCount) hops to \(target)."
                    }
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            statusMessage = error.localizedDescription
            isRunning = false
        }
    }

    private func record(_ sample: PingSample, forHopID id: Int) {
        guard let index = reports.firstIndex(where: { $0.id == id }) else { return }
        reports[index].record(sample)
    }

    private func appendHopIfNeeded(_ hop: RouteHop) {
        guard !reports.contains(where: { $0.id == hop.id }) else { return }
        reports.append(HopReport(hop: hop))
    }

    private func saveReport(extension fileExtension: String, contents: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = fileExtension == "html" ? [.html] : [.plainText]
        panel.nameFieldStringValue = "MacMTR-\(target).\(fileExtension)"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            statusMessage = "Saved \(url.lastPathComponent)."
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
