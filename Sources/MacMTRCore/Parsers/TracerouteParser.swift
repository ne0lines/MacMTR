import Foundation

public enum TracerouteParser {
    private static let ipExpression = try! NSRegularExpression(
        pattern: #"(?:\b(?:\d{1,3}\.){3}\d{1,3}\b|[A-Fa-f0-9]{0,4}:[A-Fa-f0-9:]+)"#
    )
    private static let latencyExpression = try! NSRegularExpression(
        pattern: #"([0-9]+(?:\.[0-9]+)?)\s*ms"#,
        options: [.caseInsensitive]
    )

    public static func parse(_ output: String) -> [RouteHop] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
    }

    public static func parseLine(_ line: String) -> RouteHop? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let separator = trimmed.firstIndex(where: \.isWhitespace),
            let index = Int(trimmed[..<separator])
        else {
            return nil
        }

        let remainder = trimmed[separator...].trimmingCharacters(in: .whitespaces)
        guard !remainder.isEmpty else {
            return RouteHop(index: index, address: nil, hostname: nil)
        }

        let address = firstIPAddress(in: remainder)
        let hostname = hostname(in: remainder, address: address)
        return RouteHop(index: index, address: address, hostname: hostname)
    }

    public static func parseSample(_ line: String) -> PingSample {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)

        guard
            let match = latencyExpression.firstMatch(in: line, range: range),
            match.numberOfRanges > 1,
            let valueRange = Range(match.range(at: 1), in: line),
            let latency = Double(line[valueRange])
        else {
            return PingSample(latencyMilliseconds: nil)
        }

        return PingSample(latencyMilliseconds: latency)
    }

    private static func firstIPAddress(in text: String) -> String? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = ipExpression.firstMatch(in: text, range: range),
            let matchRange = Range(match.range, in: text)
        else {
            return nil
        }

        return String(text[matchRange])
    }

    private static func hostname(in text: String, address: String?) -> String? {
        guard let address else {
            return firstToken(in: text).flatMap { $0 == "*" ? nil : $0 }
        }

        if let parenthesizedRange = text.range(of: "(\(address))") {
            let candidate = text[..<parenthesizedRange.lowerBound]
                .trimmingCharacters(in: .whitespaces)
            return candidate.isEmpty || candidate == "*" ? nil : candidate
        }

        guard let token = firstToken(in: text), token != address, token != "*" else {
            return nil
        }

        return token
    }

    private static func firstToken(in text: String) -> String? {
        text.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }
}
