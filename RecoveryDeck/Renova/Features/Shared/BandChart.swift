import SwiftUI
import RecoveryKit

/// Shared chart primitive drawn directly with `Path`/`Canvas` — no Swift
/// Charts, whose default styling fights the Control Grid look. Powers the
/// Today hero sparkline (Phase 3) and the Trends charts (Phase 4).
///
/// Z-order (mockup C): baseline band rect → dashed mean line → data polyline
/// → off-band point dots → newest-point dot (always last, always on top).
struct BandChart: View {
    let series: TrendSeries
    let height: CGFloat
    let showXAxisDates: Bool

    /// Same sdFloor convention used to compute per-point lights (TECH_SPEC §5.4).
    /// The chart doesn't know the metric, so the caller supplies it — matches
    /// `TrendBuilder.series(sdFloor:)` used to build `series` in the first place.
    var sdFloor: Double = 1

    var body: some View {
        VStack(spacing: 4) {
            Canvas { context, size in
                draw(context: context, size: size)
            }
            .frame(height: height)

            if showXAxisDates {
                xAxisLabels
            }
        }
    }

    // MARK: - Drawing

    private func draw(context: GraphicsContext, size: CGSize) {
        let points = series.points
        guard !points.isEmpty else { return }

        let domain = yDomain
        guard domain.upperBound > domain.lowerBound else { return }

        func y(for value: Double) -> CGFloat {
            let fraction = (value - domain.lowerBound) / (domain.upperBound - domain.lowerBound)
            return size.height - (CGFloat(fraction) * size.height)
        }

        func x(for index: Int) -> CGFloat {
            guard points.count > 1 else { return size.width / 2 }
            return CGFloat(index) / CGFloat(points.count - 1) * size.width
        }

        // 1. Band rect: mean ± 1 SD.
        if let mean = series.normMean, let sd = series.normSD {
            let bandTop = y(for: mean + sd)
            let bandBottom = y(for: mean - sd)
            let bandRect = CGRect(x: 0, y: bandTop, width: size.width, height: bandBottom - bandTop)
            context.fill(Path(bandRect), with: .color(CGTheme.statusOk.opacity(0.10)))

            // 2. Mean line: dashed, 1px, lineStrong.
            var meanPath = Path()
            meanPath.move(to: CGPoint(x: 0, y: y(for: mean)))
            meanPath.addLine(to: CGPoint(x: size.width, y: y(for: mean)))
            context.stroke(
                meanPath,
                with: .color(CGTheme.lineStrong),
                style: StrokeStyle(lineWidth: 1, dash: [3, 2])
            )
        }

        // 3. Data polyline: 2px, ink, round joins, straight segments.
        if points.count > 1 {
            var linePath = Path()
            linePath.move(to: CGPoint(x: x(for: 0), y: y(for: points[0].value)))
            for index in points.indices.dropFirst() {
                linePath.addLine(to: CGPoint(x: x(for: index), y: y(for: points[index].value)))
            }
            context.stroke(
                linePath,
                with: .color(CGTheme.ink),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
        }

        // 4. Off-band points: 3px dot in that light's color with a surface ring.
        for index in points.indices {
            guard let light = series.light(at: index, sdFloor: sdFloor), light != .green else { continue }
            let center = CGPoint(x: x(for: index), y: y(for: points[index].value))
            drawDot(context: context, center: center, radius: 3, fill: light.color, ringWidth: 1.5)
        }

        // 5. Newest point: 4px dot, accent, always drawn last.
        if let lastIndex = points.indices.last {
            let center = CGPoint(x: x(for: lastIndex), y: y(for: points[lastIndex].value))
            drawDot(context: context, center: center, radius: 4, fill: CGTheme.accent, ringWidth: 2)
        }
    }

    private func drawDot(context: GraphicsContext, center: CGPoint, radius: CGFloat, fill: Color, ringWidth: CGFloat) {
        let ringRadius = radius + ringWidth
        let ringRect = CGRect(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
        context.fill(Path(ellipseIn: ringRect), with: .color(CGTheme.surface))

        let dotRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: dotRect), with: .color(fill))
    }

    /// Min/max of (values ∪ band edges), padded 10%; never forced to zero —
    /// these are physiological ranges, not counts.
    private var yDomain: ClosedRange<Double> {
        var values = series.points.map(\.value)
        if let mean = series.normMean, let sd = series.normSD {
            values.append(mean + sd)
            values.append(mean - sd)
        }
        guard let rawMin = values.min(), let rawMax = values.max() else { return 0...1 }
        if rawMin == rawMax {
            let pad = max(abs(rawMin) * 0.1, 1)
            return (rawMin - pad)...(rawMax + pad)
        }
        let span = rawMax - rawMin
        let pad = span * 0.1
        return (rawMin - pad)...(rawMax + pad)
    }

    // MARK: - X axis

    private var xAxisLabels: some View {
        let points = series.points
        return HStack {
            if let first = points.first {
                Text(formattedDate(first.localDate))
                Spacer()
            }
            if points.count > 2 {
                Text(formattedDate(points[points.count / 2].localDate))
                if points.count > 1 { Spacer() }
            }
            if points.count > 1, let last = points.last {
                Text(formattedDate(last.localDate))
            }
        }
        .font(CGTheme.monoSmall)
        .foregroundStyle(CGTheme.inkFaint)
    }

    private func formattedDate(_ localDate: String) -> String {
        guard let date = Self.isoParser.date(from: localDate) else { return localDate }
        return Self.displayFormatter.string(from: date).uppercased()
    }

    private static let isoParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}

// MARK: - Previews

#Preview("Full band") {
    let values: [(String, Double)] = (1...21).map { day in
        (String(format: "2026-01-%02d", day), 58 + Double.random(in: -9...9))
    }
    let series = TrendBuilder.series(values: values, windowDays: 14, sdFloor: 1)
    return BandChart(series: series, height: 84, showXAxisDates: true)
        .padding(20)
        .background(CGTheme.surface)
}

#Preview("Building — no band") {
    let values: [(String, Double)] = (1...5).map { day in
        (String(format: "2026-01-%02d", day), 58 + Double.random(in: -4...4))
    }
    let series = TrendBuilder.series(values: values, windowDays: 14, sdFloor: 1)
    return BandChart(series: series, height: 84, showXAxisDates: true)
        .padding(20)
        .background(CGTheme.surface)
}

#Preview("Single point") {
    let series = TrendBuilder.series(values: [("2026-01-01", 58)], windowDays: 14, sdFloor: 1)
    return BandChart(series: series, height: 44, showXAxisDates: false)
        .padding(20)
        .background(CGTheme.surface)
}

#Preview("Dark mode") {
    let values: [(String, Double)] = (1...21).map { day in
        (String(format: "2026-01-%02d", day), 58 + Double.random(in: -9...9))
    }
    let series = TrendBuilder.series(values: values, windowDays: 14, sdFloor: 1)
    return BandChart(series: series, height: 84, showXAxisDates: true)
        .padding(20)
        .background(CGTheme.surface)
        .preferredColorScheme(.dark)
}
