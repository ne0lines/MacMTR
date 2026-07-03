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
}

public struct MacNetworkToolClient: NetworkToolClient {
    private let runner: ShellProcessRunner

    public init(runner: ShellProcessRunner = ShellProcessRunner()) {
        self.runner = runner
    }

    public func traceRoute(to target: String, maxHops: Int) async throws -> [RouteHop] {
        let output = try await runner.run(
            executableURL: URL(fileURLWithPath: "/usr/sbin/traceroute"),
            arguments: ["-n", "-q", "1", "-m", String(maxHops), "-w", "2", target]
        )

        let hops = TracerouteParser.parse(output.combinedOutput)
        if hops.isEmpty, output.status != 0 {
            throw NetworkToolError.failed(
                tool: "traceroute",
                status: output.status,
                output: output.combinedOutput
            )
        }

        return hops
    }

    public func ping(address: String, timeoutMilliseconds: Int = 1_000) async throws -> PingSample {
        let output = try await runner.run(
            executableURL: URL(fileURLWithPath: "/sbin/ping"),
            arguments: ["-n", "-c", "1", "-W", String(timeoutMilliseconds), address]
        )

        return PingParser.parse(output.combinedOutput)
    }
}
