import Foundation
import Testing
@testable import task_manager

@MainActor
struct HealthViewModelTests {
    @Test func healthViewModelLoadsDashboardState() {
        let now = Date(timeIntervalSince1970: 1_000)
        let checkIn = SleepCheckIn(day: now, energyRating: 4)
        let meal = MealLog(timestamp: now, mealType: .breakfast, summary: "Oats")
        let workout = WorkoutLog(timestamp: now, workoutType: .walk, durationMinutes: 30)
        let pvtSession = PVTSession(startedAt: now, reactionTimesMilliseconds: [250, 320, 510])
        let repository = FakeHealthRepository(
            sleepCheckIns: [checkIn],
            mealLogs: [meal],
            workoutLogs: [workout],
            pvtSessions: [pvtSession]
        )
        let viewModel = HealthViewModel(
            healthRepository: repository,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        #expect(viewModel.todaysSleepCheckIn == checkIn)
        #expect(viewModel.todaysMealLogs == [meal])
        #expect(viewModel.todaysWorkoutLogs == [workout])
        #expect(viewModel.todaysPVTSessions == [pvtSession])
        #expect(viewModel.sleepStatusSummary == "Energy 4/5")
        #expect(viewModel.mealsTodaySummary == "1 meal today")
        #expect(viewModel.latestWorkoutSummary == "Walk, 30m")
        #expect(viewModel.pvtStatusSummary == "Median 320ms, 1 lapse")
    }

    @Test func healthViewModelSavesAndRefreshesRecords() {
        let now = Date(timeIntervalSince1970: 1_000)
        let repository = FakeHealthRepository()
        let viewModel = HealthViewModel(
            healthRepository: repository,
            nowProvider: { now }
        )
        let checkIn = SleepCheckIn(day: now, sleepQualityRating: 4)
        let meal = MealLog(timestamp: now, summary: "Lunch")
        let workout = WorkoutLog(timestamp: now, workoutType: .strength)
        let pvtSession = PVTSession(startedAt: now, reactionTimesMilliseconds: [220, 280])

        viewModel.loadIfNeeded()
        viewModel.saveSleepCheckIn(checkIn)
        viewModel.saveMealLog(meal)
        viewModel.saveWorkoutLog(workout)
        viewModel.savePVTSession(pvtSession)

        #expect(viewModel.todaysSleepCheckIn == checkIn)
        #expect(viewModel.todaysMealLogs == [meal])
        #expect(viewModel.todaysWorkoutLogs == [workout])
        #expect(viewModel.todaysPVTSessions == [pvtSession])
    }

    @Test func healthViewModelComputesTrendSummaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 12))!
        let previousWeek = calendar.date(byAdding: .day, value: -8, to: now)!
        let checkIn = SleepCheckIn(day: now, sleepDurationMinutes: 420, sleepQualityRating: 4, energyRating: 3, calendar: calendar)
        let previousCheckIn = SleepCheckIn(day: previousWeek, sleepDurationMinutes: 360, sleepQualityRating: 2, calendar: calendar)
        let meal = MealLog(timestamp: now, mealType: .breakfast, summary: "Oats", tags: [.protein], energyAfterRating: 4)
        let workout = WorkoutLog(timestamp: now, workoutType: .strength, durationMinutes: 45, intensityRating: 4, energyBeforeRating: 2, energyAfterRating: 4)
        let pvtSession = PVTSession(startedAt: now, reactionTimesMilliseconds: [240, 300, 520])
        let previousPVTSession = PVTSession(startedAt: previousWeek, reactionTimesMilliseconds: [400, 500, 600])
        let repository = FakeHealthRepository(
            sleepCheckIns: [checkIn, previousCheckIn],
            mealLogs: [meal],
            workoutLogs: [workout],
            pvtSessions: [pvtSession, previousPVTSession]
        )
        let viewModel = HealthViewModel(
            healthRepository: repository,
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.loadIfNeeded()

        let trends = viewModel.trendSummary
        #expect(trends.sleepPVT.current7Days.daysLogged == 1)
        #expect(trends.sleepPVT.previous7Days.daysLogged == 1)
        #expect(trends.sleepPVT.current7Days.averageSleepDurationMinutes == 420)
        #expect(trends.sleepPVT.current7Days.averagePVTMedianMilliseconds == 300)
        #expect(trends.sleepPVT.previous7Days.averagePVTMedianMilliseconds == 500)
        #expect(trends.nutrition.current7Days.mealCount == 1)
        #expect(trends.nutrition.current7Days.tagCounts[.protein] == 1)
        #expect(trends.workouts.current7Days.totalDurationMinutes == 45)
        #expect(trends.workouts.current7Days.averageEnergyDelta == 2)
    }

    @Test func healthViewModelSurfacesRepositoryErrors() {
        let repository = FakeHealthRepository(shouldThrow: true)
        let viewModel = HealthViewModel(healthRepository: repository)

        viewModel.loadIfNeeded()

        #expect(viewModel.errorMessage?.contains("Unable to load Health") == true)
    }
}

private enum FakeHealthRepositoryError: Error {
    case requestedFailure
}

@MainActor
private final class FakeHealthRepository: HealthRepository {
    var sleepCheckIns: [SleepCheckIn]
    var mealLogs: [MealLog]
    var workoutLogs: [WorkoutLog]
    var pvtSessions: [PVTSession]
    var shouldThrow: Bool

    init(
        sleepCheckIns: [SleepCheckIn] = [],
        mealLogs: [MealLog] = [],
        workoutLogs: [WorkoutLog] = [],
        pvtSessions: [PVTSession] = [],
        shouldThrow: Bool = false
    ) {
        self.sleepCheckIns = sleepCheckIns
        self.mealLogs = mealLogs
        self.workoutLogs = workoutLogs
        self.pvtSessions = pvtSessions
        self.shouldThrow = shouldThrow
    }

    func fetchSleepCheckIns(limit: Int) throws -> [SleepCheckIn] {
        try failIfNeeded()
        return Array(
            sleepCheckIns
                .sorted { $0.day > $1.day }
                .prefix(max(0, limit))
        )
    }

    func fetchSleepCheckIn(on date: Date, calendar: Calendar) throws -> SleepCheckIn? {
        try failIfNeeded()
        return sleepCheckIns.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    func saveSleepCheckIn(_ checkIn: SleepCheckIn, replacingCheckInWithID originalID: UUID?) throws {
        try failIfNeeded()
        let targetID = originalID ?? checkIn.id
        if let index = sleepCheckIns.firstIndex(where: { $0.id == targetID || Calendar.current.isDate($0.day, inSameDayAs: checkIn.day) }) {
            sleepCheckIns[index] = checkIn
        } else {
            sleepCheckIns.append(checkIn)
        }
    }

    func fetchMealLogs(on date: Date, calendar: Calendar) throws -> [MealLog] {
        try failIfNeeded()
        return mealLogs
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sortedForHealthHistory()
    }

    func fetchRecentMealLogs(limit: Int) throws -> [MealLog] {
        try failIfNeeded()
        return Array(mealLogs.sortedForHealthHistory().prefix(max(0, limit)))
    }

    func mealLog(withID id: UUID) throws -> MealLog? {
        try failIfNeeded()
        return mealLogs.first { $0.id == id }
    }

    func saveMealLog(_ log: MealLog, replacingLogWithID originalID: UUID?) throws {
        try failIfNeeded()
        let targetID = originalID ?? log.id
        if let index = mealLogs.firstIndex(where: { $0.id == targetID || $0.id == log.id }) {
            mealLogs[index] = log
        } else {
            mealLogs.append(log)
        }
    }

    func deleteMealLog(withID id: UUID) throws {
        try failIfNeeded()
        mealLogs.removeAll { $0.id == id }
    }

    func fetchWorkoutLogs(on date: Date, calendar: Calendar) throws -> [WorkoutLog] {
        try failIfNeeded()
        return workoutLogs
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sortedForHealthHistory()
    }

    func fetchRecentWorkoutLogs(limit: Int) throws -> [WorkoutLog] {
        try failIfNeeded()
        return Array(workoutLogs.sortedForHealthHistory().prefix(max(0, limit)))
    }

    func workoutLog(withID id: UUID) throws -> WorkoutLog? {
        try failIfNeeded()
        return workoutLogs.first { $0.id == id }
    }

    func saveWorkoutLog(_ log: WorkoutLog, replacingLogWithID originalID: UUID?) throws {
        try failIfNeeded()
        let targetID = originalID ?? log.id
        if let index = workoutLogs.firstIndex(where: { $0.id == targetID || $0.id == log.id }) {
            workoutLogs[index] = log
        } else {
            workoutLogs.append(log)
        }
    }

    func deleteWorkoutLog(withID id: UUID) throws {
        try failIfNeeded()
        workoutLogs.removeAll { $0.id == id }
    }

    func fetchPVTSessions(on date: Date, calendar: Calendar) throws -> [PVTSession] {
        try failIfNeeded()
        return pvtSessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
            .sortedForHealthHistory()
    }

    func fetchRecentPVTSessions(limit: Int) throws -> [PVTSession] {
        try failIfNeeded()
        return Array(pvtSessions.sortedForHealthHistory().prefix(max(0, limit)))
    }

    func savePVTSession(_ session: PVTSession) throws {
        try failIfNeeded()
        if let index = pvtSessions.firstIndex(where: { $0.id == session.id }) {
            pvtSessions[index] = session
        } else {
            pvtSessions.append(session)
        }
    }

    private func failIfNeeded() throws {
        if shouldThrow {
            throw FakeHealthRepositoryError.requestedFailure
        }
    }
}
