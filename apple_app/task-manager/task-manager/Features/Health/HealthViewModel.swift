import Combine
import Foundation

@MainActor
final class HealthViewModel: ObservableObject {
    @Published private(set) var todaysSleepCheckIn: SleepCheckIn?
    @Published private(set) var recentSleepCheckIns: [SleepCheckIn] = []
    @Published private(set) var todaysMealLogs: [MealLog] = []
    @Published private(set) var recentMealLogs: [MealLog] = []
    @Published private(set) var todaysWorkoutLogs: [WorkoutLog] = []
    @Published private(set) var recentWorkoutLogs: [WorkoutLog] = []
    @Published private(set) var todaysPVTSessions: [PVTSession] = []
    @Published private(set) var recentPVTSessions: [PVTSession] = []
    @Published private(set) var errorMessage: String?

    private let healthRepository: any HealthRepository
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false

    init(
        healthRepository: any HealthRepository,
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.healthRepository = healthRepository
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    var mealsTodaySummary: String {
        "\(todaysMealLogs.count) meal\(todaysMealLogs.count == 1 ? "" : "s") today"
    }

    var workoutsTodaySummary: String {
        "\(todaysWorkoutLogs.count) workout\(todaysWorkoutLogs.count == 1 ? "" : "s") today"
    }

    var sleepStatusSummary: String {
        guard let todaysSleepCheckIn else {
            return "No sleep check-in yet"
        }

        if let energyRating = todaysSleepCheckIn.energyRating {
            return "Energy \(energyRating)/5"
        }

        if let sleepQualityRating = todaysSleepCheckIn.sleepQualityRating {
            return "Sleep \(sleepQualityRating)/5"
        }

        return "Sleep checked in"
    }

    var latestWorkoutSummary: String {
        guard let workout = recentWorkoutLogs.first else {
            return "No workouts logged"
        }

        if let duration = workout.durationMinutes {
            return "\(workout.workoutType.displayName), \(duration)m"
        }

        return workout.workoutType.displayName
    }

    var latestPVTSessionToday: PVTSession? {
        todaysPVTSessions.first
    }

    var pvtStatusSummary: String {
        guard let session = latestPVTSessionToday else {
            return "No PVT today"
        }

        var parts: [String] = []
        if let median = session.medianReactionMilliseconds {
            parts.append("Median \(Int(median.rounded()))ms")
        }

        parts.append("\(session.lapseCount) lapse\(session.lapseCount == 1 ? "" : "s")")

        if session.missCount > 0 {
            parts.append("\(session.missCount) miss\(session.missCount == 1 ? "" : "es")")
        }

        return parts.joined(separator: ", ")
    }

    var trendSummary: HealthTrendSummary {
        HealthTrendSummary(
            sleepCheckIns: recentSleepCheckIns,
            pvtSessions: recentPVTSessions,
            mealLogs: recentMealLogs,
            workoutLogs: recentWorkoutLogs,
            now: nowProvider(),
            calendar: calendar
        )
    }

    func loadIfNeeded() {
        guard hasLoaded == false else {
            return
        }

        load()
    }

    func load() {
        do {
            let now = nowProvider()
            todaysSleepCheckIn = try healthRepository.fetchSleepCheckIn(on: now, calendar: calendar)
            recentSleepCheckIns = try healthRepository.fetchSleepCheckIns(limit: 14)
            todaysMealLogs = try healthRepository.fetchMealLogs(on: now, calendar: calendar)
            recentMealLogs = try healthRepository.fetchRecentMealLogs(limit: 30)
            todaysWorkoutLogs = try healthRepository.fetchWorkoutLogs(on: now, calendar: calendar)
            recentWorkoutLogs = try healthRepository.fetchRecentWorkoutLogs(limit: 30)
            todaysPVTSessions = try healthRepository.fetchPVTSessions(on: now, calendar: calendar)
            recentPVTSessions = try healthRepository.fetchRecentPVTSessions(limit: 60)
            errorMessage = nil
            hasLoaded = true
        } catch {
            errorMessage = "Unable to load Health: \(error.localizedDescription)"
        }
    }

    func saveSleepCheckIn(_ checkIn: SleepCheckIn, replacingCheckInWithID originalID: UUID? = nil) {
        do {
            try healthRepository.saveSleepCheckIn(checkIn, replacingCheckInWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save sleep check-in: \(error.localizedDescription)"
        }
    }

    func saveMealLog(_ log: MealLog, replacingLogWithID originalID: UUID? = nil) {
        do {
            try healthRepository.saveMealLog(log, replacingLogWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save meal log: \(error.localizedDescription)"
        }
    }

    func saveWorkoutLog(_ log: WorkoutLog, replacingLogWithID originalID: UUID? = nil) {
        do {
            try healthRepository.saveWorkoutLog(log, replacingLogWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save workout log: \(error.localizedDescription)"
        }
    }

    func savePVTSession(_ session: PVTSession) {
        do {
            try healthRepository.savePVTSession(session)
            load()
        } catch {
            errorMessage = "Unable to save PVT session: \(error.localizedDescription)"
        }
    }

    func deleteMealLog(withID id: UUID) {
        do {
            try healthRepository.deleteMealLog(withID: id)
            load()
        } catch {
            errorMessage = "Unable to delete meal log: \(error.localizedDescription)"
        }
    }

    func deleteWorkoutLog(withID id: UUID) {
        do {
            try healthRepository.deleteWorkoutLog(withID: id)
            load()
        } catch {
            errorMessage = "Unable to delete workout log: \(error.localizedDescription)"
        }
    }

}
