import SwiftUI

/// A 1–7 picker that never shows a pre-selected value or thumb — matches the
/// approved "Control Grid" mockup exactly: a bare rail with 7 tick marks, and
/// the accent-colored thumb only pops in on first touch. A plain SwiftUI
/// `Slider` can't hide its thumb dynamically, so this is a custom drag surface.
struct ControlGridSlider: View {
    @Binding var value: Int?
    private let range = 1...7

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
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let clampedX = min(max(drag.location.x, 0), width)
                        let frac = width > 0 ? clampedX / width : 0
                        let raw = Int((frac * CGFloat(range.upperBound - range.lowerBound)).rounded()) + range.lowerBound
                        value = min(max(raw, range.lowerBound), range.upperBound)
                    }
            )
        }
        .frame(height: 28)
    }
}
