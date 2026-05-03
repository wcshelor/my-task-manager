import Foundation
import Testing
@testable import task_manager

struct SwiftDataPromiseRepositoryTests {
    @Test @MainActor func promiseRepositoryRoundTripsPromise() throws {
        let repository = try makeRepository()
        let promise = Promise(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!,
            title: "No weed until 6 PM",
            notes: "Keep it visible",
            startAt: Date(timeIntervalSince1970: 1_000),
            checkInAt: Date(timeIntervalSince1970: 2_000),
            whyItMatters: "Self-trust",
            expectedFriction: "Boredom",
            createdAt: Date(timeIntervalSince1970: 900)
        )

        try repository.savePromise(promise, replacingPromiseWithID: nil)

        #expect(try repository.promise(withID: promise.id) == promise)
    }

    @Test @MainActor func promiseRepositoryFiltersActiveAndHistory() throws {
        let repository = try makeRepository()
        let now = Date(timeIntervalSince1970: 2_000)
        let activePromise = Promise(
            title: "Active",
            startAt: Date(timeIntervalSince1970: 1_000),
            checkInAt: Date(timeIntervalSince1970: 3_000)
        )
        let resolvedPromise = Promise(
            title: "Resolved",
            startAt: Date(timeIntervalSince1970: 500),
            checkInAt: Date(timeIntervalSince1970: 600)
        ).resolved(
            outcome: .kept,
            reflection: nil,
            resolvedAt: Date(timeIntervalSince1970: 4_000)
        )

        try repository.savePromise(activePromise, replacingPromiseWithID: nil)
        try repository.savePromise(resolvedPromise, replacingPromiseWithID: nil)

        #expect(try repository.fetchActivePromises(at: now).map(\.title) == ["Active"])
        #expect(try repository.fetchPromiseHistory().map(\.outcome) == [.kept])
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataPromiseRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataPromiseRepository(modelContainer: container)
    }
}
