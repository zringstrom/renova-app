import SwiftUI
import RecoveryKit

extension BaselineLight {
    var color: Color {
        switch self {
        case .green: CGTheme.statusOk
        case .yellow: CGTheme.statusWatch
        case .red: CGTheme.statusAlert
        }
    }
}
