import Foundation
import SwiftData

@MainActor
final class SwiftDataSettingsRepository: SettingsRepository {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = modelContainer.mainContext
    }

    func loadSettings() throws -> AppSettings {
        if let record = try fetchRecord() {
            let settings = record.settings

            if recordNeedsNormalization(record, normalizedSettings: settings) {
                record.update(from: settings)
                try modelContext.save()
            }

            return settings
        }

        let record = AppSettingsRecord(settings: .mvpDefault)
        modelContext.insert(record)
        try modelContext.save()
        return record.settings
    }

    func saveSettings(_ settings: AppSettings) throws {
        if let record = try fetchRecord() {
            record.update(from: settings)
        } else {
            modelContext.insert(AppSettingsRecord(settings: settings))
        }

        try modelContext.save()
    }

    private func fetchRecord() throws -> AppSettingsRecord? {
        try modelContext.fetch(FetchDescriptor<AppSettingsRecord>()).first {
            $0.id == AppSettingsRecord.singletonID
        }
    }

    private func recordNeedsNormalization(
        _ record: AppSettingsRecord,
        normalizedSettings: AppSettings
    ) -> Bool {
        record.writeCalendarIdentifier != normalizedSettings.writeCalendarIdentifier
            || record.writeCalendarTitle != normalizedSettings.writeCalendarTitle
            || record.minimumGapMinutes != normalizedSettings.minimumGapMinutes
            || record.defaultAssumedDurationMinutes != normalizedSettings.defaultAssumedDurationMinutes
            || record.plannerSuggestionCap != normalizedSettings.plannerSuggestionCap
    }
}
