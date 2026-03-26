import SwiftUI
import SwiftData

struct TabHeaderContainer<Content: View>: View {
    let bottomPadding: CGFloat
    let onTap: (() -> Void)?
    @ViewBuilder var content: Content

    init(
        bottomPadding: CGFloat = 8,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.bottomPadding = bottomPadding
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal)
            .padding(.top, 0)
            .padding(.bottom, bottomPadding)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }
    }
}

struct PatientRow: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var colorStore = TagColorStore.shared
    @Bindable var patient: Patient
    private let rowVerticalPadding: CGFloat = 8
    private let selectionIndicatorSize: CGFloat = 20
    private let selectionIndicatorSpacing: CGFloat = 8
    
    // Optional Selection support
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var toggleSelection: (() -> Void)? = nil
    var onSwipeSelect: (() -> Void)? = nil
    var onShowDatePicker: (() -> Void)? = nil
    var onShowTagSheet: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 0) {
            TagTokenField(
                text: $patient.rawInput,
                tags: $patient.tags,
                allTags: existingTags(),
                placeholder: "输入新病人信息...",
                autoFocusIfEmpty: true
            )
            .padding(.leading, isSelectionMode ? selectionIndicatorSize + selectionIndicatorSpacing : 0)
            .disabled(isSelectionMode)
            
            Spacer()
        }
        .padding(.vertical, rowVerticalPadding)
        .overlay(alignment: .leading) {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: selectionIndicatorSize))
                    .frame(width: selectionIndicatorSize, height: selectionIndicatorSize)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                toggleSelection?()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isSelectionMode {
                Button(role: .destructive) {
                    modelContext.delete(patient)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Label("删除", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }

                Button {
                    onShowDatePicker?()
                } label: {
                    Label("设日期", systemImage: "calendar")
                        .labelStyle(.iconOnly)
                }
                .tint(.blue)

                Button {
                    onShowTagSheet?()
                } label: {
                    Label("标签", systemImage: "tag")
                        .labelStyle(.iconOnly)
                }
                .tint(.orange)
            }
        }
        // Row-level swipe gesture: right-swipe enters selection and pre-selects this row
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                    guard isHorizontal else { return }
                    if value.translation.width > 40 {
                        if !isSelectionMode, let onSwipeSelect = onSwipeSelect {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onSwipeSelect()
                        }
                    }
                }
        )
    }
}

struct GhostPatientRow: View {
    @ObservedObject private var colorStore = TagColorStore.shared
    var onCommit: (String, [String]) -> Void
    @State private var input: String = ""
    @State private var tags: [String] = []
    private let rowVerticalPadding: CGFloat = 8
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "plus")
                .foregroundColor(.gray)
                .font(.body)
            TagTokenField(
                text: $input,
                tags: $tags,
                allTags: existingTags(),
                placeholder: "新病人...",
                autoFocusIfEmpty: false,
                keepFocusOnSubmit: true,
                onSubmit: {
                    submit()
                }
            )
        }
        .padding(.vertical, rowVerticalPadding)
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
    @State private var draftTags: [String] = []
    @Namespace private var tagTransitionNamespace
    private let tagTransitionAnimation = Animation.snappy(duration: 0.26, extraBounce: 0)
    
    var existingTags: [String] {
        existingAllTags
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    tagEditorSection(title: "已选标签") {
                        ZStack(alignment: .leading) {
                            selectableTagChip("占位标签", systemImage: "xmark")
                                .hidden()
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            FlowLayout(spacing: 8) {
                                ForEach(draftTags, id: \.self) { tag in
                                    Button(action: {
                                        removeDraftTag(tag)
                                    }) {
                                        selectableTagChip(tag, systemImage: "xmark")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(tagTransitionAnimation, value: draftTags)

                            if draftTags.isEmpty {
                                Text("无")
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    tagEditorSection(title: "添加新标签或选择已有标签") {
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        let availableTags = existingTags.filter { !draftTags.contains($0) }
                        if !availableTags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(availableTags, id: \.self) { tag in
                                    Button(action: {
                                        addTag(tag)
                                    }) {
                                        selectableTagChip(tag, systemImage: "plus")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .animation(tagTransitionAnimation, value: availableTags)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("标签管理")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完成") {
                applyChanges()
            })
        }
        .onAppear {
            draftTags = patient.tags
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func tagEditorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
    
    @ViewBuilder
    private func selectableTagChip(_ tag: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
            Image(systemName: systemImage)
                .font(.caption2)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.tagColor(for: tag).opacity(0.8))
        .foregroundColor(Color.tagTextColor(for: tag))
        .cornerRadius(12)
        .zIndex(1)
        .matchedGeometryEffect(id: "tag-sheet-\(tag)", in: tagTransitionNamespace)
    }

    private func addTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !draftTags.contains(trimmed) {
            withAnimation(tagTransitionAnimation) {
                draftTags.append(trimmed)
            }
            newTag = ""
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func removeDraftTag(_ tag: String) {
        guard let idx = draftTags.firstIndex(of: tag) else { return }
        withAnimation(tagTransitionAnimation) {
            draftTags.remove(at: idx)
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func applyChanges() {
        registerTagsIfNeeded(draftTags)
        patient.tags = draftTags
        markTagsUsed(draftTags)
        dismiss()
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.locale = appDisplayLocale()
    return formatter
}()

extension Color {
    /// Returns the color for a tag name. Uses any user override stored in TagColorStore,
    /// falls back to hash-based selection from the preset palette.
    static func tagColor(for name: String) -> Color {
        let idx = TagColorStore.shared.colorIndexFor(name)
        return TagColorStore.color(at: idx)
    }

    static func tagTextColor(for name: String) -> Color {
        let idx = TagColorStore.shared.colorIndexFor(name)
        return TagColorStore.textColor(at: idx)
    }

    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red, green, blue, alpha: UInt64
        switch sanitized.count {
        case 8:
            (alpha, red, green, blue) = ((value >> 24) & 0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
        default:
            (alpha, red, green, blue) = (0xFF, (value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF)
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }
}

/// Single source of truth for all tags: reads from TagColorStore.
/// Any tag added to a patient is also registered there, so this covers everything.
func existingTags() -> [String] {
    orderedSelectableTags(Array(TagColorStore.shared.colorIndices.keys))
}

func registerTagsIfNeeded(_ tags: [String]) {
    for tag in tags {
        guard TagColorStore.shared.colorIndices[tag] == nil else { continue }
        TagColorStore.shared.colorIndices[tag] = TagColorStore.hashIndex(for: tag)
    }
}

func markTagsUsed(_ tags: [String]) {
    TagColorStore.shared.markTagsUsed(tags)
}

func orderedSelectableTags(_ tags: [String]) -> [String] {
    let store = TagColorStore.shared
    let builtinOrder = Dictionary(uniqueKeysWithValues: TagColorStore.builtinTags.enumerated().map { ($0.element, $0.offset) })

    return Array(Set(tags)).sorted { lhs, rhs in
        let lhsBuiltin = store.isBuiltin(lhs)
        let rhsBuiltin = store.isBuiltin(rhs)
        if lhsBuiltin != rhsBuiltin {
            return lhsBuiltin && !rhsBuiltin
        }
        if lhsBuiltin, rhsBuiltin {
            return (builtinOrder[lhs] ?? .max) < (builtinOrder[rhs] ?? .max)
        }

        let lhsRecent = store.recentUsageTimestamp(for: lhs) ?? 0
        let rhsRecent = store.recentUsageTimestamp(for: rhs) ?? 0
        if lhsRecent != rhsRecent {
            return lhsRecent > rhsRecent
        }

        return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
}

func orderedSuggestedTags(allTags: [String], excluding selectedTags: [String], query: String) -> [String] {
    let filteredTags = orderedSelectableTags(allTags).filter { !selectedTags.contains($0) }
    guard !query.isEmpty else { return filteredTags }

    let prefixMatches = filteredTags.filter {
        $0.range(of: query, options: [.caseInsensitive, .anchored]) != nil
    }
    let containsMatches = filteredTags.filter {
        $0.range(of: query, options: [.caseInsensitive, .anchored]) == nil &&
        $0.localizedCaseInsensitiveContains(query)
    }
    return prefixMatches + containsMatches
}

// MARK: - TagTokenField

/// A token-style input that renders confirmed #tags as inline capsules.
struct TagTokenField: View {
    @ObservedObject private var colorStore = TagColorStore.shared
    @Binding var text: String
    @Binding var tags: [String]
    var allTags: [String]
    var placeholder: String
    var autoFocusIfEmpty: Bool = false
    var keepFocusOnSubmit: Bool = false
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
                keepFocusOnSubmit: keepFocusOnSubmit,
                onBackspaceWhenEmpty: {
                    if !tags.isEmpty {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        tags.removeLast()
                    }
                },
                onTagExtracted: { tag in
                    // Register in TagColorStore if new — this is how patient-side tags
                    // become "system tags" visible in the tag manager.
                    registerTagsIfNeeded([tag])
                    if !tags.contains(tag) {
                        tags.append(tag)
                        markTagsUsed([tag])
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                },
                onSubmit: {
                    // Strip any remaining dangling #tags on submit
                    extractAndStripTags(text: &text, tags: &tags)
                    onSubmit?()
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)

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
                        .foregroundColor(Color.tagTextColor(for: tag))
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
                let suggestions = orderedSuggestedTags(allTags: allTags, excluding: tags, query: query)
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
                                        markTagsUsed([sug])
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }
                                } label: {
                                    Text(sug)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.tagColor(for: sug).opacity(0.15))
                                        .foregroundColor(Color.tagColor(for: sug))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
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
    var keepFocusOnSubmit: Bool
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
            if string == "\n" {
                parent.onSubmit()
                guard !parent.keepFocusOnSubmit else {
                    DispatchQueue.main.async {
                        textField.becomeFirstResponder()
                        let endPos = textField.endOfDocument
                        textField.selectedTextRange = textField.textRange(from: endPos, to: endPos)
                    }
                    return false
                }
                textField.resignFirstResponder()
                return false
            }

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
            guard !parent.keepFocusOnSubmit else {
                DispatchQueue.main.async {
                    textField.becomeFirstResponder()
                    let endPos = textField.endOfDocument
                    textField.selectedTextRange = textField.textRange(from: endPos, to: endPos)
                }
                return false
            }
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
        registerTagsIfNeeded(newTags)
        tags.append(contentsOf: newTags)
        markTagsUsed(newTags)
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

func formatAbsoluteSurgeryDate(_ date: Date) -> String {
    let isCurrentYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = isCurrentYear ? "M月d日 (E)" : "yyyy年M月d日 (E)"
    return formatter.string(from: date)
}

/// 术前分组标题：计划今天手术 / 计划明天手术 / 计划 M月d日 (周x) 手术 / 手术日期待定
func formatPreOpDate(_ date: Date?) -> String {
    guard let d = date else { return "手术日期待定" }
    let calendar = Calendar.current
    if calendar.isDateInToday(d)    { return "计划今天手术" }
    if calendar.isDateInTomorrow(d) { return "计划明天手术" }
    return "计划 \(formatAbsoluteSurgeryDate(d)) 手术"
}

/// 术后分组标题：今天手术 / 昨天手术 / M月d日 (周x) 手术
func formatPostOpDate(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date)     { return "今天手术" }
    if calendar.isDateInYesterday(date) { return "昨天手术" }
    return "\(formatAbsoluteSurgeryDate(date)) 手术"
}

struct BatchTagSheetView: View {
    var patients: [Patient]
    var existingAllTags: [String]
    var onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    @State private var newTag: String = ""
    @State private var pendingTags: [String] = []
    @Namespace private var tagTransitionNamespace
    private let tagTransitionAnimation = Animation.snappy(duration: 0.26, extraBounce: 0)
    
    var selectableTags: [String] {
        orderedSelectableTags(existingAllTags)
    }

    var availableTags: [String] {
        selectableTags.filter { !pendingTags.contains($0) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    batchTagEditorSection(title: "待添加标签") {
                        ZStack(alignment: .leading) {
                            batchTagChip("占位标签", systemImage: "xmark", isSelected: true)
                                .hidden()
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            FlowLayout(spacing: 8) {
                                ForEach(pendingTags, id: \.self) { tag in
                                    Button(action: {
                                        removePendingTag(tag)
                                    }) {
                                        batchTagChip(tag, systemImage: "xmark", isSelected: true)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(tagTransitionAnimation, value: pendingTags)

                            if pendingTags.isEmpty {
                                Text("无")
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    batchTagEditorSection(title: "添加标签到已选 (\(patients.count)) 人") {
                        HStack {
                            TextField("新标签名称", text: $newTag)
                                .onSubmit {
                                    stageBatchTag(newTag)
                                }
                            Button(action: { stageBatchTag(newTag) }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(newTag.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .orange)
                            }
                            .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        if !availableTags.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(availableTags, id: \.self) { tag in
                                    Button(action: {
                                        togglePendingTag(tag)
                                    }) {
                                        batchTagChip(tag, systemImage: "plus", isSelected: false)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .animation(tagTransitionAnimation, value: availableTags)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("批量打标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        applyPendingTags()
                    }
                    .disabled(pendingTags.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func batchTagEditorSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    private func batchTagChip(_ tag: String, systemImage: String, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            Text(tag)
            Image(systemName: systemImage)
                .font(.caption2)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.tagColor(for: tag).opacity(isSelected ? 1.0 : 0.8))
        .foregroundColor(Color.tagTextColor(for: tag))
        .cornerRadius(12)
        .zIndex(1)
        .matchedGeometryEffect(id: "batch-tag-sheet-\(tag)", in: tagTransitionNamespace)
    }
    
    private func stageBatchTag(_ tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !pendingTags.contains(trimmed) else {
            newTag = ""
            return
        }

        registerTagsIfNeeded([trimmed])
        withAnimation(tagTransitionAnimation) {
            pendingTags.append(trimmed)
        }
        newTag = ""
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func togglePendingTag(_ tag: String) {
        if pendingTags.contains(tag) {
            removePendingTag(tag)
        } else {
            stageBatchTag(tag)
        }
    }

    private func removePendingTag(_ tag: String) {
        guard let idx = pendingTags.firstIndex(of: tag) else { return }
        withAnimation(tagTransitionAnimation) {
            pendingTags.remove(at: idx)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func applyPendingTags() {
        guard !pendingTags.isEmpty else { return }

        for tag in pendingTags {
            registerTagsIfNeeded([tag])
        }

        for patient in patients {
            for tag in pendingTags where !patient.tags.contains(tag) {
                patient.tags.append(tag)
            }
        }

        markTagsUsed(pendingTags)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onComplete()
        dismiss()
    }
}
