import Foundation

public enum PingParser {
    private static let timeExpression = try! NSRegularExpression(
        pattern: #"time[=<]([0-9]+(?:\.[0-9]+)?)\s*ms"#,
        options: [.caseInsensitive]
    )

    public static func parse(_ output: String) -> PingSample {
        let range = NSRange(output.startIndex..<output.endIndex, in: output)

        guard
            let match = timeExpression.firstMatch(in: output, range: range),
            match.numberOfRanges > 1,
            let valueRange = Range(match.range(at: 1), in: output),
            let latency = Double(output[valueRange])
        else {
            return PingSample(latencyMilliseconds: nil)
        }

        return PingSample(latencyMilliseconds: latency)
    }
}
