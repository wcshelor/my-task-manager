import Foundation
import SwiftData

@Model
final class AppSettingsRecord {
    static let singletonID = "app-settings"

    var id: String = AppSettingsRecord.singletonID
    var excludedReadCalendarTitlesText: String = ""
    var writeCalendarIdentifier: String = ""
    var writeCalendarTitle: String = ""
    var minimumGapMinutes: Int = AppSettings.mvpDefault.minimumGapMinutes
    var defaultAssumedDurationMinutes: Int = AppSettings.mvpDefault.defaultAssumedDurationMinutes
    var plannerSuggestionCap: Int = AppSettings.mvpDefault.plannerSuggestionCap

    init(
        id: String = AppSettingsRecord.singletonID,
        settings: AppSettings
    ) {
        self.id = id
        self.excludedReadCalendarTitlesText = Self.encodeTitles(settings.excludedReadCalendarTitles)
        self.writeCalendarIdentifier = settings.writeCalendarIdentifier
        self.writeCalendarTitle = settings.writeCalendarTitle
        self.minimumGapMinutes = settings.minimumGapMinutes
        self.defaultAssumedDurationMinutes = settings.defaultAssumedDurationMinutes
        self.plannerSuggestionCap = settings.plannerSuggestionCap
    }

    var settings: AppSettings {
        AppSettings(
            excludedReadCalendarTitles: Self.decodeTitles(excludedReadCalendarTitlesText),
            writeCalendarIdentifier: writeCalendarIdentifier,
            writeCalendarTitle: writeCalendarTitle,
            minimumGapMinutes: minimumGapMinutes,
            defaultAssumedDurationMinutes: defaultAssumedDurationMinutes,
            plannerSuggestionCap: plannerSuggestionCap
        )
    }

    func update(from settings: AppSettings) {
        excludedReadCalendarTitlesText = Self.encodeTitles(settings.excludedReadCalendarTitles)
        writeCalendarIdentifier = settings.writeCalendarIdentifier
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
