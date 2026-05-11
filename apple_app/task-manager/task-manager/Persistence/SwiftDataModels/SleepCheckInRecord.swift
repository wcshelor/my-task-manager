import Foundation
import SwiftData

@Model
final class SleepCheckInRecord {
    var id: UUID = UUID()
    var day: Date = Date.distantPast
    var sleepDurationMinutes: Int?
    var sleepQualityRating: Int?
    var tirednessRating: Int?
    var energyRating: Int?
    var contextTagRawValues: String = ""
    var notes: String?
    var createdAt: Date = Date.distantPast
    var updatedAt: Date = Date.distantPast

    init(checkIn: SleepCheckIn) {
        update(from: checkIn)
    }

    var checkIn: SleepCheckIn {
        SleepCheckIn(
            id: id,
            day: day,
            sleepDurationMinutes: sleepDurationMinutes,
            sleepQualityRating: sleepQualityRating,
            tirednessRating: tirednessRating,
            energyRating: energyRating,
            contextTags: Self.decodeContextTags(contextTagRawValues),
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func update(from checkIn: SleepCheckIn) {
        id = checkIn.id
        day = checkIn.day
        sleepDurationMinutes = checkIn.sleepDurationMinutes
        sleepQualityRating = checkIn.sleepQualityRating
        tirednessRating = checkIn.tirednessRating
        energyRating = checkIn.energyRating
        contextTagRawValues = Self.encodeContextTags(checkIn.contextTags)
        notes = checkIn.notes
        createdAt = checkIn.createdAt
        updatedAt = checkIn.updatedAt
    }

    private static func encodeContextTags(_ tags: [HealthContextTag]) -> String {
        tags.map(\.rawValue).joined(separator: ",")
    }

    private static func decodeContextTags(_ text: String) -> [HealthContextTag] {
        HealthContextTag.cleanedRawValues(text)
    }
}

private extension HealthContextTag {
    static func cleanedRawValues(_ text: String) -> [HealthContextTag] {
        let tags = text
            .split(separator: ",")
            .compactMap { HealthContextTag(rawValue: String($0)) }
        return SleepCheckIn.cleanedTags(tags)
    }
}
