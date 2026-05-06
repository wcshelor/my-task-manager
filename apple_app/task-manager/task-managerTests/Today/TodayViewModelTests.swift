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
            taskRepository: FakeTaskRepository(),
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
            taskRepository: FakeTaskRepository(),
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
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: routineRepository,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        viewModel.setRoutineItem(routineID: routine.id, itemID: item.id, completed: true)

        #expect(viewModel.routineProgress.first?.completedCount == 1)
    }

    @Test func todayViewModelSavesQuickAddedTask() {
        let taskRepository = FakeTaskRepository()
        let viewModel = TodayViewModel(
            taskRepository: taskRepository,
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository()
        )
        let task = MyTask(title: "Send invoice", taskGroup: "Admin")

        viewModel.loadIfNeeded()
        viewModel.saveTask(task)

        #expect(taskRepository.tasks == [task])
        #expect(viewModel.tasks == [task])
        #expect(viewModel.taskGroups == ["Admin"])
        #expect(viewModel.reservedTaskIDs == [task.id])
    }

    @Test func todayViewModelExposesCurrentRoutineItemAndAdvances() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let firstItem = RoutineItem(title: "Open curtains", position: 0)
        let secondItem = RoutineItem(title: "Drink water", position: 1)
        let routine = Routine(name: "Morning", items: [firstItem, secondItem])
        let routineRepository = FakeRoutineRepository(routines: [routine])
        let viewModel = TodayViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: routineRepository,
            calendar: Calendar(identifier: .gregorian),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.progress(for: routine.id)?.currentItem == firstItem)
        #expect(viewModel.progress(for: routine.id)?.actionLabel == "Start")

        viewModel.completeCurrentRoutineItem(routineID: routine.id)

        #expect(viewModel.progress(for: routine.id)?.currentItem == secondItem)
        #expect(viewModel.progress(for: routine.id)?.actionLabel == "Continue")

        viewModel.completeCurrentRoutineItem(routineID: routine.id)

        #expect(viewModel.progress(for: routine.id)?.isComplete == true)
        #expect(viewModel.progress(for: routine.id)?.actionLabel == "Review")
    }

    @Test func todayViewModelDoesNotCarryYesterdayRoutineProgressIntoToday() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 5, day: 6, hour: 9))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: today))!
        let firstItem = RoutineItem(title: "Open curtains", position: 0)
        let secondItem = RoutineItem(title: "Drink water", position: 1)
        let routine = Routine(name: "Morning", items: [firstItem, secondItem])
        let yesterdayLog = RoutineCompletionLog(
            routineID: routine.id,
            date: yesterday,
            completedItemIDs: [firstItem.id]
        )
        let viewModel = TodayViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(routines: [routine], logs: [yesterdayLog]),
            calendar: calendar,
            nowProvider: { today }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.progress(for: routine.id)?.completedCount == 0)
        #expect(viewModel.progress(for: routine.id)?.currentItem == firstItem)
    }

    @Test func todayViewModelLoadsCalendarOverviewWhenAccessIsGranted() async {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: now)
        let event = CalendarEventSnapshot(
            identifier: "workout",
            title: "Workout",
            start: calendar.date(byAdding: .hour, value: 9, to: startOfDay)!,
            end: calendar.date(byAdding: .hour, value: 10, to: startOfDay)!,
            isAllDay: false,
            calendarTitle: "Personal"
        )
        let viewModel = TodayViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(status: .fullAccessGranted),
            calendarReader: FakeCalendarReader(events: [event]),
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()
        await Task.yield()
        await Task.yield()

        #expect(viewModel.calendarOverview?.events == [event])
        #expect(viewModel.calendarOverview?.nextEvent == event)
        #expect(viewModel.calendarPermissionStatus == .fullAccessGranted)
    }
}

@MainActor
private final class FakeTaskRepository: TaskRepository {
    var tasks: [MyTask]

    init(tasks: [MyTask] = []) {
        self.tasks = tasks
    }

    func fetchTasks() throws -> [MyTask] {
        tasks
    }

    func task(withID id: UUID) throws -> MyTask? {
        tasks.first { $0.id == id }
    }

    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID?) throws {
        let targetID = originalID ?? task.id

        if let index = tasks.firstIndex(where: { $0.id == targetID || $0.id == task.id }) {
            tasks[index] = task
        } else {
            tasks.append(task)
        }
    }

    func deleteTask(withID id: UUID) throws {
        tasks.removeAll { $0.id == id }
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

@MainActor
private final class FakeCalendarPermissionProvider: CalendarPermissionProviding {
    let status: CalendarPermissionStatus

    init(status: CalendarPermissionStatus) {
        self.status = status
    }

    func currentStatus() -> CalendarPermissionStatus {
        status
    }

    func requestFullAccess() async -> CalendarPermissionStatus {
        status
    }
}

@MainActor
private final class FakeCalendarReader: CalendarReading {
    let events: [CalendarEventSnapshot]

    init(events: [CalendarEventSnapshot]) {
        self.events = events
    }

    func fetchEvents(in window: DateInterval) async throws -> [CalendarEventSnapshot] {
        events.filter { event in
            event.end > window.start && event.start < window.end
        }
    }
}
