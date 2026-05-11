import Foundation
import SwiftData

@MainActor
final class SwiftDataHealthRepository: HealthRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func fetchSleepCheckIns(limit: Int) throws -> [SleepCheckIn] {
        Array(
            try fetchAllSleepRecords()
                .map(\.checkIn)
                .sorted { leftCheckIn, rightCheckIn in
                    if leftCheckIn.day != rightCheckIn.day {
                        return leftCheckIn.day > rightCheckIn.day
                    }

                    return leftCheckIn.id.uuidString < rightCheckIn.id.uuidString
                }
                .prefix(max(0, limit))
        )
    }

    func fetchSleepCheckIn(on date: Date, calendar: Calendar) throws -> SleepCheckIn? {
        let dayStart = calendar.startOfDay(for: date)
        return try fetchAllSleepRecords()
            .map(\.checkIn)
            .first { checkIn in
                calendar.isDate(checkIn.day, inSameDayAs: dayStart)
            }
    }

    func saveSleepCheckIn(_ checkIn: SleepCheckIn, replacingCheckInWithID originalID: UUID?) throws {
        let record =
            try originalID.flatMap(fetchSleepRecord(withID:))
            ?? fetchSleepRecord(withID: checkIn.id)
            ?? fetchSleepRecord(on: checkIn.day, calendar: .current)

        if let record {
            record.update(from: checkIn)
        } else {
            modelContext.insert(SleepCheckInRecord(checkIn: checkIn))
        }

        try modelContext.save()
    }

    func fetchMealLogs(on date: Date, calendar: Calendar) throws -> [MealLog] {
        try fetchAllMealRecords()
            .map(\.log)
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sortedForHealthHistory()
    }

    func fetchRecentMealLogs(limit: Int) throws -> [MealLog] {
        Array(
            try fetchAllMealRecords()
                .map(\.log)
                .sortedForHealthHistory()
                .prefix(max(0, limit))
        )
    }

    func mealLog(withID id: UUID) throws -> MealLog? {
        try fetchMealRecord(withID: id)?.log
    }

    func saveMealLog(_ log: MealLog, replacingLogWithID originalID: UUID?) throws {
        let record =
            try originalID.flatMap(fetchMealRecord(withID:))
            ?? fetchMealRecord(withID: log.id)

        if let record {
            record.update(from: log)
        } else {
            modelContext.insert(MealLogRecord(log: log))
        }

        try modelContext.save()
    }

    func deleteMealLog(withID id: UUID) throws {
        guard let record = try fetchMealRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchWorkoutLogs(on date: Date, calendar: Calendar) throws -> [WorkoutLog] {
        try fetchAllWorkoutRecords()
            .map(\.log)
            .filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
            .sortedForHealthHistory()
    }

    func fetchRecentWorkoutLogs(limit: Int) throws -> [WorkoutLog] {
        Array(
            try fetchAllWorkoutRecords()
                .map(\.log)
                .sortedForHealthHistory()
                .prefix(max(0, limit))
        )
    }

    func workoutLog(withID id: UUID) throws -> WorkoutLog? {
        try fetchWorkoutRecord(withID: id)?.log
    }

    func saveWorkoutLog(_ log: WorkoutLog, replacingLogWithID originalID: UUID?) throws {
        let record =
            try originalID.flatMap(fetchWorkoutRecord(withID:))
            ?? fetchWorkoutRecord(withID: log.id)

        if let record {
            record.update(from: log)
        } else {
            modelContext.insert(WorkoutLogRecord(log: log))
        }

        try modelContext.save()
    }

    func deleteWorkoutLog(withID id: UUID) throws {
        guard let record = try fetchWorkoutRecord(withID: id) else {
            return
        }

        modelContext.delete(record)
        try modelContext.save()
    }

    func fetchPVTSessions(on date: Date, calendar: Calendar) throws -> [PVTSession] {
        try fetchAllPVTRecords()
            .map(\.session)
            .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
            .sortedForHealthHistory()
    }

    func fetchRecentPVTSessions(limit: Int) throws -> [PVTSession] {
        Array(
            try fetchAllPVTRecords()
                .map(\.session)
                .sortedForHealthHistory()
                .prefix(max(0, limit))
        )
    }

    func savePVTSession(_ session: PVTSession) throws {
        if let record = try fetchPVTRecord(withID: session.id) {
            record.update(from: session)
        } else {
            modelContext.insert(PVTSessionRecord(session: session))
        }

        try modelContext.save()
    }

    private func fetchAllSleepRecords() throws -> [SleepCheckInRecord] {
        try modelContext.fetch(FetchDescriptor<SleepCheckInRecord>())
    }

    private func fetchSleepRecord(withID id: UUID) throws -> SleepCheckInRecord? {
        try fetchAllSleepRecords().first { $0.id == id }
    }

    private func fetchSleepRecord(on date: Date, calendar: Calendar) throws -> SleepCheckInRecord? {
        try fetchAllSleepRecords().first { record in
            calendar.isDate(record.day, inSameDayAs: date)
        }
    }

    private func fetchAllMealRecords() throws -> [MealLogRecord] {
        try modelContext.fetch(FetchDescriptor<MealLogRecord>())
    }

    private func fetchMealRecord(withID id: UUID) throws -> MealLogRecord? {
        try fetchAllMealRecords().first { $0.id == id }
    }

    private func fetchAllWorkoutRecords() throws -> [WorkoutLogRecord] {
        try modelContext.fetch(FetchDescriptor<WorkoutLogRecord>())
    }

    private func fetchWorkoutRecord(withID id: UUID) throws -> WorkoutLogRecord? {
        try fetchAllWorkoutRecords().first { $0.id == id }
    }

    private func fetchAllPVTRecords() throws -> [PVTSessionRecord] {
        try modelContext.fetch(FetchDescriptor<PVTSessionRecord>())
    }

    private func fetchPVTRecord(withID id: UUID) throws -> PVTSessionRecord? {
        try fetchAllPVTRecords().first { $0.id == id }
    }
}
