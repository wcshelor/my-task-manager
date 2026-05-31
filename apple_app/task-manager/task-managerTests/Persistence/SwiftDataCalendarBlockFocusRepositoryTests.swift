import Foundation
import SwiftData
import Testing
@testable import task_manager

struct SwiftDataCalendarBlockFocusRepositoryTests {
    @Test @MainActor func repositoryRoundTripsSavedFocus() throws {
        let repository = try makeRepository()
        let event = CalendarEventSnapshot(
            identifier: "event-1",
            calendarIdentifier: "work-cal",
            title: "BERThoven work block",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_800),
            isAllDay: false,
            calendarTitle: "Work"
        )
        let projectID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174321")!
        let focus = CalendarBlockFocus(
            event: event,
            linkedProjectID: projectID,
            selectedTaskIDs: [UUID(uuidString: "123E4567-E89B-12D3-A456-426614174322")!],
            intentionNote: "Finish parser",
            preferredDebriefTemplateKind: .workBlock,
            isProjectLinkUserConfirmed: true,
            createdAt: Date(timeIntervalSince1970: 500)
        )

        try repository.saveFocus(focus, replacingFocusWithID: nil)

        let fetched = try repository.fetchFocus(
            forEventIdentifier: event.identifier!,
            calendarIdentifier: event.calendarIdentifier!
        )

        #expect(fetched == focus)
    }

    @Test @MainActor func repositoryUpdatesAndFetchesByProjectAndRange() throws {
        let repository = try makeRepository()
        let projectID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174321")!
        let firstEvent = CalendarEventSnapshot(
            identifier: "event-1",
            calendarIdentifier: "work-cal",
            title: "BERThoven work block",
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_800),
            isAllDay: false,
            calendarTitle: "Work"
        )
        let secondEvent = CalendarEventSnapshot(
            identifier: "event-2",
            calendarIdentifier: "work-cal",
            title: "Other work block",
            start: Date(timeIntervalSince1970: 5_000),
            end: Date(timeIntervalSince1970: 6_800),
            isAllDay: false,
            calendarTitle: "Work"
        )

        try repository.setLinkedProject(projectID, for: firstEvent, isUserConfirmed: true)
        try repository.setSelectedTaskIDs(
            [UUID(uuidString: "123E4567-E89B-12D3-A456-426614174322")!],
            for: firstEvent
        )
        try repository.updateIntentionNote("Draft the outline", for: firstEvent)
        try repository.markNoFocusNeeded(for: secondEvent, isNoFocusNeeded: true)

        let projectFocuses = try repository.fetchFocuses(linkedTo: projectID)
        let rangeFocuses = try repository.fetchFocuses(
            in: DateInterval(
                start: Date(timeIntervalSince1970: 0),
                end: Date(timeIntervalSince1970: 10_000)
            )
        )

        #expect(projectFocuses.count == 1)
        #expect(projectFocuses.first?.intentionNote == "Draft the outline")
        #expect(projectFocuses.first?.selectedTaskIDs.count == 1)
        #expect(rangeFocuses.count == 2)
        #expect(rangeFocuses.contains { $0.isNoFocusNeeded })
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataCalendarBlockFocusRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataCalendarBlockFocusRepository(modelContainer: container)
    }
}
