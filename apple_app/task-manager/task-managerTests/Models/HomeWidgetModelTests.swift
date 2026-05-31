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
            .debriefsPending,
            .promises,
            .routines,
            .promiseHistory,
            .shoppingModule,
            .healthModule,
            .musicPracticeModule,
            .fitnessModule,
            .peopleMemoryModule,
        ])
        #expect(HomeLayout.defaultLayout.orderedWidgets.dropLast(5).allSatisfy { $0.size == .large })
        #expect(HomeLayout.defaultLayout.orderedWidgets.suffix(5).allSatisfy { $0.size == .small })
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
                    iconSystemName: "tray",
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

    @Test func layoutPreservesUnknownWidgetKindsAsUnavailable() {
        let unknownKind = HomeWidgetKind(rawValue: "futureUnknownWidget")
        let layout = HomeLayout(
            widgets: [
                HomeWidgetInstance(kind: unknownKind, size: .large, sortOrder: 0),
            ]
        )

        let normalizedLayout = layout.normalized()
        let descriptor = HomeWidgetRegistry.standard.descriptor(for: unknownKind)

        #expect(normalizedLayout.widgets.map(\.kind) == [unknownKind])
        #expect(descriptor?.isAvailable == false)
    }

    @Test func duplicatePolicyBlocksGenericDuplicateAndAllowsConfiguredVariants() {
        let registry = HomeWidgetRegistry.standard
        let projectDescriptor = registry.descriptor(for: .projectNextTask)!
        var firstConfig = HomeWidgetConfiguration.empty
        firstConfig.projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")
        var secondConfig = HomeWidgetConfiguration.empty
        secondConfig.projectID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")
        let layout = HomeLayout(
            widgets: [
                HomeWidgetInstance(kind: .inbox, size: .small, sortOrder: 0),
                HomeWidgetInstance(
                    kind: .projectNextTask,
                    size: .small,
                    sortOrder: 1,
                    configuration: firstConfig
                ),
            ]
        )

        #expect(registry.canAdd(descriptor: registry.descriptor(for: .inbox)!, configuration: .empty, to: layout) == false)
        #expect(registry.canAdd(descriptor: projectDescriptor, configuration: .empty, to: layout) == false)
        #expect(registry.canAdd(descriptor: projectDescriptor, configuration: firstConfig, to: layout) == false)
        #expect(registry.canAdd(descriptor: projectDescriptor, configuration: secondConfig, to: layout))
    }

    @Test func healthModuleWidgetIsAvailable() {
        let registry = HomeWidgetRegistry.standard
        let descriptor = registry.descriptor(for: .healthModule)

        #expect(descriptor?.module == .health)
        #expect(descriptor?.isAvailable == true)
        #expect(registry.moduleWidget(for: .health)?.kind == .healthModule)
        #expect(registry.canAdd(
            descriptor: descriptor!,
            configuration: .empty,
            to: HomeLayout(widgets: [])
        ))
        #expect(registry.canAdd(
            descriptor: descriptor!,
            configuration: .empty,
            to: HomeLayout(widgets: [
                HomeWidgetInstance(kind: .healthModule, size: .small, sortOrder: 0),
            ])
        ) == false)
    }

    @Test func musicPracticeModuleWidgetIsAvailable() {
        let registry = HomeWidgetRegistry.standard
        let descriptor = registry.descriptor(for: .musicPracticeModule)

        #expect(descriptor?.module == .musicPractice)
        #expect(descriptor?.isAvailable == true)
        #expect(registry.moduleWidget(for: .musicPractice)?.kind == .musicPracticeModule)
        #expect(registry.canAdd(
            descriptor: descriptor!,
            configuration: .empty,
            to: HomeLayout(widgets: [])
        ))
        #expect(registry.canAdd(
            descriptor: descriptor!,
            configuration: .empty,
            to: HomeLayout(widgets: [
                HomeWidgetInstance(kind: .musicPracticeModule, size: .small, sortOrder: 0),
            ])
        ) == false)
    }

    @Test func fitnessModuleWidgetIsAvailable() {
        let registry = HomeWidgetRegistry.standard
        let descriptor = registry.descriptor(for: .fitnessModule)

        #expect(descriptor?.module == .fitness)
        #expect(descriptor?.isAvailable == true)
        #expect(registry.moduleWidget(for: .fitness)?.kind == .fitnessModule)
    }

    @Test func peopleMemoryModuleWidgetIsAvailable() {
        let registry = HomeWidgetRegistry.standard
        let descriptor = registry.descriptor(for: .peopleMemoryModule)

        #expect(descriptor?.module == .peopleMemory)
        #expect(descriptor?.iconSystemName == "person.2.fill")
        #expect(descriptor?.defaultAction == .openPeopleMemory)
        #expect(descriptor?.isAvailable == true)
        #expect(registry.moduleWidget(for: .peopleMemory)?.kind == .peopleMemoryModule)
    }

    @Test func homeLayoutMigrationInjectsFitnessUnlessExplicitlyRemoved() {
        let legacyLayout = HomeLayout(
            version: 2,
            widgets: [
                HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
            ]
        )
        let removedLegacyLayout = HomeLayout(
            version: 2,
            widgets: [
                HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
            ],
            removedWidgets: [
                HomeWidgetInstance(kind: .fitnessModule, size: .small, sortOrder: 0),
            ]
        )

        #expect(legacyLayout.normalized().widgets.map(\.kind).contains(.fitnessModule))
        #expect(removedLegacyLayout.normalized().widgets.map(\.kind).contains(.fitnessModule) == false)
    }

    @Test func homeLayoutMigrationInjectsPeopleMemoryUnlessExplicitlyRemoved() {
        let legacyLayout = HomeLayout(
            version: 3,
            widgets: [
                HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
            ]
        )
        let removedLegacyLayout = HomeLayout(
            version: 3,
            widgets: [
                HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
            ],
            removedWidgets: [
                HomeWidgetInstance(kind: .peopleMemoryModule, size: .small, sortOrder: 0),
            ]
        )

        #expect(legacyLayout.normalized().widgets.map(\.kind).contains(.peopleMemoryModule))
        #expect(removedLegacyLayout.normalized().widgets.map(\.kind).contains(.peopleMemoryModule) == false)
    }

    @Test func homeLayoutMigrationInjectsDebriefsUnlessExplicitlyRemoved() {
        let legacyLayout = HomeLayout(
            version: 4,
            widgets: [
                HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
            ]
        )
        let removedLegacyLayout = HomeLayout(
            version: 4,
            widgets: [
                HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
            ],
            removedWidgets: [
                HomeWidgetInstance(kind: .debriefsPending, size: .large, sortOrder: 0),
            ]
        )

        #expect(legacyLayout.normalized().widgets.map(\.kind).contains(.debriefsPending))
        #expect(removedLegacyLayout.normalized().widgets.map(\.kind).contains(.debriefsPending) == false)
    }

    @Test func shoppingQuickAddWidgetIsAvailableAndAllowsMultipleInstances() {
        let registry = HomeWidgetRegistry.standard
        let descriptor = registry.descriptor(for: .shoppingQuickAdd)

        #expect(descriptor?.module == .shopping)
        #expect(descriptor?.isAvailable == true)
        #expect(registry.featureWidgets(for: .shopping).contains(where: { $0.kind == .shoppingQuickAdd }))

        let layout = HomeLayout(widgets: [
            HomeWidgetInstance(kind: .shoppingQuickAdd, size: .small, sortOrder: 0),
        ])

        #expect(registry.canAdd(
            descriptor: descriptor!,
            configuration: .empty,
            to: layout
        ))
    }

    @Test func visibilityToggleSupportExcludesConfiguredAndMultipleWidgets() {
        let registry = HomeWidgetRegistry.standard

        #expect(registry.supportsVisibilityToggle(for: registry.descriptor(for: .tasksModule)!) == true)
        #expect(registry.supportsVisibilityToggle(for: registry.descriptor(for: .projectNextTask)!) == false)
        #expect(registry.supportsVisibilityToggle(for: registry.descriptor(for: .shoppingQuickAdd)!) == false)
    }

    @Test func availableRoutineModuleLinkDescriptorsMirrorAvailableModuleWidgets() {
        let registry = HomeWidgetRegistry.standard

        #expect(registry.availableRoutineModuleLinkDescriptors.map(\.kind) == [
            .tasksModule,
            .plannerModule,
            .projectsModule,
            .promisesModule,
            .routinesModule,
            .shoppingModule,
            .healthModule,
            .musicPracticeModule,
            .fitnessModule,
            .peopleMemoryModule,
        ])
    }

    @Test func availableRoutineModuleLinkDescriptorsExcludePlannedAndPreserveOrder() {
        let registry = HomeWidgetRegistry(
            descriptors: [
                HomeWidgetDescriptor(
                    kind: .tasksModule,
                    displayName: "Tasks",
                    iconSystemName: "checklist",
                    module: .tasks,
                    supportedSizes: [.small],
                    defaultSize: .small,
                    isModuleWidget: true
                ),
                HomeWidgetDescriptor(
                    kind: .budgetModule,
                    displayName: "Budget",
                    iconSystemName: "creditcard",
                    module: .future,
                    supportedSizes: [.small],
                    defaultSize: .small,
                    availability: .planned("Planned"),
                    isModuleWidget: true
                ),
                HomeWidgetDescriptor(
                    kind: .healthModule,
                    displayName: "Health",
                    iconSystemName: "heart",
                    module: .health,
                    supportedSizes: [.small],
                    defaultSize: .small,
                    isModuleWidget: true
                ),
                HomeWidgetDescriptor(
                    kind: .inbox,
                    displayName: "Inbox",
                    iconSystemName: "tray",
                    module: .capture,
                    supportedSizes: [.small],
                    defaultSize: .small,
                    isModuleWidget: false
                ),
            ]
        )

        #expect(registry.availableRoutineModuleLinkDescriptors.map(\.kind) == [
            .tasksModule,
            .healthModule,
        ])
    }
}
