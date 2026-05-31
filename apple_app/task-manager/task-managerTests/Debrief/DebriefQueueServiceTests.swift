import Foundation
import Testing
@testable import task_manager

struct DebriefQueueServiceTests {
    @Test func queueFiltersEndedEventsAndResolvedDebriefs() {
        let now = Date(timeIntervalSince1970: 10_000)
        let workEvent = CalendarEventSnapshot(
            identifier: "work-1",
            calendarIdentifier: "work-cal",
            title: "Deep Work",
            start: now.addingTimeInterval(-7_200),
            end: now.addingTimeInterval(-3_600),
            isAllDay: false,
            calendarTitle: "Work"
        )
        let allDayEvent = CalendarEventSnapshot(
            identifier: "all-day",
            calendarIdentifier: "personal-cal",
            title: "All day",
            start: now.addingTimeInterval(-20_000),
            end: now.addingTimeInterval(-10_000),
            isAllDay: true,
            calendarTitle: "Personal"
        )
        let shortEvent = CalendarEventSnapshot(
            identifier: "short",
            calendarIdentifier: "work-cal",
            title: "Quick chat",
            start: now.addingTimeInterval(-900),
            end: now.addingTimeInterval(-300),
            isAllDay: false,
            calendarTitle: "Work"
        )
        let passiveEvent = CalendarEventSnapshot(
            identifier: "birthday",
            calendarIdentifier: "work-cal",
            title: "Birthday",
            start: now.addingTimeInterval(-3_000),
            end: now.addingTimeInterval(-1_200),
            isAllDay: false,
            calendarTitle: "Work"
        )
        let stillRunning = CalendarEventSnapshot(
            identifier: "running",
            calendarIdentifier: "work-cal",
            title: "Ongoing",
            start: now.addingTimeInterval(-600),
            end: now.addingTimeInterval(1_800),
            isAllDay: false,
            calendarTitle: "Work"
        )
        let workEventKey = DebriefEventKey.from(
            eventIdentifier: workEvent.identifier,
            title: workEvent.title,
            start: workEvent.start,
            end: workEvent.end,
            calendarIdentifier: workEvent.calendarIdentifier,
            calendarTitle: workEvent.calendarTitle
        )
        let completedDebrief = CalendarDebriefRecord(
            eventKey: workEventKey,
            eventIdentifier: workEvent.identifier,
            calendarIdentifier: workEvent.calendarIdentifier,
            calendarTitleSnapshot: workEvent.calendarTitle,
            titleSnapshot: workEvent.title,
            startDateSnapshot: workEvent.start,
            endDateSnapshot: workEvent.end,
            templateKind: .workBlock,
            status: .completed
        )

        let candidates = DebriefQueueService().pendingCandidates(
            from: [workEvent, allDayEvent, shortEvent, passiveEvent, stillRunning],
            existingDebriefs: [completedDebrief],
            now: now
        )

        #expect(candidates.isEmpty)
    }

    @Test func queueKeepsPendingDebriefCandidates() {
        let now = Date(timeIntervalSince1970: 20_000)
        let event = CalendarEventSnapshot(
            identifier: "meeting-1",
            calendarIdentifier: "work-cal",
            title: "Weekly meeting",
            start: now.addingTimeInterval(-5_400),
            end: now.addingTimeInterval(-3_600),
            isAllDay: false,
            calendarTitle: "Work"
        )
        let eventKey = DebriefEventKey.from(
            eventIdentifier: event.identifier,
            title: event.title,
            start: event.start,
            end: event.end,
            calendarIdentifier: event.calendarIdentifier,
            calendarTitle: event.calendarTitle
        )
        let pendingDebrief = CalendarDebriefRecord(
            eventKey: eventKey,
            eventIdentifier: event.identifier,
            calendarIdentifier: event.calendarIdentifier,
            calendarTitleSnapshot: event.calendarTitle,
            titleSnapshot: event.title,
            startDateSnapshot: event.start,
            endDateSnapshot: event.end,
            templateKind: .meeting,
            status: .pending
        )

        let candidates = DebriefQueueService().pendingCandidates(
            from: [event],
            existingDebriefs: [pendingDebrief],
            now: now
        )

        #expect(candidates.count == 1)
        #expect(candidates.first?.eventKey == eventKey)
        #expect(candidates.first?.existingRecordID == pendingDebrief.id)
    }

    @Test func templateSuggestionsUseKeywordHints() {
        #expect(CalendarDebriefRecord.suggestedTemplate(for: "Weekly meeting") == .meeting)
        #expect(CalendarDebriefRecord.suggestedTemplate(for: "Dinner with Anna") == .social)
        #expect(CalendarDebriefRecord.suggestedTemplate(for: "Deep work coding") == .workBlock)
        #expect(CalendarDebriefRecord.suggestedTemplate(for: "Untitled Event") == .workBlock)
    }
}
