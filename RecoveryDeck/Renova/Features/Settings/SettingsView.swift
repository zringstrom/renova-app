import SwiftUI

struct SettingsView: View {
    let viewModel: AppViewModel

    @AppStorage("displayName") private var displayName = ""
    @AppStorage("habitChipsEnabled") private var habitChipsEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notificationHour") private var notificationHour = 6
    @AppStorage("notificationMinute") private var notificationMinute = 30
    @AppStorage("baselineWindowDays") private var baselineWindowDays = 7
    @AppStorage("cueStyle") private var cueStyle = CueStyle.both

    @State private var showDeleteConfirmation = false
    @State private var exportFile: ExportFile?
    @State private var openExplainer: RecoveryExplainerTopic?

    var body: some View {
        ZStack {
        ScrollView {
            VStack(spacing: 0) {
                band

                sectionLabel("PROFILE")
                bordered {
                    HStack {
                        Text("DISPLAY NAME").font(.system(size: 10.5, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
                        Spacer()
                        TextField("", text: $displayName)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }

                sectionLabel("RITUAL")
                bordered {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily reminder").font(.system(size: 13))
                            Text("Questionnaire first. Then HR reading.").font(CGTheme.monoSmall).foregroundStyle(CGTheme.inkFaint)
                        }
                        Spacer()
                        rockerToggle(isOn: $notificationsEnabled)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }

                    HStack {
                        Text("Notification time").font(.system(size: 13))
                        Spacer()
                        DatePicker("", selection: reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .font(.system(size: 12, design: .monospaced))
                            .fixedSize()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }

                    HStack {
                        Text("Baseline window").font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $baselineWindowDays) {
                            Text("7 DAYS").tag(7)
                            Text("14 DAYS").tag(14)
                        }
                        .labelsHidden()
                        .tint(CGTheme.accent)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }

                    HStack {
                        Text("Session cues").font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $cueStyle) {
                            Text("HAPTIC").tag(CueStyle.haptic)
                            Text("VOICE").tag(CueStyle.voice)
                            Text("BOTH").tag(CueStyle.both)
                        }
                        .labelsHidden()
                        .tint(CGTheme.accent)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }

                    HStack {
                        Text("Habit toggles").font(.system(size: 13))
                        Spacer()
                        rockerToggle(isOn: $habitChipsEnabled)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }

                    HStack {
                        Text("Orthostatic").font(.system(size: 13))
                        Spacer()
                        Text("ALWAYS SKIPPABLE").font(.system(size: 9.5, weight: .bold, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }

                sectionLabel("DATA")
                bordered {
                    Button {
                        exportFile = makeExportFile()
                    } label: {
                        HStack {
                            Text("EXPORT DATA")
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(CGTheme.ink)
                            Spacer()
                            Text("JSON").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
                    }
                    .buttonStyle(.plain)

                    Button {
                        exportFile = makeExportCSVFile()
                    } label: {
                        HStack {
                            Text("EXPORT DATA")
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(CGTheme.ink)
                            Spacer()
                            Text("CSV").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
                    }
                    .buttonStyle(.plain)

                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Text("DELETE ALL DATA")
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(CGTheme.accent)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        #if DEBUG
                        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
                        #endif
                    }
                    .buttonStyle(.plain)

                    #if DEBUG
                    Button {
                        viewModel.seedDemoData()
                    } label: {
                        HStack {
                            Text("SEED DEMO DATA")
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(CGTheme.ink)
                            Spacer()
                            Text("DEBUG").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    #endif
                }

                sectionLabel("ABOUT YOUR METRICS")
                RecoveryExplainerTriggers(open: $openExplainer)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                    .background(CGTheme.surface)

                sectionLabel("ABOUT")
                Text("Renova is not a medical device and is not for diagnosis or treatment. A personal training journal only. Consult a clinician before orthostatic testing if you have a heart condition or dizziness on standing.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(CGTheme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .background(CGTheme.surface)

        if showDeleteConfirmation {
            deleteConfirmationOverlay
        }
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .onChange(of: notificationsEnabled) { _, _ in ReminderScheduler.sync() }
        .onChange(of: notificationHour) { _, _ in ReminderScheduler.sync() }
        .onChange(of: notificationMinute) { _, _ in ReminderScheduler.sync() }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = notificationHour
                components.minute = notificationMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                notificationHour = components.hour ?? notificationHour
                notificationMinute = components.minute ?? notificationMinute
            }
        )
    }

    private func makeExportFile() -> ExportFile {
        let data = viewModel.exportJSON()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "renova-export-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return ExportFile(url: url)
    }

    private func makeExportCSVFile() -> ExportFile {
        let data = viewModel.exportCSV()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let filename = "renova-export-\(formatter.string(from: Date())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)
        return ExportFile(url: url)
    }

    // MARK: - Delete confirmation

    private var deleteConfirmationOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { showDeleteConfirmation = false }

            VStack(alignment: .leading, spacing: 14) {
                Text("DELETE ALL DATA?")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(CGTheme.accent)

                Text("This permanently removes every questionnaire entry, measurement, and log on this device. There is no undo.")
                    .font(.system(size: 13))
                    .foregroundStyle(CGTheme.inkDim)

                VStack(spacing: 0) {
                    Button {
                        viewModel.deleteAllData()
                        showDeleteConfirmation = false
                    } label: {
                        Text("DELETE EVERYTHING")
                            .font(.system(size: 12.5, weight: .heavy))
                            .tracking(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(CGTheme.accent)
                    }

                    Button {
                        showDeleteConfirmation = false
                    } label: {
                        Text("CANCEL")
                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(CGTheme.ink)
                            .background(CGTheme.surface2)
                    }
                }
                .padding(.top, 6)
            }
            .padding(20)
            .background(CGTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.accent, lineWidth: 1))
            .padding(.horizontal, 36)
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.15), value: showDeleteConfirmation)
    }

    // MARK: - Header / shared

    private var band: some View {
        HStack {
            Text("SETTINGS")
                .font(.system(size: 15, weight: .heavy))
                .tracking(0.5)
            Spacer()
        }
        .foregroundStyle(CGTheme.ink)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.ink).frame(height: 3) }
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

    private func bordered(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) { content() }
            .background(CGTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
            .padding(.horizontal, 20)
    }

    private func rockerToggle(isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(isOn.wrappedValue ? "ON" : "OFF")
                .font(CGTheme.monoSmall)
                .foregroundStyle(CGTheme.inkFaint)
                .frame(width: 26, alignment: .trailing)
            Button {
                withAnimation(.easeOut(duration: 0.16)) { isOn.wrappedValue.toggle() }
            } label: {
                ZStack(alignment: isOn.wrappedValue ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isOn.wrappedValue ? CGTheme.accent.opacity(0.18) : CGTheme.surface2)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isOn.wrappedValue ? CGTheme.accent : CGTheme.lineStrong, lineWidth: 1))
                        .frame(width: 46, height: 24)
                    Circle()
                        .fill(isOn.wrappedValue ? CGTheme.accent : CGTheme.inkFaint)
                        .frame(width: 20, height: 20)
                        .padding(1)
                }
            }
            .buttonStyle(.plain)
        }
    }
}
