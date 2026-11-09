import SwiftUI

private enum HomeSheet: Identifiable {
    case lists, editor(FoodList), history, share(FoodList), importList(FoodList)
    var id: String {
        switch self {
        case .lists: return "lists"
        case .editor(let list): return "editor-\(list.id)"
        case .history: return "history"
        case .share(let list): return "share-\(list.id)"
        case .importList(let list): return "import-\(list.id)"
        }
    }
}

struct ContentView: View {
    let store: MealStore
    @AppStorage("selectedFoodList") private var selectedID = ""
    @State private var sheet: HomeSheet?
    @State private var spinning = false
    @State private var pendingImport: FoodList?
    @State private var importError: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    private var selected: FoodList? { store.lists.first { $0.id.uuidString == selectedID } ?? store.lists.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header.dynamicTypeSize(...DynamicTypeSize.xxxLarge).padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 20)
                if let selected {
                    selector(selected).dynamicTypeSize(...DynamicTypeSize.xxxLarge).padding(.horizontal, 24).padding(.bottom, 8)
                    WheelScreen(list: selected, store: store, spinning: $spinning, edit: { sheet = .editor(selected) }, share: { sheet = .share(selected) })
                        .id(selected)
                } else {
                    ContentUnavailableView {
                        Label("下一餐，從這裡開始", systemImage: "fork.knife.circle")
                    } description: {
                        Text("把愛吃的餐廳和食物放進清單，\n猶豫的時候，讓轉盤幫你選。")
                    } actions: {
                        Button("建立第一份清單", systemImage: "plus") { newList() }.buttonStyle(PrimaryButtonStyle())
                        Button("匯入已有清單", systemImage: "square.and.arrow.down") { sheet = .lists }.buttonStyle(.bordered)
                    }.padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.cream.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $sheet, onDismiss: presentPendingImport) { destination in
                Group {
                switch destination {
                case .lists:
                    ListLibrary(store: store, selectedID: selected?.id) { selectedID = $0.uuidString }
                case .editor(let list):
                    ListEditor(store: store, list: list, onSaved: { selectedID = $0.uuidString })
                case .history: HistoryView(store: store)
                case .share(let list): ListShareView(list: list)
                case .importList(let list): ListImportView(list: list, store: store, onImported: { selectedID = $0.uuidString })
                }
                }
                .safeAreaInset(edge: .top) { pendingBanner }
                .alert("無法讀取清單", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                    Button("知道了") { importError = nil }
                } message: { Text(importError ?? "") }
            }
            .safeAreaInset(edge: .top) { if spinning { pendingBanner } }
            .onOpenURL { url in
                Task {
                    do { pendingImport = try await ListFileReader.read(url); presentPendingImport() }
                    catch { importError = error.localizedDescription }
                }
            }
            .onChange(of: spinning) { _, value in if !value { presentPendingImport() } }
            .alert("無法讀取清單", isPresented: Binding(get: { importError != nil && sheet == nil }, set: { if !$0 { importError = nil } })) {
                Button("知道了") { importError = nil }
            } message: { Text(importError ?? "") }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("今天吃什麼").font(.system(.title2, design: .rounded, weight: .bold)).foregroundStyle(Theme.ink)
                if !typeSize.isAccessibilitySize {
                    Text("少一點猶豫，多一點好吃的。")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 0)
            Button("抽選紀錄", systemImage: "clock.arrow.circlepath") { sheet = .history }
                .buttonStyle(RoundButtonStyle()).disabled(spinning).accessibilityLabel("抽選紀錄")
            Button("新增清單", systemImage: "plus") { newList() }
                .buttonStyle(RoundButtonStyle()).disabled(spinning).accessibilityLabel("新增清單")
        }
    }

    private func selector(_ list: FoodList) -> some View {
        Button { sheet = .lists } label: {
            HStack(spacing: 14) {
                Image(systemName: list.symbol)
                    .font(.system(size: 21, weight: .medium)).foregroundStyle(Theme.orange)
                    .frame(width: 46, height: 46).background(Theme.orangeWash, in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 5) {
                    Text("目前清單").font(.caption).foregroundStyle(Theme.muted)
                    Text(list.name).font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .padding(16).background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle()).disabled(spinning)
        .accessibilityLabel("切換清單，目前是\(list.name)")
        .accessibilityHint("查看、建立或管理所有清單")
        .accessibilityIdentifier("listSelector")
    }

    @ViewBuilder private var pendingBanner: some View {
        if pendingImport != nil {
            Label("已收到清單，完成目前操作後即可預覽匯入。", systemImage: "square.and.arrow.down")
                .font(.caption).padding(12).frame(maxWidth: .infinity).background(Theme.greenWash)
        }
    }
    private func presentPendingImport() {
        guard sheet == nil, !spinning, let list = pendingImport else { return }
        pendingImport = nil
        sheet = .importList(list)
    }
    private func newList() { sheet = .editor(FoodList(name: "", items: [])) }
}
