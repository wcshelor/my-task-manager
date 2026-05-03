import Foundation

@MainActor
protocol RoutineRepository {
    func fetchRoutines() throws -> [Routine]
    func fetchActiveRoutines(on date: Date, calendar: Calendar) throws -> [Routine]
    func routine(withID id: UUID) throws -> Routine?
    func saveRoutine(_ routine: Routine, replacingRoutineWithID originalID: UUID?) throws
    func deleteRoutine(withID id: UUID) throws
    func fetchCompletionLog(for routineID: UUID, on date: Date, calendar: Calendar) throws -> RoutineCompletionLog?
    func fetchCompletionLogs(on date: Date, calendar: Calendar) throws -> [RoutineCompletionLog]
    func saveCompletionLog(_ log: RoutineCompletionLog, replacingLogWithID originalID: UUID?) throws
}
