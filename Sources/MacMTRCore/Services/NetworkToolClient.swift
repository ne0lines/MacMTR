import Foundation

public enum NetworkToolError: Error, LocalizedError, Sendable {
    case failed(tool: String, status: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case let .failed(tool, status, output):
            "\(tool) exited with status \(status): \(output)"
        }
    }
}

public protocol NetworkToolClient: Sendable {
    func traceRoute(to target: String, maxHops: Int) async throws -> [RouteHop]
    func traceRouteHops(to target: String, maxHops: Int) -> AsyncThrowingStream<RouteHop, Error>
    func ping(address: String, timeoutMilliseconds: Int) async throws -> PingSample
}

public struct ProcessOutput: Sendable {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public var combinedOutput: String {
        [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

public struct ShellProcessRunner: Sendable {
    public init() {}

    public func run(executableURL: URL, arguments: [String]) async throws -> ProcessOutput {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr

            try process.run()
            process.waitUntilExit()

            let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()

            return ProcessOutput(
                status: process.terminationStatus,
                stdout: String(decoding: stdoutData, as: UTF8.self),
                stderr: String(decoding: stderrData, as: UTF8.self)
            )
        }.value
    }

    public func streamLines(
        executableURL: URL,
        arguments: [String]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let process = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            let queue = DispatchQueue(label: "MacMTR.ShellProcessRunner.streamLines")
            let lineBuffer = LockedLineBuffer()
            let outputBuffer = LockedStringBuffer()

            process.executableURL = executableURL
            process.arguments = arguments
            process.standardOutput = stdout
            process.standardError = stderr

            let consume: @Sendable (Data) -> Void = { data in
                guard !data.isEmpty else { return }
                let text = String(decoding: data, as: UTF8.self)
                outputBuffer.append(text)
                queue.async {
                    for line in lineBuffer.append(text) {
                        continuation.yield(line)
                    }
                }
            }

            stdout.fileHandleForReading.readabilityHandler = { handle in
                consume(handle.availableData)
            }
            stderr.fileHandleForReading.readabilityHandler = { handle in
                consume(handle.availableData)
            }

            process.terminationHandler = { terminatedProcess in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil

                queue.async {
                    if let trailingLine = lineBuffer.flush() {
                        continuation.yield(trailingLine)
                    }

                    if terminatedProcess.terminationStatus == 0 || !outputBuffer.value.isEmpty {
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: NetworkToolError.failed(
                            tool: executableURL.lastPathComponent,
                            status: terminatedProcess.terminationStatus,
                            output: outputBuffer.value
                        ))
                    }
                }
            }

            continuation.onTermination = { _ in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                if process.isRunning {
                    process.terminate()
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

public struct MacNetworkToolClient: NetworkToolClient {
    private let runner: ShellProcessRunner

    public init(runner: ShellProcessRunner = ShellProcessRunner()) {
        self.runner = runner
    }

    public func traceRoute(to target: String, maxHops: Int) async throws -> [RouteHop] {
        var hops: [RouteHop] = []

        for try await hop in traceRouteHops(to: target, maxHops: maxHops) {
            hops.append(hop)
        }

        return hops
    }

    public func traceRouteHops(to target: String, maxHops: Int) -> AsyncThrowingStream<RouteHop, Error> {
        let lines = runner.streamLines(
            executableURL: URL(fileURLWithPath: "/usr/sbin/traceroute"),
            arguments: ["-n", "-q", "1", "-m", String(maxHops), "-w", "2", target]
        )

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in lines {
                        if let hop = TracerouteParser.parseLine(line) {
                            continuation.yield(hop)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func ping(address: String, timeoutMilliseconds: Int = 1_000) async throws -> PingSample {
        let output = try await runner.run(
            executableURL: URL(fileURLWithPath: "/sbin/ping"),
            arguments: ["-n", "-c", "1", "-W", String(timeoutMilliseconds), address]
        )

        return PingParser.parse(output.combinedOutput)
    }
}

private final class LockedLineBuffer: @unchecked Sendable {
    private var pending = ""
    private let lock = NSLock()

    func append(_ text: String) -> [String] {
        lock.withLock {
            pending += text
            let parts = pending.split(separator: "\n", omittingEmptySubsequences: false)

            if pending.hasSuffix("\n") {
                pending = ""
                return parts.dropLast().map(String.init)
            }

            pending = parts.last.map(String.init) ?? ""
            return parts.dropLast().map(String.init)
        }
    }

    func flush() -> String? {
        lock.withLock {
            guard !pending.isEmpty else { return nil }
            let line = pending
            pending = ""
            return line
        }
    }
}

private final class LockedStringBuffer: @unchecked Sendable {
    private var storage = ""
    private let lock = NSLock()

    var value: String {
        lock.withLock { storage }
    }

    func append(_ text: String) {
        lock.withLock {
            storage += text
        }
    }
}
