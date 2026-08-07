import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var viewModel: AppViewModel?

    var body: some View {
        Group {
            if !hasOnboarded {
                OnboardingView(onFinished: { hasOnboarded = true })
            } else if let viewModel {
                MainTabView(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CGTheme.bg)
            }
        }
        .background(CGTheme.bg)
        .task {
            if viewModel == nil {
                viewModel = AppViewModel(modelContext: modelContext)
            }
        }
        // Resuming from the background doesn't re-run `.task` or `TodayView`'s
        // `.onAppear` (the view never left screen), so without this a session
        // left open overnight keeps showing yesterday's "all done" state and
        // evening greeting until the app is force-killed.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel?.refresh() }
        }
        // Covers the same staleness while the app is left open across
        // midnight in the foreground, which `scenePhase` alone won't catch.
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            viewModel?.refresh()
        }
    }
}
