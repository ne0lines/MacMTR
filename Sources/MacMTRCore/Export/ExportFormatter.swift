import Foundation

public enum ExportFormatter {
    public static func text(target: String, reports: [HopReport]) -> String {
        var lines = [
            "MacMTR report",
            "Target: \(target)",
            "",
            "Hop\tHostname\tAddress\tLoss%\tSent\tRecv\tLast\tAvg\tBest\tWorst"
        ]

        lines.append(contentsOf: reports.map(textRow))
        return lines.joined(separator: "\n")
    }

    public static func html(target: String, reports: [HopReport]) -> String {
        let rows = reports.map { report in
            """
            <tr><td>\(report.hop.index)</td><td>\(escape(report.hop.displayHost))</td><td>\(escape(report.hop.displayAddress))</td><td>\(fixed(report.lossPercent))</td><td>\(report.sent)</td><td>\(report.received)</td><td>\(metric(report.lastMilliseconds))</td><td>\(metric(report.averageMilliseconds))</td><td>\(metric(report.bestMilliseconds))</td><td>\(metric(report.worstMilliseconds))</td></tr>
            """
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>MacMTR report for \(escape(target))</title>
        <style>
        body { font: 13px -apple-system, BlinkMacSystemFont, sans-serif; }
        table { border-collapse: collapse; }
        th, td { border: 1px solid #c8c8c8; padding: 4px 8px; text-align: right; }
        th:nth-child(2), th:nth-child(3), td:nth-child(2), td:nth-child(3) { text-align: left; }
        </style>
        </head>
        <body>
        <h1>MacMTR report</h1>
        <p>Target: \(escape(target))</p>
        <table>
        <thead><tr><th>Hop</th><th>Hostname</th><th>Address</th><th>Loss%</th><th>Sent</th><th>Recv</th><th>Last</th><th>Avg</th><th>Best</th><th>Worst</th></tr></thead>
        <tbody>
        \(rows)
        </tbody>
        </table>
        </body>
        </html>
        """
    }

    private static func textRow(_ report: HopReport) -> String {
        [
            String(report.hop.index),
            report.hop.displayHost,
            report.hop.displayAddress,
            fixed(report.lossPercent),
            String(report.sent),
            String(report.received),
            metric(report.lastMilliseconds),
            metric(report.averageMilliseconds),
            metric(report.bestMilliseconds),
            metric(report.worstMilliseconds)
        ].joined(separator: "\t")
    }

    public static func metric(_ value: Double?) -> String {
        guard let value else { return "--" }
        return fixed(value)
    }

    public static func fixed(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
            .replacingOccurrences(of: "*", with: "&ast;")
    }
}
