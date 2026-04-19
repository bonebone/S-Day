import Foundation
import SwiftData
import SwiftUI

@Model
final class Patient {
    var id: UUID
    var rawInput: String
    var parsedName: String?
    var surgeryDate: Date?
    var tags: [String]
    var createdAt: Date
    var order: Int
    var trashedAt: Date?
    
    init(rawInput: String, parsedName: String? = nil, surgeryDate: Date? = nil, tags: [String] = [], order: Int = 0, trashedAt: Date? = nil) {
        self.id = UUID()
        self.rawInput = rawInput
        self.parsedName = parsedName
        self.surgeryDate = surgeryDate
        self.tags = tags
        self.createdAt = Date()
        self.order = order
        self.trashedAt = trashedAt
    }
    
    // Computed property to determine if the patient is Post-op
    // A patient is post-op if the surgery date is in the past (before today's start)
    @Transient
    var isPostOp: Bool {
        guard let surgeryDate = surgeryDate else { return false }
        
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let surgeryDateStart = calendar.startOfDay(for: surgeryDate)
        
        return surgeryDateStart < todayStart
    }

    @Transient
    var isTrashed: Bool {
        trashedAt != nil
    }
}

func normalizedSurgeryDay(_ date: Date?) -> Date? {
    guard let date else { return nil }
    return Calendar.current.startOfDay(for: date)
}

func movePatientsToEndOfSurgeryGroup(_ movingPatients: [Patient], surgeryDate: Date?, allPatients: [Patient]) {
    let targetDay = normalizedSurgeryDay(surgeryDate)
    let movingIDs = Set(movingPatients.map(\.id))
    let changingPatients = movingPatients
        .filter { normalizedSurgeryDay($0.surgeryDate) != targetDay }
        .sorted { $0.order < $1.order }

    guard !changingPatients.isEmpty else { return }

    let maxOrderInTargetGroup = allPatients
        .filter { !movingIDs.contains($0.id) && normalizedSurgeryDay($0.surgeryDate) == targetDay }
        .map(\.order)
        .max() ?? -1

    for (offset, patient) in changingPatients.enumerated() {
        patient.surgeryDate = surgeryDate
        patient.order = maxOrderInTargetGroup + offset + 1
    }
}

func activePatients(from patients: [Patient]) -> [Patient] {
    patients.filter { !$0.isTrashed }
}

func trashedPatients(from patients: [Patient]) -> [Patient] {
    patients.filter(\.isTrashed)
}

@MainActor
func movePatientsToTrash(_ patients: [Patient], at date: Date = Date()) {
    for patient in patients {
        patient.trashedAt = date
    }
}

@MainActor
func restorePatientsFromTrash(_ patients: [Patient]) {
    for patient in patients {
        patient.trashedAt = nil
    }
}

@MainActor
func permanentlyDeletePatients(_ patients: [Patient], in context: ModelContext) {
    for patient in patients {
        context.delete(patient)
    }
}

@MainActor
@discardableResult
func purgeExpiredTrash(in context: ModelContext, now: Date = Date(), retentionDays: Int = 30) -> Int {
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) ?? now
    let descriptor = FetchDescriptor<Patient>()

    guard let allPatients = try? context.fetch(descriptor) else {
        return 0
    }

    let expiredPatients = allPatients.filter { patient in
        guard let trashedAt = patient.trashedAt else { return false }
        return trashedAt <= cutoffDate
    }

    guard !expiredPatients.isEmpty else { return 0 }

    permanentlyDeletePatients(expiredPatients, in: context)
    return expiredPatients.count
}

enum ExportDateTitleStyle {
    case preOp
    case postOp
}

func exportText(for patients: [Patient], sortDatesDescending: Bool, titleStyle: ExportDateTitleStyle) -> String {
    let groupedPatients = Dictionary(grouping: patients) { patient in
        normalizedSurgeryDay(patient.surgeryDate)
    }

    let sortedDates = groupedPatients.keys.sorted { lhs, rhs in
        switch (lhs, rhs) {
        case (nil, nil):
            return false
        case (nil, _):
            return true
        case (_, nil):
            return false
        case let (left?, right?):
            return sortDatesDescending ? left > right : left < right
        }
    }

    return sortedDates.map { date in
        let title = exportSectionTitle(for: date, style: titleStyle)
        let entries = (groupedPatients[date] ?? [])
            .sorted { $0.order < $1.order }
            .map { patient in
                let tagsText = patient.tags.map { "#\($0)" }.joined(separator: " ")
                return tagsText.isEmpty ? "- \(patient.rawInput)" : "- \(patient.rawInput) \(tagsText)"
            }
            .joined(separator: "\n")
        return "\(title)\n\(entries)"
    }
    .joined(separator: "\n\n")
}

private func exportSectionTitle(for date: Date?, style: ExportDateTitleStyle) -> String {
    switch style {
    case .preOp:
        return exportPreOpDateTitle(date)
    case .postOp:
        return exportPostOpDateTitle(date)
    }
}

private func exportPreOpDateTitle(_ date: Date?) -> String {
    guard let date else { return "手术日期待定" }
    return "计划 \(formatAbsoluteSurgeryDate(date)) 手术"
}

private func exportPostOpDateTitle(_ date: Date?) -> String {
    guard let date else { return "手术日期待定" }
    return "\(formatAbsoluteSurgeryDate(date)) 手术"
}
