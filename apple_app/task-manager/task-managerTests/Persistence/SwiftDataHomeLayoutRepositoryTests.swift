import SwiftData
import Testing
@testable import task_manager

struct SwiftDataHomeLayoutRepositoryTests {
    @Test @MainActor func homeLayoutRepositorySeedsDefaultLayout() throws {
        let repository = try makeRepository()

        let layout = try repository.loadLayout()

        #expect(layout == HomeLayout.defaultLayout)
    }

    @Test @MainActor func homeLayoutRepositoryPersistsUpdates() throws {
        let repository = try makeRepository()
        let updatedLayout = HomeLayout(
            widgets: [
                HomeWidgetInstance(kind: .promises, size: .small, sortOrder: 0),
                HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 1),
            ]
        )

        try repository.saveLayout(updatedLayout)
        let reloadedLayout = try repository.loadLayout()

        #expect(reloadedLayout == updatedLayout)
    }

    @Test @MainActor func homeLayoutRepositoryPersistsRemovedWidgets() throws {
        let repository = try makeRepository()
        var layout = try repository.loadLayout()
        layout.widgets.removeAll { $0.kind == .promiseHistory }

        try repository.saveLayout(layout)
        let reloadedLayout = try repository.loadLayout()

        #expect(reloadedLayout.widgets.contains { $0.kind == .promiseHistory } == false)
    }

    @Test @MainActor func homeLayoutRepositoryRepairsCorruptStoredLayout() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let record = HomeLayoutRecord(layout: HomeLayout.defaultLayout)
        record.widgetsJSON = "not-json"
        container.mainContext.insert(record)
        try container.mainContext.save()

        let repository = SwiftDataHomeLayoutRepository(modelContainer: container)
        let layout = try repository.loadLayout()

        #expect(layout == HomeLayout.defaultLayout)
    }

    @Test @MainActor func homeLayoutRepositoryIgnoresUnknownStoredWidgetKinds() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let record = HomeLayoutRecord(layout: HomeLayout.defaultLayout)
        record.widgetsJSON = """
        [
          {
            "id": "00000000-0000-0000-0000-000000000001",
            "kind": "inbox",
            "size": "small",
            "sortOrder": 0,
            "configuration": { "version": 1, "values": {} }
          },
          {
            "id": "00000000-0000-0000-0000-000000000002",
            "kind": "futureUnknownWidget",
            "size": "large",
            "sortOrder": 1,
            "configuration": { "version": 1, "values": {} }
          }
        ]
        """
        container.mainContext.insert(record)
        try container.mainContext.save()

        let repository = SwiftDataHomeLayoutRepository(modelContainer: container)
        let layout = try repository.loadLayout()

        #expect(layout.widgets.map(\.kind) == [.inbox])
    }

    @MainActor
    private func makeRepository() throws -> SwiftDataHomeLayoutRepository {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        return SwiftDataHomeLayoutRepository(modelContainer: container)
    }
}
