import SwiftUI

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
    @State private var weightText: String = ""

    @State private var contextSkipped = false
    @State private var lastCaffeineAt: Date?
    @State private var caffeineAmountMg: String = ""
    @State private var lastMealAt: Date?

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
        _lastCaffeineAt = State(initialValue: existing?.lastCaffeineAt)
        _caffeineAmountMg = State(initialValue: existing?.caffeineAmountMg.map { String(format: "%.0f", $0) } ?? "")
        _lastMealAt = State(initialValue: existing?.lastMealAt)
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

    private var scores: [Int?] { [fatigue, mood, soreness, sleepQuality, workStress, relationshipStress, overallLifeStress] }
    private var setCount: Int { scores.compactMap { $0 }.count }
    private var isComplete: Bool { setCount == 7 }

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

                sectionLabel("STRESS")
                metricRow(title: "Work stress", low: "Low", high: "Very high", value: $workStress)
                metricRow(title: "Relationship stress", low: "Low", high: "Very high", value: $relationshipStress)
                metricRow(title: "Overall life stress", low: "Low", high: "Very high", value: $overallLifeStress)

                sectionLabel("WEIGHT")
                weightSection

                sectionLabel("LAST CAFFEINE INTAKE & LAST CALORIE INTAKE")
                contextDisclosure

                if habitChipsEnabled {
                    sectionLabel("YESTERDAY")
                    habitTable
                }

                sectionLabel("NOTES")
                notesField
                    .padding(.bottom, 20)

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
                contextSubField("WEIGHT (\(currentWeightUnit.label))") {
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
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
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
                            DatePicker("", selection: Binding(get: { lastCaffeineAt ?? Self.defaultTimeSlotDate }, set: { lastCaffeineAt = $0 }), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                        Rectangle().fill(CGTheme.lineStrong).frame(width: 1).padding(.vertical, 10)
                        contextSubField("TOTAL (MG)") {
                            TextField("95", text: $caffeineAmountMg)
                                .keyboardType(.numberPad)
                                .focused($isTextFieldFocused)
                        }
                    }
                    .background(CGTheme.surface2)
                    .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.lineStrong, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("LAST CALORIE INTAKE").font(CGTheme.monoSmall).foregroundStyle(CGTheme.inkFaint)
                    HStack(spacing: 0) {
                        contextSubField("TIME") {
                            DatePicker("", selection: Binding(get: { lastMealAt ?? Self.defaultTimeSlotDate }, set: { lastMealAt = $0 }), displayedComponents: .hourAndMinute)
                                .labelsHidden()
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
        .overlay(RoundedRectangle(cornerRadius: 0).stroke(CGTheme.line, lineWidth: 1))
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private func contextSubField(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 9, design: .monospaced)).foregroundStyle(CGTheme.inkFaint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
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
                Text("\(setCount) / 7").font(CGTheme.monoSmall).fontWeight(.bold).foregroundStyle(CGTheme.ink)
            }
            Button {
                submit()
            } label: {
                Text(isComplete ? (isEditing ? "SAVE CHANGES" : "SUBMIT READINESS") : "SET ALL 7 METRICS TO SUBMIT")
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
        .background(CGTheme.surface2)
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
            bodyWeightKg: sanitizedBodyWeightKg,
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
