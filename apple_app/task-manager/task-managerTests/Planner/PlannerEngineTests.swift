import Foundation
import Testing
@testable import task_manager

struct PlannerEngineTests {
    private let engine = PlannerEngine()

    @Test func mergeBusyIntervalsCombinesOverlapsAndTouchingIntervals() {
        let planningWindow = DateInterval(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 8 * 3_600)
        )
        let merged = engine.mergeBusyIntervals([
            BusyInterval(
                start: Date(timeIntervalSince1970: 3_600),
                end: Date(timeIntervalSince1970: 2 * 3_600),
                source: .calendarEvent(identifier: "a")
            ),
            BusyInterval(
                start: Date(timeIntervalSince1970: 90 * 60),
                end: Date(timeIntervalSince1970: 3 * 3_600),
                source: .calendarEvent(identifier: "b")
            ),
            BusyInterval(
                start: Date(timeIntervalSince1970: 3 * 3_600),
                end: Date(timeIntervalSince1970: 4 * 3_600),
                source: .scheduledBlock(blockID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!)
            ),
            BusyInterval(
                start: Date(timeIntervalSince1970: 5 * 3_600),
                end: Date(timeIntervalSince1970: 6 * 3_600),
                source: .calendarEvent(identifier: "c")
            ),
        ], within: planningWindow)

        #expect(merged.count == 2)
        #expect(merged[0].start == Date(timeIntervalSince1970: 3_600))
        #expect(merged[0].end == Date(timeIntervalSince1970: 4 * 3_600))
        #expect(merged[0].sources.count == 3)
        #expect(merged[1].start == Date(timeIntervalSince1970: 5 * 3_600))
        #expect(merged[1].end == Date(timeIntervalSince1970: 6 * 3_600))
    }

    @Test func freeGapsAreComputedFromMergedBusyIntervals() {
        let planningWindow = DateInterval(
            start: Date(timeIntervalSince1970: 8 * 3_600),
            end: Date(timeIntervalSince1970: 14 * 3_600)
        )
        let busyIntervals = [
            BusyInterval(
                start: Date(timeIntervalSince1970: 9 * 3_600),
                end: Date(timeIntervalSince1970: 10 * 3_600),
                source: .calendarEvent(identifier: "standup")
            ),
            BusyInterval(
                start: Date(timeIntervalSince1970: 12 * 3_600),
                end: Date(timeIntervalSince1970: 13 * 3_600),
                source: .calendarEvent(identifier: "lunch")
            ),
        ]
        let gaps = engine.freeGaps(
            within: planningWindow,
            around: busyIntervals,
            minimumGapMinutes: 30
        )

        #expect(gaps.count == 3)
        #expect(gaps[0].interval == DateInterval(
            start: Date(timeIntervalSince1970: 8 * 3_600),
            end: Date(timeIntervalSince1970: 9 * 3_600)
        ))
        #expect(gaps[1].interval == DateInterval(
            start: Date(timeIntervalSince1970: 10 * 3_600),
            end: Date(timeIntervalSince1970: 12 * 3_600)
        ))
        #expect(gaps[2].interval == DateInterval(
            start: Date(timeIntervalSince1970: 13 * 3_600),
            end: Date(timeIntervalSince1970: 14 * 3_600)
        ))
    }

    @Test func tasksThatFitBeatTasksThatDoNotFit() throws {
        let gap = FreeGap(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 60 * 60)
        )
        let constraints = PlannerConstraints(
            planningWindow: DateInterval(start: gap.start, end: gap.end),
            now: Date(timeIntervalSince1970: 0),
            minimumGapMinutes: 15,
            defaultAssumedDurationMinutes: 30,
            suggestionCap: 1,
            priorityEmphasis: .balanced
        )
        let fitTask = MyTask(
            title: "Fit",
            estimatedMinutes: 45,
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let oversizedTask = MyTask(
            title: "Too Big",
            estimatedMinutes: 120,
            createdAt: Date(timeIntervalSince1970: 2),
            updatedAt: Date(timeIntervalSince1970: 2)
        )

        let suggestions = engine.rankedSuggestions(
            for: [gap],
            tasks: [oversizedTask, fitTask],
            constraints: constraints,
            rejectedSuggestions: []
        )

        let bestSuggestion = try #require(suggestions.first)
        #expect(bestSuggestion.taskID == fitTask.id)
    }

    @Test func dueSoonAndHigherPriorityTasksRankAboveWeakerAlternatives() throws {
        let gap = FreeGap(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 60 * 60)
        )
        let now = Date(timeIntervalSince1970: 0)
        let constraints = PlannerConstraints(
            planningWindow: DateInterval(start: gap.start, end: gap.end),
            now: now,
            minimumGapMinutes: 15,
            defaultAssumedDurationMinutes: 30,
            suggestionCap: 1,
            priorityEmphasis: .balanced
        )
        let strongTask = MyTask(
            title: "Ship fix",
            estimatedMinutes: 60,
            dueDate: now.addingTimeInterval(3 * 3_600),
            priority: .urgent,
            createdAt: now,
            updatedAt: now
        )
        let weakTask = MyTask(
            title: "Organize desk",
            estimatedMinutes: 60,
            priority: .low,
            createdAt: now.addingTimeInterval(1),
            updatedAt: now.addingTimeInterval(1)
        )

        let suggestions = engine.rankedSuggestions(
            for: [gap],
            tasks: [weakTask, strongTask],
            constraints: constraints,
            rejectedSuggestions: []
        )

        let bestSuggestion = try #require(suggestions.first)
        #expect(bestSuggestion.taskID == strongTask.id)
    }

    @Test func missingDurationUsesTheDefaultAssumption() throws {
        let gap = FreeGap(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 60 * 60)
        )
        let constraints = PlannerConstraints(
            planningWindow: DateInterval(start: gap.start, end: gap.end),
            now: Date(timeIntervalSince1970: 0),
            minimumGapMinutes: 15,
            defaultAssumedDurationMinutes: 30,
            suggestionCap: 1,
            priorityEmphasis: .balanced
        )
        let task = MyTask(title: "Inbox cleanup")

        let suggestion = try #require(
            engine.candidate(for: task, in: gap, constraints: constraints)
        )

        #expect(suggestion.assumedDurationMinutes == 30)
        #expect(suggestion.suggestedInterval.duration == 30 * 60)
        #expect(suggestion.explanation.contains("assumed 30m"))
    }

    @Test func invalidDefaultAssumptionFallsBackToThirtyMinutes() throws {
        let gap = FreeGap(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 60 * 60)
        )
        let constraints = PlannerConstraints(
            planningWindow: DateInterval(start: gap.start, end: gap.end),
            now: Date(timeIntervalSince1970: 0),
            minimumGapMinutes: 15,
            defaultAssumedDurationMinutes: 37,
            suggestionCap: 1,
            priorityEmphasis: .balanced
        )
        let task = MyTask(title: "Inbox cleanup")

        let suggestion = try #require(
            engine.candidate(for: task, in: gap, constraints: constraints)
        )

        #expect(suggestion.assumedDurationMinutes == 30)
    }
}
