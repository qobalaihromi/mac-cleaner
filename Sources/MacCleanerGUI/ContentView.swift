import AppKit
import SwiftUI
@preconcurrency import MacCleanerCore

struct ContentView: View {
    enum AppSection: String, CaseIterable, Identifiable {
        case overview
        case insights
        case software
        case duplicates
        case files

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: return "Overview"
            case .insights: return "Insights"
            case .software: return "Installed Software"
            case .duplicates: return "Duplicate Finder"
            case .files: return "Scanned Files"
            }
        }

        var systemImage: String {
            switch self {
            case .overview: return "gauge"
            case .insights: return "chart.bar"
            case .software: return "app.badge"
            case .duplicates: return "doc.on.doc"
            case .files: return "doc.text.magnifyingglass"
            }
        }
    }

    @StateObject private var viewModel = CleanerViewModel()
    @State private var selectedSection: AppSection = .overview
    @State private var showCleanConfirm = false
    @State private var showCleanDuplicatesConfirm = false
    @State private var showRestoreConfirm = false
    @State private var appToUninstall: InstalledAppInfo?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    controlBar
                    sectionContent
                    footer
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.visible)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1100, minHeight: 720)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button {
                    viewModel.scan()
                } label: {
                    Label("Scan", systemImage: "magnifyingglass")
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isCleaningDuplicates)

                Button {
                    viewModel.refreshStorage()
                    viewModel.refreshMemory()
                    viewModel.analyzeStorageBreakdown()
                    viewModel.loadInstalledApps()
                    viewModel.loadRunningApps()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.isCleaningDuplicates)

                Button {
                    viewModel.findDuplicates()
                } label: {
                    Label("Find Duplicates", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.isCleaningDuplicates || viewModel.items.isEmpty)
            }
        }
        .alert("Move selected files to Trash?", isPresented: $showCleanConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) { viewModel.clean() }
        } message: {
            Text("This action moves files to Trash. You can restore from Trash if needed.")
        }
        .alert("Restore last cleanup?", isPresented: $showRestoreConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) { viewModel.restoreLatestCleanup() }
        } message: {
            Text("This will try to move files from Trash back to their original locations using the latest manifest.")
        }
        .alert("Clean duplicate copies?", isPresented: $showCleanDuplicatesConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean Duplicates", role: .destructive) { viewModel.cleanDuplicateCopies() }
        } message: {
            Text("This keeps one copy per duplicate group and moves the other copies to Trash.")
        }
        .alert("Uninstall app?", isPresented: Binding(get: {
            appToUninstall != nil
        }, set: { isPresented in
            if !isPresented { appToUninstall = nil }
        })) {
            Button("Cancel", role: .cancel) { appToUninstall = nil }
            Button("Uninstall", role: .destructive) {
                if let app = appToUninstall { viewModel.uninstallApp(app) }
                appToUninstall = nil
            }
        } message: {
            Text("App akan dipindahkan ke Trash.")
        }
    }

    private var sidebar: some View {
        List(selection: $selectedSection) {
            Section("Mac Cleaner") {
                ForEach(AppSection.allCases) { section in
                    NavigationLink(value: section) {
                        Label(section.title, systemImage: section.systemImage)
                    }
                }
            }

            Section("Quick Status") {
                HStack {
                    Text("Used")
                    Spacer()
                    Text("\(Int((viewModel.storageUsedRatio * 100).rounded()))%")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Candidates")
                    Spacer()
                    Text("\(viewModel.totalFiles)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Duplicates")
                    Spacer()
                    Text("\(viewModel.duplicateGroups.count)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Memory")
                    Spacer()
                    Text("\(Int((viewModel.memoryUsedRatio * 100).rounded()))%")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Running Apps")
                    Spacer()
                    Text("\(viewModel.runningApps.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Mac Cleaner")
                    .font(.largeTitle.weight(.semibold))
                Text(selectedSection.title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
        }
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            Toggle("Include review", isOn: $viewModel.includeReview)
                .toggleStyle(.switch)
                .frame(width: 180)

            HStack(spacing: 6) {
                Text("Limit")
                    .foregroundStyle(.secondary)
                TextField("No limit", text: $viewModel.limitText)
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
            }

            Divider().frame(height: 20)

            Button(viewModel.isScanning ? "Scanning..." : "Scan") {
                viewModel.scan()
            }
            .keyboardShortcut("r", modifiers: [.command])
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isCleaningDuplicates)

            Button("Refresh") {
                viewModel.refreshStorage()
                viewModel.refreshMemory()
                viewModel.analyzeStorageBreakdown()
                viewModel.loadInstalledApps()
                viewModel.loadRunningApps()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.isCleaningDuplicates)

            Button(viewModel.isFindingDuplicates ? "Finding..." : "Find Duplicates") {
                viewModel.findDuplicates()
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.isCleaningDuplicates || viewModel.items.isEmpty)

            Button(viewModel.isCleaning ? "Cleaning..." : "Clean Selected") {
                showCleanConfirm = true
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.isCleaningDuplicates || viewModel.items.isEmpty)

            Button(viewModel.isRestoring ? "Restoring..." : "Restore Last Cleanup") {
                showRestoreConfirm = true
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.isCleaningDuplicates || viewModel.isRestoring)
        }
        .controlSize(.small)
        .cardStyle()
    }

    @ViewBuilder
    private var sectionContent: some View {
        Group {
            switch selectedSection {
            case .overview:
                storageCard
                memoryCard
                runningAppsCard
                storageOverview
                summaryCard
            case .insights:
                visualInsights
            case .software:
                softwareInsights
            case .duplicates:
                duplicateInsights
            case .files:
                fileList
            }
        }
        .id(selectedSection.id)
        .transition(.opacity.combined(with: .move(edge: .trailing)))
        .animation(.easeInOut(duration: 0.2), value: selectedSection)
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Storage")
                .font(.headline)

            HStack(spacing: 18) {
                metric(label: "Total", value: ByteCountFormatter.string(fromByteCount: viewModel.storageTotalBytes, countStyle: .file))
                metric(label: "Used", value: ByteCountFormatter.string(fromByteCount: viewModel.storageUsedBytes, countStyle: .file))
                metric(label: "Free", value: ByteCountFormatter.string(fromByteCount: viewModel.storageFreeBytes, countStyle: .file))
                Spacer()
                Text("\(Int((viewModel.storageUsedRatio * 100).rounded()))% used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.storageUsedRatio)
                .progressViewStyle(.linear)
                .tint(.accentColor)
        }
        .cardStyle()
    }

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Memory")
                .font(.headline)

            HStack(spacing: 18) {
                metric(label: "Total", value: ByteCountFormatter.string(fromByteCount: viewModel.memoryTotalBytes, countStyle: .memory))
                metric(label: "Used", value: ByteCountFormatter.string(fromByteCount: viewModel.memoryUsedBytes, countStyle: .memory))
                metric(label: "Free", value: ByteCountFormatter.string(fromByteCount: viewModel.memoryFreeBytes, countStyle: .memory))
                metric(label: "Active", value: ByteCountFormatter.string(fromByteCount: viewModel.memoryActiveBytes, countStyle: .memory))
                metric(label: "Wired", value: ByteCountFormatter.string(fromByteCount: viewModel.memoryWiredBytes, countStyle: .memory))
                metric(label: "Compressed", value: ByteCountFormatter.string(fromByteCount: viewModel.memoryCompressedBytes, countStyle: .memory))
                Spacer()
                Text("\(Int((viewModel.memoryUsedRatio * 100).rounded()))% used")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.memoryUsedRatio)
                .progressViewStyle(.linear)
                .tint(.mint)
        }
        .cardStyle()
    }

    private var runningAppsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Running Apps Memory")
                    .font(.headline)

                Toggle("Only recommended close", isOn: $viewModel.showRecommendedRunningAppsOnly)
                    .toggleStyle(.switch)
                    .frame(width: 230)

                Spacer()

                Button(viewModel.isLoadingRunningApps ? "Loading..." : "Refresh Running Apps") {
                    viewModel.loadRunningApps()
                    viewModel.refreshMemory()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isLoadingRunningApps || viewModel.isClosingRunningApp)
            }

            if viewModel.visibleRunningApps.isEmpty {
                emptyState(
                    title: "No running app recommendation",
                    subtitle: "Tidak ada app non-system yang direkomendasikan untuk ditutup sekarang.",
                    symbol: "memorychip"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.visibleRunningApps.prefix(12)), id: \.id) { app in
                        HStack(spacing: 10) {
                            Text(app.name)
                                .frame(width: 190, alignment: .leading)
                                .lineLimit(1)

                            Text(ByteCountFormatter.string(fromByteCount: app.memoryBytes, countStyle: .memory))
                                .font(.caption.monospacedDigit())
                                .frame(width: 90, alignment: .trailing)

                            Text(app.isActive ? "Active" : "Background")
                                .foregroundStyle(app.isActive ? .green : .secondary)
                                .frame(width: 90, alignment: .leading)

                            Text(app.recommendationReason)
                                .foregroundStyle(app.recommendedToClose ? .orange : .secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button("Close") {
                                viewModel.closeRunningApp(app)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(!app.canCloseSafely || viewModel.isClosingRunningApp)
                        }
                        .font(.caption)
                        .padding(.vertical, 6)

                        if app.id != viewModel.visibleRunningApps.prefix(12).last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    private var storageOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Storage Overview")
                    .font(.headline)
                Spacer()
                if viewModel.isAnalyzingStorage {
                    ProgressView().controlSize(.small)
                }
            }

            GeometryReader { geo in
                HStack(spacing: 0) {
                    let used = max(viewModel.storageUsedBytes, 1)
                    ForEach(viewModel.storageBreakdownCategories) { category in
                        Rectangle()
                            .fill(Color(hex: category.colorHex))
                            .frame(width: max(2, geo.size.width * (Double(category.bytes) / Double(used))))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .frame(height: 18)

            VStack(spacing: 6) {
                ForEach(viewModel.storageBreakdownCategories.prefix(8), id: \.id) { category in
                    HStack {
                        Circle().fill(Color(hex: category.colorHex)).frame(width: 8, height: 8)
                        Text(category.name).font(.caption)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: category.bytes, countStyle: .file))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .cardStyle()
    }

    private var summaryCard: some View {
        HStack {
            Label("Candidates: \(viewModel.totalFiles)", systemImage: "doc.text.magnifyingglass")
            Spacer()
            Text("Potential savings: \(ByteCountFormatter.string(fromByteCount: viewModel.totalBytes, countStyle: .file))")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .cardStyle()
    }

    private var visualInsights: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Category Breakdown").font(.headline)
                if viewModel.categoryUsageRows.isEmpty {
                    emptyState(
                        title: "No insight data",
                        subtitle: "Run a scan to view category insights.",
                        symbol: "chart.bar.xaxis"
                    )
                } else {
                    ForEach(viewModel.categoryUsageRows) { row in
                        metricBarRow(
                            title: row.category.rawValue,
                            subtitle: "\(row.files) files",
                            bytes: row.bytes,
                            ratio: row.ratio,
                            color: .blue
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .cardStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Top Space Wasters").font(.headline)
                if viewModel.topFolderRows.isEmpty {
                    emptyState(
                        title: "No folder hotspots",
                        subtitle: "Run a scan to identify large folders.",
                        symbol: "folder.badge.questionmark"
                    )
                } else {
                    ForEach(viewModel.topFolderRows) { row in
                        metricBarRow(
                            title: row.folderPath,
                            subtitle: "\(row.files) files",
                            bytes: row.bytes,
                            ratio: row.ratio,
                            color: .orange
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .cardStyle()
        }
    }

    private var softwareInsights: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Installed Software")
                    .font(.headline)

                Toggle("Only uninstall recommendations", isOn: $viewModel.showRecommendedAppsOnly)
                    .toggleStyle(.switch)
                    .frame(width: 260)

                Spacer()

                Button(viewModel.isLoadingInstalledApps ? "Loading..." : "Refresh Apps") {
                    viewModel.loadInstalledApps()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isLoadingInstalledApps || viewModel.isUninstallingApp)
            }

            if viewModel.visibleInstalledApps.isEmpty {
                if viewModel.isLoadingInstalledApps {
                    emptyState(
                        title: "Loading apps",
                        subtitle: "Gathering installed software data.",
                        symbol: "app.badge.checkmark"
                    )
                } else {
                    emptyState(
                        title: "No apps in this filter",
                        subtitle: "Disable the recommendation filter to see all apps.",
                        symbol: "line.3.horizontal.decrease.circle"
                    )
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.visibleInstalledApps.prefix(16)), id: \.id) { app in
                        HStack(spacing: 10) {
                            Text(app.name)
                                .frame(width: 190, alignment: .leading)
                                .lineLimit(1)

                            Text(ByteCountFormatter.string(fromByteCount: app.sizeBytes, countStyle: .file))
                                .font(.caption.monospacedDigit())
                                .frame(width: 90, alignment: .trailing)

                            Text(lastUsedLabel(app.lastUsedAt))
                                .foregroundStyle(.secondary)
                                .frame(width: 120, alignment: .leading)

                            Text(app.recommendationReason)
                                .foregroundStyle(app.recommendation == .uninstallCandidate ? .orange : .secondary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button("Install") { openAppStoreSearch(for: app.name) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)

                            Button("Uninstall") { appToUninstall = app }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(viewModel.isUninstallingApp)
                        }
                        .font(.caption)
                        .padding(.vertical, 6)

                        if app.id != viewModel.visibleInstalledApps.prefix(16).last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
        }
        .cardStyle()
    }

    private var duplicateInsights: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Duplicate Finder")
                    .font(.headline)
                Spacer()
                Text("Reclaimable: \(ByteCountFormatter.string(fromByteCount: viewModel.totalDuplicateReclaimableBytes, countStyle: .file))")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Button(viewModel.isCleaningDuplicates ? "Cleaning..." : "Clean Duplicate Copies") {
                    showCleanDuplicatesConfirm = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(
                    viewModel.isScanning ||
                    viewModel.isCleaning ||
                    viewModel.isFindingDuplicates ||
                    viewModel.isCleaningDuplicates ||
                    viewModel.duplicateItemsToDelete.isEmpty
                )
            }

            if viewModel.duplicateGroups.isEmpty {
                emptyState(
                    title: "No duplicate analysis yet",
                    subtitle: "Click Find Duplicates after scanning.",
                    symbol: "doc.on.doc.fill"
                )
            } else {
                Text("Candidate files to delete: \(viewModel.duplicateItemsToDelete.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(viewModel.duplicateGroups.prefix(8)), id: \.id) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        let eachSize = ByteCountFormatter.string(fromByteCount: group.fileSizeBytes, countStyle: .file)
                        let reclaim = ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file)
                        Text("\(group.duplicateCount)x \(eachSize) • reclaimable \(reclaim)")
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text(group.files.first ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .cardStyle()
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scanned Files")
                .font(.headline)

            if viewModel.items.isEmpty {
                emptyState(
                    title: "No scanned files",
                    subtitle: "Run Scan to populate cleanup candidates.",
                    symbol: "doc.text.magnifyingglass"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.items.prefix(120)), id: \.id) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Text(item.category.rawValue)
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)

                            Text(item.risk.rawValue)
                                .foregroundStyle(item.risk == .safe ? .green : .orange)
                                .frame(width: 56, alignment: .leading)

                            Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                                .font(.caption.monospacedDigit())
                                .frame(width: 96, alignment: .trailing)

                            Text(item.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                        .font(.caption)
                        .padding(.vertical, 5)

                        if item.id != viewModel.items.prefix(120).last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }

                if viewModel.items.count > 120 {
                    Text("... and \(viewModel.items.count - 120) more files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            }
        }
        .cardStyle()
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !viewModel.lastManifestPath.isEmpty {
                Text("Manifest: \(viewModel.lastManifestPath)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text("Tip: run scan first, review results, then clean.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 2)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func metricBarRow(title: String, subtitle: String, bytes: Int64, ratio: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                    .font(.caption.monospacedDigit())
            }
            HStack {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(max(ratio, 0), 1))
                .tint(color)
                .progressViewStyle(.linear)
        }
    }

    private func lastUsedLabel(_ date: Date?) -> String {
        guard let date else { return "Never/Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Used \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private func openAppStoreSearch(for appName: String) {
        let encoded = appName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? appName
        if let url = URL(string: "macappstore://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func emptyState(title: String, subtitle: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

private extension View {
    func cardStyle() -> some View {
        self
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

private extension Color {
    init(hex: String) {
        let value = hex.replacingOccurrences(of: "#", with: "")
        guard value.count == 6, let intValue = Int(value, radix: 16) else {
            self = .gray
            return
        }
        let red = Double((intValue >> 16) & 0xFF) / 255.0
        let green = Double((intValue >> 8) & 0xFF) / 255.0
        let blue = Double(intValue & 0xFF) / 255.0
        self = Color(red: red, green: green, blue: blue)
    }
}
