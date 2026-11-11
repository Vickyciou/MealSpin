import Foundation
import Observation

struct FoodList: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var symbol: String = "fork.knife"
    var items: [String]
    static let samples = [
        FoodList(name: "晚餐吃什麼（平價版）", symbol: "takeoutbag.and.cup.and.straw.fill", items: ["滷肉飯", "牛肉麵", "水餃", "雞腿便當", "鍋燒意麵", "炒飯"]),
        FoodList(name: "晚餐吃什麼（奢華版）", symbol: "sparkles", items: ["日式燒肉", "壽司", "牛排", "義式料理", "海鮮火鍋", "法式料理"]),
        FoodList(name: "早餐吃什麼", symbol: "sun.max.fill", items: ["蛋餅", "飯糰", "蘿蔔糕", "三明治", "貝果", "燒餅豆漿"])
    ]
}

struct MealDecision: Identifiable, Codable {
    var id = UUID()
    let listName: String
    let food: String
    let date: Date
}

struct SavedMeals: Codable {
    var lists: [FoodList]
    var history: [MealDecision]
}

@MainActor @Observable final class MealStore {
    enum LoadState: Equatable {
        case firstLaunch, loaded, recoveryRequired(String)
    }

    private(set) var lists: [FoodList] = []
    private(set) var history: [MealDecision] = []
    private(set) var loadState: LoadState = .firstLaunch
    private(set) var backupURL: URL?
    private(set) var backups: [URL] = []
    var errorMessage: String?
    private(set) var temporaryExclusions: [UUID: Set<String>] = [:]
    private let file: URL
    private let backupDirectory: URL
    private let writeData: (Data, URL) throws -> Void

    var needsRecovery: Bool {
        if case .recoveryRequired = loadState { return true }
        return false
    }
    var loadFailure: String? {
        if case .recoveryRequired(let message) = loadState { return message }
        return nil
    }

    init(file: URL? = nil, backupDirectory: URL? = nil,
         writeData: @escaping (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }) {
        self.file = file ?? URL.documentsDirectory.appending(path: "meals.json")
        self.backupDirectory = backupDirectory ?? self.file.deletingLastPathComponent().appending(path: "MealSpin Recovery", directoryHint: .isDirectory)
        self.writeData = writeData
        do {
            let data = try Data(contentsOf: self.file)
            let saved = try JSONDecoder().decode(SavedMeals.self, from: data)
            lists = saved.lists
            history = saved.history
            loadState = .loaded
        } catch {
            if (error as NSError).domain == NSCocoaErrorDomain,
               (error as NSError).code == NSFileReadNoSuchFileError {
                lists = FoodList.samples
                _ = commit(lists: lists, history: [])
            } else {
                protect(error)
            }
        }
        refreshBackups()
    }

    private func refreshBackups() {
        backups = ((try? FileManager.default.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("meals-") && $0.lastPathComponent.hasSuffix(".original.json") }
            .sorted { lhs, rhs in
                let left = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let right = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return left > right
            }
    }

    private func protect(_ error: Error) {
        let message = String(localized: "無法讀取已儲存的清單。原始資料已受保護，請重新讀取或保留副本後重建。") + "\n" + error.localizedDescription
        loadState = .recoveryRequired(message)
        errorMessage = message
    }

    @discardableResult func reload() -> Bool {
        do {
            let saved = try JSONDecoder().decode(SavedMeals.self, from: Data(contentsOf: file))
            apply(lists: saved.lists, history: saved.history)
            loadState = .loaded
            errorMessage = nil
            return true
        } catch {
            protect(error)
            return false
        }
    }

    @discardableResult func preserveOriginal() -> URL? {
        guard needsRecovery else { return nil }
        do {
            let data = try Data(contentsOf: file)
            try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            let backup = backupDirectory.appending(path: "meals-\(UUID().uuidString).original.json")
            try data.write(to: backup, options: .atomic)
            guard try Data(contentsOf: backup) == data else { throw CocoaError(.fileReadCorruptFile) }
            backupURL = backup
            refreshBackups()
            errorMessage = nil
            return backup
        } catch {
            errorMessage = String(localized: "無法保留原始資料副本。原始資料仍受保護，尚未重建。") + "\n" + error.localizedDescription
            return nil
        }
    }

    @discardableResult func rebuild() -> Bool {
        guard needsRecovery, preserveOriginal() != nil else { return false }
        guard write(lists: FoodList.samples, history: []) else { return false }
        loadState = .loaded
        errorMessage = nil
        return true
    }

    private func commit(lists: [FoodList], history: [MealDecision]) -> Bool {
        guard !needsRecovery else {
            errorMessage = String(localized: "原始資料已受保護。請先在首頁完成資料回復，再儲存變更。")
            return false
        }
        return write(lists: lists, history: history)
    }

    private func write(lists: [FoodList], history: [MealDecision]) -> Bool {
        do {
            let data = try JSONEncoder().encode(SavedMeals(lists: lists, history: history))
            try writeData(data, file)
            apply(lists: lists, history: history)
            return true
        } catch {
            errorMessage = String(localized: "儲存失敗，這次變更尚未保存。") + "\n" + error.localizedDescription
            return false
        }
    }

    private func apply(lists: [FoodList], history: [MealDecision]) {
        self.lists = lists
        self.history = history
        let current = Dictionary(lists.map { ($0.id, Set($0.items)) }, uniquingKeysWith: { _, latest in latest })
        temporaryExclusions = temporaryExclusions.reduce(into: [:]) { result, entry in
            if let names = current[entry.key] {
                let remaining = entry.value.intersection(names)
                if !remaining.isEmpty { result[entry.key] = remaining }
            }
        }
    }

    @discardableResult func save(_ list: FoodList) -> Bool {
        var next = lists
        if let index = next.firstIndex(where: { $0.id == list.id }) { next[index] = list }
        else { next.append(list) }
        return commit(lists: next, history: history)
    }
    @discardableResult func delete(_ list: FoodList) -> Bool { commit(lists: lists.filter { $0.id != list.id }, history: history) }
    @discardableResult func record(food: String, list: FoodList) -> Bool {
        let entry = MealDecision(listName: list.name, food: food, date: .now)
        return commit(lists: lists, history: Array(([entry] + history).prefix(100)))
    }
    func participatingItems(in list: FoodList) -> [String] {
        let excluded = temporaryExclusions[list.id] ?? []
        return list.items.filter { !excluded.contains($0) }
    }
    func isParticipating(_ food: String, in list: FoodList) -> Bool {
        !(temporaryExclusions[list.id]?.contains(food) ?? false)
    }
    func setParticipation(_ food: String, in list: FoodList, enabled: Bool) {
        guard list.items.contains(food) else { return }
        var excluded = temporaryExclusions[list.id] ?? []
        if enabled { excluded.remove(food) } else { excluded.insert(food) }
        temporaryExclusions[list.id] = excluded.isEmpty ? nil : excluded
    }
    func includeAll(in list: FoodList) { temporaryExclusions[list.id] = nil }
    @discardableResult func clearHistory() -> Bool { commit(lists: lists, history: []) }
}

// The fixed pointer is at twelve o'clock. Segment zero begins there.
enum WheelMath {
    static func targetRotation(current: Double, index: Int, count: Int, turns: Int) -> Double {
        let center = (Double(index) + 0.5) * 360 / Double(count)
        let target = (360 - center).truncatingRemainder(dividingBy: 360)
        let normalized = current.truncatingRemainder(dividingBy: 360)
        let delta = (target - normalized + 360).truncatingRemainder(dividingBy: 360)
        return current + Double(turns) * 360 + delta
    }
}

/// Portable format: includes only one list, never local IDs or decision history.
struct ListPackage: Codable {
    let format: String
    let version: Int
    let name: String
    let symbol: String
    let items: [String]

    enum PackageError: LocalizedError {
        case invalid, version, tooLarge, invalidName, tooManyItems, longItem
        var errorDescription: String? {
            switch self {
            case .invalid: return "這不是有效的「今天吃什麼」清單檔案。"
            case .version: return "這份清單使用較新的格式，請更新 App 後再試。"
            case .tooLarge: return "檔案太大，請選擇小於 1 MB 的清單檔案。"
            case .invalidName: return "清單名稱不可空白，且需在 120 個字以內。"
            case .tooManyItems: return "一份分享清單最多可包含 500 個選項。"
            case .longItem: return "每個選項需在 200 個字以內。"
            }
        }
    }
    static let maxBytes = 1_048_576
    static func encode(_ list: FoodList) throws -> Data {
        let package = ListPackage(format: "mealspin-list", version: 1, name: list.name, symbol: list.symbol, items: list.items)
        _ = try package.makeList()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(package)
        guard data.count <= maxBytes else { throw PackageError.tooLarge }
        return data
    }
    static func decode(_ data: Data) throws -> FoodList {
        guard data.count <= maxBytes else { throw PackageError.tooLarge }
        guard let package = try? JSONDecoder().decode(ListPackage.self, from: data) else { throw PackageError.invalid }
        return try package.makeList()
    }
    private func makeList() throws -> FoodList {
        guard format == "mealspin-list" else { throw PackageError.invalid }
        guard version == 1 else { throw PackageError.version }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 120 else { throw PackageError.invalidName }
        guard items.count <= 500 else { throw PackageError.tooManyItems }
        guard items.allSatisfy({ $0.count <= 200 }) else { throw PackageError.longItem }
        var seen = Set<String>()
        let clean = items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && seen.insert($0).inserted }
        let supported = ["fork.knife", "takeoutbag.and.cup.and.straw.fill", "sparkles", "sun.max.fill", "cup.and.saucer.fill", "birthday.cake.fill"]
        return FoodList(name: title, symbol: supported.contains(symbol) ? symbol : "fork.knife", items: clean)
    }
}
