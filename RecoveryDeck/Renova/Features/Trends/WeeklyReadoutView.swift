import SwiftUI
import RecoveryKit

/// One-screen weekly summary (plan Phase 10). Per-metric comparisons only —
/// never a blended "readiness score" (permanent product prohibition). The
/// on-screen view and the shared PNG render the exact same content view at a
/// fixed 390pt width, so the shared image is stable across devices.
struct WeeklyReadoutView: View {
    let viewModel: AppViewModel

    @State private var shareFile: ExportFile?

    private var readout: AppViewModel.WeeklyReadout {
        viewModel.weeklyReadout()
    }

    var body: some View {
        ScrollView {
            ReadoutContent(readout: readout)
        }
        .background(CGTheme.surface)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    shareFile = renderShareImage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(CGTheme.ink)
                }
            }
        }
        .sheet(item: $shareFile) { file in
            ShareSheet(activityItems: [file.url])
        }
    }

    /// Renders `ReadoutContent` alone (no scroll chrome) at a fixed 390pt
    /// width, in light mode, to a PNG on disk for the share sheet.
    @MainActor
    private func renderShareImage() -> ExportFile? {
        let content = ReadoutContent(readout: readout)
            .frame(width: 390)
            .background(CGTheme.surface)
            .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "renova-weekly-readout-\(formatter.string(from: Date())).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return ExportFile(url: url)
    }
}

/// The actual readout content — factored out so the on-screen `ScrollView`
/// and the fixed-width share-sheet snapshot render byte-identical content.
private struct ReadoutContent: View {
    let readout: AppViewModel.WeeklyReadout

    var body: some View {
        VStack(spacing: 0) {
            band

            metricRow(label: "RMSSD", unit: "ms", row: readout.rmssd)
                .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
            metricRow(label: "RHR", unit: "bpm", row: readout.rhr)
                .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
            metricRow(label: "GAP (PEAK)", unit: "bpm", row: readout.gapPeak)

            bandExitRow

            subjectiveRow

            if let topChip = readout.topChipEffect {
                topChipRow(topChip)
            }
        }
        .padding(.bottom, 20)
    }

    private var band: some View {
        HStack(alignment: .top) {
            Text("\(readout.weekLabel) · \(readout.dateRangeLabel)")
                .font(.system(size: 14, weight: .heavy))
                .tracking(0.5)
            Spacer()
        }
        .foregroundStyle(CGTheme.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.ink).frame(height: 3) }
        .background(CGTheme.surface)
    }

    private func metricRow(label: String, unit: String, row: AppViewModel.WeeklyMetricRow) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(CGTheme.monoSmall)
                    .foregroundStyle(CGTheme.inkFaint)
                if let sevenDayMean = row.sevenDayMean {
                    Text("\(sevenDayMean, specifier: "%.0f") \(unit)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(CGTheme.ink)
                } else {
                    Text("—")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(CGTheme.inkFaint)
                }
                Text("7-DAY MEAN")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(CGTheme.inkFaint)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let sixtyDayMean = row.sixtyDayMean, let sd = row.sixtyDaySD {
                    Text("\(sixtyDayMean, specifier: "%.0f") ± \(sd, specifier: "%.0f")")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(CGTheme.inkDim)
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(row.light?.color ?? CGTheme.lineStrong)
                            .frame(width: 7, height: 7)
                        Text(directionText(row.direction))
                            .font(CGTheme.monoSmall)
                            .foregroundStyle(row.light?.color ?? CGTheme.inkFaint)
                    }
                } else {
                    Text("BASELINE BUILDING")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(CGTheme.inkFaint)
                }
                Text("60-DAY MEAN")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(CGTheme.inkFaint)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(CGTheme.surface)
    }

    private func directionText(_ direction: BaselineDirection?) -> String {
        switch direction {
        case .none: return ""
        case .withinNormal: return "usual"
        case .aboveNormal: return "higher than usual"
        case .belowNormal: return "lower than usual"
        }
    }

    private var bandExitRow: some View {
        HStack {
            Text("\(readout.daysOutsideBand) DAYS OUTSIDE BAND")
                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(readout.daysOutsideBand > 0 ? CGTheme.statusWatch : CGTheme.inkFaint)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
        .background(CGTheme.surface2)
    }

    private var subjectiveRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SUBJECTIVE · 7-DAY AVERAGE")
                .font(CGTheme.monoSmall)
                .foregroundStyle(CGTheme.inkFaint)
            if let average = readout.subjectiveAverage {
                Text("\(average, specifier: "%.1f") / 7")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(CGTheme.ink)
                Text("Mood, soreness, sleep, fatigue, and stress combined — higher is better.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(CGTheme.inkDim)
            } else {
                Text("Not enough logged days yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(CGTheme.inkFaint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(CGTheme.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
    }

    private func topChipRow(_ effect: ChipEffect) -> some View {
        let rmssdColor: Color = (effect.rmssdPctDelta ?? 0) < 0 ? CGTheme.statusWatch : CGTheme.statusOk
        return VStack(alignment: .leading, spacing: 6) {
            Text("BIGGEST PATTERN THIS WINDOW")
                .font(CGTheme.monoSmall)
                .foregroundStyle(CGTheme.inkFaint)
            HStack(alignment: .firstTextBaseline) {
                Text(CorrelationEngine.displayName(for: effect.chip))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(CGTheme.ink)
                Text("N=\(effect.nWith)")
                    .font(CGTheme.monoSmall)
                    .foregroundStyle(CGTheme.inkFaint)
                Spacer()
                if let pct = effect.rmssdPctDelta {
                    Text("rMSSD \(pct >= 0 ? "+" : "")\(pct, specifier: "%.0f")%")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(rmssdColor)
                }
            }
            Text("Small-sample averages on your own log. Correlation, not causation.")
                .font(CGTheme.monoSmall)
                .foregroundStyle(CGTheme.inkFaint)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(CGTheme.surface)
    }
}
