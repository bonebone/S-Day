import SwiftUI

private let currentStage: DemoStage = .singleFullScreenBlock

enum DemoStage: String, CaseIterable, Identifiable {
    case basicTabViewOnly
    case navigationStacks
    case simpleLists
    case listWithoutSection
    case listWithoutNavigationStack
    case scrollViewLazyVStack
    case staticLongVStack
    case staticLongVStackNoNavTitle
    case fullHeightBlocks
    case singleFullScreenBlock
    case listGroupedStyle
    case customHeader
    case customSearchBar
    case bottomInsetBar
    case appLikeLayout
    case appLikeLayoutWithAnimation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basicTabViewOnly:
            return "Stage 1"
        case .navigationStacks:
            return "Stage 2"
        case .simpleLists:
            return "Stage 3"
        case .listWithoutSection:
            return "Stage 3A"
        case .listWithoutNavigationStack:
            return "Stage 3B"
        case .scrollViewLazyVStack:
            return "Stage 3C"
        case .staticLongVStack:
            return "Stage 3E"
        case .staticLongVStackNoNavTitle:
            return "Stage 3F"
        case .fullHeightBlocks:
            return "Stage 3G"
        case .singleFullScreenBlock:
            return "Stage 3H"
        case .listGroupedStyle:
            return "Stage 3D"
        case .customHeader:
            return "Stage 4"
        case .customSearchBar:
            return "Stage 5"
        case .bottomInsetBar:
            return "Stage 6"
        case .appLikeLayout:
            return "Stage 7"
        case .appLikeLayoutWithAnimation:
            return "Stage 8"
        }
    }

    var summary: String {
        switch self {
        case .basicTabViewOnly:
            return "纯系统 TabView + 4 个 Text 页面"
        case .navigationStacks:
            return "每个 tab 外层加 NavigationStack"
        case .simpleLists:
            return "Text 改成最简单的 List"
        case .listWithoutSection:
            return "List 保留，去掉 Section"
        case .listWithoutNavigationStack:
            return "List + Section 保留，移除 NavigationStack"
        case .scrollViewLazyVStack:
            return "用 ScrollView + LazyVStack 替代 List"
        case .staticLongVStack:
            return "很多行内容，但不用任何滚动容器"
        case .staticLongVStackNoNavTitle:
            return "很多静态行内容，不设 navigationTitle"
        case .fullHeightBlocks:
            return "少量块状布局，但铺满整屏高度"
        case .singleFullScreenBlock:
            return "单个全屏内容块，不含复杂层次"
        case .listGroupedStyle:
            return "List + Section 保留，改成 insetGrouped 风格"
        case .customHeader:
            return "页面顶部加入自定义 header"
        case .customSearchBar:
            return "在 header 下加入搜索框样式组件"
        case .bottomInsetBar:
            return "增加 safeAreaInset 底部占位条"
        case .appLikeLayout:
            return "切换到接近主 app 的 header + search + list 组合"
        case .appLikeLayoutWithAnimation:
            return "在接近主 app 的布局里加入显式列表动画"
        }
    }
}

struct DemoContentView: View {
    var body: some View {
        switch currentStage {
        case .basicTabViewOnly:
            demoTabView { tab in
                DemoCenteredPage(
                    title: tab.title,
                    subtitle: currentStage.summary
                )
            }
        case .navigationStacks:
            demoTabView { tab in
                NavigationStack {
                    DemoCenteredPage(
                        title: tab.title,
                        subtitle: currentStage.summary
                    )
                }
            }
        case .simpleLists:
            demoTabView { tab in
                NavigationStack {
                    DemoListPage(
                        title: tab.title,
                        subtitle: currentStage.summary,
                        showsSection: true,
                        listStyle: .plain
                    )
                }
            }
        case .listWithoutSection:
            demoTabView { tab in
                NavigationStack {
                    DemoListPage(
                        title: tab.title,
                        subtitle: currentStage.summary,
                        showsSection: false,
                        listStyle: .plain
                    )
                }
            }
        case .listWithoutNavigationStack:
            demoTabView { tab in
                DemoListPage(
                    title: tab.title,
                    subtitle: currentStage.summary,
                    showsSection: true,
                    listStyle: .plain
                )
            }
        case .scrollViewLazyVStack:
            demoTabView { tab in
                NavigationStack {
                    DemoScrollPage(
                        title: tab.title,
                        subtitle: currentStage.summary
                    )
                }
            }
        case .staticLongVStack:
            demoTabView { tab in
                NavigationStack {
                    DemoStaticStackPage(
                        title: tab.title,
                        subtitle: currentStage.summary,
                        showsNavigationTitle: true
                    )
                }
            }
        case .staticLongVStackNoNavTitle:
            demoTabView { tab in
                NavigationStack {
                    DemoStaticStackPage(
                        title: tab.title,
                        subtitle: currentStage.summary,
                        showsNavigationTitle: false
                    )
                }
            }
        case .fullHeightBlocks:
            demoTabView { tab in
                NavigationStack {
                    DemoFullHeightBlocksPage(
                        title: tab.title,
                        subtitle: currentStage.summary
                    )
                }
            }
        case .singleFullScreenBlock:
            demoTabView { tab in
                NavigationStack {
                    DemoSingleFullScreenBlockPage(
                        title: tab.title,
                        subtitle: currentStage.summary
                    )
                }
            }
        case .listGroupedStyle:
            demoTabView { tab in
                NavigationStack {
                    DemoListPage(
                        title: tab.title,
                        subtitle: currentStage.summary,
                        showsSection: true,
                        listStyle: .insetGrouped
                    )
                }
            }
        case .customHeader:
            demoTabView { tab in
                NavigationStack {
                    DemoHeaderListPage(
                        title: tab.title,
                        subtitle: currentStage.summary,
                        showsSearchBar: false,
                        showsBottomInset: false,
                        showsAnimationControls: false
                    )
                }
            }
        case .customSearchBar:
            demoTabView { tab in
                NavigationStack {
                    DemoHeaderListPage(
                        title: tab.title,
                        subtitle: currentStage.summary,
                        showsSearchBar: true,
                        showsBottomInset: false,
                        showsAnimationControls: false
                    )
                }
            }
        case .bottomInsetBar:
            demoTabView { tab in
                NavigationStack {
                    DemoHeaderListPage(
                        title: tab.title,
                        subtitle: currentStage.summary,
                        showsSearchBar: true,
                        showsBottomInset: true,
                        showsAnimationControls: false
                    )
                }
            }
        case .appLikeLayout:
            demoTabView { tab in
                NavigationStack {
                    DemoAppLikePage(
                        title: tab.title,
                        subtitle: currentStage.summary,
                        showsAnimationControls: false
                    )
                }
            }
        case .appLikeLayoutWithAnimation:
            demoTabView { tab in
                NavigationStack {
                    DemoAppLikePage(
                        title: tab.title,
                        subtitle: currentStage.summary,
                        showsAnimationControls: true
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func demoTabView<Content: View>(@ViewBuilder page: @escaping (DemoTab) -> Content) -> some View {
        TabView {
            ForEach(DemoTab.allCases) { tab in
                page(tab)
                    .tag(tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
            }
        }
    }
}

private enum DemoTab: CaseIterable, Identifiable {
    case overview
    case preOp
    case postOp
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .overview:
            return "概览"
        case .preOp:
            return "术前"
        case .postOp:
            return "术后"
        case .settings:
            return "设置"
        }
    }

    var icon: String {
        switch self {
        case .overview:
            return "chart.bar.doc.horizontal"
        case .preOp:
            return "list.bullet.clipboard"
        case .postOp:
            return "checkmark.circle"
        case .settings:
            return "gearshape"
        }
    }
}

private struct DemoCenteredPage: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private struct DemoListPage: View {
    let title: String
    let subtitle: String
    let showsSection: Bool
    let listStyle: DemoListStyle

    var body: some View {
        List {
            if showsSection {
                Section {
                    rows
                }
            } else {
                rows
            }
        }
        .modifier(DemoListStyleModifier(style: listStyle))
        .navigationTitle(title)
    }

    @ViewBuilder
    private var rows: some View {
        ForEach(0..<20, id: \.self) { index in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(title) Row \(index + 1)")
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

private struct DemoScrollPage: View {
    let title: String
    let subtitle: String

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<20, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(title) Row \(index + 1)")
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
        .navigationTitle(title)
    }
}

private struct DemoStaticStackPage: View {
    let title: String
    let subtitle: String
    let showsNavigationTitle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.largeTitle.bold())
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ForEach(0..<20, id: \.self) { index in
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(title) Row \(index + 1)")
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
                    .padding(.leading, 16)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(DemoNavigationTitleModifier(title: title, isEnabled: showsNavigationTitle))
    }
}

private struct DemoNavigationTitleModifier: ViewModifier {
    let title: String
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.navigationTitle(title)
        } else {
            content.toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct DemoFullHeightBlocksPage: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.largeTitle.bold())
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.secondarySystemBackground))

            Spacer(minLength: 24)

            RoundedRectangle(cornerRadius: 18)
                .fill(Color.blue.opacity(0.15))
                .frame(height: 140)
                .overlay {
                    Text("Middle Block")
                        .font(.headline)
                }
                .padding(.horizontal, 16)

            Spacer(minLength: 24)

            RoundedRectangle(cornerRadius: 18)
                .fill(Color.green.opacity(0.15))
                .frame(height: 180)
                .overlay {
                    Text("Bottom Block")
                        .font(.headline)
                }
                .padding(.horizontal, 16)

            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct DemoSingleFullScreenBlockPage: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.secondarySystemBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.largeTitle.bold())
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private enum DemoListStyle {
    case plain
    case insetGrouped
}

private struct DemoListStyleModifier: ViewModifier {
    let style: DemoListStyle

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .plain:
            content.listStyle(.plain)
        case .insetGrouped:
            content.listStyle(.insetGrouped)
        }
    }
}

private struct DemoHeaderListPage: View {
    let title: String
    let subtitle: String
    let showsSearchBar: Bool
    let showsBottomInset: Bool
    let showsAnimationControls: Bool

    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            DemoHeader(title: title, subtitle: subtitle)

            if showsSearchBar {
                DemoSearchBar(text: $query)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            List {
                ForEach(filteredRows, id: \.self) { row in
                    Text(row)
                        .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            if showsBottomInset {
                DemoBottomInset()
            }
        }
    }

    private var filteredRows: [String] {
        let rows = (1...20).map { "\(title) Item \($0)" }
        guard !query.isEmpty else { return rows }
        return rows.filter { $0.localizedCaseInsensitiveContains(query) }
    }
}

private struct DemoAppLikePage: View {
    let title: String
    let subtitle: String
    let showsAnimationControls: Bool

    @State private var query = ""
    @State private var chips = ["需追踪", "收藏", "普通"]
    @State private var selectedChip: String?

    var body: some View {
        VStack(spacing: 0) {
            DemoHeader(title: title, subtitle: subtitle)

            VStack(spacing: 10) {
                DemoSearchBar(text: $query)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chipButton("全部", value: nil)
                        ForEach(chips, id: \.self) { chip in
                            chipButton(chip, value: chip)
                        }
                    }
                    .padding(.vertical, 2)
                }

                if showsAnimationControls {
                    HStack(spacing: 12) {
                        Button("新增标签") {
                            withAnimation(.snappy(duration: 0.25, extraBounce: 0)) {
                                let next = "标签\(chips.count + 1)"
                                if !chips.contains(next) {
                                    chips.append(next)
                                }
                            }
                        }

                        Button("重置") {
                            withAnimation(.snappy(duration: 0.25, extraBounce: 0)) {
                                chips = ["需追踪", "收藏", "普通"]
                                selectedChip = nil
                            }
                        }
                    }
                    .font(.footnote.weight(.medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            List {
                ForEach(filteredRows, id: \.self) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(row)
                        Text("Stage 7/8: 贴近主 app 的 header + search + chips + list")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            DemoBottomInset()
        }
    }

    @ViewBuilder
    private func chipButton(_ label: String, value: String?) -> some View {
        let isSelected = selectedChip == value

        Button {
            if showsAnimationControls {
                withAnimation(.snappy(duration: 0.25, extraBounce: 0)) {
                    selectedChip = value
                }
            } else {
                selectedChip = value
            }
        } label: {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var filteredRows: [String] {
        let baseRows = (1...20).map { "\(title) Patient \($0)" }
        let tagFiltered: [String]
        if let selectedChip {
            tagFiltered = baseRows.enumerated().compactMap { index, row in
                index % 3 == chipIndex(for: selectedChip) ? row : nil
            }
        } else {
            tagFiltered = baseRows
        }

        guard !query.isEmpty else { return tagFiltered }
        return tagFiltered.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private func chipIndex(for chip: String) -> Int {
        chips.firstIndex(of: chip) ?? 0
    }
}

private struct DemoHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.largeTitle.bold())
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }
}

private struct DemoSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("搜索...", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }
}

private struct DemoBottomInset: View {
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Text("Bottom Inset Placeholder")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 16)
            .background(.regularMaterial)
        }
    }
}

#Preview {
    DemoContentView()
}
