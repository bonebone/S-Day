import SwiftData
import SwiftUI

struct OverviewView: View {
    @EnvironmentObject private var navigationState: AppNavigationState
    @Query private var allPatients: [Patient]
    @State private var searchText = ""
    @State private var expandedSectionID: String?

    private let trackingTag = "需追踪"

    private var preOpPatients: [Patient] {
        allPatients.filter { !$0.isPostOp }
    }

    private var postOpPatients: [Patient] {
        allPatients.filter(\.isPostOp)
    }

    private var unscheduledPatients: [Patient] {
        preOpPatients
            .filter { $0.surgeryDate == nil }
            .sorted { $0.order < $1.order }
    }

    private var recentPreOpGroups: [(date: Date, patients: [Patient])] {
        let grouped = Dictionary(grouping: preOpPatients.compactMap { patient -> (Date, Patient)? in
            guard let date = normalizedSurgeryDay(patient.surgeryDate) else { return nil }
            return (date, patient)
        }, by: \.0)

        return grouped.keys
            .sorted()
            .prefix(2)
            .map { date in
                let patients = (grouped[date] ?? []).map(\.1).sorted { $0.order < $1.order }
                return (date, patients)
            }
    }

    private var preOpTrackingPatients: [Patient] {
        preOpPatients
            .filter { $0.tags.contains(trackingTag) }
            .sorted { lhs, rhs in
                switch (lhs.surgeryDate, rhs.surgeryDate) {
                case let (l?, r?):
                    return l < r
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.order < rhs.order
                }
            }
    }

    private var postOpTrackingPatients: [Patient] {
        postOpPatients
            .filter { $0.tags.contains(trackingTag) }
            .sorted { ($0.surgeryDate ?? .distantPast) > ($1.surgeryDate ?? .distantPast) }
    }

    private var recentPatients: [Patient] {
        allPatients.sorted { $0.createdAt > $1.createdAt }
    }

    private var sections: [OverviewDataSection] {
        var result: [OverviewDataSection] = []

        if !unscheduledPatients.isEmpty {
            result.append(
                OverviewDataSection(
                    id: "unscheduled",
                    title: "未排期手术",
                    count: unscheduledPatients.count,
                    patients: unscheduledPatients
                )
            )
        }

        result.append(contentsOf: recentPreOpGroups.map { group in
            OverviewDataSection(
                id: "preop-\(group.date.timeIntervalSinceReferenceDate)",
                title: formatPreOpDate(group.date),
                count: group.patients.count,
                patients: group.patients
            )
        })

        if !preOpTrackingPatients.isEmpty {
            result.append(
                OverviewDataSection(
                    id: "preop-tracking",
                    title: "术前需追踪",
                    count: preOpTrackingPatients.count,
                    patients: preOpTrackingPatients
                )
            )
        }

        if !postOpTrackingPatients.isEmpty {
            result.append(
                OverviewDataSection(
                    id: "postop-tracking",
                    title: "术后需追踪",
                    count: postOpTrackingPatients.count,
                    patients: postOpTrackingPatients
                )
            )
        }

        if !recentPatients.isEmpty {
            result.append(
                OverviewDataSection(
                    id: "recent",
                    title: "最近新增",
                    count: nil,
                    patients: recentPatients
                )
            )
        }

        return result
    }

    private var searchResults: [Patient] {
        guard !searchText.isEmpty else { return [] }
        return allPatients.filter { patient in
            let matchesText = patient.rawInput.localizedCaseInsensitiveContains(searchText) ||
            (patient.parsedName?.localizedCaseInsensitiveContains(searchText) ?? false)
            let matchesTag = patient.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesText || matchesTag
        }
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    TabHeaderContainer(onTap: {
                        withAnimation {
                            proxy.scrollTo("topPosition", anchor: .top)
                        }
                    }) {
                        HStack(alignment: .center) {
                            Text("概览")
                                .font(.largeTitle)
                                .bold()
                                .layoutPriority(1)

                            Spacer(minLength: 16)

                            NativeSearchBar(text: $searchText, placeholder: "全局快速定位...")
                        }
                    }

                    if !searchText.isEmpty {
                        List {
                            Color.clear
                                .frame(height: 0)
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .id("topPosition")

                            searchContent
                        }
                        .listStyle(.plain)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                Color.clear
                                    .frame(height: 0)
                                    .id("topPosition")

                                if sections.isEmpty {
                                    Text("暂无可展示内容")
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 8)
                                } else {
                                    ForEach(sections) { section in
                                        OverviewExpandableSection(
                                    section: section,
                                    isExpanded: expandedSectionID == section.id,
                                    subtitleProvider: subtitle(for:in:),
                                    onToggle: {
                                        withAnimation(.snappy(duration: 0.28, extraBounce: 0)) {
                                            expandedSectionID = expandedSectionID == section.id ? nil : section.id
                                                }
                                            },
                                            onSelectPatient: open(patient:from:)
                                        )
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if searchResults.isEmpty {
            Text("未找到相关患者")
                .foregroundColor(.secondary)
                .italic()
        } else {
            ForEach(searchResults, id: \.id) { patient in
                Section(header: Text(patient.isPostOp ? "术后 · \(headerDateString(for: patient.surgeryDate))" : "术前 · \(headerDateString(for: patient.surgeryDate))")) {
                    Button {
                        open(patient: patient)
                    } label: {
                        OverviewSearchRow(patient: patient, subtitle: searchSubtitle(for: patient))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
        }
    }

    private func open(patient: Patient, from section: OverviewDataSection) {
        let query = patient.parsedName?.isEmpty == false ? patient.parsedName! : patient.rawInput

        switch section.id {
        case "unscheduled":
            navigationState.showPreOp(date: nil)
        case "preop-tracking", "recent":
            navigationState.showPreOp(searchText: query)
        case "postop-tracking":
            navigationState.showPostOp(searchText: query)
        default:
            if section.id.hasPrefix("preop-"), let date = patient.surgeryDate {
                navigationState.showPreOp(date: date)
            } else if patient.isPostOp {
                navigationState.showPostOp(searchText: query)
            } else if patient.surgeryDate == nil {
                navigationState.showPreOp(date: nil)
            } else {
                navigationState.showPreOp(searchText: query)
            }
        }
    }

    private func open(patient: Patient) {
        let query = patient.parsedName?.isEmpty == false ? patient.parsedName! : patient.rawInput
        if patient.isPostOp {
            navigationState.showPostOp(searchText: query)
        } else if patient.surgeryDate == nil {
            navigationState.showPreOp(date: nil)
        } else {
            navigationState.showPreOp(searchText: query)
        }
    }

    private func subtitle(for patient: Patient, in section: OverviewDataSection) -> String {
        if patient.tags.contains(trackingTag), section.id != "preop-tracking", section.id != "postop-tracking" {
            return "#\(trackingTag)"
        }
        if section.id == "recent" {
            if Calendar.current.isDateInToday(patient.createdAt) {
                return "今天新增"
            }
            if Calendar.current.isDateInYesterday(patient.createdAt) {
                return "昨天新增"
            }
            return ""
        }
        if section.id == "postop-tracking", let date = patient.surgeryDate {
            return formatPostOpDate(date)
        }
        if section.id == "preop-tracking" {
            if let date = patient.surgeryDate {
                return formatPreOpDate(date)
            }
            return "手术日期待定"
        }
        if section.id.hasPrefix("preop-") {
            return ""
        }
        return ""
    }

    private func searchSubtitle(for patient: Patient) -> String {
        if patient.isPostOp, let date = patient.surgeryDate {
            return formatPostOpDate(date)
        }
        if let date = patient.surgeryDate {
            return formatPreOpDate(date)
        }
        return "手术日期待定"
    }

    private func headerDateString(for date: Date?) -> String {
        guard let date else { return "无排期" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = appDisplayLocale()
        return formatter.string(from: date)
    }
}

private struct OverviewDataSection: Identifiable {
    let id: String
    let title: String
    let count: Int?
    let patients: [Patient]
}

private struct OverviewExpandableSection: View {
    let section: OverviewDataSection
    let isExpanded: Bool
    let subtitleProvider: (Patient, OverviewDataSection) -> String
    let onToggle: () -> Void
    let onSelectPatient: (Patient, OverviewDataSection) -> Void
    @State private var visibleCount: Int = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Text(section.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    if let count = section.count {
                        Text("\(count)")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 12, alignment: .center)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(visiblePatients, id: \.id) { patient in
                        Button {
                            onSelectPatient(patient, section)
                        } label: {
                            OverviewTextLine(
                                title: patientDisplayName(patient),
                                subtitle: subtitleProvider(patient, section)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if visibleCount < section.patients.count {
                        Button {
                            withAnimation(.snappy(duration: 0.24, extraBounce: 0)) {
                                visibleCount = min(visibleCount + 5, section.patients.count)
                            }
                        } label: {
                            Text("显示更多")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 6)
                .padding(.top, 2)
            }
        }
        .onChange(of: isExpanded) { _, newValue in
            if !newValue {
                visibleCount = 5
            }
        }
    }

    private var visiblePatients: ArraySlice<Patient> {
        section.patients.prefix(visibleCount)
    }

    private func patientDisplayName(_ patient: Patient) -> String {
        if let parsedName = patient.parsedName, !parsedName.isEmpty {
            return parsedName
        }
        return patient.rawInput.isEmpty ? "未命名患者" : patient.rawInput
    }
}

private struct OverviewTextLine: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(1)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
        .contentShape(Rectangle())
    }
}

private struct OverviewSearchRow: View {
    let patient: Patient
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(patient.parsedName?.isEmpty == false ? patient.parsedName! : patient.rawInput)
                .foregroundColor(.primary)
                .lineLimit(1)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    OverviewView()
}
