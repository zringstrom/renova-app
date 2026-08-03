import SwiftUI
import UIKit

/// Thin wrapper so a plain file URL can go through the standard iOS share
/// sheet — Mail (email to self), Save to Files, AirDrop, Messages, etc. — all
/// for free, no custom export UI needed.
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }
}
