import Foundation

@MainActor final class ControlledReader {
    private var calls: [URL: CheckedContinuation<FoodList, Error>] = [:]
    private var starts: [URL: CheckedContinuation<Void, Never>] = [:]

    func read(_ url: URL) async throws -> FoodList {
        try await withCheckedThrowingContinuation { continuation in
            calls[url] = continuation
            starts.removeValue(forKey: url)?.resume()
        }
    }
    func started(_ url: URL) async {
        if calls[url] != nil { return }
        await withCheckedContinuation { starts[url] = $0 }
    }
    func finish(_ url: URL, _ result: Result<FoodList, Error>) {
        calls.removeValue(forKey: url)!.resume(with: result)
    }
}

@main struct ImportChecks {
    @MainActor static func main() async {
        let a = URL(fileURLWithPath: "/a.mealspin")
        let b = URL(fileURLWithPath: "/b.mealspin")
        let first = FoodList(name: "A", items: ["A"])
        let latest = FoodList(name: "B", items: ["B"])
        let reader = ControlledReader()
        let coordinator = ListImportCoordinator(reader: reader.read)

        let oldSuccess = coordinator.start(a)
        await reader.started(a)
        let newSuccess = coordinator.start(b)
        await reader.started(b)
        reader.finish(b, .success(latest))
        await newSuccess.value
        reader.finish(a, .success(first))
        await oldSuccess.value
        precondition(coordinator.takePending() == .ready(latest))

        let oldFailure = coordinator.start(a)
        await reader.started(a)
        let replacement = coordinator.start(b)
        await reader.started(b)
        reader.finish(b, .success(latest))
        await replacement.value
        reader.finish(a, .failure(CocoaError(.fileReadCorruptFile)))
        await oldFailure.value
        precondition(coordinator.takePending() == .ready(latest))
        precondition(coordinator.state == .idle)

        let cancelledSuccess = coordinator.start(a)
        await reader.started(a)
        coordinator.cancel()
        reader.finish(a, .success(first))
        await cancelledSuccess.value
        precondition(coordinator.state == .idle)

        let cancelledFailure = coordinator.start(a)
        await reader.started(a)
        coordinator.cancel()
        reader.finish(a, .failure(CocoaError(.fileReadNoPermission)))
        await cancelledFailure.value
        precondition(coordinator.state == .idle)

        let currentFailure = coordinator.start(b)
        await reader.started(b)
        reader.finish(b, .failure(CocoaError(.fileReadCorruptFile)))
        await currentFailure.value
        precondition(coordinator.takePending() == .failed(CocoaError(.fileReadCorruptFile).localizedDescription))

        let pending = coordinator.start(a)
        await reader.started(a)
        reader.finish(a, .success(first))
        await pending.value
        precondition(coordinator.state == .ready(first))
        let teardown = coordinator.start(b)
        precondition(coordinator.state != .ready(first), "新請求使尚未呈現的結果失效")
        await reader.started(b)
        coordinator.cancel()
        reader.finish(b, .success(latest))
        await teardown.value
        precondition(coordinator.takePending() == .idle)
        print("PASS: controlled reverse completion; stale success/error; cancellation; pending invalidation; teardown")
    }
}
