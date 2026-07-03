import MacMTRCore
import SwiftUI

struct ContentView: View {
    @StateObject var model: MTRSessionModel

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            resultsTable
            Divider()
            statusBar
        }
        .frame(minWidth: 900, minHeight: 560)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.copyTextReport()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(!model.canExport)

                Menu {
                    Button("Text") { model.saveTextReport() }
                    Button("HTML") { model.saveHTMLReport() }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.down")
                }
                .disabled(!model.canExport)
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            TextField("Host or IP", text: $model.target)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 260)
                .disabled(model.isRunning)
                .onSubmit {
                    if !model.isRunning {
                        model.start()
                    }
                }

            Menu {
                ForEach(model.recentTargets, id: \.self) { target in
                    Button(target) {
                        model.selectRecentTarget(target)
                    }
                }

                if !model.recentTargets.isEmpty {
                    Divider()
                    Button(role: .destructive) {
                        model.clearRecentTargets()
                    } label: {
                        Label("Clear Recent Hosts", systemImage: "trash")
                    }
                }
            } label: {
                Label("Recent Hosts", systemImage: "clock")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .help("Recent hosts")
            .disabled(model.isRunning || model.recentTargets.isEmpty)

            Stepper("Max hops: \(model.maxHops)", value: $model.maxHops, in: 1...64)
                .frame(width: 140)
                .disabled(model.isRunning)

            Picker("Interval", selection: $model.intervalMilliseconds) {
                Text("1s").tag(1_000)
                Text("2s").tag(2_000)
                Text("5s").tag(5_000)
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
            .disabled(model.isRunning)

            Spacer()

            Button {
                model.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(model.reports.isEmpty && !model.isRunning)

            Button {
                model.isRunning ? model.stop() : model.start()
            } label: {
                Label(model.isRunning ? "Stop" : "Start", systemImage: model.isRunning ? "stop.fill" : "play.fill")
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
    }

    private var resultsTable: some View {
        Table(model.reports) {
            TableColumn("Hop") { report in
                Text("\(report.hop.index)")
                    .monospacedDigit()
            }
            .width(45)

            TableColumn("Hostname") { report in
                Text(report.hop.displayHost)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .width(min: 190, ideal: 260)

            TableColumn("Address") { report in
                Text(report.hop.displayAddress)
                    .fontDesign(.monospaced)
                    .lineLimit(1)
            }
            .width(min: 130, ideal: 160)

            TableColumn("Loss%") { report in
                metricText(ExportFormatter.fixed(report.lossPercent))
            }
            .width(70)

            TableColumn("Sent") { report in
                metricText("\(report.sent)")
            }
            .width(60)

            TableColumn("Recv") { report in
                metricText("\(report.received)")
            }
            .width(60)

            TableColumn("Last") { report in
                metricText(ExportFormatter.metric(report.lastMilliseconds))
            }
            .width(70)

            TableColumn("Avg") { report in
                metricText(ExportFormatter.metric(report.averageMilliseconds))
            }
            .width(70)

            TableColumn("Best") { report in
                metricText(ExportFormatter.metric(report.bestMilliseconds))
            }
            .width(70)

            TableColumn("Worst") { report in
                metricText(ExportFormatter.metric(report.worstMilliseconds))
            }
            .width(70)
        }
        .overlay {
            if model.reports.isEmpty {
                ContentUnavailableView(
                    "No trace running",
                    systemImage: "point.3.connected.trianglepath.dotted",
                    description: Text("Enter a host and start a trace.")
                )
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Image(systemName: model.isRunning ? "waveform.path.ecg" : "info.circle")
                .foregroundStyle(model.isRunning ? .green : .secondary)
            Text(model.statusMessage)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func metricText(_ value: String) -> some View {
        Text(value)
            .monospacedDigit()
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
