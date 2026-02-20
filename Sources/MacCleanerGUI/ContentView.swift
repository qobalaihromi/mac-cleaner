import SwiftUI
import MacCleanerCore

struct ContentView: View {
    @StateObject private var viewModel = CleanerViewModel()
    @State private var showCleanConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            storageCard
            controls
            summary
            visualInsights
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
            .disabled(viewModel.isScanning || viewModel.isCleaning)

            Button {
                viewModel.refreshStorage()
            } label: {
                Text("Refresh Storage")
            }
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates)

            Button {
                viewModel.findDuplicates()
            } label: {
                Text(viewModel.isFindingDuplicates ? "Finding..." : "Find Duplicates")
            }
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.items.isEmpty)

            Button {
                showCleanConfirm = true
            } label: {
                Text(viewModel.isCleaning ? "Cleaning..." : "Clean Selected")
            }
            .disabled(viewModel.isScanning || viewModel.isCleaning || viewModel.isFindingDuplicates || viewModel.items.isEmpty)
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
                Text("Reclaimable: \(ByteCountFormatter.string(fromByteCount: viewModel.totalDuplicateReclaimableBytes, countStyle: .file))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if viewModel.duplicateGroups.isEmpty {
                Text("Klik \"Find Duplicates\" setelah scan untuk mendeteksi file duplikat.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
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
}
