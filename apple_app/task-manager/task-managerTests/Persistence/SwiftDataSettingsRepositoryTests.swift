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
            writeCalendarTitle: "Important",
            minimumGapMinutes: 20,
            defaultAssumedDurationMinutes: 45,
            plannerSuggestionCap: 7
        )

        try repository.saveSettings(updatedSettings)

        let reloadedSettings = try repository.loadSettings()

        #expect(reloadedSettings == updatedSettings)
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataSettingsRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataSettingsRepository(modelContainer: container)
    }
}
