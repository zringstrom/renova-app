import WidgetKit
import SwiftUI

struct RenovaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RenovaEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(entry.rmssdMs == nil ? "MORNING" : "RMSSD")
                    .font(CGTheme.sectionLabel)
                    .tracking(1)
                    .foregroundStyle(CGTheme.inkDim)
                Spacer(minLength: 0)
                Rectangle()
                    .fill(markerColor)
                    .frame(width: 9, height: 9)
            }

            Spacer(minLength: 0)

            if let rmssdMs = entry.rmssdMs {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(rmssdMs, specifier: "%.0f")")
                        .font(.system(size: 40, weight: .bold, design: .monospaced))
                        .foregroundStyle(CGTheme.ink)
                    Text(" ms")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(CGTheme.inkFaint)
                }
            } else {
                Text("\(entry.tasksPending)")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundStyle(CGTheme.ink)
                Text(entry.tasksPending == 1 ? "TASK PENDING" : "TASKS PENDING")
                    .font(CGTheme.monoSmall)
                    .tracking(1)
                    .foregroundStyle(CGTheme.inkDim)
            }

            Rectangle()
                .fill(CGTheme.line)
                .frame(height: 1)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(CGTheme.surface, for: .widget)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.rmssdMs == nil ? "MORNING" : "RMSSD")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1)
            if let rmssdMs = entry.rmssdMs {
                Text("\(rmssdMs, specifier: "%.0f") MS")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
            } else {
                Text("\(entry.tasksPending) \(entry.tasksPending == 1 ? "TASK" : "TASKS")")
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                Text("PENDING")
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(.clear, for: .widget)
    }

    private var markerColor: Color {
        guard entry.rmssdMs != nil else { return CGTheme.accent }
        switch entry.light {
        case "green": return CGTheme.statusOk
        case "yellow": return CGTheme.statusWatch
        case "red": return CGTheme.statusAlert
        default: return CGTheme.lineStrong
        }
    }
}
