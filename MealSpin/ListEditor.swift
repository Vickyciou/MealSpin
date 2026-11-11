import SwiftUI

private struct DraftFood: Identifiable {
    let id = UUID()
    var name: String
}

struct ListEditor: View {
    let store: MealStore
    private let original: FoodList
    var onSaved: (UUID) -> Void
    @State private var name: String
    @State private var symbol: String
    @State private var options: [DraftFood]
    @State private var newItem = ""
    @State private var feedback: String?
    @State private var editMode: EditMode = .inactive
    @State private var saveError: String?
    @State private var discard = false
    private enum Field: Hashable { case name, newItem }
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss
    private let symbols: [(String, LocalizedStringResource)] = [("fork.knife", "餐點"), ("takeoutbag.and.cup.and.straw.fill", "外帶"), ("sparkles", "犒賞"), ("sun.max.fill", "早餐"), ("cup.and.saucer.fill", "咖啡"), ("birthday.cake.fill", "甜點")]

    init(store: MealStore, list: FoodList, onSaved: @escaping (UUID) -> Void = { _ in }) {
        self.store = store
        original = list
        self.onSaved = onSaved
        _name = State(initialValue: list.name)
        _symbol = State(initialValue: list.symbol)
        _options = State(initialValue: list.items.map { DraftFood(name: $0) })
    }
    private var isNew: Bool { !store.lists.contains { $0.id == original.id } }
    private var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var dirty: Bool { name != original.name || symbol != original.symbol || options.map(\.name) != original.items || !newItem.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例如：晚餐吃什麼（平價版）", text: $name, axis: .vertical)
                        .font(.headline).lineLimit(1...3).padding(.vertical, 6)
                        .accessibilityLabel("清單名稱").accessibilityIdentifier("listNameField")
                        .focused($focusedField, equals: .name)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
                        ForEach(symbols, id: \.0) { value in
                            Button { symbol = value.0 } label: {
                                Image(systemName: value.0).font(.system(size: 20))
                                    .foregroundStyle(symbol == value.0 ? Theme.orange : Theme.muted)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(symbol == value.0 ? Theme.orangeWash : Theme.cream, in: RoundedRectangle(cornerRadius: 13))
                                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(symbol == value.0 ? Theme.orange : .clear, lineWidth: 1.5))
                            }.buttonStyle(.borderless).accessibilityLabel(Text(value.1))
                                .accessibilityAddTraits(symbol == value.0 ? .isSelected : [])
                        }
                    }.padding(.vertical, 6)
                } header: { Text("清單資訊") }
                footer: { if !valid { Text("先為這份清單取個名字，再加入想吃的選項。") } }

                Section {
                    HStack(alignment: .center, spacing: 8) {
                        TextField("新增餐廳或食物", text: $newItem, axis: .vertical)
                            .accessibilityIdentifier("newFoodField")
                            .lineLimit(1...4).focused($focusedField, equals: .newItem).submitLabel(.done)
                            .onSubmit(addItems)
                        Button("加入", systemImage: "plus.circle.fill", action: addItems)
                            .labelStyle(.iconOnly).font(.title2).frame(width: 44, height: 44)
                            .buttonStyle(.borderless).disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if let feedback { Text(feedback).font(.caption).foregroundStyle(Theme.green) }
                } header: { Text("想吃什麼？") }
                footer: { Text("可貼上多行文字，一行一個選項；儲存時也會一起加入。") }

                Section {
                    if options.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "carrot").font(.title2).foregroundStyle(Theme.orange)
                            Text("口袋名單等你填滿").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                            Text("例如：巷口牛肉麵、蛋餅、日式燒肉")
                                .font(.caption).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity).padding(.vertical, 20)
                    }
                    ForEach($options) { $option in
                        HStack(spacing: 8) {
                            Circle().fill(Theme.orange.opacity(0.7)).frame(width: 6, height: 6).accessibilityHidden(true)
                            TextField("餐廳或食物", text: $option.name)
                            if editMode != .active {
                                Button("刪除\(option.name)", systemImage: "minus.circle") {
                                    options.removeAll { $0.id == option.id }
                                }.labelStyle(.iconOnly).foregroundStyle(Theme.muted)
                                    .frame(width: 44, height: 44).buttonStyle(.borderless)
                            }
                        }.frame(minHeight: 44)
                    }
                    .onDelete { options.remove(atOffsets: $0) }
                    .onMove { options.move(fromOffsets: $0, toOffset: $1) }
                } header: {
                    HStack {
                        Text("\(options.count) 個選項")
                        Spacer()
                        Button(editMode == .active ? String(localized: "完成排序") : String(localized: "排序")) {
                            focusedField = nil
                            withAnimation { editMode = editMode == .active ? .inactive : .active }
                        }.font(.caption.weight(.semibold)).frame(minHeight: 44).disabled(options.count < 2)
                    }
                } footer: { Text("選項機率相同。空白與重複名稱會在儲存時自動整理。") }
            }
            .environment(\.editMode, $editMode)
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden).background(Theme.cream)
            .navigationTitle(isNew ? String(localized: "新增清單") : String(localized: "編輯清單")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { focusedField = nil; if dirty { discard = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) { Button("儲存", action: save).fontWeight(.semibold).disabled(!valid) }
            }
            .interactiveDismissDisabled(dirty)
            .alert("要放棄這次修改嗎？", isPresented: $discard) {
                Button("放棄修改", role: .destructive) { dismiss() }
                Button("繼續編輯", role: .cancel) { }
            } message: { Text("尚未儲存的內容將不會保留。") }
            .alert("無法儲存", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("知道了") { saveError = nil }
            } message: { Text(saveError ?? "") }
        }.presentationDragIndicator(.visible)
    }

    private func addItems() {
        let incoming = newItem.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var seen = Set(options.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) })
        let added = incoming.filter { seen.insert($0).inserted }
        options.append(contentsOf: added.map { DraftFood(name: $0) })
        if !incoming.isEmpty { feedback = added.isEmpty ? String(localized: "這些選項已經在清單裡囉。") : String(localized: "已加入 \(added.count) 個選項") }
        newItem = ""
    }
    private func save() {
        addItems()
        var next = original
        next.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        next.symbol = symbol
        var seen = Set<String>()
        next.items = options.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0).inserted }
        if store.save(next) { onSaved(next.id); dismiss() }
        else { saveError = store.errorMessage; store.errorMessage = nil }
    }
}
