import SwiftUI

enum AppTab: CaseIterable {
    case today, history, settings

    var label: String {
        switch self {
        case .today: "TODAY"
        case .history: "TRENDS"
        case .settings: "SETTINGS"
        }
    }

    var glyph: String {
        switch self {
        case .today: "sun.max"
        case .history: "chart.line.uptrend.xyaxis"
        case .settings: "gearshape"
        }
    }
}

/// Flat, bordered tab bar matching the Control Grid theme — mono uppercase
/// labels, a hairline top border, and an accent underline on the active tab,
/// instead of the default translucent SF Symbols tab bar.
struct ControlGridTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.glyph)
                            .font(.system(size: 15, weight: .medium))
                        Text(tab.label)
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .tracking(0.6)
                    }
                    .foregroundStyle(selection == tab ? CGTheme.ink : CGTheme.inkFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(selection == tab ? CGTheme.accent : Color.clear)
                            .frame(height: 2)
                            .offset(y: -2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(CGTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(CGTheme.ink).frame(height: 3) }
    }
}
