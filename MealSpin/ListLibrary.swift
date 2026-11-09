import SwiftUI
import UniformTypeIdentifiers

private enum LibrarySheet: Identifiable {
    case editor(FoodList), share(FoodList), importList(FoodList)
    var id: String {
        switch self {
        case .editor(let list): return "edit-\(list.id)"
        case .share(let list): return "share-\(list.id)"
        case .importList(let list): return "import-\(list.id)"
        }
    }
}

struct ListLibrary: View {
    let store: MealStore
    let selectedID: UUID?
    var onSelect: (UUID) -> Void
    @State private var sheet: LibrarySheet?
    @State private var importing = false
    @State private var importError: String?
    @State private var deleting: FoodList?
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss
    private var filtered: [FoodList] { store.lists.filter { search.isEmpty || $0.name.localizedStandardContains(search) } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(filtered) { list in
                        HStack(spacing: 8) {
                            Button {
                                onSelect(list.id)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: list.symbol).font(.title3).foregroundStyle(Theme.orange)
                                        .frame(width: 44, height: 44).background(Theme.orangeWash, in: RoundedRectangle(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(list.name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(list.items.isEmpty ? "還沒有選項" : "\(list.items.count) 個選項")
                                            .font(.caption).foregroundStyle(Theme.muted)
                                    }
                                    Spacer(minLength: 4)
                                    if selectedID == list.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                                    }
                                }.padding(.vertical, 8).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("list-\(list.name)")
                            .accessibilityAddTraits(selectedID == list.id ? .isSelected : [])
                            Menu {
                                Button("分享清單", systemImage: "square.and.arrow.up") { sheet = .share(list) }
                                Button("編輯清單", systemImage: "pencil") { sheet = .editor(list) }
                                Button("刪除清單", systemImage: "trash", role: .destructive) { deleting = list }
                            } label: {
                                Image(systemName: "ellipsis").font(.body.weight(.semibold))
                                    .frame(width: 44, height: 44).foregroundStyle(Theme.muted)
                            }.accessibilityLabel("管理\(list.name)")
                        }
                        .listRowBackground(selectedID == list.id ? Theme.greenWash : Theme.card)
                        .swipeActions {
                            Button("刪除", role: .destructive) { deleting = list }
                            Button("編輯") { sheet = .editor(list) }.tint(Theme.orange)
                        }
                    }
                } header: { Text("\(store.lists.count) 份自己的口袋名單") }
                footer: { Text("點選清單即可切換，按 ⋯ 管理名稱與選項。") }
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: search).listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden).background(Theme.cream)
            .searchable(text: $search, prompt: "搜尋清單")
            .navigationTitle("我的清單").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("匯入清單", systemImage: "square.and.arrow.down") { importing = true } }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                Button("新增清單", systemImage: "plus") { sheet = .editor(FoodList(name: "", items: [])) }
                    .buttonStyle(PrimaryButtonStyle()).padding(20).background(Theme.cream)
            }
            .sheet(item: $sheet) { destination in
                switch destination {
                case .editor(let list): ListEditor(store: store, list: list, onSaved: onSelect)
                case .share(let list): ListShareView(list: list)
                case .importList(let list): ListImportView(list: list, store: store, onImported: onSelect)
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.mealSpinList], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        do { sheet = .importList(try await ListFileReader.read(url)) }
                        catch { importError = error.localizedDescription }
                    }
                case .failure(let error):
                    if (error as NSError).code != NSUserCancelledError { importError = error.localizedDescription }
                }
            }
            .alert("無法讀取清單", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("知道了") { importError = nil }
            } message: { Text(importError ?? "") }
            .confirmationDialog("刪除「\(deleting?.name ?? "")」？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("刪除清單", role: .destructive) { if let deleting { store.delete(deleting) }; deleting = nil }
            } message: { Text("這份清單與其中的選項將被移除，抽選紀錄會保留。") }
        }.presentationDragIndicator(.visible)
    }
}
