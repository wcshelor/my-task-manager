import Foundation

@MainActor
protocol HealthRepository {
    func fetchSleepCheckIns(limit: Int) throws -> [SleepCheckIn]
    func fetchSleepCheckIn(on date: Date, calendar: Calendar) throws -> SleepCheckIn?
    func saveSleepCheckIn(_ checkIn: SleepCheckIn, replacingCheckInWithID originalID: UUID?) throws

    func fetchMealLogs(on date: Date, calendar: Calendar) throws -> [MealLog]
    func fetchRecentMealLogs(limit: Int) throws -> [MealLog]
    func mealLog(withID id: UUID) throws -> MealLog?
    func saveMealLog(_ log: MealLog, replacingLogWithID originalID: UUID?) throws
    func deleteMealLog(withID id: UUID) throws

    func fetchWorkoutLogs(on date: Date, calendar: Calendar) throws -> [WorkoutLog]
    func fetchRecentWorkoutLogs(limit: Int) throws -> [WorkoutLog]
    func workoutLog(withID id: UUID) throws -> WorkoutLog?
    func saveWorkoutLog(_ log: WorkoutLog, replacingLogWithID originalID: UUID?) throws
    func deleteWorkoutLog(withID id: UUID) throws

    func fetchPVTSessions(on date: Date, calendar: Calendar) throws -> [PVTSession]
    func fetchRecentPVTSessions(limit: Int) throws -> [PVTSession]
    func savePVTSession(_ session: PVTSession) throws
}
