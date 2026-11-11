import SwiftUI

struct HistoryView: View {
    let store: MealStore
    @Environment(\.dismiss) private var dismiss
    @State private var clear = false
    private var days: [Date] { Set(store.history.map { Calendar.current.startOfDay(for: $0.date) }).sorted(by: >) }
    var body: some View {
        NavigationStack {
            Group {
                if store.history.isEmpty {
                    ContentUnavailableView("美味的紀錄，從下一餐開始", systemImage: "clock", description: Text("每次轉盤的決定都會保存在這裡。"))
                } else {
                    List {
                        ForEach(days, id: \.self) { day in
                            Section(dayTitle(day)) {
                                ForEach(store.history.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }) { entry in
                                    HStack(alignment: .top, spacing: 14) {
                                        Image(systemName: "fork.knife").font(.body).foregroundStyle(Theme.green)
                                            .frame(width: 42, height: 42).background(Theme.greenWash, in: RoundedRectangle(cornerRadius: 13))
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(entry.food).accessibilityIdentifier("historyFood").font(.headline).foregroundStyle(Theme.ink)
                                            Text(entry.listName).font(.caption).foregroundStyle(Theme.muted)
                                        }
                                        Spacer(minLength: 4)
                                        Text(entry.date, format: .dateTime.hour().minute()).font(.caption.monospacedDigit()).foregroundStyle(Theme.muted)
                                    }.padding(.vertical, 8).listRowBackground(Theme.card)
                                }
                            }
                        }
                        Text("保留最近 100 次決定").font(.caption).foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }.scrollContentBackground(.hidden)
                }
            }.background(Theme.cream)
                .navigationTitle("最近吃了什麼").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } }
                    ToolbarItem(placement: .primaryAction) {
                        Menu { Button("清除所有紀錄", systemImage: "trash", role: .destructive) { clear = true } }
                        label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                        .accessibilityLabel("管理紀錄").disabled(store.history.isEmpty)
                    }
                }
                .confirmationDialog("清除所有抽選紀錄？", isPresented: $clear, titleVisibility: .visible) {
                    Button("清除所有紀錄", role: .destructive) { store.clearHistory() }
                } message: { Text("清單與食物選項仍會保留。") }
        }.presentationDragIndicator(.visible)
    }
    private func dayTitle(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "今天" }
        if Calendar.current.isDateInYesterday(date) { return "昨天" }
        return date.formatted(.dateTime.month().day())
    }
}
