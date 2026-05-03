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
}

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var activePromises: [Promise] = []
    @Published private(set) var duePromises: [Promise] = []
    @Published private(set) var promiseHistory: [Promise] = []
    @Published private(set) var routineProgress: [TodayRoutineProgress] = []
    @Published private(set) var errorMessage: String?

    private let promiseRepository: any PromiseRepository
    private let routineRepository: any RoutineRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false

    init(
        promiseRepository: any PromiseRepository,
        routineRepository: any RoutineRepository,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.promiseRepository = promiseRepository
        self.routineRepository = routineRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var keptCount: Int {
        promiseHistory.filter { $0.outcome == .kept }.count
    }

    var missedCount: Int {
        promiseHistory.filter { $0.outcome == .missed }.count
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
            routineProgress = activeRoutines.map { routine in
                TodayRoutineProgress(routine: routine, completionLog: logLookup[routine.id])
            }
            errorMessage = nil
            hasLoaded = true
        } catch {
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
