import AppKit
import Foundation
import MacMTRCore

@MainActor
final class MTRSessionModel: ObservableObject {
    @Published var target = "github.com"
    @Published var maxHops = 30
    @Published var intervalMilliseconds = 1_000
    @Published private(set) var isRunning = false
    @Published private(set) var statusMessage = "Ready"
    @Published private(set) var reports: [HopReport] = []

    private let client: any NetworkToolClient
    private var runTask: Task<Void, Never>?

    init(client: any NetworkToolClient = MacNetworkToolClient()) {
        self.client = client
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
            let route = try await client.traceRoute(to: target, maxHops: maxHops)
            guard !Task.isCancelled else { return }

            reports = route.map(HopReport.init)
            statusMessage = "Running \(reports.count) hops to \(target)."

            while !Task.isCancelled {
                let hops = reports.map(\.hop)
                for hop in hops {
                    guard !Task.isCancelled else { return }
                    guard let address = hop.address else {
                        record(PingSample(latencyMilliseconds: nil), forHopID: hop.id)
                        continue
                    }

                    let sample = (try? await client.ping(
                        address: address,
                        timeoutMilliseconds: intervalMilliseconds
                    )) ?? PingSample(latencyMilliseconds: nil)
                    record(sample, forHopID: hop.id)
                }

                try await Task.sleep(nanoseconds: UInt64(intervalMilliseconds) * 1_000_000)
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
