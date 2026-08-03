import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
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
    }
}
