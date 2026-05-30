import Foundation
import Testing
@testable import task_manager

@MainActor
struct HomeLayoutViewModelTests {
    @Test func viewModelLoadsLayout() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .small, sortOrder: 0),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)

        viewModel.load()

        #expect(viewModel.widgets.map(\.kind) == [.inbox])
        #expect(viewModel.widgets.first?.size == .small)
    }

    @Test func viewModelAddsGenericModuleWidget() throws {
        let repository = InMemoryHomeLayoutRepository(layout: HomeLayout(widgets: []))
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        let descriptor = viewModel.registry.moduleWidget(for: .tasks)!
        viewModel.load()

        viewModel.addWidget(from: descriptor)

        #expect(viewModel.widgets.map(\.kind) == [.tasksModule])
        #expect(repository.layout.widgets.map(\.kind) == [.tasksModule])
    }

    @Test func viewModelAddsFeatureWidget() throws {
        let repository = InMemoryHomeLayoutRepository(layout: HomeLayout(widgets: []))
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        let descriptor = viewModel.registry.descriptor(for: .calendarOverview)!
        viewModel.load()

        viewModel.addWidget(from: descriptor, size: .small)

        #expect(viewModel.widgets.map(\.kind) == [.calendarOverview])
        #expect(viewModel.widgets.first?.size == .small)
    }

    @Test func viewModelReordersWidgets() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
                    HomeWidgetInstance(kind: .promises, size: .large, sortOrder: 1),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        viewModel.load()

        viewModel.moveWidgets(from: IndexSet(integer: 0), to: 2)

        #expect(viewModel.widgets.map(\.kind) == [.promises, .inbox])
    }

    @Test func viewModelCanMoveWidgetAfterTarget() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
                    HomeWidgetInstance(kind: .promises, size: .large, sortOrder: 1),
                    HomeWidgetInstance(kind: .routines, size: .large, sortOrder: 2),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        viewModel.load()
        let movingID = viewModel.widgets[0].id
        let targetID = viewModel.widgets[1].id

        viewModel.moveWidget(
            withID: movingID,
            relativeTo: targetID,
            placement: .after
        )

        #expect(viewModel.widgets.map(\.kind) == [.promises, .inbox, .routines])
    }

    @Test func reorderedWidgetsCanMoveBeforeTarget() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
                    HomeWidgetInstance(kind: .promises, size: .large, sortOrder: 1),
                    HomeWidgetInstance(kind: .routines, size: .large, sortOrder: 2),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        viewModel.load()

        let reorderedWidgets = viewModel.reorderedWidgets(
            movingID: viewModel.widgets[2].id,
            relativeTo: viewModel.widgets[0].id,
            placement: .before
        )

        #expect(reorderedWidgets.map(\.kind) == [.routines, .inbox, .promises])
    }

    @Test func reorderedWidgetsCanMoveAfterTarget() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
                    HomeWidgetInstance(kind: .promises, size: .large, sortOrder: 1),
                    HomeWidgetInstance(kind: .routines, size: .large, sortOrder: 2),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        viewModel.load()

        let reorderedWidgets = viewModel.reorderedWidgets(
            movingID: viewModel.widgets[0].id,
            relativeTo: viewModel.widgets[1].id,
            placement: .after
        )

        #expect(reorderedWidgets.map(\.kind) == [.promises, .inbox, .routines])
    }

    @Test func reorderedWidgetsIsNoOpWhenMovingRelativeToSelf() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
                    HomeWidgetInstance(kind: .promises, size: .large, sortOrder: 1),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        viewModel.load()

        let reorderedWidgets = viewModel.reorderedWidgets(
            movingID: viewModel.widgets[0].id,
            relativeTo: viewModel.widgets[0].id,
            placement: .before
        )

        #expect(reorderedWidgets.map(\.id) == viewModel.widgets.map(\.id))
    }

    @Test func reorderedWidgetsPreservesStableSortOrder() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
                    HomeWidgetInstance(kind: .promises, size: .large, sortOrder: 1),
                    HomeWidgetInstance(kind: .routines, size: .large, sortOrder: 2),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        viewModel.load()

        let reorderedWidgets = viewModel.reorderedWidgets(
            movingID: viewModel.widgets[2].id,
            relativeTo: viewModel.widgets[0].id,
            placement: .before
        )

        #expect(reorderedWidgets.map(\.sortOrder) == [0, 1, 2])
    }

    @Test func viewModelRemovesWidgets() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
                    HomeWidgetInstance(kind: .promises, size: .large, sortOrder: 1),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        viewModel.load()
        let id = viewModel.widgets.first!.id

        viewModel.removeWidget(withID: id)

        #expect(viewModel.widgets.map(\.kind) == [.promises])
    }

    @Test func viewModelResizesSupportedWidgets() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        viewModel.load()
        let id = viewModel.widgets.first!.id

        viewModel.resizeWidget(withID: id, to: .small)

        #expect(viewModel.widgets.first?.size == .small)
    }

    @Test func viewModelBlocksDuplicateGenericWidgets() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .small, sortOrder: 0),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        let descriptor = viewModel.registry.descriptor(for: .inbox)!
        viewModel.load()

        viewModel.addWidget(from: descriptor)

        #expect(viewModel.widgets.map(\.kind) == [.inbox])
    }

    @Test func viewModelAddsConfiguredWidgetVariants() throws {
        let repository = InMemoryHomeLayoutRepository(layout: HomeLayout(widgets: []))
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        let descriptor = viewModel.registry.descriptor(for: .projectNextTask)!
        var firstConfig = HomeWidgetConfiguration.empty
        firstConfig.projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        var secondConfig = HomeWidgetConfiguration.empty
        secondConfig.projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")
        viewModel.load()

        viewModel.addWidget(from: descriptor, configuration: firstConfig)
        viewModel.addWidget(from: descriptor, configuration: secondConfig)
        viewModel.addWidget(from: descriptor, configuration: firstConfig)

        #expect(viewModel.widgets.count == 2)
        #expect(viewModel.widgets.map(\.configuration) == [firstConfig, secondConfig])
    }

    @Test func viewModelRestoresRemovedConfiguredWidget() throws {
        var configuration = HomeWidgetConfiguration.empty
        configuration.projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        let removedID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [],
                removedWidgets: [
                    HomeWidgetInstance(
                        id: removedID,
                        kind: .projectNextTask,
                        size: .small,
                        sortOrder: 0,
                        configuration: configuration
                    ),
                ]
            )
        )
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        let descriptor = viewModel.registry.descriptor(for: .projectNextTask)!
        viewModel.load()

        viewModel.addWidget(from: descriptor, configuration: configuration)

        #expect(viewModel.widgets.first?.id == removedID)
        #expect(repository.layout.removedWidgets.isEmpty)
    }

    @Test func viewModelResetsToDefaultLayout() throws {
        let repository = InMemoryHomeLayoutRepository(layout: HomeLayout(widgets: []))
        let viewModel = HomeLayoutViewModel(homeLayoutRepository: repository)
        viewModel.load()

        viewModel.resetToDefaultLayout()

        #expect(viewModel.widgets.map(\.kind) == HomeLayout.defaultLayout.widgets.map(\.kind))
    }

    @Test func viewModelHidesVisibleWidgetIntoRemovedWidgets() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .tasksModule, size: .small, sortOrder: 0),
                ]
            )
        )
        let settingsRepository = InMemorySettingsRepository()
        let viewModel = HomeLayoutViewModel(
            homeLayoutRepository: repository,
            settingsRepository: settingsRepository
        )
        let descriptor = viewModel.registry.descriptor(for: .tasksModule)!
        viewModel.load()

        viewModel.setVisibility(false, for: descriptor)

        #expect(viewModel.widgets.isEmpty)
        #expect(repository.layout.removedWidgets.map(\.kind) == [.tasksModule])
        #expect(settingsRepository.settings.hiddenHomeWidgetKinds == ["tasksModule"])
    }

    @Test func viewModelRestoresHiddenWidgetWithSameIdentifier() throws {
        let removedID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [],
                removedWidgets: [
                    HomeWidgetInstance(
                        id: removedID,
                        kind: .tasksModule,
                        size: .small,
                        sortOrder: 0
                    ),
                ]
            )
        )
        let settingsRepository = InMemorySettingsRepository(
            settings: AppSettings(
                excludedReadCalendarTitles: ["Birthdays"],
                writeCalendarIdentifier: "",
                writeCalendarTitle: "Tasks",
                hiddenHomeWidgetKinds: ["tasksModule"],
                minimumGapMinutes: 15,
                defaultAssumedDurationMinutes: 30,
                plannerSuggestionCap: 5
            )
        )
        let viewModel = HomeLayoutViewModel(
            homeLayoutRepository: repository,
            settingsRepository: settingsRepository
        )
        let descriptor = viewModel.registry.descriptor(for: .tasksModule)!
        viewModel.load()

        viewModel.setVisibility(true, for: descriptor)

        #expect(viewModel.widgets.first?.id == removedID)
        #expect(repository.layout.removedWidgets.isEmpty)
        #expect(settingsRepository.settings.hiddenHomeWidgetKinds.isEmpty)
    }

    @Test func viewModelCanReorderAfterVisibilityToggle() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .tasksModule, size: .small, sortOrder: 0),
                    HomeWidgetInstance(kind: .promises, size: .large, sortOrder: 1),
                ]
            )
        )
        let settingsRepository = InMemorySettingsRepository()
        let viewModel = HomeLayoutViewModel(
            homeLayoutRepository: repository,
            settingsRepository: settingsRepository
        )
        let descriptor = viewModel.registry.descriptor(for: .tasksModule)!
        viewModel.load()

        viewModel.setVisibility(false, for: descriptor)
        viewModel.setVisibility(true, for: descriptor)
        viewModel.moveWidgets(from: IndexSet(integer: 0), to: 2)

        #expect(viewModel.widgets.map(\.kind) == [.tasksModule, .promises])
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

@MainActor
private final class InMemorySettingsRepository: SettingsRepository {
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
