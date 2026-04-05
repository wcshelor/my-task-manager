import Foundation
import Testing
@testable import task_manager

struct SwiftDataScheduledBlockRepositoryTests {
    @Test @MainActor func scheduledBlockRepositoryRoundTripsSavedBlock() throws {
        let repository = try makeRepository()
        let taskID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        let block = ScheduledBlock(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!,
            taskID: taskID,
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_800),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-123",
            calendarTitle: "Important",
            eventTitleSnapshot: "Plan sprint"
        )

        try repository.saveScheduledBlock(block, replacingBlockWithID: nil)

        let fetchedBlocks = try repository.fetchScheduledBlocks(for: taskID)

        #expect(fetchedBlocks == [block])
    }

    @Test @MainActor func scheduledBlockRepositoryFiltersByTaskID() throws {
        let repository = try makeRepository()
        let firstTaskID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        let secondTaskID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174001")!

        try repository.saveScheduledBlock(
            ScheduledBlock(
                taskID: firstTaskID,
                start: Date(timeIntervalSince1970: 1_000),
                end: Date(timeIntervalSince1970: 2_000),
                status: .accepted,
                calendarLinkState: .linked
            ),
            replacingBlockWithID: nil
        )
        try repository.saveScheduledBlock(
            ScheduledBlock(
                taskID: secondTaskID,
                start: Date(timeIntervalSince1970: 3_000),
                end: Date(timeIntervalSince1970: 4_000)
            ),
            replacingBlockWithID: nil
        )

        let firstTaskBlocks = try repository.fetchScheduledBlocks(for: firstTaskID)

        #expect(firstTaskBlocks.count == 1)
        #expect(firstTaskBlocks.first?.taskID == firstTaskID)
    }

    @Test @MainActor func scheduledBlockRepositoryDeletesBlock() throws {
        let repository = try makeRepository()
        let block = ScheduledBlock(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!,
            taskID: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!,
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_000)
        )

        try repository.saveScheduledBlock(block, replacingBlockWithID: nil)
        try repository.deleteScheduledBlock(withID: block.id)

        #expect(try repository.fetchScheduledBlocks().isEmpty)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataScheduledBlockRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataScheduledBlockRepository(modelContainer: container)
    }
}
