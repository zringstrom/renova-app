import SwiftUI
import UIKit

struct QuestionnaireView: View {
    let viewModel: AppViewModel
    var isEditing: Bool = false
    @Environment(\.dismiss) private var dismiss

    @State private var fatigue: Int?
    @State private var mood: Int?
    @State private var soreness: Int?
    @State private var sleepQuality: Int?
    @State private var workStress: Int?
    @State private var relationshipStress: Int?
    @State private var overallLifeStress: Int?

    @AppStorage("weightUnit") private var weightUnit = WeightUnit.kg.rawValue
    @AppStorage("weightTrackingEnabled") private var weightTrackingEnabled = true
    @State private var weightText: String = ""

    @State private var contextSkipped = false
    @State private var lastCaffeineAt: Date?
    @State private var caffeineAmountMg: String = ""
    @State private var lastMealAt: Date?
    @State private var showCaffeineWheel = false

    @AppStorage("habitChipsEnabled") private var habitChipsEnabled = true
    @State private var habitAlcohol = false
    @State private var habitIntenseTraining = false
    @State private var habitLongTraining = false
    @State private var habitTravel = false
    @State private var habitLateNight = false
    @State private var habitSick = false
    @State private var habitMeditation = false

    @State private var notes = ""
    @FocusState private var isTextFieldFocused: Bool

    init(viewModel: AppViewModel, isEditing: Bool = false) {
        self.viewModel = viewModel
        self.isEditing = isEditing
        let existing = isEditing ? viewModel.todayRecord : nil
        _fatigue = State(initialValue: existing?.fatigue)
        _mood = State(initialValue: existing?.mood)
        _soreness = State(initialValue: existing?.soreness)
        _sleepQuality = State(initialValue: existing?.sleepQuality)
        _workStress = State(initialValue: existing?.workStress)
        _relationshipStress = State(initialValue: existing?.relationshipStress)
        _overallLifeStress = State(initialValue: existing?.overallLifeStress)
        let storedUnit = WeightUnit(rawValue: UserDefaults.standard.string(forKey: "weightUnit") ?? "") ?? .kg
        _weightText = State(initialValue: existing?.bodyWeightKg.map { String(format: "%.1f", storedUnit.fromKg($0)) } ?? "")
        // Caffeine/meal timing tends to repeat day to day, so default all
        // three fields to whatever was logged yesterday instead of starting
        // blank.
        let yesterday = viewModel.dayRecord(for: viewModel.today.adding(days: -1, timeZone: .current))
        _lastCaffeineAt = State(initialValue: existing?.lastCaffeineAt ?? yesterday?.lastCaffeineAt)
        _caffeineAmountMg = State(initialValue: existing?.caffeineAmountMg.map { String(format: "%.0f", $0) }
            ?? yesterday?.caffeineAmountMg.map { String(format: "%.0f", $0) }
            ?? "")
        _lastMealAt = State(initialValue: existing?.lastMealAt ?? yesterday?.lastMealAt)
        _habitAlcohol = State(initialValue: existing?.habitAlcohol ?? false)
        _habitIntenseTraining = State(initialValue: existing?.habitIntenseTrainingYesterday ?? false)
        _habitLongTraining = State(initialValue: existing?.habitLongTrainingYesterday ?? false)
        _habitTravel = State(initialValue: existing?.habitTravel ?? false)
        _habitLateNight = State(initialValue: existing?.habitLateNight ?? false)
        _habitSick = State(initialValue: existing?.habitSick ?? false)
        _habitMeditation = State(initialValue: existing?.habitMeditationYesterday ?? false)
        _notes = State(initialValue: existing?.notes ?? "")
    }

    /// Midnight, not "whenever the app happened to be opened" — a picker has to
    /// show *some* time before the user touches it, and the current moment
    /// silently implies a real answer that was never given.
    private static var defaultTimeSlotDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Only the true fallback — once yesterday's value is available (see
    /// `init`), that wins over this. A more plausible starting point than
    /// midnight for the first time either field is ever touched.
    private static var defaultCaffeineTimeSlotDate: Date {
        Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? defaultTimeSlotDate
    }

    private static var defaultMealTimeSlotDate: Date {
        Calendar.current.date(bySettingHour: 18, minute: 30, second: 0, of: Date()) ?? defaultTimeSlotDate
    }

    /// Life Stress collapses three underlying fields into one row, so it
    /// only counts once here — otherwise touching that one slider jumps the
    /// counter by 3 at once (e.g. straight from 4/7 to 7/7, skipping 5 and 6
    /// entirely) since it writes all three fields simultaneously.
    private var scores: [Int?] { [fatigue, mood, soreness, sleepQuality, lifeStressBinding.wrappedValue] }
    private var setCount: Int { scores.compactMap { $0 }.count }
    private var isComplete: Bool { setCount == scores.count }

    /// One slider standing in for all three stress fields — writes the same
    /// value to `workStress`/`relationshipStress`/`overallLifeStress` so
    /// nothing downstream (baselines, exports) has to change. Reads back
    /// whichever of the three is set (they're always equal once touched
    /// through this binding).
    private var lifeStressBinding: Binding<Int?> {
        Binding(
            get: { workStress ?? relationshipStress ?? overallLifeStress },
            set: { newValue in
                workStress = newValue
                relationshipStress = newValue
                overallLifeStress = newValue
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                band
                columnHeader

                sectionLabel("BODY")
                metricRow(title: "Fatigue", low: "Feeling fresh", high: "Exhausted", value: $fatigue)
                metricRow(title: "Mood", low: "Very low", high: "Great", value: $mood)
                metricRow(title: "Soreness / heavy legs", low: "None", high: "Very sore", value: $soreness)
                metricRow(title: "Sleep quality", low: "Terrible", high: "Excellent", value: $sleepQuality)

                metricRow(title: "Life stress", low: "Low", high: "Very high", value: lifeStressBinding)

                if weightTrackingEnabled {
                    sectionLabel("MORNING WEIGHT")
                    weightSection
                }

                sectionLabel("LAST CAFFEINE INTAKE & LAST CALORIE INTAKE")
                contextDisclosure

                if habitChipsEnabled {
                    sectionLabel("YESTERDAY")
                    habitTable
                }

                sectionLabel("NOTES")
                notesField
                    .padding(.bottom, 20)
                    .background(CGTheme.surface)

                submitBlock
            }
        }
        .background(CGTheme.bg)
        .scrollDismissesKeyboard(.immediately)
        .onTapGesture { dismissKeyboard() }
    }

    private func dismissKeyboard() {
        isTextFieldFocused = false
    }

    // MARK: - Header

    /// A "Done" button pinned in the header, not a keyboard input-accessory
    /// toolbar — this view has no navigation bar of its own (it's embedded
    /// directly inside the Today tab's custom bottom tab bar), and the system
    /// keyboard toolbar doesn't respect that custom layout, so it visually
    /// collided with the tab bar. A plain button up top never can.
    private var band: some View {
        HStack(alignment: .top) {
            Text("READINESS INPUT")
                .font(.system(size: 15, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(CGTheme.ink)
            Spacer()
            if isTextFieldFocused {
                Button {
                    dismissKeyboard()
                } label: {
                    Text("DONE")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(CGTheme.accent)
                }
                .transition(.opacity)
            } else {
                Text(dateMeta)
                    .font(CGTheme.monoSmall)
                    .foregroundStyle(CGTheme.inkFaint)
                    .multilineTextAlignment(.trailing)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isTextFieldFocused)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.ink).frame(height: 3) }
        .background(CGTheme.surface)
    }

    private var dateMeta: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE dd MMM yyyy"
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        return "\(formatter.string(from: Date()).uppercased())\n\(time.string(from: Date())) LOCAL"
    }

    private var columnHeader: some View {
        HStack {
            Text("METRIC").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(1...7, id: \.self) { n in
                Text("\(n)").frame(maxWidth: .infinity)
            }
        }
        .font(CGTheme.monoSmall)
        .foregroundStyle(CGTheme.inkFaint)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 4)
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

    // MARK: - Metric rows

    private func metricRow(title: String, low: String, high: String, value: Binding<Int?>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.system(size: 13.5, weight: .bold))
                    .tracking(0.2)
                Spacer()
                Text(value.wrappedValue.map(String.init) ?? "—")
                    .font(CGTheme.mono)
                    .foregroundStyle(value.wrappedValue == nil ? CGTheme.inkFaint : CGTheme.accent)
                    .fontWeight(value.wrappedValue == nil ? .regular : .bold)
            }
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(CGTheme.monoSmall)
            .foregroundStyle(CGTheme.inkFaint)

            ControlGridSlider(value: value)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(CGTheme.line).frame(height: 1) }
        .background(CGTheme.surface)
    }

    // MARK: - Weight

    private var currentWeightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnit) ?? .kg
    }

    /// Optional — deliberately not part of `scores`/`isComplete`, so leaving
    /// it blank never blocks submission.
    private var weightSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                contextSubField("MORNING WEIGHT (\(currentWeightUnit.label))") {
                    TextField(currentWeightUnit == .kg ? "70.0" : "154.0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .focused($isTextFieldFocused)
                }
                Rectangle().fill(CGTheme.lineStrong).frame(width: 1).padding(.vertical, 10)
                HStack(spacing: 6) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Button {
                            switchUnit(to: unit)
                        } label: {
                            Text(unit.label)
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(currentWeightUnit == unit ? CGTheme.accent : CGTheme.inkFaint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
            }
            .background(CGTheme.surface2)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.lineStrong, lineWidth: 1))
        }
        .padding(14)
        .background(CGTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.lineStrong, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .background(CGTheme.surface)
    }

    /// Re-expresses the currently typed value in the new unit rather than
    /// clearing it, so switching units mid-entry doesn't lose input.
    private func switchUnit(to unit: WeightUnit) {
        guard unit.rawValue != weightUnit else { return }
        if let parsed = parsedWeightInput, currentWeightUnit != unit {
            let kg = currentWeightUnit.toKg(parsed)
            weightText = String(format: "%.1f", unit.fromKg(kg))
        }
        weightUnit = unit.rawValue
    }

    private var parsedWeightInput: Double? {
        Double(weightText.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: - Context

    /// Shown expanded by default — caffeine/meal timing is genuinely useful
    /// data, so it's asked for up front rather than hidden behind a disclosure.
    /// The opt-out is intentionally low-key (small, muted text) so it reads as
    /// available, not invited. Caffeine time+amount are one connected box (split
    /// by an inner divider, not two separate boxes) since they're one thought.
    /// Last meal mirrors the exact same treatment — label outside/above the
    /// box, left-justified — just as its own row underneath.
    private var contextDisclosure: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !contextSkipped {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LAST CAFFEINE INTAKE | TOTAL CAFFEINE YESTERDAY").font(CGTheme.monoSmall).foregroundStyle(CGTheme.inkFaint)
                    HStack(spacing: 0) {
                        contextSubField("TIME") {
                            timePicker(selection: Binding(get: { lastCaffeineAt ?? Self.defaultCaffeineTimeSlotDate }, set: { lastCaffeineAt = $0 }))
                        }
                        Rectangle().fill(CGTheme.lineStrong).frame(width: 1).padding(.vertical, 10)
                        contextSubField("TOTAL (MG)") {
                            caffeineAmountField
                        }
                    }
                    .background(CGTheme.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.lineStrong, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("LAST CALORIE INTAKE").font(CGTheme.monoSmall).foregroundStyle(CGTheme.inkFaint)
                    HStack(spacing: 0) {
                        contextSubField("TIME") {
                            timePicker(selection: Binding(get: { lastMealAt ?? Self.defaultMealTimeSlotDate }, set: { lastMealAt = $0 }))
                        }
                    }
                    .background(CGTheme.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.lineStrong, lineWidth: 1))
                }

                Button {
                    contextSkipped = true
                    lastCaffeineAt = nil
                    caffeineAmountMg = ""
                    lastMealAt = nil
                } label: {
                    Text("skip")
                        .font(.system(size: 10))
                        .foregroundStyle(CGTheme.inkFaint.opacity(0.6))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                Button {
                    contextSkipped = false
                } label: {
                    Text("Add caffeine / meal timing")
                        .font(CGTheme.monoSmall)
                        .foregroundStyle(CGTheme.inkDim)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(CGTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.lineStrong, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
        .background(CGTheme.surface)
    }

    private func contextSubField(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
    }

    /// A fixed list of 15-minute slots in a wheel, same pattern as
    /// `caffeineAmountField` below. An earlier version snapped a plain
    /// `DatePicker`'s value to the nearest 15 minutes *after* selection —
    /// that left the wheel itself still scrolling every single minute, which
    /// didn't read as "15-minute increments" at all. A still-earlier version
    /// wrapped `UIDatePicker` directly to get real `minuteInterval` scrolling,
    /// but two `.compact`-style `UIDatePicker`s on one screen is a known
    /// UIKit bug — the second one renders blank. Building the wheel's option
    /// list ourselves sidesteps both problems.
    private func timePicker(selection: Binding<Date>) -> some View {
        QuarterHourTimeField(selection: selection)
    }

    /// Same pill look as the plain text field it replaces — tapping it opens
    /// a scrollable wheel (values in steps of 10) instead of typing on the
    /// keyboard or repeatedly tapping +/- buttons.
    private var caffeineAmountField: some View {
        Button {
            showCaffeineWheel = true
        } label: {
            Text(caffeineAmountMg.isEmpty ? "0" : caffeineAmountMg)
                .foregroundStyle(CGTheme.ink)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showCaffeineWheel) {
            Picker("", selection: caffeineAmountBinding) {
                ForEach(Array(stride(from: 0, through: 750, by: 10)), id: \.self) { value in
                    Text("\(value) mg").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 200, height: 200)
            .presentationCompactAdaptation(.popover)
        }
    }

    /// Rounds to the nearest 10 on read — a yesterday-carried-forward default
    /// (or a value typed before this build existed) might not already land
    /// on a multiple of 10.
    private var caffeineAmountBinding: Binding<Int> {
        Binding(
            get: {
                let current = Int(caffeineAmountMg) ?? 0
                return Int((Double(current) / 10).rounded()) * 10
            },
            set: { newValue in
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                caffeineAmountMg = String(newValue)
            }
        )
    }

    // MARK: - Habits

    private var habitTable: some View {
        VStack(spacing: 0) {
            ControlGridToggle(label: "Consumed Alcohol", isOn: $habitAlcohol)
            ControlGridToggle(label: "Intense Training", isOn: $habitIntenseTraining)
            ControlGridToggle(label: "Long Training", isOn: $habitLongTraining)
            ControlGridToggle(label: "Travel", isOn: $habitTravel)
            ControlGridToggle(label: "Late Night", isOn: $habitLateNight)
            ControlGridToggle(label: "Felt Sick / Under the Weather", isOn: $habitSick)
            ControlGridToggle(label: "Did Breathwork", isOn: $habitMeditation)
        }
        .padding(.horizontal, 20)
        .background(CGTheme.surface)
    }

    // MARK: - Notes

    private var notesField: some View {
        TextField("Anything else worth logging...", text: $notes, axis: .vertical)
            .font(.system(size: 13.5))
            .lineLimit(3...6)
            .focused($isTextFieldFocused)
            .padding(10)
            .background(CGTheme.surface2)
            .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.lineStrong, lineWidth: 1))
            .padding(.horizontal, 20)
            .background(CGTheme.surface)
    }

    // MARK: - Submit

    private var submitBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FIELDS SET").font(CGTheme.monoSmall).foregroundStyle(CGTheme.inkFaint)
                Spacer()
                Text("\(setCount) / \(scores.count)").font(CGTheme.monoSmall).fontWeight(.bold).foregroundStyle(CGTheme.ink)
            }
            Button {
                submit()
            } label: {
                Text(isComplete ? (isEditing ? "SAVE CHANGES" : "SUBMIT READINESS") : "SET ALL \(scores.count) METRICS TO SUBMIT")
                    .font(.system(size: 13, weight: .heavy))
                    .tracking(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle(isComplete ? .white : CGTheme.surface)
                    .background(isComplete ? CGTheme.accent : CGTheme.ink)
                    .opacity(isComplete ? 1 : 0.35)
            }
            .disabled(!isComplete)
        }
        .padding(20)
        .background(CGTheme.surface)
        .overlay(alignment: .top) { Rectangle().fill(CGTheme.line).frame(height: 1) }
    }

    /// Converts the typed weight to kg, discarding anything outside a
    /// plausible human body-weight range rather than saving a fat-fingered
    /// value (e.g. a stray extra digit) as gospel.
    private var sanitizedBodyWeightKg: Double? {
        guard let parsed = parsedWeightInput else { return nil }
        let kg = currentWeightUnit.toKg(parsed)
        guard (20...400).contains(kg) else { return nil }
        return kg
    }

    private func submit() {
        guard let fatigue, let mood, let soreness, let sleepQuality,
              let workStress, let relationshipStress, let overallLifeStress else { return }
        let answers = DayRepository.QuestionnaireAnswers(
            fatigue: fatigue,
            mood: mood,
            soreness: soreness,
            sleepQuality: sleepQuality,
            workStress: workStress,
            relationshipStress: relationshipStress,
            overallLifeStress: overallLifeStress,
            bodyWeightKg: weightTrackingEnabled ? sanitizedBodyWeightKg : viewModel.todayRecord?.bodyWeightKg,
            lastCaffeineAt: lastCaffeineAt,
            caffeineAmountMg: Double(caffeineAmountMg),
            caffeineAmountBand: nil,
            lastMealAt: lastMealAt,
            habitAlcohol: habitChipsEnabled ? habitAlcohol : nil,
            habitIntenseTrainingYesterday: habitChipsEnabled ? habitIntenseTraining : nil,
            habitLongTrainingYesterday: habitChipsEnabled ? habitLongTraining : nil,
            habitTravel: habitChipsEnabled ? habitTravel : nil,
            habitLateNight: habitChipsEnabled ? habitLateNight : nil,
            habitSick: habitChipsEnabled ? habitSick : nil,
            habitMeditationYesterday: habitChipsEnabled ? habitMeditation : nil,
            notes: notes.isEmpty ? nil : notes
        )
        viewModel.submitQuestionnaire(answers)
        dismiss()
    }
}

/// Same pill-button-opens-a-wheel pattern as the caffeine mg field, just
/// over a fixed list of 15-minute-of-day slots instead of numbers. Picking
/// the option list ourselves (rather than relying on `UIDatePicker.minuteInterval`,
/// which needs a `UIViewRepresentable` and breaks when there's more than one
/// `.compact`-style instance on screen) is what actually gets real 15-minute
/// steps in the wheel.
private struct QuarterHourTimeField: View {
    @Binding var selection: Date
    @State private var showPicker = false

    private static let minuteOptions: [Int] = Array(stride(from: 0, to: 24 * 60, by: 15))

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private func date(forMinutesSinceMidnight minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: selection)
            ?? selection
    }

    private func label(forMinutesSinceMidnight minutes: Int) -> String {
        Self.formatter.string(from: date(forMinutesSinceMidnight: minutes))
    }

    /// Rounds whatever's currently stored to the nearest slot in the list —
    /// covers values set before this build existed, or the once-a-day
    /// yesterday-carried-forward default.
    private var currentMinutesSinceMidnight: Int {
        let calendar = Calendar.current
        let raw = calendar.component(.hour, from: selection) * 60 + calendar.component(.minute, from: selection)
        let remainder = raw % 15
        return remainder < 8 ? raw - remainder : raw + (15 - remainder)
    }

    var body: some View {
        Button {
            showPicker = true
        } label: {
            Text(Self.formatter.string(from: selection))
                .font(.system(size: 17))
                .foregroundStyle(CGTheme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(CGTheme.surface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker) {
            Picker(
                "",
                selection: Binding(
                    get: { currentMinutesSinceMidnight },
                    set: { selection = date(forMinutesSinceMidnight: $0) }
                )
            ) {
                ForEach(Self.minuteOptions, id: \.self) { minutes in
                    Text(label(forMinutesSinceMidnight: minutes)).tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 200, height: 200)
            .presentationCompactAdaptation(.popover)
        }
    }
}

