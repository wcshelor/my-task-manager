import Foundation
import SwiftData

@Model
final class AppSettingsRecord {
    static let singletonID = "app-settings"

    @Attribute(.unique) var id: String
    var excludedReadCalendarTitlesText: String
    var writeCalendarTitle: String
    var minimumGapMinutes: Int
    var defaultAssumedDurationMinutes: Int
    var plannerSuggestionCap: Int

    init(
        id: String = AppSettingsRecord.singletonID,
        settings: AppSettings
    ) {
        self.id = id
        self.excludedReadCalendarTitlesText = Self.encodeTitles(settings.excludedReadCalendarTitles)
        self.writeCalendarTitle = settings.writeCalendarTitle
        self.minimumGapMinutes = settings.minimumGapMinutes
        self.defaultAssumedDurationMinutes = settings.defaultAssumedDurationMinutes
        self.plannerSuggestionCap = settings.plannerSuggestionCap
    }

    var settings: AppSettings {
        AppSettings(
            excludedReadCalendarTitles: Self.decodeTitles(excludedReadCalendarTitlesText),
            writeCalendarTitle: writeCalendarTitle,
            minimumGapMinutes: minimumGapMinutes,
            defaultAssumedDurationMinutes: defaultAssumedDurationMinutes,
            plannerSuggestionCap: plannerSuggestionCap
        )
    }

    func update(from settings: AppSettings) {
        excludedReadCalendarTitlesText = Self.encodeTitles(settings.excludedReadCalendarTitles)
        writeCalendarTitle = settings.writeCalendarTitle
        minimumGapMinutes = settings.minimumGapMinutes
        defaultAssumedDurationMinutes = settings.defaultAssumedDurationMinutes
        plannerSuggestionCap = settings.plannerSuggestionCap
    }

    private static func encodeTitles(_ titles: [String]) -> String {
        titles.joined(separator: "\n")
    }

    private static func decodeTitles(_ text: String) -> [String] {
        text
            .split(separator: "\n")
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }
}
