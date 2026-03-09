import SwiftUI
import Combine

/// Global singleton that stores per-tag color index overrides in UserDefaults.
/// Falls back to the deterministic hash-based color when no override is set.
final class TagColorStore: ObservableObject {
    static let shared = TagColorStore()

    /// Built-in system tags: always present, non-deletable, non-renameable.
    static let builtinTags: [String] = ["需追踪", "收藏"]
    /// Default color indices for built-in tags (orange for 追踪, purple for 收藏)
    private static let builtinDefaults: [String: Int] = ["需追踪": 6, "收藏": 8]

    private let defaultsKey = "tagColorIndices"

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

    static let presetHues: [Double] = [
        0.00, // Red
        0.33, // Green
        0.66, // Blue
        0.16, // Yellow
        0.50, // Cyan
        0.83, // Magenta
        0.08, // Orange
        0.41, // Spring Green
        0.75, // Purple
        0.25, // Chartreuse
        0.58, // Azure
        0.91  // Rose
    ]

    static let presetLabels: [String] = [
        "红", "绿", "蓝", "黄", "青", "品红",
        "橙", "春绿", "紫", "黄绿", "蔚蓝", "玫红"
    ]

    private init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: data) {
            colorIndices = decoded
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

    /// Safe delete: does nothing for builtin tags.
    func removeTag(_ name: String) {
        guard !isBuiltin(name) else { return }
        colorIndices.removeValue(forKey: name)
    }

    static func hashIndex(for name: String) -> Int {
        var hash = 0
        for char in name.utf8 {
            hash = (hash &<< 5) &+ hash &+ Int(char)
        }
        return abs(hash) % presetHues.count
    }

    static func color(at index: Int) -> Color {
        Color(hue: presetHues[index % presetHues.count], saturation: 0.7, brightness: 0.85)
    }
}
