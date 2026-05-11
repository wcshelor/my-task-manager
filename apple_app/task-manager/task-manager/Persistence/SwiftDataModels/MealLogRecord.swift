import Foundation
import SwiftData

@Model
final class MealLogRecord {
    var id: UUID = UUID()
    var timestamp: Date = Date.distantPast
    var mealTypeRawValue: String = MealType.other.rawValue
    var summary: String = ""
    var tagRawValues: String = ""
    var energyAfterRating: Int?
    var notes: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(log: MealLog) {
        update(from: log)
    }

    var log: MealLog {
        MealLog(
            id: id,
            timestamp: timestamp,
            mealType: MealType(rawValue: mealTypeRawValue) ?? .other,
            summary: summary,
            tags: Self.decodeTags(tagRawValues),
            energyAfterRating: energyAfterRating,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from log: MealLog) {
        id = log.id
        timestamp = log.timestamp
        mealTypeRawValue = log.mealType.rawValue
        summary = log.summary
        tagRawValues = Self.encodeTags(log.tags)
        energyAfterRating = log.energyAfterRating
        notes = log.notes
        createdAt = log.createdAt
        updatedAt = log.updatedAt
    }

    private static func encodeTags(_ tags: [MealTag]) -> String {
        tags.map(\.rawValue).joined(separator: ",")
    }

    private static func decodeTags(_ text: String) -> [MealTag] {
        let tags = text
            .split(separator: ",")
            .compactMap { MealTag(rawValue: String($0)) }
        return MealLog.cleanedTags(tags)
    }
}
