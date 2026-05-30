import Foundation
import Testing
@testable import task_manager

@MainActor
struct SettingsViewModelTests {
    @Test func settingsViewModelLoadsRepositoryState() async {
        let repository = FakeSettingsRepository(
            settings: AppSettings(
                excludedReadCalendarTitles: ["Birthdays"],
                writeCalendarIdentifier: "tasks",
                writeCalendarTitle: "Tasks",
                minimumGapMinutes: 20,
                defaultAssumedDurationMinutes: 45,
                plannerSuggestionCap: 7
            )
        )
        let homeLayoutRepository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
                    HomeWidgetInstance(kind: .promises, size: .small, sortOrder: 1),
                ]
            )
        )
        let viewModel = SettingsViewModel(
            settingsRepository: repository,
            homeLayoutRepository: homeLayoutRepository,
            calendarPermissionProvider: StubCalendarPermissionService(status: .fullAccessGranted),
            calendarListingService: StubCalendarListingService(
                calendars: [
                    ReadableCalendar(
                        id: "tasks",
                        title: "Tasks",
                        allowsContentModifications: true,
                        isExcludedBySettings: false
                    ),
                ]
            )
        )

        await viewModel.loadIfNeeded()

        #expect(viewModel.settings.minimumGapMinutes == 20)
        #expect(viewModel.settings.defaultAssumedDurationMinutes == 45)
        #expect(viewModel.settings.plannerSuggestionCap == 7)
        #expect(viewModel.homeWidgetCount == 2)
        #expect(viewModel.selectedWriteCalendarIdentifier == "tasks")
    }

    @Test func settingsViewModelPersistsPlannerValues() async throws {
        let repository = FakeSettingsRepository()
        let viewModel = SettingsViewModel(
            settingsRepository: repository,
            homeLayoutRepository: InMemoryHomeLayoutRepository(layout: .defaultLayout),
            calendarPermissionProvider: StubCalendarPermissionService(status: .notDetermined),
            calendarListingService: StubCalendarListingService()
        )

        await viewModel.loadIfNeeded()
        viewModel.updateMinimumGapMinutes(25)
        viewModel.updateDefaultAssumedDurationMinutes(45)
        viewModel.updatePlannerSuggestionCap(9)

        let reloaded = try repository.loadSettings()
        #expect(reloaded.minimumGapMinutes == 25)
        #expect(reloaded.defaultAssumedDurationMinutes == 45)
        #expect(reloaded.plannerSuggestionCap == 9)
    }

    @Test func settingsViewModelNormalizesDefaultDurationOnSave() async throws {
        let repository = FakeSettingsRepository()
        let viewModel = SettingsViewModel(
            settingsRepository: repository,
            homeLayoutRepository: InMemoryHomeLayoutRepository(layout: .defaultLayout),
            calendarPermissionProvider: StubCalendarPermissionService(status: .notDetermined),
            calendarListingService: StubCalendarListingService()
        )

        await viewModel.loadIfNeeded()
        viewModel.updateDefaultAssumedDurationMinutes(37)

        let reloaded = try repository.loadSettings()
        #expect(reloaded.defaultAssumedDurationMinutes == 30)
    }

    @Test func settingsViewModelPersistsExcludedCalendars() async throws {
        let repository = FakeSettingsRepository()
        let viewModel = SettingsViewModel(
            settingsRepository: repository,
            homeLayoutRepository: InMemoryHomeLayoutRepository(layout: .defaultLayout),
            calendarPermissionProvider: StubCalendarPermissionService(status: .fullAccessGranted),
            calendarListingService: StubCalendarListingService(
                calendars: [
                    ReadableCalendar(
                        id: "birthdays",
                        title: "Birthdays",
                        allowsContentModifications: false,
                        isExcludedBySettings: false
                    ),
                ]
            )
        )

        await viewModel.loadIfNeeded()
        viewModel.setCalendarExcluded("Birthdays", isExcluded: true)

        let reloaded = try repository.loadSettings()
        #expect(reloaded.excludedReadCalendarTitles == ["Birthdays"])
    }

    @Test func settingsViewModelPersistsWriteCalendarSelection() async throws {
        let repository = FakeSettingsRepository()
        let viewModel = SettingsViewModel(
            settingsRepository: repository,
            homeLayoutRepository: InMemoryHomeLayoutRepository(layout: .defaultLayout),
            calendarPermissionProvider: StubCalendarPermissionService(status: .fullAccessGranted),
            calendarListingService: StubCalendarListingService(
                calendars: [
                    ReadableCalendar(
                        id: "tasks",
                        title: "Tasks",
                        allowsContentModifications: true,
                        isExcludedBySettings: false
                    ),
                ]
            )
        )

        await viewModel.loadIfNeeded()
        viewModel.selectWriteCalendar(withID: "tasks")

        let reloaded = try repository.loadSettings()
        #expect(reloaded.writeCalendarIdentifier == "tasks")
        #expect(reloaded.writeCalendarTitle == "Tasks")
    }
}

@MainActor
private final class FakeSettingsRepository: SettingsRepository {
    var settings: AppSettings

    init(settings: AppSettings = .mvpDefault) {
        self.settings = settings
    }

    func loadSettings() throws -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) throws {
        self.settings = settings
    }
}

@MainActor
private final class InMemoryHomeLayoutRepository: HomeLayoutRepository {
    var layout: HomeLayout

    init(layout: HomeLayout) {
        self.layout = layout
    }

    func loadLayout() throws -> HomeLayout {
        layout
    }

    func saveLayout(_ layout: HomeLayout) throws {
        self.layout = layout
    }
}
