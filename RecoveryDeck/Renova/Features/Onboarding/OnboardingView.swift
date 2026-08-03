import SwiftUI
import UserNotifications

/// Ported from the approved `onboarding-v5.html` mockup ("Control Grid").
struct OnboardingView: View {
    let onFinished: () -> Void

    @AppStorage("displayName") private var displayName = ""
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notificationHour") private var notificationHour = 6
    @AppStorage("notificationMinute") private var notificationMinute = 30
    /// One or none — never both. Opening one closes the other.
    @State private var openExplainer: RecoveryExplainerTopic?

    var body: some View {
        VStack(spacing: 0) {
            band

            ScrollView {
                VStack(spacing: 0) {
                    hero

                    sectionLabel("REQUIREMENTS")
                    requirementsCallout

                    sectionLabel("OPERATOR")
                    nameField

                    sectionLabel("SCHEDULE")
                    scheduleRow

                    submitBlock
                }
            }
            .background(CGTheme.surface)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(CGTheme.surface)
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "renova" else { return .systemAction }
            switch url.host {
            case "explain-hrv":
                withAnimation { openExplainer = (openExplainer == .hrv) ? nil : .hrv }
                return .handled
            case "explain-orthostatic":
                withAnimation { openExplainer = (openExplainer == .orthostatic) ? nil : .orthostatic }
                return .handled
            default:
                return .systemAction
            }
        })
    }

    // MARK: - Header

    private var band: some View {
        HStack(alignment: .top) {
            Text("SYSTEM ONBOARDING")
                .font(.system(size: 15, weight: .heavy))
                .tracking(0.5)
            Spacer()
            Text("\(dateString)\nFIRST RUN")
                .font(CGTheme.monoSmall)
                .foregroundStyle(CGTheme.inkFaint)
                .multilineTextAlignment(.trailing)
        }
        .foregroundStyle(CGTheme.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.ink).frame(height: 3) }
        .background(CGTheme.surface)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE dd MMM yyyy"
        return formatter.string(from: Date()).uppercased()
    }

    /// "HRV" and "orthostatic HR" are real tappable links inline in the
    /// paragraph (not just colored text) — each toggles its own explainer via
    /// a custom `renova://explain-*` URL handled above. Only one card
    /// is ever open — opening either one closes the other.
    private var heroParagraph: AttributedString {
        var lead = AttributedString("Two inputs every morning: a short questionnaire, then a guided HR strap session measuring ")
        lead.font = .system(size: 13.5)
        lead.foregroundColor = CGTheme.inkDim

        var hrvLink = AttributedString("HRV")
        hrvLink.font = .system(size: 13.5, weight: .bold)
        hrvLink.foregroundColor = CGTheme.accent
        hrvLink.underlineStyle = .single
        hrvLink.link = URL(string: "renova://explain-hrv")

        var mid = AttributedString(" and ")
        mid.font = .system(size: 13.5)
        mid.foregroundColor = CGTheme.inkDim

        var orthoLink = AttributedString("orthostatic HR")
        orthoLink.font = .system(size: 13.5, weight: .bold)
        orthoLink.foregroundColor = CGTheme.accent
        orthoLink.underlineStyle = .single
        orthoLink.link = URL(string: "renova://explain-orthostatic")

        var tail = AttributedString(". This gives you real recovery data that you can track over time, not just feelings.")
        tail.font = .system(size: 13.5)
        tail.foregroundColor = CGTheme.inkDim

        return lead + hrvLink + mid + orthoLink + tail
    }

    @ViewBuilder
    private var openExplainerCard: some View {
        if let openExplainer {
            RecoveryExplainerCard(topic: openExplainer) {
                withAnimation { self.openExplainer = nil }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RENOVA")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(CGTheme.accent)
            Text("A daily reading of your body's recovery.")
                .font(.system(size: 25, weight: .heavy))
                .foregroundStyle(CGTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(heroParagraph)
                .lineSpacing(4)
            Text("For best results, try to take measurements at the same time every morning.")
                .font(.system(size: 13.5))
                .foregroundStyle(CGTheme.inkDim)
                .lineSpacing(4)

            openExplainerCard
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
        .background(CGTheme.surface)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(CGTheme.sectionLabel)
            .tracking(1.4)
            .foregroundStyle(CGTheme.inkFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .background(CGTheme.surface)
    }

    // MARK: - Requirements

    private var requirementsCallout: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("READ BEFORE FIRST SESSION")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(CGTheme.accent)
            Text("Requires an HR chest strap paired via Bluetooth.")
            Text("If you have a heart condition or feel dizzy on standing, consult a clinician before orthostatic testing. Stop immediately if lightheaded.")
        }
        .font(.system(size: 12.5))
        .foregroundStyle(CGTheme.inkDim)
        .padding(16)
        .background(CGTheme.accent.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.accent, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    // MARK: - Operator

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DISPLAY NAME. OPTIONAL, GREETING ONLY")
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(CGTheme.inkFaint)
            TextField("For morning greetings, not an account", text: $displayName)
                .font(.system(size: 14))
                .padding(11)
                .background(CGTheme.surface2)
                .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.lineStrong, lineWidth: 1))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Schedule

    private var scheduleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Daily reminder").font(.system(size: 13))
                Text("\(String(format: "%02d:%02d", notificationHour, notificationMinute)) · \"Questionnaire first. Then HR reading.\"")
                    .font(CGTheme.monoSmall)
                    .foregroundStyle(CGTheme.inkFaint)
            }
            Spacer()
            HStack(spacing: 8) {
                Text(notificationsEnabled ? "ON" : "OFF")
                    .font(CGTheme.monoSmall)
                    .foregroundStyle(CGTheme.inkFaint)
                    .frame(width: 30, alignment: .trailing)
                Button {
                    withAnimation(.easeOut(duration: 0.16)) { notificationsEnabled.toggle() }
                } label: {
                    ZStack(alignment: notificationsEnabled ? .trailing : .leading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(notificationsEnabled ? CGTheme.accent.opacity(0.18) : CGTheme.surface2)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(notificationsEnabled ? CGTheme.accent : CGTheme.lineStrong, lineWidth: 1))
                            .frame(width: 46, height: 24)
                        Circle()
                            .fill(notificationsEnabled ? CGTheme.accent : CGTheme.inkFaint)
                            .frame(width: 20, height: 20)
                            .padding(1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 13)
        .overlay(alignment: .top) { Rectangle().fill(CGTheme.line).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
        .padding(.horizontal, 20)
    }

    // MARK: - Submit

    private var submitBlock: some View {
        VStack(spacing: 10) {
            HStack {
                Text("READY TO INITIALIZE").font(CGTheme.monoSmall).foregroundStyle(CGTheme.inkFaint)
                Spacer()
                Text("ALL SYSTEMS SET").font(CGTheme.monoSmall).fontWeight(.bold).foregroundStyle(CGTheme.accent)
            }
            Button {
                if notificationsEnabled { requestNotificationPermission() }
                onFinished()
            } label: {
                Text("BEGIN READINESS SCAN")
                    .font(.system(size: 13.5, weight: .heavy))
                    .tracking(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(.white)
                    .background(CGTheme.accent)
            }
            Text("Your data belongs to you. All data stays on your device.")
                .font(.system(size: 9.5, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(CGTheme.inkFaint)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(CGTheme.surface)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
