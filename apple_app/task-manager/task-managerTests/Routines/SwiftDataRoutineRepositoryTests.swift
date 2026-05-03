import Foundation
import Testing
@testable import task_manager

struct SwiftDataRoutineRepositoryTests {
    @Test @MainActor func routineRepositoryRoundTripsRoutine() throws {
        let repository = try makeRepository()
        let routine = Routine(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174222")!,
            name: "Evening Reset",
            notes: "Close the day",
            activeWeekdays: [.monday, .wednesday],
            items: [
                RoutineItem(title: "Clear desk", position: 0),
                RoutineItem(title: "Set first task", position: 1),
            ],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        try repository.saveRoutine(routine, replacingRoutineWithID: nil)

        #expect(try repository.routine(withID: routine.id) == routine)
    }

    @Test @MainActor func routineRepositoryPersistsDailyCompletionLog() throws {
        let repository = try makeRepository()
        let item = RoutineItem(title: "Plan", position: 0)
        let routine = Routine(name: "Morning", items: [item])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_710_201_600)
        let dayStart = calendar.startOfDay(for: day)
        let log = RoutineCompletionLog(
            routineID: routine.id,
            date: dayStart,
            completedItemIDs: [item.id]
        )

        try repository.saveRoutine(routine, replacingRoutineWithID: nil)
        try repository.saveCompletionLog(log, replacingLogWithID: nil)

        let fetchedLog = try repository.fetchCompletionLog(
            for: routine.id,
            on: day.addingTimeInterval(60 * 60),
            calendar: calendar
        )

        #expect(fetchedLog == log)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataRoutineRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataRoutineRepository(modelContainer: container)
    }
}
