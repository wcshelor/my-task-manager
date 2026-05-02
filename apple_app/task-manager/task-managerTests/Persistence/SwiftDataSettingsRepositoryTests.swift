import SwiftData
import Testing
@testable import task_manager

struct SwiftDataSettingsRepositoryTests {
    @Test @MainActor func settingsRepositorySeedsMVPDefaults() throws {
        let repository = try makeRepository()

        let settings = try repository.loadSettings()

        #expect(settings == .mvpDefault)
    }

    @Test @MainActor func settingsRepositoryPersistsUpdates() throws {
        let repository = try makeRepository()
        let updatedSettings = AppSettings(
            excludedReadCalendarTitles: ["Birthdays", "Holidays"],
            writeCalendarIdentifier: "planner",
            writeCalendarTitle: "Important",
            minimumGapMinutes: 20,
            defaultAssumedDurationMinutes: 45,
            plannerSuggestionCap: 7
        )

        try repository.saveSettings(updatedSettings)

        let reloadedSettings = try repository.loadSettings()

        #expect(reloadedSettings == updatedSettings)
    }

    @Test @MainActor func settingsRepositoryNormalizesInvalidDefaultAssumedDurationOnSave() throws {
        let repository = try makeRepository()
        let updatedSettings = AppSettings(
            excludedReadCalendarTitles: [],
            writeCalendarIdentifier: "planner",
            writeCalendarTitle: "Important",
            minimumGapMinutes: 15,
            defaultAssumedDurationMinutes: 37,
            plannerSuggestionCap: 5
        )

        try repository.saveSettings(updatedSettings)

        let reloadedSettings = try repository.loadSettings()

        #expect(reloadedSettings.defaultAssumedDurationMinutes == 30)
    }

    @Test @MainActor func settingsRepositoryRepairsLegacyInvalidDefaultAssumedDurationOnLoad() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let record = AppSettingsRecord(settings: .mvpDefault)
        record.defaultAssumedDurationMinutes = 20
        container.mainContext.insert(record)
        try container.mainContext.save()

        let repository = SwiftDataSettingsRepository(modelContainer: container)
        let settings = try repository.loadSettings()
        let persistedRecord = try container.mainContext
            .fetch(FetchDescriptor<AppSettingsRecord>())
            .first { $0.id == AppSettingsRecord.singletonID }

        #expect(settings.defaultAssumedDurationMinutes == 30)
        #expect(persistedRecord?.defaultAssumedDurationMinutes == 30)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataSettingsRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataSettingsRepository(modelContainer: container)
    }
}
