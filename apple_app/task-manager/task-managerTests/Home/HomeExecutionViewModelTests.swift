import Foundation
import Testing
@testable import task_manager

@MainActor
struct HomeExecutionViewModelTests {
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
        let viewModel = HomeExecutionViewModel(
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
        let viewModel = HomeExecutionViewModel(
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
        let viewModel = HomeExecutionViewModel(
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
        let viewModel = HomeExecutionViewModel(
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

    @Test func todayViewModelLoadsInboxAndPinnedProjectSummaries() {
        let now = Date(timeIntervalSince1970: 10_000)
        let project = Project(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!,
            name: "Master's Thesis",
            isPinned: true
        )
        let capture = CaptureItem(
            title: "Ask advisor",
            projectID: project.id,
            createdAt: now.addingTimeInterval(-3_600)
        )
        let task = MyTask(title: "Draft outline", dueDate: now.addingTimeInterval(86_400), projectID: project.id)
        let completedTask = MyTask(
            title: "Submit intro",
            status: .completed,
            dueDate: now.addingTimeInterval(-86_400),
            projectID: project.id
        )
        let item = ProjectItem(projectID: project.id, kind: .maybe, title: "Explore method")
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(tasks: [task, completedTask]),
            projectRepository: FakeProjectRepository(projects: [project]),
            captureRepository: FakeCaptureRepository(captures: [capture]),
            projectItemRepository: FakeProjectItemRepository(items: [item]),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.inboxSummary.count == 1)
        #expect(viewModel.inboxSummary.projectTaggedCount == 1)
        #expect(viewModel.inboxSummary.oldestAgeLabel == "1h")
        #expect(viewModel.pinnedProjectSummaries.count == 1)
        #expect(viewModel.pinnedProjectSummaries.first?.activeTaskCount == 1)
        #expect(viewModel.pinnedProjectSummaries.first?.completedTaskCount == 1)
        #expect(viewModel.pinnedProjectSummaries.first?.progressSummary == "1/2 tasks complete")
        #expect(viewModel.pinnedProjectSummaries.first?.projectItemCount == 1)
        #expect(viewModel.pinnedProjectSummaries.first?.nextTask == task)
    }

    @Test func inboxReviewViewModelConvertsCaptureToTaskAndProjectItem() {
        let now = Date(timeIntervalSince1970: 10_000)
        let project = Project(name: "Posso")
        let taskRepository = FakeTaskRepository()
        let captureRepository = FakeCaptureRepository(captures: [
            CaptureItem(title: "Fix onboarding", projectID: project.id),
            CaptureItem(title: "Explore pricing", projectID: project.id)
        ])
        let projectItemRepository = FakeProjectItemRepository()
        let viewModel = InboxReviewViewModel(
            taskRepository: taskRepository,
            projectRepository: FakeProjectRepository(projects: [project]),
            captureRepository: captureRepository,
            projectItemRepository: projectItemRepository,
            initialCaptures: [],
            initialProjects: [],
            nowProvider: { now }
        )

        viewModel.load()
        viewModel.convertCurrentCaptureToTask(
            MyTaskFormData(title: "Fix onboarding", projectID: project.id)
        )

        #expect(taskRepository.tasks.count == 1)
        #expect(taskRepository.tasks.first?.projectID == project.id)
        #expect(captureRepository.captures.first?.processedAt == now)

        viewModel.convertCurrentCaptureToProjectItem(
            kind: .maybe,
            title: "Explore pricing",
            notes: nil,
            projectID: project.id,
            source: nil,
            pressure: .useful,
            reviewAfter: nil
        )

        #expect(projectItemRepository.items.count == 1)
        #expect(projectItemRepository.items.first?.kind == .maybe)
        #expect(projectItemRepository.items.first?.projectID == project.id)
    }

    @Test func todayViewModelExposesCurrentRoutineItemAndAdvances() {
        let now = Date(timeIntervalSince1970: 1_710_201_600)
        let firstItem = RoutineItem(title: "Open curtains", position: 0)
        let secondItem = RoutineItem(title: "Drink water", position: 1)
        let routine = Routine(name: "Morning", items: [firstItem, secondItem])
        let routineRepository = FakeRoutineRepository(routines: [routine])
        let viewModel = HomeExecutionViewModel(
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
        let viewModel = HomeExecutionViewModel(
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
        let viewModel = HomeExecutionViewModel(
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

    @Test func todayViewModelLoadsHealthSummary() {
        let now = Date(timeIntervalSince1970: 1_000)
        let checkIn = SleepCheckIn(day: now, energyRating: 4)
        let meal = MealLog(timestamp: now, summary: "Oats")
        let workout = WorkoutLog(timestamp: now, workoutType: .walk)
        let viewModel = HomeExecutionViewModel(
            taskRepository: FakeTaskRepository(),
            promiseRepository: FakePromiseRepository(),
            routineRepository: FakeRoutineRepository(),
            healthRepository: FakeHomeHealthRepository(
                sleepCheckIns: [checkIn],
                mealLogs: [meal],
                workoutLogs: [workout]
            ),
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.healthSummary.sleepCheckIn == checkIn)
        #expect(viewModel.healthSummary.todaysMealLogs == [meal])
        #expect(viewModel.healthSummary.recentWorkoutLogs == [workout])
        #expect(viewModel.healthSummary.detail == "Energy 4/5 · 1 meal")
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
private final class FakeProjectRepository: ProjectRepository {
    var projects: [Project]

    init(projects: [Project] = []) {
        self.projects = projects
    }

    func fetchProjects(includeArchived: Bool) throws -> [Project] {
        projects.filter { includeArchived || $0.isArchived == false }
    }

    func project(withID id: UUID) throws -> Project? {
        projects.first { $0.id == id }
    }

    func saveProject(_ project: Project, replacingProjectWithID originalID: UUID?) throws {
        let targetID = originalID ?? project.id
        if let index = projects.firstIndex(where: { $0.id == targetID || $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
    }

    func archiveProject(withID id: UUID, archivedAt: Date) throws {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            return
        }
        projects[index].isArchived = true
        projects[index].updatedAt = archivedAt
    }

    func deleteProject(withID id: UUID) throws {
        projects.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeCaptureRepository: CaptureRepository {
    var captures: [CaptureItem]

    init(captures: [CaptureItem] = []) {
        self.captures = captures
    }

    func fetchCaptures(includeProcessed: Bool, includeArchived: Bool) throws -> [CaptureItem] {
        captures.filter { capture in
            (includeProcessed || capture.processedAt == nil)
                && (includeArchived || capture.archivedAt == nil)
        }
    }

    func capture(withID id: UUID) throws -> CaptureItem? {
        captures.first { $0.id == id }
    }

    func saveCapture(_ capture: CaptureItem, replacingCaptureWithID originalID: UUID?) throws {
        let targetID = originalID ?? capture.id
        if let index = captures.firstIndex(where: { $0.id == targetID || $0.id == capture.id }) {
            captures[index] = capture
        } else {
            captures.append(capture)
        }
    }

    func deleteCapture(withID id: UUID) throws {
        captures.removeAll { $0.id == id }
    }
}

@MainActor
private final class FakeProjectItemRepository: ProjectItemRepository {
    var items: [ProjectItem]

    init(items: [ProjectItem] = []) {
        self.items = items
    }

    func fetchProjectItems(includeArchived: Bool) throws -> [ProjectItem] {
        items.filter { includeArchived || $0.isArchived == false }
    }

    func fetchProjectItems(for projectID: UUID, includeArchived: Bool) throws -> [ProjectItem] {
        try fetchProjectItems(includeArchived: includeArchived).filter { $0.projectID == projectID }
    }

    func projectItem(withID id: UUID) throws -> ProjectItem? {
        items.first { $0.id == id }
    }

    func saveProjectItem(_ item: ProjectItem, replacingProjectItemWithID originalID: UUID?) throws {
        let targetID = originalID ?? item.id
        if let index = items.firstIndex(where: { $0.id == targetID || $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    func archiveProjectItem(withID id: UUID, archivedAt: Date) throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            return
        }
        items[index].isArchived = true
        items[index].updatedAt = archivedAt
    }

    func deleteProjectItem(withID id: UUID) throws {
        items.removeAll { $0.id == id }
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
private final class FakeHomeHealthRepository: HealthRepository {
    var sleepCheckIns: [SleepCheckIn]
    var mealLogs: [MealLog]
    var workoutLogs: [WorkoutLog]

    init(
        sleepCheckIns: [SleepCheckIn] = [],
        mealLogs: [MealLog] = [],
        workoutLogs: [WorkoutLog] = []
    ) {
        self.sleepCheckIns = sleepCheckIns
        self.mealLogs = mealLogs
        self.workoutLogs = workoutLogs
    }

    func fetchSleepCheckIns(limit: Int) throws -> [SleepCheckIn] {
        Array(sleepCheckIns.prefix(max(0, limit)))
    }

    func fetchSleepCheckIn(on date: Date, calendar: Calendar) throws -> SleepCheckIn? {
        sleepCheckIns.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    func saveSleepCheckIn(_ checkIn: SleepCheckIn, replacingCheckInWithID originalID: UUID?) throws {
        sleepCheckIns.append(checkIn)
    }

    func fetchMealLogs(on date: Date, calendar: Calendar) throws -> [MealLog] {
        mealLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.sortedForHealthHistory()
    }

    func fetchRecentMealLogs(limit: Int) throws -> [MealLog] {
        Array(mealLogs.sortedForHealthHistory().prefix(max(0, limit)))
    }

    func mealLog(withID id: UUID) throws -> MealLog? {
        mealLogs.first { $0.id == id }
    }

    func saveMealLog(_ log: MealLog, replacingLogWithID originalID: UUID?) throws {
        mealLogs.append(log)
    }

    func deleteMealLog(withID id: UUID) throws {
        mealLogs.removeAll { $0.id == id }
    }

    func fetchWorkoutLogs(on date: Date, calendar: Calendar) throws -> [WorkoutLog] {
        workoutLogs.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }.sortedForHealthHistory()
    }

    func fetchRecentWorkoutLogs(limit: Int) throws -> [WorkoutLog] {
        Array(workoutLogs.sortedForHealthHistory().prefix(max(0, limit)))
    }

    func workoutLog(withID id: UUID) throws -> WorkoutLog? {
        workoutLogs.first { $0.id == id }
    }

    func saveWorkoutLog(_ log: WorkoutLog, replacingLogWithID originalID: UUID?) throws {
        workoutLogs.append(log)
    }

    func deleteWorkoutLog(withID id: UUID) throws {
        workoutLogs.removeAll { $0.id == id }
    }

    func fetchPVTSessions(on date: Date, calendar: Calendar) throws -> [PVTSession] {
        []
    }

    func fetchRecentPVTSessions(limit: Int) throws -> [PVTSession] {
        []
    }

    func savePVTSession(_ session: PVTSession) throws {}
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
