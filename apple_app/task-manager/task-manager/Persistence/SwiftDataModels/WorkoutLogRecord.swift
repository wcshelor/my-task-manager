import Foundation
import SwiftData

@Model
final class WorkoutLogRecord {
    var id: UUID = UUID()
    var timestamp: Date = Date.distantPast
    var workoutTypeRawValue: String = WorkoutType.other.rawValue
    var durationMinutes: Int?
    var intensityRating: Int?
    var energyBeforeRating: Int?
    var energyAfterRating: Int?
    var notes: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(log: WorkoutLog) {
        update(from: log)
    }

    var log: WorkoutLog {
        WorkoutLog(
            id: id,
            timestamp: timestamp,
            workoutType: WorkoutType(rawValue: workoutTypeRawValue) ?? .other,
            durationMinutes: durationMinutes,
            intensityRating: intensityRating,
            energyBeforeRating: energyBeforeRating,
            energyAfterRating: energyAfterRating,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from log: WorkoutLog) {
        id = log.id
        timestamp = log.timestamp
        workoutTypeRawValue = log.workoutType.rawValue
        durationMinutes = log.durationMinutes
        intensityRating = log.intensityRating
        energyBeforeRating = log.energyBeforeRating
        energyAfterRating = log.energyAfterRating
        notes = log.notes
        createdAt = log.createdAt
        updatedAt = log.updatedAt
    }
}
