import Foundation
import Testing
@testable import task_manager

@MainActor
struct HomeViewModelTests {
    @Test func viewModelLoadsLayout() throws {
        let repository = InMemoryHomeLayoutRepository(
            layout: HomeLayout(
                widgets: [
                    HomeWidgetInstance(kind: .inbox, size: .small, sortOrder: 0),
                ]
            )
        )
        let viewModel = HomeViewModel(homeLayoutRepository: repository)

        viewModel.load()

        #expect(viewModel.widgets.map(\.kind) == [.inbox])
        #expect(viewModel.widgets.first?.size == .small)
    }

    @Test func viewModelAddsGenericModuleWidget() throws {
        let repository = InMemoryHomeLayoutRepository(layout: HomeLayout(widgets: []))
        let viewModel = HomeViewModel(homeLayoutRepository: repository)
        let descriptor = viewModel.registry.moduleWidget(for: .tasks)!
        viewModel.load()

        viewModel.addWidget(from: descriptor)

        #expect(viewModel.widgets.map(\.kind) == [.tasksModule])
        #expect(repository.layout.widgets.map(\.kind) == [.tasksModule])
    }

    @Test func viewModelAddsFeatureWidget() throws {
        let repository = InMemoryHomeLayoutRepository(layout: HomeLayout(widgets: []))
        let viewModel = HomeViewModel(homeLayoutRepository: repository)
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
        let viewModel = HomeViewModel(homeLayoutRepository: repository)
        viewModel.load()

        viewModel.moveWidgets(from: IndexSet(integer: 0), to: 2)

        #expect(viewModel.widgets.map(\.kind) == [.promises, .inbox])
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
        let viewModel = HomeViewModel(homeLayoutRepository: repository)
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
        let viewModel = HomeViewModel(homeLayoutRepository: repository)
        viewModel.load()
        let id = viewModel.widgets.first!.id

        viewModel.resizeWidget(withID: id, to: .small)

        #expect(viewModel.widgets.first?.size == .small)
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
