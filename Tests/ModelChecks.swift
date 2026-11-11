import Foundation

@main struct ModelChecks {
    @MainActor static func main() throws {
        func tryRead(_ url: URL) -> Data { try! Data(contentsOf: url) }
        // Check the pointer against every segment, after repeated spins.
        var current = 0.0
        for count in 1...100 {
            for index in 0..<count {
                let target = WheelMath.targetRotation(current: current, index: index, count: count, turns: 5)
                precondition(target - current >= 1800)
                let pointerAngle = (360 - target.truncatingRemainder(dividingBy: 360)).truncatingRemainder(dividingBy: 360)
                precondition(Int(pointerAngle / (360 / Double(count))) == index)
                current = target
            }
        }
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "meals.json")
        let store = MealStore(file: file)
        precondition(store.lists.count == 3)
        precondition(MealStore(file: file).lists == store.lists, "首次建立的預設清單也需保留識別碼")
        var list = FoodList(name: "測試早餐", items: ["蛋餅", "飯糰"])
        precondition(store.save(list))
        list.name = "修改後的早餐"
        precondition(store.save(list))
        store.record(food: "蛋餅", list: list)
        let restored = MealStore(file: file)
        precondition(restored.lists.last == list)
        precondition(restored.history.first?.food == "蛋餅")
        restored.delete(list)
        precondition(!MealStore(file: file).lists.contains(where: { $0.id == list.id }))
        restored.clearHistory()
        precondition(MealStore(file: file).history.isEmpty)
        let broken = MealStore(file: directory.appending(path: "missing/fail.json"))
        precondition(!broken.save(list))
        precondition(broken.errorMessage != nil && broken.lists.count == 3)
        try Data("invalid json".utf8).write(to: file)
        let corrupt = MealStore(file: file)
        precondition(corrupt.errorMessage != nil)
        let original = try String(contentsOf: file, encoding: .utf8)
        precondition(original == "invalid json")
        let protectedFile = directory.appending(path: "protected.json")
        let damagedBytes = Data("damaged original bytes".utf8)
        try damagedBytes.write(to: protectedFile)
        let protected = MealStore(file: protectedFile)
        precondition(protected.needsRecovery)
        protected.errorMessage = nil
        let protectedWrites: [() -> Bool] = [{ protected.save(list) }, { protected.delete(list) }, { protected.record(food: "蛋餅", list: list) }, { protected.clearHistory() }]
        for attempt in protectedWrites {
            protected.errorMessage = nil
            precondition(!attempt())
            precondition(tryRead(protectedFile) == damagedBytes)
        }
        let restartedProtected = MealStore(file: protectedFile)
        precondition(restartedProtected.needsRecovery)
        let restartedWrites: [() -> Bool] = [{ restartedProtected.save(list) }, { restartedProtected.delete(list) }, { restartedProtected.record(food: "蛋餅", list: list) }, { restartedProtected.clearHistory() }]
        for attempt in restartedWrites {
            restartedProtected.errorMessage = nil
            precondition(!attempt())
            precondition(tryRead(protectedFile) == damagedBytes)
        }
        precondition(!protected.reload())
        precondition(tryRead(protectedFile) == damagedBytes)
        let backup = protected.preserveOriginal()!
        precondition(tryRead(backup) == damagedBytes)
        precondition(protected.needsRecovery)
        let goodData = try JSONEncoder().encode(SavedMeals(lists: [list], history: [MealDecision(listName: list.name, food: "蛋餅", date: .now)]))
        try goodData.write(to: protectedFile)
        precondition(protected.reload())
        precondition(!protected.needsRecovery && protected.lists == [list] && protected.history.count == 1)
        precondition(protected.save(list))
        try damagedBytes.write(to: protectedFile)
        let recovery = MealStore(file: protectedFile)
        precondition(recovery.rebuild())
        precondition(!recovery.needsRecovery && recovery.lists.count == 3)
        precondition(tryRead(recovery.backupURL!) == damagedBytes)
        precondition(MealStore(file: protectedFile).lists == recovery.lists)
        let discoveredBackups = MealStore(file: protectedFile).backups
        precondition(discoveredBackups.contains { $0.resolvingSymlinksInPath() == recovery.backupURL!.resolvingSymlinksInPath() })
        precondition(discoveredBackups.contains { tryRead($0) == damagedBytes })
        try damagedBytes.write(to: protectedFile)
        let blocker = directory.appending(path: "backup-blocker")
        try Data().write(to: blocker)
        let backupFailure = MealStore(file: protectedFile, backupDirectory: blocker)
        precondition(!backupFailure.rebuild() && backupFailure.needsRecovery)
        precondition(tryRead(protectedFile) == damagedBytes)
        let writeFailure = MealStore(file: protectedFile, writeData: { _, _ in throw CocoaError(.fileWriteNoPermission) })
        precondition(!writeFailure.rebuild() && writeFailure.needsRecovery)
        precondition(writeFailure.lists.isEmpty && writeFailure.errorMessage != nil)
        precondition(tryRead(writeFailure.backupURL!) == damagedBytes)
        precondition(tryRead(protectedFile) == damagedBytes)
        try FileManager.default.removeItem(at: protectedFile)
        precondition(!writeFailure.reload() && !writeFailure.rebuild() && writeFailure.needsRecovery)
        let emptyFile = directory.appending(path: "empty.json")
        try JSONEncoder().encode(SavedMeals(lists: [], history: [])).write(to: emptyFile)
        let legitimateEmpty = MealStore(file: emptyFile)
        precondition(!legitimateEmpty.needsRecovery && legitimateEmpty.lists.isEmpty)
        let shared = FoodList(name: " 早餐 ", symbol: "sun.max.fill", items: [" 蛋餅 ", "飯糰", "", "蛋餅"])
        let exported = try ListPackage.encode(shared)
        let decoded = try ListPackage.decode(exported)
        precondition(decoded.name == "早餐" && decoded.items == ["蛋餅", "飯糰"])
        precondition(decoded.id != shared.id && decoded.symbol == shared.symbol)
        let json = try JSONSerialization.jsonObject(with: exported) as! [String: Any]
        precondition(json["id"] == nil && json["history"] == nil)
        let beforeCount = store.lists.count
        precondition(store.save(decoded))
        let secondCopy = try ListPackage.decode(exported)
        precondition(store.save(secondCopy))
        precondition(store.lists.count == beforeCount + 2)
        func rejects(_ data: Data) {
            do { _ = try ListPackage.decode(data); preconditionFailure("不應接受無效清單") }
            catch { }
        }
        rejects(Data("not a list".utf8))
        rejects(Data(repeating: 32, count: ListPackage.maxBytes + 1))
        for (key, value) in [("version", 999 as Any), ("format", "other-app" as Any), ("name", " " as Any), ("items", Array(repeating: "蛋餅", count: 501) as Any), ("items", [String(repeating: "a", count: 201)] as Any)] {
            var invalid = json
            invalid[key] = value
            rejects(try JSONSerialization.data(withJSONObject: invalid))
        }
        var unknownSymbol = json
        unknownSymbol["symbol"] = "not-a-system-symbol"
        let fallback = try ListPackage.decode(JSONSerialization.data(withJSONObject: unknownSymbol))
        precondition(fallback.symbol == "fork.knife")
        let empty = try ListPackage.decode(ListPackage.encode(FoodList(name: "空清單", items: [])))
        precondition(empty.items.isEmpty)
        let sessionFile = directory.appending(path: "session.json")
        let session = MealStore(file: sessionFile)
        let source = session.lists[0]
        let other = session.lists[1]
        for food in source.items.dropFirst() { session.setParticipation(food, in: source, enabled: false) }
        precondition(session.participatingItems(in: source) == [source.items[0]])
        precondition(session.lists[0].items == source.items)
        precondition(session.participatingItems(in: other) == other.items)
        session.record(food: source.items[0], list: source)
        precondition(session.participatingItems(in: source).count == 1)
        let sharedFullList = try ListPackage.decode(ListPackage.encode(source))
        precondition(sharedFullList.items == source.items)
        let restarted = MealStore(file: sessionFile)
        precondition(restarted.participatingItems(in: restarted.lists[0]) == source.items)
        session.includeAll(in: source)
        precondition(session.participatingItems(in: source) == source.items)
        for food in source.items { session.setParticipation(food, in: source, enabled: false) }
        precondition(session.participatingItems(in: source).isEmpty)
        session.setParticipation(source.items[0], in: source, enabled: true)
        precondition(session.participatingItems(in: source) == [source.items[0]])
        var edited = source
        edited.items = [source.items[0], "新餐廳"]
        precondition(session.save(edited))
        precondition(session.participatingItems(in: edited) == edited.items)
        session.setParticipation("新餐廳", in: edited, enabled: false)
        session.delete(edited)
        precondition(session.temporaryExclusions[edited.id] == nil)
        print("PASS: 5,050 pointer checks; create/edit/delete/reload; history; save failure; protected writes/reload/backup/rebuild failures; sharing round-trip; independent copies; privacy; malformed/version/size validation; session exclusions/filter/reset/share/edit/delete")
    }
}
