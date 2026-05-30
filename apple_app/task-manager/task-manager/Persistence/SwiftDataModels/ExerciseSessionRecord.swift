import Foundation
import SwiftData

@Model
final class ExerciseSessionRecord {
    var id: UUID = UUID()
    var exerciseID: UUID = UUID()
    var performedAt: Date = Date.distantPast
    var strengthSetsData: Data = Data()
    var durationMinutes: Int?
    var difficultyLevel: Int?
    var averageRPM: Int?
    var distance: Double?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(session: ExerciseSession) {
        update(from: session)
    }

    var session: ExerciseSession {
        ExerciseSession(
            id: id,
            exerciseID: exerciseID,
            performedAt: performedAt,
            strengthSets: Self.decode([StrengthSet].self, from: strengthSetsData) ?? [],
            durationMinutes: durationMinutes,
            difficultyLevel: difficultyLevel,
            averageRPM: averageRPM,
            distance: distance,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from session: ExerciseSession) {
        id = session.id
        exerciseID = session.exerciseID
        performedAt = session.performedAt
        strengthSetsData = Self.encode(session.strengthSets)
        durationMinutes = session.durationMinutes
        difficultyLevel = session.difficultyLevel
        averageRPM = session.averageRPM
        distance = session.distance
        createdAt = session.createdAt
        updatedAt = session.updatedAt
    }

    private static func encode<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}
