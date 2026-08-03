import SwiftUI

/// A single left-to-right sweep with a growing tinted trail behind it —
/// approved over 4 other candidates for the measurement session's waiting
/// phases (Settle / Lying / Standing). Tied to real elapsed/target time, not
/// an ambient loop: the trail's width *is* how far through the phase you are.
struct ScanLineProgress: View {
    /// 0...1
    var progress: Double

    private let tickCount = 11

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clamped = min(max(progress, 0), 1)

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { index in
                        Rectangle().fill(CGTheme.line).frame(width: 1)
                        if index < tickCount - 1 { Spacer(minLength: 0) }
                    }
                }

                Rectangle()
                    .fill(CGTheme.accent.opacity(0.12))
                    .frame(width: width * clamped)

                Rectangle()
                    .fill(CGTheme.accent)
                    .frame(width: 2)
                    .shadow(color: CGTheme.accent.opacity(0.55), radius: 4)
                    .offset(x: max(0, width * clamped - 1))
            }
        }
        .frame(height: 40)
        .background(CGTheme.surface2)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .animation(.linear(duration: 0.35), value: progress)
    }
}
