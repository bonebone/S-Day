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
    
    init(rawInput: String, parsedName: String? = nil, surgeryDate: Date? = nil, tags: [String] = [], order: Int = 0) {
        self.id = UUID()
        self.rawInput = rawInput
        self.parsedName = parsedName
        self.surgeryDate = surgeryDate
        self.tags = tags
        self.createdAt = Date()
        self.order = order
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
}
