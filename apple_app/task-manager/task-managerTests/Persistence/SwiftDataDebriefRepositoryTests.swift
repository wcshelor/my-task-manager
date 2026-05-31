import Foundation
import SwiftData
import Testing
@testable import task_manager

struct SwiftDataDebriefRepositoryTests {
    @Test @MainActor func debriefRepositoryRoundTripsSavedDebrief() throws {
        let repository = try makeRepository()
        let debriefID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174010")!
        let debrief = CalendarDebriefRecord(
            id: debriefID,
            eventKey: "event-key-1",
            eventIdentifier: "event-1",
            calendarIdentifier: "work-cal",
            calendarTitleSnapshot: "Work",
            titleSnapshot: "Weekly meeting",
            startDateSnapshot: Date(timeIntervalSince1970: 1_000),
            endDateSnapshot: Date(timeIntervalSince1970: 2_800),
            templateKind: .meeting,
            status: .completed,
            essentialNote: "Agreed on milestones",
            createdCaptureIDs: [UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!],
            meetingOutcomes: "Milestones assigned",
            meetingFollowUps: "Send notes",
            meetingUsefulnessRating: 4,
            taskOutcomes: [
                DebriefTaskOutcome(
                    debriefID: debriefID,
                    taskID: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174001")!,
                    taskTitleSnapshot: "Finish outline",
                    outcome: .completed,
                    note: "Wrapped up the draft",
                    didUpdateTaskStatus: true,
                    createdAt: Date(timeIntervalSince1970: 3_000)
                )
            ]
        )

        try repository.saveDebrief(debrief, replacingDebriefWithID: nil)

        let fetchedDebrief = try repository.debrief(withID: debrief.id)

        #expect(fetchedDebrief == debrief)
    }

    @Test @MainActor func debriefRepositoryCanFindByEventKey() throws {
        let repository = try makeRepository()
        let debrief = CalendarDebriefRecord(
            eventKey: "event-key-2",
            eventIdentifier: "event-2",
            calendarIdentifier: "social-cal",
            calendarTitleSnapshot: "Personal",
            titleSnapshot: "Dinner",
            startDateSnapshot: Date(timeIntervalSince1970: 5_000),
            endDateSnapshot: Date(timeIntervalSince1970: 7_200),
            templateKind: .social,
            status: .pending
        )

        try repository.saveDebrief(debrief, replacingDebriefWithID: nil)

        #expect(try repository.debrief(withEventKey: "event-key-2")?.id == debrief.id)
    }

    @Test @MainActor func debriefRepositoryUpdatesExistingRecordByEventKey() throws {
        let repository = try makeRepository()
        let existing = CalendarDebriefRecord(
            eventKey: "event-key-3",
            eventIdentifier: "event-3",
            calendarIdentifier: "work-cal",
            calendarTitleSnapshot: "Work",
            titleSnapshot: "Focus block",
            startDateSnapshot: Date(timeIntervalSince1970: 10_000),
            endDateSnapshot: Date(timeIntervalSince1970: 12_000),
            templateKind: .workBlock,
            status: .pending
        )
        let updated = CalendarDebriefRecord(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!,
            eventKey: existing.eventKey,
            eventIdentifier: existing.eventIdentifier,
            calendarIdentifier: existing.calendarIdentifier,
            calendarTitleSnapshot: existing.calendarTitleSnapshot,
            titleSnapshot: existing.titleSnapshot,
            startDateSnapshot: existing.startDateSnapshot,
            endDateSnapshot: existing.endDateSnapshot,
            templateKind: .workBlock,
            createdAt: existing.createdAt,
            status: .completed,
            essentialNote: "Loop closed"
        )

        try repository.saveDebrief(existing, replacingDebriefWithID: nil)
        try repository.saveDebrief(updated, replacingDebriefWithID: nil)

        let allDebriefs = try repository.fetchDebriefs()

        #expect(allDebriefs.count == 1)
        #expect(allDebriefs.first?.status == .completed)
        #expect(allDebriefs.first?.id == updated.id)
    }

    @Test @MainActor func debriefRepositoryDeletesDebrief() throws {
        let repository = try makeRepository()
        let debrief = CalendarDebriefRecord(
            eventKey: "event-key-4",
            eventIdentifier: "event-4",
            calendarIdentifier: "work-cal",
            calendarTitleSnapshot: "Work",
            titleSnapshot: "Admin block",
            startDateSnapshot: Date(timeIntervalSince1970: 20_000),
            endDateSnapshot: Date(timeIntervalSince1970: 21_000),
            templateKind: .workBlock,
            status: .skipped,
            noDebriefNeeded: true
        )

        try repository.saveDebrief(debrief, replacingDebriefWithID: nil)
        try repository.deleteDebrief(withID: debrief.id)

        #expect(try repository.fetchDebriefs().isEmpty)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataDebriefRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataDebriefRepository(modelContainer: container)
    }
}
