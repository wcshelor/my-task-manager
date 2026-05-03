import Foundation
import Testing
@testable import task_manager

@MainActor
struct TodayViewModelTests {
    @Test func todayViewModelAggregatesActivePromisesAndRoutines() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let promise = Promise(
            title: "No weed until 6 PM",
            startAt: now.addingTimeInterval(-60),
            checkInAt: now.addingTimeInterval(60)
        )
        let item = RoutineItem(title: "Plan day", position: 0)
        let routine = Routine(name: "Morning", items: [item])
        let log = RoutineCompletionLog(
            routineID: routine.id,
            date: Calendar(identifier: .gregorian).startOfDay(for: now),
            completedItemIDs: [item.id]
        )
        let viewModel = TodayViewModel(
            promiseRepository: FakePromiseRepository(promises: [promise]),
            routineRepository: FakeRoutineRepository(routines: [routine], logs: [log]),
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.activePromises == [promise])
        #expect(viewModel.routineProgress.count == 1)
        #expect(viewModel.routineProgress.first?.completedCount == 1)
    }

    @Test func todayViewModelResolvesPromiseAndUpdatesHistoryCounts() {
        let now = Date(timeIntervalSince1970: 1_000)
        let promiseRepository = FakePromiseRepository(promises: [
            Promise(title: "Stay present", startAt: now, checkInAt: now)
        ])
        let viewModel = TodayViewModel(
            promiseRepository: promiseRepository,
            routineRepository: FakeRoutineRepository(),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.resolvePromise(
            withID: promiseRepository.promises[0].id,
            outcome: .kept,
            reflection: "Did it"
        )

        #expect(viewModel.activePromises.isEmpty)
        #expect(viewModel.keptCount == 1)
        #expect(viewModel.missedCount == 0)
    }

    @Test func todayViewModelUpdatesRoutineItemCompletion() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let item = RoutineItem(title: "Plan day", position: 0)
        let routine = Routine(name: "Morning", items: [item])
        let routineRepository = FakeRoutineRepository(routines: [routine])
        let viewModel = TodayViewModel(
            promiseRepository: FakePromiseRepository(),
            routineRepository: routineRepository,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.setRoutineItem(routineID: routine.id, itemID: item.id, completed: true)

        #expect(viewModel.routineProgress.first?.completedCount == 1)
    }
}

@MainActor
private final class FakePromiseRepository: PromiseRepository {
    var promises: [Promise]

    init(promises: [Promise] = []) {
        self.promises = promises
    }

    func fetchPromises() throws -> [Promise] {
        promises
    }

    func fetchActivePromises(at date: Date) throws -> [Promise] {
        promises.filter { $0.isPresent(at: date) }
    }

    func fetchDuePromises(at date: Date) throws -> [Promise] {
        promises.filter { $0.isDueForCheckIn(at: date) }
    }

    func fetchPromiseHistory() throws -> [Promise] {
        promises.filter { $0.status == .resolved }
    }

    func promise(withID id: UUID) throws -> Promise? {
        promises.first { $0.id == id }
    }

    func savePromise(_ promise: Promise, replacingPromiseWithID originalID: UUID?) throws {
        let targetID = originalID ?? promise.id

        if let index = promises.firstIndex(where: { $0.id == targetID || $0.id == promise.id }) {
            promises[index] = promise
        } else {
            promises.append(promise)
        }
    }

    func resolvePromise(
        withID id: UUID,
        outcome: PromiseOutcome,
        reflection: String?,
        resolvedAt: Date
    ) throws {
        guard let promise = promises.first(where: { $0.id == id }) else {
            return
        }

        try savePromise(
            promise.resolved(outcome: outcome, reflection: reflection, resolvedAt: resolvedAt),
            replacingPromiseWithID: id
        )
    }

    func deletePromise(withID id: UUID) throws {
        promises.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeRoutineRepository: RoutineRepository {
    var routines: [Routine]
    var logs: [RoutineCompletionLog]

    init(routines: [Routine] = [], logs: [RoutineCompletionLog] = []) {
        self.routines = routines
        self.logs = logs
    }

    func fetchRoutines() throws -> [Routine] {
        routines
    }

    func fetchActiveRoutines(on date: Date, calendar: Calendar) throws -> [Routine] {
        routines.filter { $0.isActive(on: date, calendar: calendar) }
    }

    func routine(withID id: UUID) throws -> Routine? {
        routines.first { $0.id == id }
    }

    func saveRoutine(_ routine: Routine, replacingRoutineWithID originalID: UUID?) throws {
        let targetID = originalID ?? routine.id

        if let index = routines.firstIndex(where: { $0.id == targetID || $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }
    }

    func deleteRoutine(withID id: UUID) throws {
        routines.removeAll { $0.id == id }
    }

    func fetchCompletionLog(
        for routineID: UUID,
        on date: Date,
        calendar: Calendar
    ) throws -> RoutineCompletionLog? {
        logs.first { log in
            log.routineID == routineID && calendar.isDate(log.date, inSameDayAs: date)
        }
    }

    func fetchCompletionLogs(on date: Date, calendar: Calendar) throws -> [RoutineCompletionLog] {
        logs.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func saveCompletionLog(_ log: RoutineCompletionLog, replacingLogWithID originalID: UUID?) throws {
        let targetID = originalID ?? log.id

        if let index = logs.firstIndex(where: { $0.id == targetID || $0.id == log.id }) {
            logs[index] = log
        } else {
            logs.append(log)
        }
    }
}
