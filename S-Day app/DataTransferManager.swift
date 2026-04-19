import Foundation
import SwiftData
import UniformTypeIdentifiers
import SwiftUI

/// Structured data for exporting and importing
struct SDayExportData: Codable {
    struct ExportedPatient: Codable {
        var id: UUID
        var rawInput: String
        var parsedName: String?
        var surgeryDate: Date?
        var tags: [String]
        var createdAt: Date
        var order: Int
        var trashedAt: Date?
    }
    
    var patients: [ExportedPatient]
    var tagColors: [String: Int]
    var appAppearance: AppAppearance?
    var patientTagDisplayMode: PatientTagDisplayMode?
    var requireBiometrics: Bool?
}

/// A custom document type to support .fileExporter
struct SDayExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var data: SDayExportData
    
    init(data: SDayExportData) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let fileData = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = try JSONDecoder().decode(SDayExportData.self, from: fileData)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let fileData = try encoder.encode(data)
        return .init(regularFileWithContents: fileData)
    }
}

class DataTransferManager {
    static func createExportData(from patients: [Patient]) -> SDayExportData {
        let exportedPatients = patients.map { p in
            SDayExportData.ExportedPatient(
                id: p.id,
                rawInput: p.rawInput,
                parsedName: p.parsedName,
                surgeryDate: p.surgeryDate,
                tags: p.tags,
                createdAt: p.createdAt,
                order: p.order,
                trashedAt: p.trashedAt
            )
        }
        
        let rawAppearance = UserDefaults.standard.string(forKey: "appAppearance") ?? AppAppearance.system.rawValue
        let currentAppearance = AppAppearance(rawValue: rawAppearance) ?? .system
        let rawPatientTagDisplayMode = UserDefaults.standard.string(forKey: "patientTagDisplayMode") ?? PatientTagDisplayMode.followText.rawValue
        let currentPatientTagDisplayMode = PatientTagDisplayMode(rawValue: rawPatientTagDisplayMode) ?? .followText
        
        // Use UserDefaults to retrieve toggle state
        let currentRequireBiometrics = UserDefaults.standard.bool(forKey: "requireBiometrics")
        
        return SDayExportData(
            patients: exportedPatients,
            tagColors: TagColorStore.shared.colorIndices,
            appAppearance: currentAppearance,
            patientTagDisplayMode: currentPatientTagDisplayMode,
            requireBiometrics: currentRequireBiometrics
        )
    }
    
    @MainActor
    static func importData(_ exportData: SDayExportData, into context: ModelContext) {
        // 1. Clear existing patients
        if let existing = try? context.fetch(FetchDescriptor<Patient>()) {
            for p in existing {
                context.delete(p)
            }
        }
        
        // 2. Clear and set tags + app state settings
        TagColorStore.shared.colorIndices = exportData.tagColors
        if let importedAppearance = exportData.appAppearance {
            UserDefaults.standard.set(importedAppearance.rawValue, forKey: "appAppearance")
        }
        if let importedPatientTagDisplayMode = exportData.patientTagDisplayMode {
            UserDefaults.standard.set(importedPatientTagDisplayMode.rawValue, forKey: "patientTagDisplayMode")
        } else {
            UserDefaults.standard.set(PatientTagDisplayMode.followText.rawValue, forKey: "patientTagDisplayMode")
        }
        if let importedBiometrics = exportData.requireBiometrics {
            UserDefaults.standard.set(importedBiometrics, forKey: "requireBiometrics")
        } else {
            // Unset or disable if not present in legacy export
            UserDefaults.standard.set(false, forKey: "requireBiometrics")
        }
        
        // 3. Create new patients
        for ep in exportData.patients {
            let p = Patient(
                rawInput: ep.rawInput,
                parsedName: ep.parsedName,
                surgeryDate: ep.surgeryDate,
                tags: ep.tags,
                order: ep.order,
                trashedAt: ep.trashedAt
            )
            p.id = ep.id
            p.createdAt = ep.createdAt
            context.insert(p)
        }
    }
}
