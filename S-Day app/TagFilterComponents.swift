import SwiftUI

struct TagFilterBar: View {
    let tags: [String]
    let selectedTag: String?
    let onSelect: (String?) -> Void
    let onMore: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TagFilterChip(
                        title: "全部",
                        tag: nil,
                        isSelected: selectedTag == nil
                    ) {
                        onSelect(nil)
                    }

                    ForEach(tags, id: \.self) { tag in
                        TagFilterChip(
                            title: tag,
                            tag: tag,
                            isSelected: selectedTag == tag
                        ) {
                            onSelect(tag)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Button(action: onMore) {
                HStack(spacing: 6) {
                    Text("更多")
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption)
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(.separator).opacity(0.6), lineWidth: 0.8)
                )
            }
            .buttonStyle(.plain)
        }
    }
}

struct TagFilterChip: View {
    let title: String
    let tag: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(backgroundColor)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(borderColor, lineWidth: isSelected ? 0 : 0.8)
                )
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if let tag, isSelected {
            return Color.tagColor(for: tag)
        }
        if isSelected {
            return Color(.tertiarySystemFill)
        }
        return Color(.secondarySystemBackground)
    }

    private var foregroundColor: Color {
        if let tag, isSelected {
            return Color.tagTextColor(for: tag)
        }
        return isSelected ? .primary : .secondary
    }

    private var borderColor: Color {
        if let tag, !isSelected {
            return Color.tagColor(for: tag).opacity(0.24)
        }
        return Color(.separator).opacity(0.6)
    }
}

struct TagFilterSheet: View {
    let scopeTitle: String
    let allCount: Int
    let tags: [String]
    let counts: [String: Int]
    let selectedTag: String?
    let isPinned: (String) -> Bool
    let onSelect: (String?) -> Void
    let onTogglePinned: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        TagFilterAllRow(
                            count: allCount,
                            isSelected: selectedTag == nil
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(tags, id: \.self) { tag in
                        TagFilterRow(
                            tag: tag,
                            count: counts[tag, default: 0],
                            isSelected: selectedTag == tag,
                            isPinned: isPinned(tag),
                            onSelect: {
                                onSelect(tag)
                                dismiss()
                            },
                            onTogglePinned: {
                                onTogglePinned(tag)
                            }
                        )
                    }
                }
            }
            .navigationTitle("\(scopeTitle)标签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TagFilterAllRow: View {
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("全部")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Image(systemName: "checkmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .opacity(isSelected ? 1 : 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct TagFilterRow: View {
    let tag: String
    let count: Int
    let isSelected: Bool
    let isPinned: Bool
    let onSelect: () -> Void
    let onTogglePinned: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.tagColor(for: tag))
                        .frame(width: 10, height: 10)

                    Text(tag)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.tagColor(for: tag))
                        .opacity(isSelected ? 1 : 0)
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onTogglePinned) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isPinned ? Color.tagColor(for: tag) : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPinned ? "取消固定 \(tag)" : "固定 \(tag)")
        }
    }
}
