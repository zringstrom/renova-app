import SwiftUI
import RecoveryKit

struct HistoryView: View {
    let viewModel: AppViewModel

    private static let chartWindowDays = 28

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    band

                    if !viewModel.canAccessHistory {
                        lockedState
                    } else {
                        let days = viewModel.historyDays()
                        if days.isEmpty {
                            emptyState
                        } else {
                            let trend = viewModel.trendData(windowDays: Self.chartWindowDays)
                            if trend.rmssd.points.count >= 2 {
                                chartsSection(trend)
                            }
                            sectionLabel("LOG")
                            dayList(days)
                        }
                    }
                }
            }
            .background(CGTheme.surface)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Header

    private var band: some View {
        HStack(alignment: .top) {
            Text("TRENDS")
                .font(.system(size: 15, weight: .heavy))
                .tracking(0.5)
            Spacer()
            Text("\(Self.chartWindowDays) DAYS · \(viewModel.historyDays().count) LOGGED")
                .font(CGTheme.monoSmall)
                .foregroundStyle(CGTheme.inkFaint)
        }
        .foregroundStyle(CGTheme.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.ink).frame(height: 3) }
        .background(CGTheme.surface)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(CGTheme.sectionLabel)
            .tracking(1.4)
            .foregroundStyle(CGTheme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(CGTheme.surface)
    }

    private var lockedState: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill").font(.system(size: 28)).foregroundStyle(CGTheme.inkFaint)
            Text("LOCKED").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(CGTheme.ink)
            Text("Finish today's questionnaire to unlock history.")
                .font(.system(size: 13))
                .foregroundStyle(CGTheme.inkDim)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(CGTheme.surface)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar").font(.system(size: 28)).foregroundStyle(CGTheme.inkFaint)
            Text("NO DAYS YET").font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundStyle(CGTheme.ink)
            Text("Your morning log will build up here.")
                .font(.system(size: 13))
                .foregroundStyle(CGTheme.inkDim)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(CGTheme.surface)
    }

    // MARK: - Charts

    private func chartsSection(_ trend: AppViewModel.TrendData) -> some View {
        VStack(spacing: 0) {
            chartCard(
                sectionTitle: "RMSSD · MS",
                metric: .rmssd,
                series: trend.rmssd,
                height: 84,
                showXAxisDates: true,
                todayValue: viewModel.todayRecord?.measurement?.rmssdMs
            )
            chartCard(
                sectionTitle: "RHR · BPM",
                metric: .rhr,
                series: trend.rhr,
                height: 56,
                showXAxisDates: false,
                todayValue: viewModel.todayRecord?.measurement?.avgLyingHr
            )
            if trend.gapPeak.points.count >= 7 {
                chartCard(
                    sectionTitle: "GAP (PEAK) · BPM",
                    metric: .gapPeak,
                    series: trend.gapPeak,
                    height: 56,
                    showXAxisDates: false,
                    todayValue: (viewModel.todayRecord?.measurement?.orthostaticSkipped ?? true)
                        ? nil
                        : viewModel.todayRecord?.measurement?.gapPeak
                )
            }
        }
    }

    private func chartCard(
        sectionTitle: String,
        metric: AppViewModel.TrendMetric,
        series: TrendSeries,
        height: CGFloat,
        showXAxisDates: Bool,
        todayValue: Double?
    ) -> some View {
        VStack(spacing: 0) {
            sectionLabel(sectionTitle)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(chartHeaderLeft(series: series, metric: metric))
                        .font(CGTheme.monoSmall)
                        .foregroundStyle(CGTheme.inkFaint)
                    Spacer()
                    Text(todayValue.map { "TODAY \(Int($0.rounded()))" } ?? "TODAY —")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(CGTheme.ink)
                }
                BandChart(series: series, height: height, showXAxisDates: showXAxisDates, sdFloor: 1)
            }
            .padding(14)
            .background(CGTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 4)
    }

    private func chartHeaderLeft(series: TrendSeries, metric: AppViewModel.TrendMetric) -> String {
        if let mean = series.normMean, let sd = series.normSD {
            return "60-DAY MEAN \(Int(mean.rounded())) ± \(Int(sd.rounded()))"
        }
        if let progress = viewModel.baselineProgress(for: metric) {
            return "BASELINE BUILDING — \(progress.collected)/\(progress.needed)"
        }
        return ""
    }

    // MARK: - List

    private func dayList(_ days: [DayRecord]) -> some View {
        let logSeries = viewModel.trendData(windowDays: 90).rmssd
        let indexByDate = Dictionary(uniqueKeysWithValues: logSeries.points.enumerated().map { ($1.localDate, $0) })

        return VStack(spacing: 0) {
            ForEach(days) { day in
                NavigationLink {
                    DayDetailView(day: day)
                } label: {
                    dayRow(day, indexByDate: indexByDate, series: logSeries)
                }
                .buttonStyle(.plain)
            }
        }
        .background(CGTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    private func dayRow(_ day: DayRecord, indexByDate: [String: Int], series: TrendSeries) -> some View {
        HStack(spacing: 12) {
            Text(day.localDate)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(CGTheme.ink)

            Spacer()

            if let measurement = day.measurement {
                let parts: [String] = [
                    measurement.rmssdMs.map { "\(Int($0.rounded())) ms" },
                    measurement.avgLyingHr.map { "\(Int($0.rounded())) bpm" }
                ].compactMap { $0 }
                if !parts.isEmpty {
                    Text(parts.joined(separator: " · "))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(CGTheme.inkDim)
                }

                let dotColor: Color = {
                    if let index = indexByDate[day.localDate], let light = series.light(at: index, sdFloor: 1) {
                        return light.color
                    }
                    return CGTheme.inkFaint
                }()
                RoundedRectangle(cornerRadius: 2).fill(dotColor).frame(width: 8, height: 8)
            } else {
                Text("PARTIAL")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(CGTheme.inkFaint)
                RoundedRectangle(cornerRadius: 2).fill(CGTheme.lineStrong).frame(width: 8, height: 8)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(CGTheme.inkFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
        .contentShape(Rectangle())
    }
}

extension DayRecord: Identifiable {
    public var id: String { localDate }
}
