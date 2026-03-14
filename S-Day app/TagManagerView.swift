import SwiftUI
import SwiftData

// MARK: - TagManagerView

struct TagManagerView: View {
    @Query private var patients: [Patient]
    @ObservedObject private var colorStore = TagColorStore.shared

    // Which tag's color picker is open
    @State private var colorPickerTag: String? = nil

    var allTags: [String] {
        // Union of tags on patients + tags created in the manager (stored in colorStore)
        let fromPatients = Set(patients.flatMap { $0.tags })
        let fromColorStore = Set(colorStore.colorIndices.keys)
        return Array(fromPatients.union(fromColorStore)).sorted()
    }

    var builtinTags: [String] { TagColorStore.builtinTags }

    var userTags: [String] {
        allTags.filter { !colorStore.isBuiltin($0) }
    }

    var body: some View {
        List {
            // ── Built-in (system) tags ──
            Section(header: Text("系统标签")) {
                ForEach(builtinTags, id: \.self) { tag in
                    BuiltinTagRow(
                        tag: tag,
                        patientCount: patients.filter { $0.tags.contains(tag) }.count,
                        onColorDotTap: { colorPickerTag = tag }
                    )
                }
            }

            // ── User-created tags ──
            Section(header: Text("自定义标签")) {
                // Ghost row for creating new tags
                TagGhostRow(existingTags: allTags) { newName in
                    colorStore.colorIndices[newName] = TagColorStore.hashIndex(for: newName)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                ForEach(userTags, id: \.self) { tag in
                    TagManagerRow(
                        tag: tag,
                        patientCount: patients.filter { $0.tags.contains(tag) }.count,
                        onColorDotTap: { colorPickerTag = tag },
                        onRename: { old, new in renameTag(from: old, to: new) },
                        onDelete: { deleteTag(tag) }
                    )
                }
            }
        }
        .navigationTitle("标签管理")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $colorPickerTag) { tag in
            TagColorPickerSheet(tagName: tag)
                .presentationDetents([.fraction(0.55)])
        }
    }

    private func deleteTag(_ tag: String) {
        for patient in patients where patient.tags.contains(tag) {
            patient.tags.removeAll { $0 == tag }
        }
        colorStore.removeTag(tag)   // safe: ignores builtins
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func renameTag(from oldName: String, to newName: String) {
        guard oldName != newName, !newName.isEmpty, !colorStore.isBuiltin(oldName) else { return }
        for patient in patients where patient.tags.contains(oldName) {
            if let idx = patient.tags.firstIndex(of: oldName) {
                patient.tags[idx] = newName
            }
        }
        if let colorIdx = colorStore.colorIndices[oldName] {
            colorStore.colorIndices[newName] = colorIdx
            colorStore.colorIndices.removeValue(forKey: oldName)
        }
        colorStore.renameTagUsage(from: oldName, to: newName)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

// MARK: - BuiltinTagRow

/// Display-only row for system built-in tags (color is editable, everything else is locked).
struct BuiltinTagRow: View {
    let tag: String
    let patientCount: Int
    var onColorDotTap: () -> Void
    @ObservedObject private var colorStore = TagColorStore.shared

    var body: some View {
        HStack(spacing: 12) {
            // Tappable color dot
            Button(action: onColorDotTap) {
                Circle()
                    .fill(Color.tagColor(for: tag))
                    .frame(width: 22, height: 22)
                    .shadow(color: Color.tagColor(for: tag).opacity(0.4), radius: 3, x: 0, y: 1)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)

            Text(tag)
                .foregroundColor(.primary)

            // Lock icon indicating non-editable
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            Text("\(patientCount)人")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
            dimensions.width
        }
    }
}

// MARK: - TagGhostRow

/// An always-visible placeholder row that lets the user inline-create a new tag.
struct TagGhostRow: View {
    var existingTags: [String]
    var onCommit: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(text.isEmpty ? Color.gray.opacity(0.3) : Color.tagColor(for: text))
                .frame(width: 18, height: 18)
                .animation(.easeInOut(duration: 0.2), value: text)

            TextField("新建标签...", text: $text)
                .foregroundColor(isFocused || !text.isEmpty ? .primary : .secondary)
                .focused($isFocused)
                .onSubmit { commit() }
                .submitLabel(.done)
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
            dimensions.width
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !existingTags.contains(trimmed) else {
            text = ""  // clear even if duplicate
            return
        }
        onCommit(trimmed)
        text = ""
    }
}

// MARK: - TagManagerRow

struct TagManagerRow: View {
    let tag: String
    let patientCount: Int
    var onColorDotTap: () -> Void
    var onRename: (String, String) -> Void
    var onDelete: () -> Void

    @ObservedObject private var colorStore = TagColorStore.shared
    @State private var editText: String = ""
    @FocusState private var isEditing: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Tappable color dot → opens color picker
            Button(action: onColorDotTap) {
                Circle()
                    .fill(Color.tagColor(for: tag))
                    .frame(width: 22, height: 22)
                    .shadow(color: Color.tagColor(for: tag).opacity(0.4), radius: 3, x: 0, y: 1)
                    .overlay(
                        Image(systemName: "pencil")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .buttonStyle(.plain)

            // Inline editable tag name
            TextField(tag, text: $editText)
                .focused($isEditing)
                .foregroundColor(.primary)
                .onAppear { editText = tag }
                .onSubmit { save() }
                .onChange(of: isEditing) { editing in
                    if !editing { save() }
                }
                .submitLabel(.done)

            Spacer()

            Text("\(patientCount)人")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
            dimensions.width
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("删除", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
        }
    }

    private func save() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            editText = tag  // revert
        } else if trimmed != tag {
            onRename(tag, trimmed)
        }
    }
}

// MARK: - TagColorPickerSheet

struct TagColorPickerSheet: View {
    let tagName: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var colorStore = TagColorStore.shared

    let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("选择颜色")
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
            }
            .padding(.horizontal)
            .padding(.top, 20)

            // Live preview capsule
            Text(tagName)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.tagColor(for: tagName))
                .cornerRadius(12)
                .animation(.easeInOut(duration: 0.2), value: colorStore.colorIndices[tagName])

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<TagColorStore.presetHues.count, id: \.self) { idx in
                    let color = TagColorStore.color(at: idx)
                    let isSelected = colorStore.colorIndexFor(tagName) == idx
                    Button {
                        colorStore.setColorIndex(idx, for: tagName)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 42, height: 42)
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: isSelected ? 3 : 0))
                            .overlay(
                                Circle().strokeBorder(color, lineWidth: isSelected ? 5 : 0).padding(-4)
                            )
                            .scaleEffect(isSelected ? 1.12 : 1.0)
                            .animation(.spring(response: 0.25), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Button("重置为自动颜色") {
                colorStore.colorIndices.removeValue(forKey: tagName)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .font(.callout)
            .foregroundColor(.secondary)

            Spacer()
        }
    }
}

// Allow String as sheet item
extension String: @retroactive Identifiable {
    public var id: String { self }
}
