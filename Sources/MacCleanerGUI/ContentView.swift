import AppKit
import SwiftUI
import MacCleanerCore

struct ContentView: View {
    @StateObject private var viewModel = CleanerViewModel()
    @State private var showCleanConfirm = false
    @State private var showCleanDuplicatesConfirm = false
    @State private var showRestoreConfirm = false
    @State private var appToUninstall: InstalledAppInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            storageCard
            storageOverview
            controls
            summary
            visualInsights
            softwareInsights
            duplicateInsights
            fileList
            footer
        }
        .padding(16)
        .frame(minWidth: 980, minHeight: 640)
        .alert("Move selected files to Trash?", isPresented: $showCleanConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean", role: .destructive) {
                viewModel.clean()
            }
        } message: {
            Text("This action moves files to Trash. You can restore from Trash if needed.")
        }
        .alert("Restore last cleanup?", isPresented: $showRestoreConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                viewModel.restoreLatestCleanup()
            }
        } message: {
            Text("This will try to move files from Trash back to their original locations using the latest manifest.")
        }
        .alert("Clean duplicate copies?", isPresented: $showCleanDuplicatesConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clean Duplicates", role: .destructive) {
                viewModel.cleanDuplicateCopies()
            }
        } message: {
            Text("This keeps one copy per duplicate group and moves the other copies to Trash.")
        }
        .alert("Uninstall app?", isPresented: Binding(get: {
            appToUninstall != nil
        }, set: { isPresented in
            if !isPresented { appToUninstall = nil }
        })) {
            Button("Cancel", role: .cancel) {
                appToUninstall = nil
            }
            Button("Uninstall", role: .destructive) {
                if let app = appToUninstall {
                    viewModel.uninstallApp(app)
                }
                appToUninstall = nil
            }
        } message: {
            Text("App akan dipindahkan ke Trash.")
        }
    }

    private var header: some View {
        HStack {
            Text("Mac Cleaner")
                .font(.system(size: 28, weight: .bold))
            Spacer()
            Text(viewModel.statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Toggle("Include review risk", isOn: $viewModel.includeReview)
                .toggleStyle(.switch)
                .frame(width: 220)

            HStack(spacing: 6) {
                Text("Limit")
                TextField("No limit", text: $viewModel.limitText)
                    .frame(width: 80)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                viewModel.scan()
            } label: {
                Text(viewModel.isScanning ? "Scanning..." : "Scan")
            }
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isCleaningDuplicates)

            Button {
                viewModel.refreshStorage()
                viewModel.analyzeStorageBreakdown()
                viewModel.loadInstalledApps()
            } label: {
                Text("Refresh Storage")
            }
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.isCleaningDuplicates)

            Button {
                viewModel.findDuplicates()
            } label: {
                Text(viewModel.isFindingDuplicates ? "Finding..." : "Find Duplicates")
            }
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.isCleaningDuplicates || viewModel.items.isEmpty)

            Button {
                showCleanConfirm = true
            } label: {
                Text(viewModel.isCleaning ? "Cleaning..." : "Clean Selected")
            }
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.isCleaningDuplicates || viewModel.items.isEmpty)

            Button {
                showRestoreConfirm = true
            } label: {
                Text(viewModel.isRestoring ? "Restoring..." : "Restore Last Cleanup")
            }
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.isCleaningDuplicates || viewModel.isRestoring)
        }
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Storage")
                .font(.headline)

            HStack(spacing: 16) {
                Text("Total: \(ByteCountFormatter.string(fromByteCount: viewModel.storageTotalBytes, countStyle: .file))")
                Text("Used: \(ByteCountFormatter.string(fromByteCount: viewModel.storageUsedBytes, countStyle: .file))")
                Text("Free: \(ByteCountFormatter.string(fromByteCount: viewModel.storageFreeBytes, countStyle: .file))")
            }
            .font(.subheadline)

            ProgressView(value: viewModel.storageUsedRatio)
                .progressViewStyle(.linear)

            Text("Used \(Int((viewModel.storageUsedRatio * 100).rounded()))%")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Tip: kosongkan Limit atau isi 0 untuk proses semua file.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var storageOverview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Storage Overview")
                    .font(.headline)
                Spacer()
                if viewModel.isAnalyzingStorage {
                    Text("Analyzing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
            .frame(height: 18)

            ForEach(viewModel.storageBreakdownCategories.prefix(8), id: \.id) { category in
                HStack {
                    Circle()
                        .fill(Color(hex: category.colorHex))
                        .frame(width: 10, height: 10)
                    Text(category.name)
                        .font(.caption)
                    Spacer()
                    Text(ByteCountFormatter.string(fromByteCount: category.bytes, countStyle: .file))
                        .font(.caption.monospacedDigit())
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var summary: some View {
        HStack {
            Text("Candidates: \(viewModel.totalFiles) files")
            Text("Potential savings: \(ByteCountFormatter.string(fromByteCount: viewModel.totalBytes, countStyle: .file))")
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private var visualInsights: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Category Breakdown")
                    .font(.headline)

                if viewModel.categoryUsageRows.isEmpty {
                    Text("Scan dulu untuk melihat breakdown.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            .padding(12)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                Text("Top Space Wasters")
                    .font(.headline)

                if viewModel.topFolderRows.isEmpty {
                    Text("Belum ada data folder dari hasil scan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            .padding(12)
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var fileList: some View {
        List(viewModel.items, id: \.id) { item in
            HStack(alignment: .top, spacing: 12) {
                Text(item.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)

                Text(item.risk.rawValue)
                    .font(.caption)
                    .foregroundStyle(item.risk == .safe ? .green : .orange)
                    .frame(width: 52, alignment: .leading)

                Text(ByteCountFormatter.string(fromByteCount: item.sizeBytes, countStyle: .file))
                    .font(.caption.monospacedDigit())
                    .frame(width: 90, alignment: .trailing)

                Text(item.path)
                    .font(.caption)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 2)
        }
        .listStyle(.inset)
    }

    private var duplicateInsights: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Duplicate Finder")
                    .font(.headline)
                Spacer()
                Button {
                    showCleanDuplicatesConfirm = true
                } label: {
                    Text(viewModel.isCleaningDuplicates ? "Cleaning..." : "Clean Duplicate Copies")
                }
                .disabled(
                    viewModel.isScanning ||
                    viewModel.isCleaning ||
                    viewModel.isFindingDuplicates ||
                    viewModel.isCleaningDuplicates ||
                    viewModel.duplicateItemsToDelete.isEmpty
                )

                Text("Reclaimable: \(ByteCountFormatter.string(fromByteCount: viewModel.totalDuplicateReclaimableBytes, countStyle: .file))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if viewModel.duplicateGroups.isEmpty {
                Text("Klik \"Find Duplicates\" setelah scan untuk mendeteksi file duplikat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var softwareInsights: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Installed Software")
                    .font(.headline)

                Toggle("Hanya rekomendasi uninstall", isOn: $viewModel.showRecommendedAppsOnly)
                    .toggleStyle(.switch)
                    .frame(width: 260)

                Spacer()

                Button {
                    viewModel.loadInstalledApps()
                } label: {
                    Text(viewModel.isLoadingInstalledApps ? "Loading..." : "Refresh Apps")
                }
                .disabled(viewModel.isLoadingInstalledApps || viewModel.isUninstallingApp)
            }

            if viewModel.visibleInstalledApps.isEmpty {
                Text(viewModel.isLoadingInstalledApps ? "Memuat daftar aplikasi..." : "Tidak ada aplikasi dalam filter saat ini.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.visibleInstalledApps.prefix(12)), id: \.id) { app in
                    HStack(alignment: .center, spacing: 10) {
                        Text(app.name)
                            .font(.caption)
                            .frame(width: 180, alignment: .leading)
                            .lineLimit(1)

                        Text(ByteCountFormatter.string(fromByteCount: app.sizeBytes, countStyle: .file))
                            .font(.caption.monospacedDigit())
                            .frame(width: 90, alignment: .trailing)

                        Text(lastUsedLabel(app.lastUsedAt))
                            .font(.caption)
                            .frame(width: 140, alignment: .leading)
                            .foregroundStyle(.secondary)

                        Text(app.recommendationReason)
                            .font(.caption2)
                            .foregroundStyle(app.recommendation == .uninstallCandidate ? .orange : .secondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Install") {
                            openAppStoreSearch(for: app.name)
                        }
                        .font(.caption)

                        Button("Uninstall") {
                            appToUninstall = app
                        }
                        .font(.caption)
                        .disabled(viewModel.isUninstallingApp)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !viewModel.lastManifestPath.isEmpty {
                Text("Manifest: \(viewModel.lastManifestPath)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Text("Tip: jalankan scan dulu, review hasil, lalu clean.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
