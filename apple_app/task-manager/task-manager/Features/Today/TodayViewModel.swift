import Combine
import Foundation

nonisolated struct TodayRoutineProgress: Identifiable, Equatable, Sendable {
    let routine: Routine
    let completionLog: RoutineCompletionLog?

    var id: UUID {
        routine.id
    }

    var completedCount: Int {
        completionLog?.completionCount(for: routine) ?? 0
    }

    var totalCount: Int {
        routine.orderedItems.count
    }

    var progressLabel: String {
        "\(completedCount)/\(totalCount)"
    }

    var isComplete: Bool {
        completionLog?.isComplete(for: routine) ?? false
    }

    var currentItem: RoutineItem? {
        routine.orderedItems.first { item in
            completionLog?.completedItemIDs.contains(item.id) != true
        }
    }

    var actionLabel: String {
        if isComplete {
            return "Review"
        }

        return completedCount == 0 ? "Start" : "Continue"
    }
}

nonisolated struct TodayCalendarOverview: Equatable, Sendable {
    let events: [CalendarEventSnapshot]
    let nextEvent: CalendarEventSnapshot?

    var allDayEvents: [CalendarEventSnapshot] {
        events.filter(\.isAllDay)
    }

    var timedEvents: [CalendarEventSnapshot] {
        events.filter { $0.isAllDay == false }
    }
}

nonisolated struct TodayInboxSummary: Equatable, Sendable {
    let pendingCaptures: [CaptureItem]
    let now: Date

    var count: Int {
        pendingCaptures.count
    }

    var projectTaggedCount: Int {
        pendingCaptures.filter { $0.projectID != nil }.count
    }

    var oldestCapture: CaptureItem? {
        pendingCaptures.min { $0.createdAt < $1.createdAt }
    }

    var oldestAgeLabel: String? {
        guard let oldestCapture else {
            return nil
        }

        let seconds = max(0, now.timeIntervalSince(oldestCapture.createdAt))
        if seconds < 3_600 {
            let minutes = max(1, Int(seconds / 60))
            return "\(minutes)m"
        }

        if seconds < 86_400 {
            return "\(Int(seconds / 3_600))h"
        }

        return "\(Int(seconds / 86_400))d"
    }
}

nonisolated struct TodayPinnedProjectSummary: Identifiable, Equatable, Sendable {
    let project: Project
    let activeTaskCount: Int
    let projectItemCount: Int
    let nextTask: MyTask?

    var id: UUID {
        project.id
    }
}

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var activePromises: [Promise] = []
    @Published private(set) var duePromises: [Promise] = []
    @Published private(set) var promiseHistory: [Promise] = []
    @Published private(set) var routineProgress: [TodayRoutineProgress] = []
    @Published private(set) var tasks: [MyTask] = []
    @Published private(set) var captures: [CaptureItem] = []
    @Published private(set) var projects: [Project] = []
    @Published private(set) var projectItems: [ProjectItem] = []
    @Published private(set) var calendarOverview: TodayCalendarOverview?
    @Published private(set) var calendarPermissionStatus: CalendarPermissionStatus?
    @Published private(set) var errorMessage: String?

    private let taskRepository: any TaskRepository
    private let projectRepository: (any ProjectRepository)?
    private let captureRepository: (any CaptureRepository)?
    private let projectItemRepository: (any ProjectItemRepository)?
    private let promiseRepository: any PromiseRepository
    private let routineRepository: any RoutineRepository
    private let calendarPermissionProvider: (any CalendarPermissionProviding)?
    private let calendarReader: (any CalendarReading)?
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false

    init(
        taskRepository: any TaskRepository,
        projectRepository: (any ProjectRepository)? = nil,
        captureRepository: (any CaptureRepository)? = nil,
        projectItemRepository: (any ProjectItemRepository)? = nil,
        promiseRepository: any PromiseRepository,
        routineRepository: any RoutineRepository,
        calendarPermissionProvider: (any CalendarPermissionProviding)? = nil,
        calendarReader: (any CalendarReading)? = nil,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
        self.promiseRepository = promiseRepository
        self.routineRepository = routineRepository
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarReader = calendarReader
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var keptCount: Int {
        promiseHistory.filter { $0.outcome == .kept }.count
    }

    var missedCount: Int {
        promiseHistory.filter { $0.outcome == .missed }.count
    }

    var taskGroups: [String] {
        Array(Set(tasks.compactMap(\.taskGroup))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var inboxSummary: TodayInboxSummary {
        TodayInboxSummary(pendingCaptures: captures, now: nowProvider())
    }

    var pinnedProjectSummaries: [TodayPinnedProjectSummary] {
        let activeTasks = tasks.filter { task in
            task.status != .completed && task.status != .archived
        }
        let activeItems = projectItems.filter { $0.isArchived == false }

        return projects
            .filter { $0.isPinned && $0.isArchived == false }
            .map { project in
                let projectTasks = activeTasks.filter { $0.projectID == project.id }
                let nextTask = Self.nextTask(from: projectTasks)
                return TodayPinnedProjectSummary(
                    project: project,
                    activeTaskCount: projectTasks.count,
                    projectItemCount: activeItems.filter { $0.projectID == project.id }.count,
                    nextTask: nextTask
                )
            }
    }

    var reservedTaskIDs: Set<UUID> {
        Set(tasks.map(\.id))
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        load()
    }

    func handleSceneDidBecomeActive() {
        guard hasLoaded else {
            return
        }

        load()
    }

    func load() {
        do {
            let now = nowProvider()
            let activeRoutines = try routineRepository.fetchActiveRoutines(on: now, calendar: calendar)
            let logs = try routineRepository.fetchCompletionLogs(on: now, calendar: calendar)
            let logLookup = Dictionary(uniqueKeysWithValues: logs.map { ($0.routineID, $0) })

            activePromises = try promiseRepository.fetchActivePromises(at: now)
            duePromises = try promiseRepository.fetchDuePromises(at: now)
            promiseHistory = try promiseRepository.fetchPromiseHistory()
            tasks = try taskRepository.fetchTasks()
            captures = try captureRepository?.fetchCaptures(
                includeProcessed: false,
                includeArchived: false
            ) ?? []
            projects = try projectRepository?.fetchProjects(includeArchived: false) ?? []
            projectItems = try projectItemRepository?.fetchProjectItems(includeArchived: false) ?? []
            routineProgress = activeRoutines.map { routine in
                TodayRoutineProgress(routine: routine, completionLog: logLookup[routine.id])
            }
            errorMessage = nil
            hasLoaded = true
            Task {
                await refreshCalendarOverview()
            }
        } catch {
            errorMessage = "Unable to load Today: \(error.localizedDescription)"
        }
    }

    private func refreshCalendarOverview() async {
        guard let calendarPermissionProvider, let calendarReader else {
            calendarPermissionStatus = nil
            calendarOverview = nil
            return
        }

        let permissionStatus = calendarPermissionProvider.currentStatus()
        calendarPermissionStatus = permissionStatus

        guard permissionStatus == .fullAccessGranted else {
            calendarOverview = nil
            return
        }

        let now = nowProvider()
        let dayStart = calendar.startOfDay(for: now)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(86_400)

        do {
            let events = try await calendarReader.fetchEvents(
                in: DateInterval(start: dayStart, end: dayEnd)
            )
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay {
                    return lhs.isAllDay && rhs.isAllDay == false
                }

                if lhs.start != rhs.start {
                    return lhs.start < rhs.start
                }

                return lhs.end < rhs.end
            }

            calendarOverview = TodayCalendarOverview(
                events: events,
                nextEvent: events.first(where: { $0.end > now && $0.isAllDay == false })
            )
        } catch {
            calendarOverview = nil
            errorMessage = "Unable to load Today: \(error.localizedDescription)"
        }
    }

    func savePromise(_ promise: Promise, replacingPromiseWithID originalID: UUID? = nil) {
        do {
            try promiseRepository.savePromise(promise, replacingPromiseWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save promise: \(error.localizedDescription)"
        }
    }

    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID? = nil) {
        do {
            try taskRepository.saveTask(task, replacingTaskWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save task: \(error.localizedDescription)"
        }
    }

    func saveCapture(_ capture: CaptureItem, replacingCaptureWithID originalID: UUID? = nil) {
        do {
            try captureRepository?.saveCapture(capture, replacingCaptureWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save capture: \(error.localizedDescription)"
        }
    }

    func resolvePromise(withID id: UUID, outcome: PromiseOutcome, reflection: String?) {
        do {
            try promiseRepository.resolvePromise(
                withID: id,
                outcome: outcome,
                reflection: reflection,
                resolvedAt: nowProvider()
            )
            load()
        } catch {
            errorMessage = "Unable to check in: \(error.localizedDescription)"
        }
    }

    func makeResetPromise(from promise: Promise, title: String, checkInAt: Date) {
        let now = nowProvider()
        savePromise(
            Promise(
                title: title,
                notes: promise.notes,
                startAt: now,
                checkInAt: checkInAt,
                whyItMatters: promise.whyItMatters,
                expectedFriction: promise.expectedFriction,
                parentPromiseID: promise.id,
                createdAt: now
            )
        )
    }

    func saveRoutine(_ routine: Routine, replacingRoutineWithID originalID: UUID? = nil) {
        do {
            try routineRepository.saveRoutine(routine, replacingRoutineWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save routine: \(error.localizedDescription)"
        }
    }

    func setRoutineItem(
        routineID: UUID,
        itemID: UUID,
        completed: Bool
    ) {
        do {
            let now = nowProvider()
            let dayStart = calendar.startOfDay(for: now)
            var log = try routineRepository.fetchCompletionLog(
                for: routineID,
                on: dayStart,
                calendar: calendar
            ) ?? RoutineCompletionLog(routineID: routineID, date: dayStart, createdAt: now)
            log.setItem(itemID, completed: completed, updatedAt: now)
            try routineRepository.saveCompletionLog(log, replacingLogWithID: log.id)
            load()
        } catch {
            errorMessage = "Unable to update routine: \(error.localizedDescription)"
        }
    }

    func progress(for routineID: UUID) -> TodayRoutineProgress? {
        routineProgress.first { $0.routine.id == routineID }
    }

    func completeCurrentRoutineItem(routineID: UUID) {
        guard let item = progress(for: routineID)?.currentItem else {
            return
        }

        setRoutineItem(routineID: routineID, itemID: item.id, completed: true)
    }

    private static func nextTask(from tasks: [MyTask]) -> MyTask? {
        tasks.sorted { leftTask, rightTask in
            switch (leftTask.dueDate, rightTask.dueDate) {
            case (.some(let leftDueDate), .some(let rightDueDate)):
                if leftDueDate != rightDueDate {
                    return leftDueDate < rightDueDate
                }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }

            if leftTask.createdAt != rightTask.createdAt {
                return leftTask.createdAt < rightTask.createdAt
            }

            return leftTask.id.uuidString < rightTask.id.uuidString
        }
        .first
    }
}

@MainActor
final class PromisePresenceViewModel: ObservableObject {
    @Published private(set) var activePromises: [Promise] = []
    @Published private(set) var errorMessage: String?

    private let promiseRepository: any PromiseRepository
    private let nowProvider: @Sendable () -> Date

    init(
        promiseRepository: any PromiseRepository,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.promiseRepository = promiseRepository
        self.nowProvider = nowProvider
    }

    func load() {
        do {
            activePromises = try promiseRepository.fetchActivePromises(at: nowProvider())
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load promises: \(error.localizedDescription)"
        }
    }
}
