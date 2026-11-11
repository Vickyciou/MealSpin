import Foundation
import Observation

@MainActor @Observable final class ListImportCoordinator {
    enum State: Equatable {
        case idle, reading(UUID), ready(FoodList), failed(String)
    }

    private(set) var state: State = .idle
    @ObservationIgnored private var task: Task<Void, Never>?
    private let reader: (URL) async throws -> FoodList

    init(reader: @escaping (URL) async throws -> FoodList) { self.reader = reader }

    @discardableResult func start(_ url: URL) -> Task<Void, Never> {
        cancel()
        let request = UUID()
        state = .reading(request)
        let reader = reader
        let next = Task { [weak self] in
            do {
                let list = try await reader(url)
                guard !Task.isCancelled, let self, self.state == .reading(request) else { return }
                self.state = .ready(list)
                self.task = nil
            } catch {
                guard !Task.isCancelled, let self, self.state == .reading(request) else { return }
                self.state = error is CancellationError ? .idle : .failed(error.localizedDescription)
                self.task = nil
            }
        }
        task = next
        return next
    }

    func cancel() {
        task?.cancel()
        task = nil
        state = .idle
    }

    func takePending() -> State {
        switch state {
        case .ready, .failed:
            let pending = state
            state = .idle
            return pending
        case .idle, .reading:
            return .idle
        }
    }
}
