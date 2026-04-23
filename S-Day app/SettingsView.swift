import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import LocalAuthentication

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var patients: [Patient]
    @State private var showingClearConfirm = false
    @State private var confirmText = ""
    
    // Import/Export state
    @State private var showingExporter = false
    @State private var exportDocument: SDayExportDocument? = nil
    
    @State private var showingImporter = false
    @State private var showingImportConfirm = false
    @State private var pendingImportURL: URL? = nil
    @State private var importConfirmText = ""
    
    // Appearance state
    @AppStorage("appAppearance") private var appearance: AppAppearance = .system
    @AppStorage("patientTagDisplayMode") private var patientTagDisplayMode: PatientTagDisplayMode = .followText
    
    // Privacy state
    @AppStorage("requireBiometrics") private var requireBiometrics: Bool = false
    
    // Toast notification state
    @State private var showingToast = false
    @State private var toastMessage = ""
    
    private let confirmPhrase = "清除所有数据"
    private let importConfirmPhrase = "确认导入并覆盖"

    private var trashCount: Int {
        trashedPatients(from: patients).count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabHeaderContainer {
                    HStack {
                        Text("设置")
                            .font(.largeTitle)
                            .bold()
                        Spacer()
                    }
                }
                
                Form {
                    Section(header: Text("关于").padding(.top, 18)) {
                        Text("S-Day (Surgery Day)")
                        Text("极速外科病人管理")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(header: Text("外观")) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 12) {
                                settingsRowLabel("界面颜色", systemImage: "paintpalette")
                                    .fixedSize(horizontal: true, vertical: false)

                                Spacer(minLength: 12)

                                Picker("界面颜色", selection: $appearance) {
                                    ForEach(AppAppearance.allCases) { style in
                                        Text(style.rawValue).tag(style)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .controlSize(.mini)
                                .labelsHidden()
                                .frame(width: 220)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                settingsRowLabel("界面颜色", systemImage: "paintpalette")
                                Picker("界面颜色", selection: $appearance) {
                                    ForEach(AppAppearance.allCases) { style in
                                        Text(style.rawValue).tag(style)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        .environment(\.defaultMinListRowHeight, 0)

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .center, spacing: 12) {
                                settingsRowLabel("标签布局", systemImage: "text.alignleft")
                                    .fixedSize(horizontal: true, vertical: false)

                                Spacer(minLength: 12)

                                Picker("标签布局", selection: $patientTagDisplayMode) {
                                    ForEach(PatientTagDisplayMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .controlSize(.mini)
                                .labelsHidden()
                                .frame(width: 220)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                settingsRowLabel("标签布局", systemImage: "text.alignleft")
                                Picker("标签布局", selection: $patientTagDisplayMode) {
                                    ForEach(PatientTagDisplayMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        .environment(\.defaultMinListRowHeight, 0)
                    }

                    Section(header: Text("隐私保护")) {
                        Toggle(isOn: $requireBiometrics) {
                            Label("要求 Face ID / 密码", systemImage: "faceid")
                        }
                    }
                    
                    Section(header: Text("标签")) {
                        NavigationLink(destination: TagManagerView()) {
                            Label("标签管理", systemImage: "tag")
                        }
                    }

                    Section(header: Text("数据")) {
                        Button {
                            let data = DataTransferManager.createExportData(from: patients)
                            exportDocument = SDayExportDocument(data: data)
                            showingExporter = true
                        } label: {
                            Label("导出数据", systemImage: "square.and.arrow.up")
                        }
                        
                        Button {
                            showingImporter = true
                        } label: {
                            Label("导入数据", systemImage: "square.and.arrow.down")
                        }

                        NavigationLink(destination: TrashView()) {
                            HStack {
                                Label("回收站", systemImage: "archivebox")
                                Spacer()
                                if trashCount > 0 {
                                    Text("\(trashCount)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Button(role: .destructive) {
                            confirmText = ""
                            showingClearConfirm = true
                        } label: {
                            Label("清除所有数据", systemImage: "trash.fill")
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                purgeExpiredTrash(in: modelContext)
            }
            .sheet(isPresented: $showingClearConfirm) {
                ClearDataConfirmView(
                    confirmPhrase: confirmPhrase,
                    confirmText: $confirmText,
                    onConfirm: {
                        clearAllData()
                        showingClearConfirm = false
                    },
                    onCancel: {
                        showingClearConfirm = false
                    }
                )
                .presentationDetents([.fraction(0.4)])
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: backupFilename()
        ) { result in
            switch result {
            case .success(let url):
                print("Exported to: \(url)")
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                showToast("导出成功")
            case .failure(let error):
                print("Export failed: \(error.localizedDescription)")
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    pendingImportURL = url
                    showingImportConfirm = true
                }
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $showingImportConfirm) {
            ImportDataConfirmView(
                confirmPhrase: importConfirmPhrase,
                confirmText: $importConfirmText,
                onConfirm: {
                    if let url = pendingImportURL {
                        performImport(from: url)
                    }
                    showingImportConfirm = false
                    importConfirmText = ""
                },
                onCancel: {
                    pendingImportURL = nil
                    showingImportConfirm = false
                    importConfirmText = ""
                }
            )
        }
        .overlay(
            VStack {
                if showingToast {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                        Text(toastMessage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(.regularMaterial)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 16)
                }
                Spacer()
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showingToast)
        )
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation { showingToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showingToast = false }
        }
    }
    
    private func performImport(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let exportData = try JSONDecoder().decode(SDayExportData.self, from: data)
            DataTransferManager.importData(exportData, into: modelContext)
            
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            
            showToast("导入成功")
        } catch {
            print("Import parse failed: \(error)")
        }
    }
    
    private func backupFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "SDay_Backup_\(formatter.string(from: Date()))"
    }
    
    private func clearAllData() {
        for patient in patients {
            modelContext.delete(patient)
        }
        TagColorStore.shared.resetToDefaults()
        TagFilterStore.shared.resetPinnedTags()
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        showToast("已清除所有数据")
    }

    @ViewBuilder
    private func settingsRowLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundColor(.blue)
            Text(title)
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .font(.body)
    }
}

struct ImportDataConfirmView: View {
    let confirmPhrase: String
    @Binding var confirmText: String
    var onConfirm: () -> Void
    var onCancel: () -> Void
    @FocusState private var isFocused: Bool
    
    var isMatch: Bool {
        confirmText == confirmPhrase
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text("导入数据")
                    .font(.title2)
                    .bold()
                (Text("此操作会完全覆盖当前的所有数据（包括病人条目和标签设置），\n请在下方输入")
                    + Text(confirmPhrase).bold()
                    + Text("以确认。"))
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            
            TextField("在此输入确认文字", text: $confirmText)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .focused($isFocused)
                .autocorrectionDisabled()
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("取消", action: onCancel)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                
                Button(action: onConfirm) {
                    Text("确认导入")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isMatch ? Color.orange : Color.orange.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!isMatch)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 20)
        .presentationDetents([.fraction(0.4)])
        .onAppear {
            isFocused = true
        }
    }
}

struct ClearDataConfirmView: View {
    let confirmPhrase: String
    @Binding var confirmText: String
    var onConfirm: () -> Void
    var onCancel: () -> Void
    @FocusState private var isFocused: Bool
    
    var isMatch: Bool {
        confirmText == confirmPhrase
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.red)
                Text("清除所有数据")
                    .font(.title2)
                    .bold()
                (Text("此操作不可撤销，术前、术后以及回收站中的所有病人数据都将永久删除。\n请在下方输入")
                    + Text(confirmPhrase).bold()
                    + Text("以确认。"))
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            
            TextField("在此输入确认文字", text: $confirmText)
                .textFieldStyle(.roundedBorder)
                .font(.body)
                .focused($isFocused)
                .autocorrectionDisabled()
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                Button("取消", action: onCancel)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                
                Button(action: onConfirm) {
                    Text("确认清除")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isMatch ? Color.red : Color.red.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(!isMatch)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .onAppear { isFocused = true }
    }
}

#Preview {
    SettingsView()
}
