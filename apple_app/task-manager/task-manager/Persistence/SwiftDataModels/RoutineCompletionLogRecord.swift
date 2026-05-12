import Foundation
import SwiftData

@Model
final class RoutineCompletionLogRecord {
    var id: UUID = UUID()
    var routineID: UUID = UUID()
    var date: Date = Date.distantPast
    var completedItemIDsText: String = ""
    var skippedItemIDsText: String = ""
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(log: RoutineCompletionLog) {
        update(from: log)
    }

    var log: RoutineCompletionLog {
        RoutineCompletionLog(
            id: id,
            routineID: routineID,
            date: date,
            completedItemIDs: Self.decodeCompletedItemIDs(completedItemIDsText),
            skippedItemIDs: Self.decodeCompletedItemIDs(skippedItemIDsText),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from log: RoutineCompletionLog) {
        id = log.id
        routineID = log.routineID
        date = log.date
        completedItemIDsText = Self.encodeCompletedItemIDs(log.completedItemIDs)
        skippedItemIDsText = Self.encodeCompletedItemIDs(log.skippedItemIDs)
        createdAt = log.createdAt
        updatedAt = log.updatedAt
    }

    private static func encodeCompletedItemIDs(_ ids: Set<UUID>) -> String {
        ids.map(\.uuidString).sorted().joined(separator: ",")
    }

    private static func decodeCompletedItemIDs(_ text: String) -> Set<UUID> {
        Set(text.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }
}
