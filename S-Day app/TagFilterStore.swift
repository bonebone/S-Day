import Combine
import Foundation
import SwiftUI

enum TagFilterScope: String, CaseIterable {
    case preOp
    case postOp
}

struct TagFilterSnapshot {
    let availableTags: [String]
    let counts: [String: Int]
    let totalPatientCount: Int
    let barTags: [String]
    let sheetTags: [String]
}

final class TagFilterStore: ObservableObject {
    static let shared = TagFilterStore()

    private let defaultsKey = "tagFilterPinnedTagsByScope"

    @Published private var pinnedTagsByScope: [String: [String]] = [:] {
        didSet {
            savePinnedTags()
        }
    }

    private init() {
        loadPinnedTags()
    }

    func pinnedTags(in scope: TagFilterScope) -> [String] {
        pinnedTagsByScope[scope.rawValue] ?? []
    }

    func isPinned(_ tag: String, in scope: TagFilterScope) -> Bool {
        pinnedTags(in: scope).contains(tag)
    }

    func togglePinned(_ tag: String, in scope: TagFilterScope) {
        var updated = pinnedTags(in: scope)
        if let index = updated.firstIndex(of: tag) {
            updated.remove(at: index)
        } else {
            updated.append(tag)
        }
        pinnedTagsByScope[scope.rawValue] = updated
    }

    func removeTag(_ tag: String) {
        var updated = pinnedTagsByScope
        for scope in TagFilterScope.allCases {
            let scopeKey = scope.rawValue
            updated[scopeKey] = (updated[scopeKey] ?? []).filter { $0 != tag }
        }
        pinnedTagsByScope = updated
    }

    func renameTag(from oldName: String, to newName: String) {
        guard oldName != newName else { return }

        var updated = pinnedTagsByScope
        for scope in TagFilterScope.allCases {
            let scopeKey = scope.rawValue
            var tags = updated[scopeKey] ?? []
            guard let index = tags.firstIndex(of: oldName) else { continue }

            if tags.contains(newName) {
                tags.removeAll { $0 == oldName }
            } else {
                tags[index] = newName
            }

            updated[scopeKey] = Array(NSOrderedSet(array: tags)) as? [String] ?? tags
        }

        pinnedTagsByScope = updated
    }

    func snapshot(
        for scope: TagFilterScope,
        patients: [Patient],
        selectedTag: String?
    ) -> TagFilterSnapshot {
        let scopedPatients = activePatients(from: patients).filter { patient in
            switch scope {
            case .preOp:
                return !patient.isPostOp
            case .postOp:
                return patient.isPostOp
            }
        }

        let counts = tagCounts(for: scopedPatients)
        let availableTags = counts.keys.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        let activeSelectedTag = selectedTag.flatMap { counts[$0] != nil ? $0 : nil }
        let pinnedTags = pinnedTags(in: scope).filter { counts[$0] != nil }

        let remainingTags = counts.keys.sorted { lhs, rhs in
            let lhsCount = counts[lhs, default: 0]
            let rhsCount = counts[rhs, default: 0]
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }
            return lhs.localizedStandardCompare(rhs) == .orderedAscending
        }

        let barTags = buildOrderedTags(
            selectedTag: activeSelectedTag,
            pinnedTags: pinnedTags,
            remainingTags: remainingTags
        )
        let sheetTags = buildOrderedTags(
            selectedTag: activeSelectedTag,
            pinnedTags: pinnedTags,
            remainingTags: remainingTags
        )

        return TagFilterSnapshot(
            availableTags: availableTags,
            counts: counts,
            totalPatientCount: scopedPatients.count,
            barTags: barTags,
            sheetTags: sheetTags
        )
    }

    private func buildOrderedTags(
        selectedTag: String?,
        pinnedTags: [String],
        remainingTags: [String]
    ) -> [String] {
        var ordered: [String] = []

        if let selectedTag {
            ordered.append(selectedTag)
        }

        for tag in pinnedTags where !ordered.contains(tag) {
            ordered.append(tag)
        }

        for tag in remainingTags where !ordered.contains(tag) {
            ordered.append(tag)
        }

        return ordered
    }

    private func tagCounts(for patients: [Patient]) -> [String: Int] {
        var counts: [String: Int] = [:]

        for patient in patients {
            for tag in Set(patient.tags) {
                counts[tag, default: 0] += 1
            }
        }

        return counts
    }

    private func loadPinnedTags() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            pinnedTagsByScope = [:]
            return
        }

        pinnedTagsByScope = decoded
    }

    private func savePinnedTags() {
        guard let data = try? JSONEncoder().encode(pinnedTagsByScope) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
