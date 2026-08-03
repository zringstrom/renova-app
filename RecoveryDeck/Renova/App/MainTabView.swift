import SwiftUI

struct MainTabView: View {
    @Bindable var viewModel: AppViewModel
    @State private var selection: AppTab = .today

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selection {
                case .today: TodayView(viewModel: viewModel)
                case .history: HistoryView(viewModel: viewModel)
                case .settings: SettingsView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ControlGridTabBar(selection: $selection)
        }
        .background(CGTheme.surface)
    }
}
