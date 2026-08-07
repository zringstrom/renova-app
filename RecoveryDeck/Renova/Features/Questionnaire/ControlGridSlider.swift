import SwiftUI

/// A 1–7 picker that never shows a pre-selected value or thumb — matches the
/// approved "Control Grid" mockup exactly: a bare rail with 7 tick marks, and
/// the accent-colored thumb only pops in on first touch. A plain SwiftUI
/// `Slider` can't hide its thumb dynamically, so this is a custom drag surface.
struct ControlGridSlider: View {
    @Binding var value: Int?
    private let range = 1...7

    /// `nil` until a drag's first `onChanged` callback classifies it as
    /// horizontal (slider scrub) or vertical (a page scroll that merely
    /// started on top of this row) — see `body`'s `.gesture` for why this
    /// exists at all.
    @State private var dragAxis: Axis?

    private enum Axis { case horizontal, vertical }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = value.map { CGFloat($0 - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound) }

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(CGTheme.lineStrong)
                    .frame(height: 2)

                if let fraction {
                    Rectangle()
                        .fill(CGTheme.accent)
                        .frame(width: width * fraction, height: 2)
                }

                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        Rectangle().fill(CGTheme.lineStrong).frame(width: 1, height: 6)
                        if i < 6 { Spacer(minLength: 0) }
                    }
                }

                if let fraction {
                    Circle()
                        .fill(CGTheme.accent)
                        .overlay(Circle().stroke(CGTheme.surface, lineWidth: 3))
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
                        .offset(x: width * fraction - 10)
                }
            }
            .frame(height: 28)
            .contentShape(Rectangle())
            // A `minimumDistance: 0` drag fires on touch-down, before the
            // enclosing ScrollView gets a chance to claim the gesture — so a
            // vertical page scroll that merely started on a slider row was
            // being read as a horizontal scrub and silently setting/changing
            // that row's answer. Raising the threshold lets normal SwiftUI
            // gesture arbitration hand pure vertical pans to the ScrollView;
            // the axis lock below is belt-and-braces for a finger that rests
            // first and then moves diagonally.
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { drag in
                        if dragAxis == nil {
                            let horizontal = abs(drag.translation.width) >= abs(drag.translation.height)
                            dragAxis = horizontal ? .horizontal : .vertical
                        }
                        guard dragAxis == .horizontal else { return }
                        value = resolvedValue(atX: drag.location.x, width: width)
                    }
                    .onEnded { _ in dragAxis = nil }
            )
            // `minimumDistance: 10` above means a plain tap never reaches
            // `onChanged`, so a direct tap on a tick needs its own gesture.
            .onTapGesture { location in
                value = resolvedValue(atX: location.x, width: width)
            }
        }
        .frame(height: 28)
    }

    private func resolvedValue(atX x: CGFloat, width: CGFloat) -> Int {
        let clampedX = min(max(x, 0), width)
        let frac = width > 0 ? clampedX / width : 0
        let raw = Int((frac * CGFloat(range.upperBound - range.lowerBound)).rounded()) + range.lowerBound
        return min(max(raw, range.lowerBound), range.upperBound)
    }
}
