import SwiftUI

struct RecoveryView: View {
    let store: MealStore
    var scrollsInternally = true
    @State private var confirmRebuild = false

    var body: some View {
        Group {
            if scrollsInternally { ScrollView { recoveryContent } }
            else { recoveryContent }
        }
        .confirmationDialog("保留副本並重建？", isPresented: $confirmRebuild, titleVisibility: .visible) {
            Button("確認重建", role: .destructive) { store.rebuild() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("只有副本成功保存後才會重建。請確認你願意以範例清單重新開始。")
        }
    }

    private var recoveryContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("資料需要回復", systemImage: "externaldrive.badge.exclamationmark")
                .font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text("為了保留原始資料，目前無法新增、匯入或修改清單。關閉提醒或重開 App 都不會解除保護。")
            if let failure = store.loadFailure { Text(failure).font(.callout).foregroundStyle(Theme.muted) }
            Button("重新讀取資料", systemImage: "arrow.clockwise") { store.reload() }
                .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("reloadData")
            Button("保留原始資料副本", systemImage: "doc.on.doc") { store.preserveOriginal() }
                .buttonStyle(.bordered).accessibilityIdentifier("backupData")
            if let backup = store.backupURL {
                Text("原始資料副本已保留在 App 中。請匯出到安全的位置；重建後仍可從首頁的「原始資料副本」開啟。")
                ShareLink(item: backup) { Label("匯出原始資料副本", systemImage: "square.and.arrow.up") }
                    .accessibilityIdentifier("exportBackup")
            }
            Button("保留副本並重建資料", role: .destructive) { confirmRebuild = true }
                .buttonStyle(.bordered).accessibilityIdentifier("rebuildData")
            Text("重建會先保留目前原始檔案，再以範例清單開始。原始清單與抽選紀錄不會自動還原。若保留副本或儲存失敗，資料仍維持保護狀態。")
                .font(.footnote).foregroundStyle(Theme.muted)
        }.padding(24).frame(maxWidth: 580).frame(maxWidth: .infinity)
    }
}

struct RecoveryBackupsView: View {
    let store: MealStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.backups, id: \.self) { file in
                        ShareLink(item: file) {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("匯出原始資料副本", systemImage: "square.and.arrow.up")
                                Text(file.lastPathComponent).font(.caption).foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                } footer: {
                    Text("這些副本保留重建前的原始內容，可能仍需修復才能讀取。它們與 App 一起保存在此裝置，刪除 App 也會移除副本，請另存到安全的位置。")
                }
            }
            .navigationTitle("原始資料副本").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
