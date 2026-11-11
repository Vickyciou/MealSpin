import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension UTType {
    static let mealSpinList = UTType(exportedAs: "com.personal.mealspin.list", conformingTo: .json)
}

enum ListFileExporter {
    static func write(_ list: FoodList) throws -> URL {
        let data = try ListPackage.encode(list)
        let directory = URL.temporaryDirectory.appending(path: "MealSpinShares", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Keep recent exports available while the system share sheet is using them.
        for file in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])) ?? [] {
            if let date = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
               date.timeIntervalSinceNow < -86_400 { try? FileManager.default.removeItem(at: file) }
        }
        let folder = directory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = String(list.name.unicodeScalars.filter { CharacterSet.alphanumerics.union(.init(charactersIn: " -_（）()")).contains($0) }.map(String.init).joined().prefix(60))
        let file = folder.appending(path: (name.isEmpty ? "吃什麼清單" : name) + ".mealspin")
        try data.write(to: file, options: .atomic)
        return file
    }
}

enum ListFileReader {
    static func read(_ url: URL) async throws -> FoodList {
        let worker = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            guard url.isFileURL else { throw ListPackage.PackageError.invalid }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            var result: Result<FoodList, Error>?
            var coordinationError: NSError?
            try Task.checkCancellation()
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                result = Result {
                    try Task.checkCancellation()
                    let handle = try FileHandle(forReadingFrom: readable)
                    defer { try? handle.close() }
                    let data = try handle.read(upToCount: ListPackage.maxBytes + 1) ?? Data()
                    try Task.checkCancellation()
                    let list = try ListPackage.decode(data)
                    try Task.checkCancellation()
                    return list
                }
            }
            try Task.checkCancellation()
            if let coordinationError { throw coordinationError }
            guard let result else { throw ListPackage.PackageError.invalid }
            return try result.get()
        }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let list = try await worker.value
            try Task.checkCancellation()
            return list
        } onCancel: {
            worker.cancel()
        }
    }
}

struct ListShareView: View {
    let list: FoodList
    @Environment(\.dismiss) private var dismiss
    @State private var activity: ShareActivity?
    @State private var sharingError: String?
    private var text: String { ([list.name, ""] + list.items.map { "• \($0)" }).joined(separator: "\n") }
    private var fileError: String? { do { _ = try ListPackage.encode(list); return nil } catch { return error.localizedDescription } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(list.name).font(.headline)
                            Text("\(list.items.count) 個選項").font(.caption).foregroundStyle(Theme.muted)
                        }
                    } icon: { Image(systemName: list.symbol).foregroundStyle(Theme.orange) }
                    .padding(.vertical, 8)
                }
                Section {
                    Button {
                        do { activity = ShareActivity(file: try ListFileExporter.write(list), text: nil) }
                        catch { sharingError = error.localizedDescription }
                    } label: {
                        Label("分享可匯入的清單檔案", systemImage: "doc.badge.arrow.up")
                            .frame(minHeight: 44)
                    }.disabled(fileError != nil).accessibilityIdentifier("shareListFile")
                    if let fileError { Text(fileError).font(.caption).foregroundStyle(.red) }
                } header: { Text("給同樣使用這個 App 的人") }
                footer: { Text("傳送 .mealspin 檔案，可透過 AirDrop、訊息或儲存到「檔案」。對方可在 App 的「我的清單」中匯入，或直接開啟收到的檔案。") }
                Section {
                    Button { activity = ShareActivity(file: nil, text: text) } label: {
                        Label("分享文字清單", systemImage: "text.alignleft").frame(minHeight: 44)
                    }.accessibilityIdentifier("shareListText")
                } header: { Text("傳給朋友看") }
                footer: { Text("以文字分享名稱與選項，不需安裝 App 也能閱讀。分享內容不包含你的抽選紀錄。") }
            }.scrollContentBackground(.hidden).background(Theme.cream)
                .navigationTitle("分享清單").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }.presentationDragIndicator(.visible)
        .sheet(item: $activity) { payload in
            NativeShareSheet(items: payload.items) { activity = nil }
                .presentationDetents([.medium, .large])
        }
        .alert("無法分享", isPresented: Binding(get: { sharingError != nil }, set: { if !$0 { sharingError = nil } })) {
            Button("知道了") { sharingError = nil }
        } message: { Text(sharingError ?? "") }
    }
}

private struct ShareActivity: Identifiable {
    let id = UUID()
    let file: URL?
    let text: String?
    var items: [Any] { if let file { return [file] }; return [text ?? ""] }
}

private struct NativeShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let didFinish: () -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { didFinish() }
        }
        return controller
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

struct ListImportView: View {
    let list: FoodList
    let store: MealStore
    var onImported: (UUID) -> Void
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(list.name, systemImage: list.symbol).font(.headline).padding(.vertical, 8)
                    Text("\(list.items.count) 個選項").foregroundStyle(Theme.muted)
                } footer: {
                    Text(store.lists.contains { $0.name == list.name } ? "已有同名清單。匯入會建立另一份副本，不會覆蓋原本內容。" : "匯入會建立一份新清單，不會變更現有清單。")
                }
                Section("選項預覽") {
                    ForEach(Array(list.items.enumerated()), id: \.offset) { _, food in Text(food) }
                    if list.items.isEmpty { Text("這份清單尚未加入食物。").foregroundStyle(Theme.muted) }
                }
            }.scrollContentBackground(.hidden).background(Theme.cream)
                .navigationTitle("匯入清單").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
                .safeAreaInset(edge: .bottom) {
                    Button("加入我的清單", systemImage: "plus") {
                        if store.save(list) { onImported(list.id); dismiss() }
                        else { error = store.errorMessage; store.errorMessage = nil }
                    }.buttonStyle(PrimaryButtonStyle()).padding(20).background(Theme.cream)
                    .accessibilityIdentifier("confirmImport")
                }
                .alert("無法匯入", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                    Button("知道了") { error = nil }
                } message: { Text(error ?? "") }
        }.presentationDragIndicator(.visible)
    }
}

struct ImportStatusView: View {
    let coordinator: ListImportCoordinator
    var body: some View {
        switch coordinator.state {
        case .reading:
            VStack(alignment: .leading, spacing: 8) {
                ProgressView("正在讀取清單⋯")
                Button("取消讀取", role: .cancel) { coordinator.cancel() }
                    .accessibilityIdentifier("cancelImportRead")
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Theme.greenWash)
        case .ready:
            Label("已收到清單，完成目前操作後即可預覽匯入。", systemImage: "square.and.arrow.down")
                .font(.caption).padding(12).frame(maxWidth: .infinity).background(Theme.greenWash)
                .accessibilityIdentifier("pendingImport")
        case .idle, .failed:
            EmptyView()
        }
    }
}
