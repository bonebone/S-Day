import SwiftUI
import Combine

/// Global singleton that stores per-tag color index overrides in UserDefaults.
/// Falls back to the deterministic hash-based color when no override is set.
final class TagColorStore: ObservableObject {
    struct PresetColor: Identifiable {
        let level: Int
        let backgroundHex: String
        let textHex: String

        var id: Int { level }
    }

    struct PresetGroup: Identifiable {
        let name: String
        let colors: [PresetColor]

        var id: String { name }
    }

    static let shared = TagColorStore()

    /// Built-in system tags: always present, non-deletable, non-renameable.
    static let builtinTags: [String] = ["需追踪", "收藏"]
    /// Default color indices for built-in tags.
    private static let builtinDefaults: [String: Int] = ["需追踪": 18, "收藏": 38]

    private let defaultsKey = "tagColorIndices"
    private let recentUsageKey = "recentTagUsageTimestamps"

    @Published var colorIndices: [String: Int] = [:] {
        didSet {
            // Protect builtins: restore them if accidentally removed
            for (tag, defaultIdx) in Self.builtinDefaults {
                if colorIndices[tag] == nil {
                    colorIndices[tag] = defaultIdx
                }
            }
            if let data = try? JSONEncoder().encode(colorIndices) {
                UserDefaults.standard.set(data, forKey: defaultsKey)
            }
        }
    }

    @Published private(set) var recentUsageTimestamps: [String: TimeInterval] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(recentUsageTimestamps) {
                UserDefaults.standard.set(data, forKey: recentUsageKey)
            }
        }
    }

    static let presetGroups: [PresetGroup] = [
        PresetGroup(name: "粉红系", colors: [
            PresetColor(level: 1, backgroundHex: "#FBE3E8", textHex: "#E25778"),
            PresetColor(level: 2, backgroundHex: "#F8CCD9", textHex: "#E25778"),
            PresetColor(level: 3, backgroundHex: "#F4B3C5", textHex: "#FFFFFF"),
            PresetColor(level: 4, backgroundHex: "#EF8BA6", textHex: "#FFFFFF"),
            PresetColor(level: 5, backgroundHex: "#E25778", textHex: "#FFFFFF")
        ]),
        PresetGroup(name: "藕紫系", colors: [
            PresetColor(level: 1, backgroundHex: "#EFE5ED", textHex: "#894E7B"),
            PresetColor(level: 2, backgroundHex: "#E9D5E3", textHex: "#894E7B"),
            PresetColor(level: 3, backgroundHex: "#D4B4CD", textHex: "#FFFFFF"),
            PresetColor(level: 4, backgroundHex: "#AA7BA0", textHex: "#FFFFFF"),
            PresetColor(level: 5, backgroundHex: "#894E7B", textHex: "#FFFFFF")
        ]),
        PresetGroup(name: "暖橙系", colors: [
            PresetColor(level: 1, backgroundHex: "#FBDAC6", textHex: "#E27260"),
            PresetColor(level: 2, backgroundHex: "#F8C4B2", textHex: "#E27260"),
            PresetColor(level: 3, backgroundHex: "#F4AA8D", textHex: "#FFFFFF"),
            PresetColor(level: 4, backgroundHex: "#F19071", textHex: "#FFFFFF"),
            PresetColor(level: 5, backgroundHex: "#E27260", textHex: "#FFFFFF")
        ]),
        PresetGroup(name: "灰棕系", colors: [
            PresetColor(level: 1, backgroundHex: "#EFE8E8", textHex: "#8E6D63"),
            PresetColor(level: 2, backgroundHex: "#D7CCC9", textHex: "#8E6D63"),
            PresetColor(level: 3, backgroundHex: "#BBAAA5", textHex: "#FFFFFF"),
            PresetColor(level: 4, backgroundHex: "#A1877E", textHex: "#FFFFFF"),
            PresetColor(level: 5, backgroundHex: "#8E6D63", textHex: "#FFFFFF")
        ]),
        PresetGroup(name: "湛蓝系", colors: [
            PresetColor(level: 1, backgroundHex: "#E2EEF7", textHex: "#3A86BD"),
            PresetColor(level: 2, backgroundHex: "#D1E7F5", textHex: "#3A86BD"),
            PresetColor(level: 3, backgroundHex: "#96C2E2", textHex: "#FFFFFF"),
            PresetColor(level: 4, backgroundHex: "#6FA3D0", textHex: "#FFFFFF"),
            PresetColor(level: 5, backgroundHex: "#3A86BD", textHex: "#FFFFFF")
        ]),
        PresetGroup(name: "青绿系", colors: [
            PresetColor(level: 1, backgroundHex: "#D5EBE3", textHex: "#008D75"),
            PresetColor(level: 2, backgroundHex: "#C4E4DA", textHex: "#008D75"),
            PresetColor(level: 3, backgroundHex: "#A3D6CA", textHex: "#FFFFFF"),
            PresetColor(level: 4, backgroundHex: "#6EC3B3", textHex: "#FFFFFF"),
            PresetColor(level: 5, backgroundHex: "#008D75", textHex: "#FFFFFF")
        ]),
        PresetGroup(name: "明黄系", colors: [
            PresetColor(level: 1, backgroundHex: "#F5DF7A", textHex: "#885C20"),
            PresetColor(level: 2, backgroundHex: "#F2BE38", textHex: "#885C20"),
            PresetColor(level: 3, backgroundHex: "#D29C2F", textHex: "#FFFFFF"),
            PresetColor(level: 4, backgroundHex: "#A97C26", textHex: "#FFFFFF"),
            PresetColor(level: 5, backgroundHex: "#885C20", textHex: "#FFFFFF")
        ]),
        PresetGroup(name: "蓝紫系", colors: [
            PresetColor(level: 1, backgroundHex: "#F8D6E5", textHex: "#626E98"),
            PresetColor(level: 2, backgroundHex: "#D6B9D0", textHex: "#626E98"),
            PresetColor(level: 3, backgroundHex: "#B29EBC", textHex: "#FFFFFF"),
            PresetColor(level: 4, backgroundHex: "#8C85A9", textHex: "#FFFFFF"),
            PresetColor(level: 5, backgroundHex: "#626E98", textHex: "#FFFFFF")
        ]),
        PresetGroup(name: "砖红系", colors: [
            PresetColor(level: 1, backgroundHex: "#F7B3AC", textHex: "#941B14"),
            PresetColor(level: 2, backgroundHex: "#F9877D", textHex: "#941B14"),
            PresetColor(level: 3, backgroundHex: "#F54D40", textHex: "#FFFFFF"),
            PresetColor(level: 4, backgroundHex: "#D0241C", textHex: "#FFFFFF"),
            PresetColor(level: 5, backgroundHex: "#941B14", textHex: "#FFFFFF")
        ])
    ]
    static let presetColors: [PresetColor] = presetGroups.flatMap(\.colors)

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            colorIndices = decoded
        }
        if let data = UserDefaults.standard.data(forKey: recentUsageKey),
           let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) {
            recentUsageTimestamps = decoded
        }
        // Always ensure builtins exist
        for (tag, defaultIdx) in Self.builtinDefaults {
            if colorIndices[tag] == nil {
                colorIndices[tag] = defaultIdx
            }
        }
    }

    func isBuiltin(_ name: String) -> Bool {
        Self.builtinTags.contains(name)
    }

    /// Returns the color index for a given tag name (override or hash-based fallback).
    func colorIndexFor(_ name: String) -> Int {
        if let idx = colorIndices[name] { return idx }
        return Self.hashIndex(for: name)
    }

    func setColorIndex(_ idx: Int, for name: String) {
        colorIndices[name] = idx
    }

    func markTagsUsed(_ tags: [String]) {
        let now = Date().timeIntervalSince1970
        for tag in tags {
            recentUsageTimestamps[tag] = now
        }
    }

    func recentUsageTimestamp(for name: String) -> TimeInterval? {
        recentUsageTimestamps[name]
    }

    /// Safe delete: does nothing for builtin tags.
    func removeTag(_ name: String) {
        guard !isBuiltin(name) else { return }
        colorIndices.removeValue(forKey: name)
        recentUsageTimestamps.removeValue(forKey: name)
    }

    func renameTagUsage(from oldName: String, to newName: String) {
        guard let timestamp = recentUsageTimestamps.removeValue(forKey: oldName) else { return }
        recentUsageTimestamps[newName] = timestamp
    }

    func exportSnapshot() -> TagColorSnapshot {
        TagColorSnapshot(
            colorIndices: colorIndices,
            recentUsageTimestamps: recentUsageTimestamps
        )
    }

    func restore(from snapshot: TagColorSnapshot) {
        colorIndices = snapshot.colorIndices
        recentUsageTimestamps = snapshot.recentUsageTimestamps
    }

    func resetToDefaults() {
        colorIndices = Self.builtinDefaults
        recentUsageTimestamps = [:]
    }

    /// Returns the color index to assign to the (n)th user-created tag (0-indexed).
    /// Sequence: level-5 of all 9 groups, then level-4, …, level-1.
    /// Slots occupied by builtin tags are skipped so they are never reused.
    static func assignmentColorIndex(forNthUserTag n: Int) -> Int {
        let numGroups = presetGroups.count            // 9
        let numLevels = presetGroups[0].colors.count  // 5
        let reserved  = Set(builtinDefaults.values)

        var sequence: [Int] = []
        for levelRound in 0..<numLevels {
            let level = numLevels - levelRound          // 5, 4, 3, 2, 1
            for groupIndex in 0..<numGroups {
                let colorIndex = groupIndex * numLevels + (level - 1)
                if !reserved.contains(colorIndex) {
                    sequence.append(colorIndex)
                }
            }
        }
        // Wrap around if the user creates more tags than available slots
        return sequence[n % sequence.count]
    }

    static func hashIndex(for name: String) -> Int {
        var hash = 0
        for char in name.utf8 {
            hash = (hash &<< 5) &+ hash &+ Int(char)
        }
        return abs(hash) % presetColors.count
    }

    static func color(at index: Int) -> Color {
        let preset = presetColors[index % presetColors.count]
        return Color(hex: preset.backgroundHex)
    }

    static func textColor(at index: Int) -> Color {
        let preset = presetColors[index % presetColors.count]
        return Color(hex: preset.textHex)
    }
}

struct TagColorSnapshot: Codable {
    var colorIndices: [String: Int]
    var recentUsageTimestamps: [String: TimeInterval]
}
