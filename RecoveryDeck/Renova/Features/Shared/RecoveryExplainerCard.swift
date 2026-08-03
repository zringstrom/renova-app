import SwiftUI

/// The expandable accent-bordered What/So What/Now What card — shared UI for
/// whichever `RecoveryExplainerTopic` is open.
struct RecoveryExplainerCard: View {
    let topic: RecoveryExplainerTopic
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(topic.title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(CGTheme.accent)
                Spacer()
                Button(action: onClose) {
                    Text("✕")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(CGTheme.inkFaint)
                }
            }
            ForEach(topic.rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.0)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(CGTheme.ink)
                    Text(row.1)
                        .font(.system(size: 12.5))
                        .foregroundStyle(CGTheme.inkDim)
                        .lineSpacing(2)
                }
            }
        }
        .padding(16)
        .background(CGTheme.accent.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.accent, lineWidth: 1))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// Two small "what's this?" chips (mutually exclusive — opening one closes
/// the other) plus the card itself when one is open. Drop this in anywhere
/// someone might want to look up HRV or orthostatic HR: the live session,
/// Today, and Settings.
struct RecoveryExplainerTriggers: View {
    @Binding var open: RecoveryExplainerTopic?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(RecoveryExplainerTopic.allCases, id: \.self) { topic in
                    chip(for: topic)
                }
            }
            if let open {
                RecoveryExplainerCard(topic: open) {
                    withAnimation { self.open = nil }
                }
            }
        }
    }

    private func chip(for topic: RecoveryExplainerTopic) -> some View {
        let isOpen = open == topic
        return Button {
            withAnimation { open = isOpen ? nil : topic }
        } label: {
            Text("WHAT'S \(topic.shortLabel.uppercased())?")
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .foregroundStyle(isOpen ? Color.white : CGTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOpen ? CGTheme.accent : CGTheme.accent.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.accent, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
