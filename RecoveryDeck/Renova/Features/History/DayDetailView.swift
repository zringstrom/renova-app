import SwiftUI

struct DayDetailView: View {
    let day: DayRecord

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                sectionLabel("QUESTIONNAIRE")
                bordered {
                    scoreRow("Fatigue", day.fatigue)
                    scoreRow("Mood", day.mood)
                    scoreRow("Soreness / heavy legs", day.soreness)
                    scoreRow("Sleep quality", day.sleepQuality)
                    scoreRow("Work stress", day.workStress)
                    scoreRow("Relationship stress", day.relationshipStress)
                    scoreRow("Overall life stress", day.overallLifeStress, last: true)
                }

                if hasAnyHabitAnswer {
                    sectionLabel("YESTERDAY")
                    bordered {
                        habitRow("Alcohol last night", day.habitAlcohol)
                        habitRow("Intense training yesterday", day.habitIntenseTrainingYesterday)
                        habitRow("Long training yesterday", day.habitLongTrainingYesterday)
                        habitRow("Travel", day.habitTravel)
                        habitRow("Late night", day.habitLateNight)
                        habitRow("Feeling sick", day.habitSick)
                        habitRow("Meditated / breathwork", day.habitMeditationYesterday, last: true)
                    }
                }

                if let notes = day.notes, !notes.isEmpty {
                    sectionLabel("NOTES")
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundStyle(CGTheme.inkDim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(CGTheme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
                        .padding(.horizontal, 20)
                }

                sectionLabel("MEASUREMENT")
                if let measurement = day.measurement {
                    bordered {
                        metricRow("rMSSD", measurement.rmssdMs, "ms")
                        metricRow("Mean HR", measurement.meanHrBpm, "bpm")
                        if measurement.orthostaticSkipped {
                            HStack {
                                Text("Orthostatic").font(.system(size: 12.5)).foregroundStyle(CGTheme.ink)
                                Spacer()
                                Text("SKIPPED").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                        } else {
                            metricRow("Lying HR (RHR)", measurement.avgLyingHr, "bpm")
                            metricRow("Standing HR", measurement.avgStandingHr, "bpm")
                            metricRow("Peak standing HR", measurement.peakStandingHr, "bpm")
                            metricRow("Gap (peak)", measurement.gapPeak, "bpm")
                            metricRow("Gap (avg)", measurement.gapAvg, "bpm", last: true)
                        }
                        if let quality = measurement.hrvQuality, quality != "ok" {
                            Text("Quality: \(quality)").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(CGTheme.statusWatch)
                                .padding(.horizontal, 14).padding(.bottom, 8)
                        }
                    }
                } else {
                    HStack {
                        Text("No measurement recorded. Partial day")
                            .font(.system(size: 13))
                            .foregroundStyle(CGTheme.inkFaint)
                        Spacer()
                    }
                    .padding(14)
                    .background(CGTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 24)
        }
        .background(CGTheme.surface)
        .navigationTitle(day.localDate)
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
    }

    private func bordered(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) { content() }
            .background(CGTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
            .padding(.horizontal, 20)
    }

    private var hasAnyHabitAnswer: Bool {
        [day.habitAlcohol, day.habitIntenseTrainingYesterday, day.habitLongTrainingYesterday,
         day.habitTravel, day.habitLateNight, day.habitSick, day.habitMeditationYesterday]
            .contains { $0 != nil }
    }

    private func habitRow(_ label: String, _ value: Bool?, last: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 12.5)).foregroundStyle(CGTheme.ink)
            Spacer()
            if let value {
                Text(value ? "YES" : "NO")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(CGTheme.ink)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { last ? nil : Rectangle().fill(CGTheme.line).frame(height: 1) }
    }

    private func scoreRow(_ label: String, _ value: Int?, last: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 12.5)).foregroundStyle(CGTheme.ink)
            Spacer()
            Text(value.map(String.init) ?? "—")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(value == nil ? CGTheme.inkFaint : CGTheme.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { last ? nil : Rectangle().fill(CGTheme.line).frame(height: 1) }
    }

    private func metricRow(_ label: String, _ value: Double?, _ unit: String, last: Bool = false) -> some View {
        HStack {
            Text(label).font(.system(size: 12.5)).foregroundStyle(CGTheme.ink)
            Spacer()
            if let value {
                Text("\(value, specifier: "%.0f") \(unit)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(CGTheme.ink)
            } else {
                Text("—").font(.system(size: 12, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { last ? nil : Rectangle().fill(CGTheme.line).frame(height: 1) }
    }
}
