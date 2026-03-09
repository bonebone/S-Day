import SwiftUI
import SwiftData

struct PatientRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var patient: Patient
    @State private var showingDatePicker = false
    @State private var showingTagSheet = false
    @State private var tempSurgeryDate: Date = Date()
    
    var body: some View {
        HStack {
            TagTokenField(
                text: $patient.rawInput,
                tags: $patient.tags,
                allTags: existingTags(),
                placeholder: "输入新病人信息...",
                autoFocusIfEmpty: true
            )
            Spacer()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                modelContext.delete(patient)
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("删除", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            
            Button {
                showingDatePicker = true
            } label: {
                Label("设日期", systemImage: "calendar")
                    .labelStyle(.iconOnly)
            }
            .tint(.blue)
            
            Button {
                showingTagSheet = true
            } label: {
                Label("标签", systemImage: "tag")
                    .labelStyle(.iconOnly)
            }
            .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            Button {
                // Set date to today (fast action)
                patient.surgeryDate = Date()
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
            } label: {
                Label("放在今天", systemImage: "calendar.badge.clock")
                    .labelStyle(.iconOnly)
            }
            .tint(.green)
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationStack {
                Form {
                    Section {
                        DatePicker("手术日期", selection: $tempSurgeryDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .environment(\.calendar, Calendar.autoupdatingCurrent)
                            .environment(\.locale, Locale.autoupdatingCurrent)
                    }
                    
                    if patient.surgeryDate != nil {
                        Section {
                            Button(role: .destructive) {
                                patient.surgeryDate = nil
                                showingDatePicker = false
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("清除手术日期")
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .navigationTitle("设置手术日")
                .navigationBarItems(trailing: Button("完成") {
                    patient.surgeryDate = tempSurgeryDate
                    showingDatePicker = false
                })
                .onAppear {
                    // Initialize the temporary date specifically when the sheet is opened
                    tempSurgeryDate = patient.surgeryDate ?? Date()
                }
            }
            .presentationDetents(patient.surgeryDate != nil ? [.fraction(0.75), .large] : [.fraction(0.6)])
        }
        .sheet(isPresented: $showingTagSheet) {
            TagSheetView(patient: patient, existingAllTags: existingTags())
        }
    }
}

struct GhostPatientRow: View {
    var onCommit: (String, [String]) -> Void
    @State private var input: String = ""
    @State private var tags: [String] = []
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .foregroundColor(.gray)
                .font(.body)
            TagTokenField(
                text: $input,
                tags: $tags,
                allTags: existingTags(),
                placeholder: "新病人(例如：张三 #高危)...",
                autoFocusIfEmpty: false,
                onSubmit: {
                    submit()
                }
            )
        }
    }
    
    private func submit() {
        extractAndStripTags(text: &input, tags: &tags)
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty || !tags.isEmpty {
            onCommit(trimmed, tags)
            input = ""
            tags = []
        }
    }
}

struct TagSheetView: View {
    @Bindable var patient: Patient
    @Environment(\.dismiss) var dismiss
    var existingAllTags: [String]
    @State private var newTag: String = ""
    
    var existingTags: [String] {
        existingAllTags
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("已选标签")) {
                    if patient.tags.isEmpty {
                        Text("无").foregroundColor(.secondary)
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(patient.tags, id: \.self) { tag in
                                Button(action: {
                                    if let idx = patient.tags.firstIndex(of: tag) {
                                        patient.tags.remove(at: idx)
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text(tag)
                                        Image(systemName: "xmark")
                                            .font(.caption2)
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.tagColor(for: tag).opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("添加新标签或选择已有标签")) {
                    HStack {
                        TextField("新标签名称", text: $newTag)
                            .onSubmit {
                                addTag(newTag)
                            }
                        Button(action: { addTag(newTag) }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(newTag.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .orange)
                        }
                        .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    let availableTags = existingTags.filter { !patient.tags.contains($0) }
                    if !availableTags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(availableTags, id: \.self) { tag in
                                Button(action: {
                                    addTag(tag)
                                }) {
                                    HStack(spacing: 4) {
                                        Text(tag)
                                        Image(systemName: "plus")
                                            .font(.caption2)
                                    }
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.tagColor(for: tag).opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("标签管理")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完成") { dismiss() })
        }
        .presentationDetents([.medium, .large])
    }
    
    private func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !patient.tags.contains(trimmed) {
            // Register in TagColorStore so it appears system-wide
            if TagColorStore.shared.colorIndices[trimmed] == nil {
                TagColorStore.shared.colorIndices[trimmed] = TagColorStore.hashIndex(for: trimmed)
            }
            patient.tags.append(trimmed)
            newTag = ""
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.locale = Locale(identifier: "zh_CN")
    return formatter
}()

extension Color {
    /// Returns the color for a tag name. Uses any user override stored in TagColorStore,
    /// falls back to hash-based selection from the preset palette.
    static func tagColor(for name: String) -> Color {
        let idx = TagColorStore.shared.colorIndexFor(name)
        return TagColorStore.color(at: idx)
    }
}

/// Single source of truth for all tags: reads from TagColorStore.
/// Any tag added to a patient is also registered there, so this covers everything.
func existingTags() -> [String] {
    Array(TagColorStore.shared.colorIndices.keys).sorted()
}

// MARK: - TagTokenField

/// A token-style input that renders confirmed #tags as inline capsules.
struct TagTokenField: View {
    @Binding var text: String
    @Binding var tags: [String]
    var allTags: [String]
    var placeholder: String
    var autoFocusIfEmpty: Bool = false
    var onSubmit: (() -> Void)? = nil

    @State private var isFocused: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Text input row — always on top
            BackspaceDetectingTextField(
                text: $text,
                placeholder: placeholder,
                isFocused: $isFocused,
                autoFocusIfEmpty: autoFocusIfEmpty,
                onBackspaceWhenEmpty: {
                    if !tags.isEmpty {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        tags.removeLast()
                    }
                },
                onTagExtracted: { tag in
                    // Register in TagColorStore if new — this is how patient-side tags
                    // become "system tags" visible in the tag manager.
                    if TagColorStore.shared.colorIndices[tag] == nil {
                        TagColorStore.shared.colorIndices[tag] = TagColorStore.hashIndex(for: tag)
                    }
                    if !tags.contains(tag) {
                        tags.append(tag)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                },
                onSubmit: {
                    // Strip any remaining dangling #tags on submit
                    extractAndStripTags(text: &text, tags: &tags)
                    onSubmit?()
                }
            )
            .frame(maxWidth: .infinity, minHeight: 22)

            // Confirmed tag capsules - appear below the text in order
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: isFocused ? 3 : 0) {
                            Text(tag)
                                .font(.caption)
                            // Only show ✕ in editing mode
                            if isFocused {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.tagColor(for: tag))
                        .cornerRadius(12)
                        .onTapGesture {
                            // Only allow deletion when in editing mode
                            guard isFocused else { return }
                            tags.removeAll { $0 == tag }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            // End editing so the cursor stops blinking
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                            to: nil, from: nil, for: nil)
                        }
                    }
                }
            }

            // Autocomplete suggestion bar — appears when #typing
            if isFocused, let query = activeTagQuery(for: text) {
                let suggestions = allTags
                    .filter { !tags.contains($0) }
                    .filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) }
                if !suggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(suggestions, id: \.self) { sug in
                                Button {
                                    // Directly apply the suggestion: strip #partial query, add tag
                                    let tagRegex = try! NSRegularExpression(pattern: "#([^\\s#]*)$")
                                    if let match = tagRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                                       let fullRange = Range(match.range, in: text) {
                                        text.replaceSubrange(fullRange, with: "")
                                    }
                                    if !tags.contains(sug) {
                                        tags.append(sug)
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                } label: {
                                    Text(sug)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.tagColor(for: sug).opacity(0.15))
                                        .foregroundColor(Color.tagColor(for: sug))
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.tagColor(for: sug).opacity(0.5), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - BackspaceDetectingTextField

struct BackspaceDetectingTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @Binding var isFocused: Bool
    var autoFocusIfEmpty: Bool
    var onBackspaceWhenEmpty: () -> Void
    var onTagExtracted: (String) -> Void   // synchronous: called when #tag is committed by space
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> InnerTextField {
        let tf = InnerTextField()
        tf.delegate = context.coordinator
        tf.placeholder = placeholder
        tf.font = UIFont.preferredFont(forTextStyle: .body)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tf.returnKeyType = .done
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .words
        tf.onBackspaceWhenEmpty = onBackspaceWhenEmpty
        if autoFocusIfEmpty && text.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                tf.becomeFirstResponder()
            }
        }
        return tf
    }

    func updateUIView(_ uiView: InnerTextField, context: Context) {
        // Keep coordinator fresh so closures capture current bindings
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }
        uiView.placeholder = placeholder
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: BackspaceDetectingTextField
        // Pre-compiled regexes for performance
        private let endTagRegex = try! NSRegularExpression(pattern: "#([^\\s#]+)$")

        init(_ parent: BackspaceDetectingTextField) { self.parent = parent }

        // Synchronously intercept space key — this is where tag-to-capsule conversion happens
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                       replacementString string: String) -> Bool {
            guard string == " " else { return true }
            let currentText = textField.text ?? ""
            // Look for a completed #tag at the END of the current text
            guard let match = endTagRegex.firstMatch(in: currentText,
                    range: NSRange(currentText.startIndex..., in: currentText)),
                  let tagRange = Range(match.range(at: 1), in: currentText),
                  let fullRange = Range(match.range, in: currentText)
            else { return true }  // no tag at end — allow the space normally

            let tag = String(currentText[tagRange])
            // Strip just the #tag from the end; keep everything before it intact
            var stripped = currentText
            stripped.replaceSubrange(fullRange, with: "")
            // (Intentionally NOT trimming — preserve separator spaces the user typed)

            // Update the UITextField text directly (synchronous, no SwiftUI round-trip)
            textField.text = stripped
            let endPos = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: endPos, to: endPos)

            // Notify SwiftUI bindings
            parent.text = stripped
            parent.onTagExtracted(tag)
            return false  // swallow the space — we handled it
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            let newText = textField.text ?? ""
            if newText != parent.text {
                parent.text = newText
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFocused = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFocused = false
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            textField.resignFirstResponder()
            return false
        }
    }
}

// UITextField subclass that intercepts deleteBackward on empty
class InnerTextField: UITextField {
    var onBackspaceWhenEmpty: (() -> Void)?

    override func deleteBackward() {
        if (text ?? "").isEmpty {
            onBackspaceWhenEmpty?()
        }
        super.deleteBackward()
    }
}

func activeTagQuery(for text: String) -> String? {
    let regex = try! NSRegularExpression(pattern: "#([^\\s#]*)$")
    if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
        if let tagRange = Range(match.range(at: 1), in: text) {
            return String(text[tagRange])
        }
    }
    return nil
}

func completeTag(_ tag: String, in text: inout String) {
    let regex = try! NSRegularExpression(pattern: "#([^\\s#]*)$")
    if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
        if let fullRange = Range(match.range, in: text) {
            text.replaceSubrange(fullRange, with: "#\(tag) ")
        }
    }
}

// MARK: - Native Search Bar
struct NativeSearchBar: View {
    @Binding var text: String
    var placeholder: String = "搜索..."
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField(placeholder, text: $text)
                .submitLabel(.search)
                .autocorrectionDisabled()
            
            if !text.isEmpty {
                Button(action: {
                    withAnimation {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGray6))
        .clipShape(Capsule())
    }
}

func extractAndStripTags(text: inout String, tags: inout [String]) {
    // Only match the #tag token itself — do NOT consume surrounding spaces
    let tagRegex = try! NSRegularExpression(pattern: "#([^\\s#]+)")
    let spaceRegex = try! NSRegularExpression(pattern: "\\s{2,}")

    let matches = tagRegex.matches(in: text, range: NSRange(text.startIndex..., in: text))
    var newTags: [String] = []
    for match in matches {
        if let tagRange = Range(match.range(at: 1), in: text) {
            let tag = String(text[tagRange])
            if !tags.contains(tag) && !newTags.contains(tag) {
                newTags.append(tag)
            }
        }
    }

    if !newTags.isEmpty {
        tags.append(contentsOf: newTags)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    if !matches.isEmpty {
        // Strip just the #tag tokens, leaving surrounding spaces intact
        var stripped = tagRegex.stringByReplacingMatches(
            in: text, options: [], range: NSRange(text.startIndex..., in: text), withTemplate: ""
        )
        // Collapse any double-spaces produced by the removal into single spaces
        stripped = spaceRegex.stringByReplacingMatches(
            in: stripped, options: [], range: NSRange(stripped.startIndex..., in: stripped), withTemplate: " "
        )
        text = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            let point = result.frames[index].origin
            subview.place(at: CGPoint(x: point.x + bounds.minX, y: point.y + bounds.minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxX: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if currentX + size.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                maxX = max(maxX, currentX)
            }
            self.size = CGSize(width: maxWidth == 0 ? maxX : maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Smart Date Formatting Helpers

/// 术前分组标题：计划今天手术 / 计划明天手术 / 计划 M月d日 (周x) 手术 / 手术日期待定
func formatPreOpDate(_ date: Date?) -> String {
    guard let d = date else { return "手术日期待定" }
    let calendar = Calendar.current
    if calendar.isDateInToday(d)    { return "计划今天手术" }
    if calendar.isDateInTomorrow(d) { return "计划明天手术" }
    let isCurrentYear = calendar.isDate(d, equalTo: Date(), toGranularity: .year)
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = isCurrentYear ? "M月d日 (E)" : "yyyy年M月d日 (E)"
    return "计划 \(f.string(from: d)) 手术"
}

/// 术后分组标题：今天手术 / 昨天手术 / M月d日 (周x) 手术
func formatPostOpDate(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date)     { return "今天手术" }
    if calendar.isDateInYesterday(date) { return "昨天手术" }
    let isCurrentYear = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
    let f = DateFormatter()
    f.locale = Locale(identifier: "zh_CN")
    f.dateFormat = isCurrentYear ? "M月d日 (E)" : "yyyy年M月d日 (E)"
    return "\(f.string(from: date)) 手术"
}
