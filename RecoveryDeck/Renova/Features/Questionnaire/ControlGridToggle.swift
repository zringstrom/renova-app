import SwiftUI

/// The habit-row Yes/No rocker from the approved mockup: a right-aligned
/// NO/YES text label plus a two-state switch (accent-red knob for Yes,
/// accent-teal knob for No) — a deliberate design choice, not a system Toggle.
struct ControlGridToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(CGTheme.ink)
            Spacer()
            HStack(spacing: 8) {
                Text(isOn ? "YES" : "NO")
                    .font(CGTheme.monoSmall)
                    .foregroundStyle(CGTheme.inkFaint)
                    .frame(width: 30, alignment: .trailing)

                Button {
                    withAnimation(.easeOut(duration: 0.16)) { isOn.toggle() }
                } label: {
                    ZStack(alignment: isOn ? .trailing : .leading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isOn ? CGTheme.accent.opacity(0.18) : CGTheme.accent2.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isOn ? CGTheme.accent : CGTheme.accent2, lineWidth: 1)
                            )
                            .frame(width: 46, height: 24)
                        Circle()
                            .fill(isOn ? CGTheme.accent : CGTheme.accent2)
                            .frame(width: 20, height: 20)
                            .padding(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
    }
}
