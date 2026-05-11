import Foundation
import Testing
@testable import task_manager

struct SwiftDataHealthRepositoryTests {
    @Test @MainActor func healthRepositoryRoundTripsRecords() throws {
        let repository = try makeRepository()
        let day = Date(timeIntervalSince1970: 1_000)
        let checkIn = SleepCheckIn(day: day, sleepQualityRating: 4, energyRating: 3)
        let meal = MealLog(timestamp: day, mealType: .breakfast, summary: "Eggs", tags: [.protein])
        let workout = WorkoutLog(timestamp: day, workoutType: .strength, durationMinutes: 45)
        let pvtSession = PVTSession(startedAt: day, reactionTimesMilliseconds: [250, 300, 550], falseStartCount: 1)

        try repository.saveSleepCheckIn(checkIn, replacingCheckInWithID: nil)
        try repository.saveMealLog(meal, replacingLogWithID: nil)
        try repository.saveWorkoutLog(workout, replacingLogWithID: nil)
        try repository.savePVTSession(pvtSession)

        #expect(try repository.fetchSleepCheckIn(on: day, calendar: .current) == checkIn)
        #expect(try repository.mealLog(withID: meal.id) == meal)
        #expect(try repository.workoutLog(withID: workout.id) == workout)
        #expect(try repository.fetchPVTSessions(on: day, calendar: .current) == [pvtSession])
    }

    @Test @MainActor func healthRepositoryUpdatesSleepCheckInForSameDay() throws {
        let repository = try makeRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let morning = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 8))!
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 15))!
        let original = SleepCheckIn(day: morning, sleepQualityRating: 2, calendar: calendar)
        let updated = SleepCheckIn(day: afternoon, sleepQualityRating: 5, energyRating: 4, calendar: calendar)

        try repository.saveSleepCheckIn(original, replacingCheckInWithID: nil)
        try repository.saveSleepCheckIn(updated, replacingCheckInWithID: nil)

        let checkIns = try repository.fetchSleepCheckIns(limit: 10)
        #expect(checkIns.count == 1)
        #expect(checkIns.first?.sleepQualityRating == 5)
        #expect(checkIns.first?.energyRating == 4)
    }

    @Test @MainActor func healthRepositoryFetchesByDayAndRecentHistory() throws {
        let repository = try makeRepository()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 5, day: 11, hour: 10))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let todayMeal = MealLog(timestamp: today, mealType: .lunch, summary: "Soup")
        let oldMeal = MealLog(timestamp: yesterday, mealType: .dinner, summary: "Pasta")
        let todayWorkout = WorkoutLog(timestamp: today, workoutType: .walk)
        let oldWorkout = WorkoutLog(timestamp: yesterday, workoutType: .cardio)
        let todayPVTSession = PVTSession(startedAt: today, reactionTimesMilliseconds: [220, 260])
        let oldPVTSession = PVTSession(startedAt: yesterday, reactionTimesMilliseconds: [320, 360])

        try repository.saveMealLog(oldMeal, replacingLogWithID: nil)
        try repository.saveMealLog(todayMeal, replacingLogWithID: nil)
        try repository.saveWorkoutLog(oldWorkout, replacingLogWithID: nil)
        try repository.saveWorkoutLog(todayWorkout, replacingLogWithID: nil)
        try repository.savePVTSession(oldPVTSession)
        try repository.savePVTSession(todayPVTSession)

        #expect(try repository.fetchMealLogs(on: today, calendar: calendar) == [todayMeal])
        #expect(try repository.fetchWorkoutLogs(on: today, calendar: calendar) == [todayWorkout])
        #expect(try repository.fetchPVTSessions(on: today, calendar: calendar) == [todayPVTSession])
        #expect(try repository.fetchRecentMealLogs(limit: 1) == [todayMeal])
        #expect(try repository.fetchRecentWorkoutLogs(limit: 1) == [todayWorkout])
        #expect(try repository.fetchRecentPVTSessions(limit: 1) == [todayPVTSession])
    }

    @Test @MainActor func healthRepositoryDeletesLogs() throws {
        let repository = try makeRepository()
        let meal = MealLog(summary: "Toast")
        let workout = WorkoutLog(workoutType: .mobility)

        try repository.saveMealLog(meal, replacingLogWithID: nil)
        try repository.saveWorkoutLog(workout, replacingLogWithID: nil)
        try repository.deleteMealLog(withID: meal.id)
        try repository.deleteWorkoutLog(withID: workout.id)

        #expect(try repository.fetchRecentMealLogs(limit: 10).isEmpty)
        #expect(try repository.fetchRecentWorkoutLogs(limit: 10).isEmpty)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataHealthRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataHealthRepository(modelContainer: container)
    }
}
