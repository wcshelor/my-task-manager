import Foundation
import Testing
@testable import task_manager

struct HomeWidgetModelTests {
    @Test func defaultLayoutContainsMigratedTodayWidgets() {
        let kinds = HomeLayout.defaultLayout.orderedWidgets.map(\.kind)

        #expect(kinds == [
            .inbox,
            .pinnedProjects,
            .calendarOverview,
            .promises,
            .routines,
            .promiseHistory,
        ])
        #expect(HomeLayout.defaultLayout.orderedWidgets.allSatisfy { $0.size == .large })
    }

    @Test func layoutNormalizesSortOrderDeterministically() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let layout = HomeLayout(
            widgets: [
                HomeWidgetInstance(
                    id: secondID,
                    kind: .promises,
                    size: .large,
                    sortOrder: 10
                ),
                HomeWidgetInstance(
                    id: firstID,
                    kind: .inbox,
                    size: .small,
                    sortOrder: 10
                ),
            ]
        )

        #expect(layout.orderedWidgets.map(\.id) == [firstID, secondID])
        #expect(layout.orderedWidgets.map(\.sortOrder) == [0, 1])
    }

    @Test func unsupportedSizeFallsBackToDescriptorDefault() {
        let registry = HomeWidgetRegistry(
            descriptors: [
                HomeWidgetDescriptor(
                    kind: .inbox,
                    displayName: "Inbox",
                    module: .capture,
                    supportedSizes: [.small],
                    defaultSize: .small
                ),
            ]
        )
        let layout = HomeLayout(
            widgets: [
                HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
            ]
        )

        let normalizedLayout = layout.normalized(using: registry)

        #expect(normalizedLayout.widgets.first?.size == .small)
    }
}
