import Foundation

nonisolated enum HomeWidgetModule: String, Codable, CaseIterable, Sendable {
    case capture
    case tasks
    case planner
    case projects
    case promises
    case routines
    case shopping
    case health
    case musicPractice
    case fitness
    case peopleMemory
    case future

    var displayName: String {
        switch self {
        case .capture:
            return "Capture"
        case .tasks:
            return "Tasks"
        case .planner:
            return "Planner"
        case .projects:
            return "Projects"
        case .promises:
            return "Promises"
        case .routines:
            return "Routines"
        case .shopping:
            return "Shopping"
        case .health:
            return "Health"
        case .musicPractice:
            return "Music Practice"
        case .fitness:
            return "Fitness"
        case .peopleMemory:
            return "People"
        case .future:
            return "Planned"
        }
    }
}

nonisolated struct HomeWidgetKind: RawRepresentable, Codable, Hashable, CaseIterable, Sendable, ExpressibleByStringLiteral {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }

    static let inbox = HomeWidgetKind(rawValue: "inbox")
    static let quickCapture = HomeWidgetKind(rawValue: "quickCapture")
    static let calendarOverview = HomeWidgetKind(rawValue: "calendarOverview")
    static let planTheDay = HomeWidgetKind(rawValue: "planTheDay")
    static let nextEvent = HomeWidgetKind(rawValue: "nextEvent")
    static let pinnedProjects = HomeWidgetKind(rawValue: "pinnedProjects")
    static let projectNextTask = HomeWidgetKind(rawValue: "projectNextTask")
    static let promises = HomeWidgetKind(rawValue: "promises")
    static let duePromiseCheckIn = HomeWidgetKind(rawValue: "duePromiseCheckIn")
    static let routines = HomeWidgetKind(rawValue: "routines")
    static let currentRoutineStep = HomeWidgetKind(rawValue: "currentRoutineStep")
    static let promiseHistory = HomeWidgetKind(rawValue: "promiseHistory")
    static let shoppingQuickAdd = HomeWidgetKind(rawValue: "shoppingQuickAdd")
    static let tasksModule = HomeWidgetKind(rawValue: "tasksModule")
    static let plannerModule = HomeWidgetKind(rawValue: "plannerModule")
    static let projectsModule = HomeWidgetKind(rawValue: "projectsModule")
    static let promisesModule = HomeWidgetKind(rawValue: "promisesModule")
    static let routinesModule = HomeWidgetKind(rawValue: "routinesModule")
    static let shoppingModule = HomeWidgetKind(rawValue: "shoppingModule")
    static let healthModule = HomeWidgetKind(rawValue: "healthModule")
    static let musicPracticeModule = HomeWidgetKind(rawValue: "musicPracticeModule")
    static let fitnessModule = HomeWidgetKind(rawValue: "fitnessModule")
    static let peopleMemoryModule = HomeWidgetKind(rawValue: "peopleMemoryModule")
    static let moduleCarousel = HomeWidgetKind(rawValue: "moduleCarousel")
    static let budgetModule = HomeWidgetKind(rawValue: "budgetModule")

    static let allCases: [HomeWidgetKind] = [
        .inbox,
        .quickCapture,
        .calendarOverview,
        .planTheDay,
        .nextEvent,
        .pinnedProjects,
        .projectNextTask,
        .promises,
        .duePromiseCheckIn,
        .routines,
        .currentRoutineStep,
        .promiseHistory,
        .shoppingQuickAdd,
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
        .moduleCarousel,
        .budgetModule,
    ]
}

nonisolated enum HomeWidgetSize: String, Codable, CaseIterable, Sendable {
    case small
    case large
}

nonisolated struct HomeWidgetConfiguration: Codable, Equatable, Sendable {
    var version: Int
    var values: [String: String]

    init(
        version: Int = 1,
        values: [String: String] = [:]
    ) {
        self.version = max(1, version)
        self.values = values
    }

    static let empty = HomeWidgetConfiguration()

    var isEmpty: Bool {
        values.isEmpty
    }

    var projectID: UUID? {
        get { uuidValue(for: "projectID") }
        set { setUUIDValue(newValue, for: "projectID") }
    }

    var routineID: UUID? {
        get { uuidValue(for: "routineID") }
        set { setUUIDValue(newValue, for: "routineID") }
    }

    var tagID: UUID? {
        get { uuidValue(for: "tagID") }
        set { setUUIDValue(newValue, for: "tagID") }
    }

    private func uuidValue(for key: String) -> UUID? {
        values[key].flatMap(UUID.init(uuidString:))
    }

    private mutating func setUUIDValue(_ uuid: UUID?, for key: String) {
        values[key] = uuid?.uuidString
    }
}

nonisolated struct HomeWidgetInstance: Identifiable, Equatable, Sendable {
    let id: UUID
    var kind: HomeWidgetKind
    var size: HomeWidgetSize
    var sortOrder: Int
    var configuration: HomeWidgetConfiguration

    init(
        id: UUID = UUID(),
        kind: HomeWidgetKind,
        size: HomeWidgetSize,
        sortOrder: Int,
        configuration: HomeWidgetConfiguration = .empty
    ) {
        self.id = id
        self.kind = kind
        self.size = size
        self.sortOrder = sortOrder
        self.configuration = configuration
    }
}

nonisolated struct HomeLayout: Equatable, Sendable {
    static let currentVersion = 4

    var version: Int
    var widgets: [HomeWidgetInstance]
    var removedWidgets: [HomeWidgetInstance]

    init(
        version: Int = Self.currentVersion,
        widgets: [HomeWidgetInstance],
        removedWidgets: [HomeWidgetInstance] = []
    ) {
        self.version = max(1, version)
        self.widgets = Self.normalizedWidgets(widgets)
        self.removedWidgets = Self.normalizedWidgets(removedWidgets)
    }

    static let defaultLayout = HomeLayout(
        widgets: [
            HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
            HomeWidgetInstance(kind: .pinnedProjects, size: .large, sortOrder: 1),
            HomeWidgetInstance(kind: .calendarOverview, size: .large, sortOrder: 2),
            HomeWidgetInstance(kind: .promises, size: .large, sortOrder: 3),
            HomeWidgetInstance(kind: .routines, size: .large, sortOrder: 4),
            HomeWidgetInstance(kind: .promiseHistory, size: .large, sortOrder: 5),
            HomeWidgetInstance(kind: .shoppingModule, size: .small, sortOrder: 6),
            HomeWidgetInstance(kind: .healthModule, size: .small, sortOrder: 7),
            HomeWidgetInstance(kind: .musicPracticeModule, size: .small, sortOrder: 8),
            HomeWidgetInstance(kind: .fitnessModule, size: .small, sortOrder: 9),
            HomeWidgetInstance(kind: .peopleMemoryModule, size: .small, sortOrder: 10),
        ]
    )

    var orderedWidgets: [HomeWidgetInstance] {
        Self.normalizedWidgets(widgets)
    }

    func normalized(using registry: HomeWidgetRegistry = .standard) -> HomeLayout {
        var normalized = orderedWidgets
            .enumerated()
            .map { index, widget in
                var normalizedWidget = widget
                if let descriptor = registry.descriptor(for: widget.kind),
                   descriptor.supportedSizes.contains(widget.size) == false {
                    normalizedWidget.size = descriptor.defaultSize
                }
                normalizedWidget.sortOrder = index
                return normalizedWidget
            }

        let normalizedRemoved = removedWidgets
            .enumerated()
            .map { index, widget in
                var normalizedWidget = widget
                if let descriptor = registry.descriptor(for: widget.kind),
                   descriptor.supportedSizes.contains(widget.size) == false {
                    normalizedWidget.size = descriptor.defaultSize
                }
                normalizedWidget.sortOrder = index
                return normalizedWidget
            }

        normalized = HomeLayoutMigrator.migrateWidgets(
            normalized,
            removedWidgets: normalizedRemoved,
            fromVersion: version
        )

        return HomeLayout(
            version: HomeLayoutMigrator.currentVersion(for: version),
            widgets: normalized,
            removedWidgets: normalizedRemoved
        )
    }

    private static func normalizedWidgets(
        _ widgets: [HomeWidgetInstance]
    ) -> [HomeWidgetInstance] {
        widgets
            .sorted { leftWidget, rightWidget in
                if leftWidget.sortOrder != rightWidget.sortOrder {
                    return leftWidget.sortOrder < rightWidget.sortOrder
                }

                return leftWidget.id.uuidString < rightWidget.id.uuidString
            }
            .enumerated()
            .map { index, widget in
                var normalizedWidget = widget
                normalizedWidget.sortOrder = index
                return normalizedWidget
            }
    }
}

nonisolated enum HomeWidgetAvailability: Equatable, Sendable {
    case available
    case planned(String)
    case unavailable(String)

    var isAvailable: Bool {
        if case .available = self {
            return true
        }

        return false
    }

    var message: String? {
        switch self {
        case .available:
            return nil
        case .planned(let message), .unavailable(let message):
            return message
        }
    }
}

nonisolated enum HomeWidgetDuplicatePolicy: Equatable, Sendable {
    case singleUnconfigured
    case uniqueConfiguration
    case multiple
}

nonisolated enum HomeWidgetConfigurationFieldKind: String, Codable, Equatable, Sendable {
    case project
    case routine
    case tag
}

nonisolated struct HomeWidgetConfigurationField: Equatable, Sendable {
    let key: String
    let displayName: String
    let kind: HomeWidgetConfigurationFieldKind
}

nonisolated enum HomeWidgetDefaultAction: Equatable, Sendable {
    case openCapture
    case reviewInbox
    case openTasks
    case openPlanner
    case openProjects
    case openConfiguredProject
    case newPromise
    case checkInDuePromise
    case newRoutine
    case openConfiguredRoutine
    case openShopping
    case quickAddShopping
    case openHealth
    case openMusicPractice
    case openFitness
    case openPeopleMemory
}

nonisolated enum HomeLayoutMigrator {
    static func currentVersion(for version: Int) -> Int {
        max(version, HomeLayout.currentVersion)
    }

    static func migrateWidgets(
        _ widgets: [HomeWidgetInstance],
        removedWidgets: [HomeWidgetInstance],
        fromVersion version: Int
    ) -> [HomeWidgetInstance] {
        var migratedWidgets = widgets

        if version < 3 {
            let hasFitness = migratedWidgets.contains { $0.kind == .fitnessModule }
            let removedFitness = removedWidgets.contains { $0.kind == .fitnessModule }

            if hasFitness == false, removedFitness == false {
                migratedWidgets.append(
                    HomeWidgetInstance(
                        kind: .fitnessModule,
                        size: .small,
                        sortOrder: migratedWidgets.count
                    )
                )
            }
        }

        if version < 4 {
            let hasPeopleMemory = migratedWidgets.contains { $0.kind == .peopleMemoryModule }
            let removedPeopleMemory = removedWidgets.contains { $0.kind == .peopleMemoryModule }

            if hasPeopleMemory == false, removedPeopleMemory == false {
                migratedWidgets.append(
                    HomeWidgetInstance(
                        kind: .peopleMemoryModule,
                        size: .small,
                        sortOrder: migratedWidgets.count
                    )
                )
            }
        }

        return migratedWidgets.enumerated().map { index, widget in
            var updatedWidget = widget
            updatedWidget.sortOrder = index
            return updatedWidget
        }
    }
}

nonisolated struct HomeWidgetDescriptor: Identifiable, Equatable, Sendable {
    var id: HomeWidgetKind { kind }

    let kind: HomeWidgetKind
    let displayName: String
    let iconSystemName: String
    let module: HomeWidgetModule
    let supportedSizes: [HomeWidgetSize]
    let defaultSize: HomeWidgetSize
    let availability: HomeWidgetAvailability
    let duplicatePolicy: HomeWidgetDuplicatePolicy
    let configurationFields: [HomeWidgetConfigurationField]
    let defaultAction: HomeWidgetDefaultAction?
    let isModuleWidget: Bool

    var requiresConfiguration: Bool {
        configurationFields.isEmpty == false
    }

    var isAvailable: Bool {
        availability.isAvailable
    }

    init(
        kind: HomeWidgetKind,
        displayName: String,
        iconSystemName: String,
        module: HomeWidgetModule,
        supportedSizes: [HomeWidgetSize],
        defaultSize: HomeWidgetSize,
        availability: HomeWidgetAvailability = .available,
        duplicatePolicy: HomeWidgetDuplicatePolicy = .singleUnconfigured,
        configurationFields: [HomeWidgetConfigurationField] = [],
        defaultAction: HomeWidgetDefaultAction? = nil,
        isModuleWidget: Bool = false,
    ) {
        self.kind = kind
        self.displayName = displayName
        self.iconSystemName = iconSystemName
        self.module = module
        self.supportedSizes = supportedSizes
        self.defaultSize = supportedSizes.contains(defaultSize)
            ? defaultSize
            : supportedSizes.first ?? .large
        self.availability = availability
        self.duplicatePolicy = duplicatePolicy
        self.configurationFields = configurationFields
        self.defaultAction = defaultAction
        self.isModuleWidget = isModuleWidget
    }
}

nonisolated struct HomeWidgetRegistry: Equatable, Sendable {
    let descriptors: [HomeWidgetDescriptor]

    static let standard = HomeWidgetRegistry(
        descriptors: [
            HomeWidgetDescriptor(
                kind: .inbox,
                displayName: "Inbox",
                iconSystemName: "tray.full.fill",
                module: .capture,
                supportedSizes: [.small, .large],
                defaultSize: .large,
                defaultAction: .reviewInbox
            ),
            HomeWidgetDescriptor(
                kind: .quickCapture,
                displayName: "Quick Capture",
                iconSystemName: "tray.and.arrow.down",
                module: .capture,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openCapture
            ),
            HomeWidgetDescriptor(
                kind: .moduleCarousel,
                displayName: "Module Carousel",
                iconSystemName: "square.grid.3x1.below.line.grid.1x2",
                module: .capture,
                supportedSizes: [.large],
                defaultSize: .large
            ),
            HomeWidgetDescriptor(
                kind: .tasksModule,
                displayName: "Tasks",
                iconSystemName: "checklist",
                module: .tasks,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openTasks,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .plannerModule,
                displayName: "Planner",
                iconSystemName: "calendar",
                module: .planner,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openPlanner,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .calendarOverview,
                displayName: "Today's Events",
                iconSystemName: "calendar.badge.clock",
                module: .planner,
                supportedSizes: [.small, .large],
                defaultSize: .large,
                defaultAction: .openPlanner
            ),
            HomeWidgetDescriptor(
                kind: .planTheDay,
                displayName: "Plan the Day",
                iconSystemName: "calendar.badge.plus",
                module: .planner,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openPlanner
            ),
            HomeWidgetDescriptor(
                kind: .nextEvent,
                displayName: "Next Event",
                iconSystemName: "calendar.badge.clock",
                module: .planner,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openPlanner
            ),
            HomeWidgetDescriptor(
                kind: .projectsModule,
                displayName: "Projects",
                iconSystemName: "folder.fill",
                module: .projects,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openProjects,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .pinnedProjects,
                displayName: "Pinned Projects",
                iconSystemName: "pin.fill",
                module: .projects,
                supportedSizes: [.small, .large],
                defaultSize: .large,
                defaultAction: .openProjects
            ),
            HomeWidgetDescriptor(
                kind: .projectNextTask,
                displayName: "Project Next Task",
                iconSystemName: "folder.badge.gearshape",
                module: .projects,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                duplicatePolicy: .uniqueConfiguration,
                configurationFields: [
                    HomeWidgetConfigurationField(
                        key: "projectID",
                        displayName: "Project",
                        kind: .project
                    ),
                ],
                defaultAction: .openConfiguredProject
            ),
            HomeWidgetDescriptor(
                kind: .promisesModule,
                displayName: "Promises",
                iconSystemName: "hand.raised.fill",
                module: .promises,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .newPromise,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .promises,
                displayName: "Active Promises",
                iconSystemName: "hand.raised.fill",
                module: .promises,
                supportedSizes: [.small, .large],
                defaultSize: .large,
                defaultAction: .newPromise
            ),
            HomeWidgetDescriptor(
                kind: .duePromiseCheckIn,
                displayName: "Due Promise Check-in",
                iconSystemName: "hand.raised.square",
                module: .promises,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .checkInDuePromise
            ),
            HomeWidgetDescriptor(
                kind: .promiseHistory,
                displayName: "Promise History",
                iconSystemName: "clock.arrow.circlepath",
                module: .promises,
                supportedSizes: [.small, .large],
                defaultSize: .large
            ),
            HomeWidgetDescriptor(
                kind: .routinesModule,
                displayName: "Routines",
                iconSystemName: "checklist.checked",
                module: .routines,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .newRoutine,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .routines,
                displayName: "Today's Routines",
                iconSystemName: "checklist.checked",
                module: .routines,
                supportedSizes: [.small, .large],
                defaultSize: .large,
                defaultAction: .newRoutine
            ),
            HomeWidgetDescriptor(
                kind: .currentRoutineStep,
                displayName: "Current Routine Step",
                iconSystemName: "figure.walk.motion",
                module: .routines,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                duplicatePolicy: .uniqueConfiguration,
                configurationFields: [
                    HomeWidgetConfigurationField(
                        key: "routineID",
                        displayName: "Routine",
                        kind: .routine
                    ),
                ],
                defaultAction: .openConfiguredRoutine
            ),
            HomeWidgetDescriptor(
                kind: .shoppingModule,
                displayName: "Shopping",
                iconSystemName: "cart.fill",
                module: .shopping,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openShopping,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .shoppingQuickAdd,
                displayName: "Shopping Quick Add",
                iconSystemName: "cart.badge.plus",
                module: .shopping,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                duplicatePolicy: .multiple,
                defaultAction: .quickAddShopping
            ),
            HomeWidgetDescriptor(
                kind: .healthModule,
                displayName: "Health",
                iconSystemName: "heart.text.square",
                module: .health,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openHealth,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .musicPracticeModule,
                displayName: "Music Practice",
                iconSystemName: "music.note.list",
                module: .musicPractice,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openMusicPractice,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .fitnessModule,
                displayName: "Fitness",
                iconSystemName: "dumbbell.fill",
                module: .fitness,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openFitness,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .peopleMemoryModule,
                displayName: "People",
                iconSystemName: "person.2.fill",
                module: .peopleMemory,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                defaultAction: .openPeopleMemory,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .budgetModule,
                displayName: "Budget",
                iconSystemName: "creditcard.fill",
                module: .future,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                availability: .planned("Budget widgets will become available when the Budget module ships."),
                isModuleWidget: true
            ),
        ]
    )

    var modules: [HomeWidgetModule] {
        HomeWidgetModule.allCases.filter { module in
            descriptors.contains { $0.module == module }
        }
    }

    func descriptor(for kind: HomeWidgetKind) -> HomeWidgetDescriptor? {
        descriptors.first { $0.kind == kind }
            ?? unavailableDescriptor(for: kind)
    }

    func moduleWidget(for module: HomeWidgetModule) -> HomeWidgetDescriptor? {
        descriptors.first {
            $0.module == module && $0.isModuleWidget
        }
    }

    func featureWidgets(for module: HomeWidgetModule) -> [HomeWidgetDescriptor] {
        descriptors.filter {
            $0.module == module && $0.isModuleWidget == false
        }
    }

    func supportsVisibilityToggle(for descriptor: HomeWidgetDescriptor) -> Bool {
        guard descriptor.isAvailable else {
            return false
        }

        switch descriptor.duplicatePolicy {
        case .multiple:
            return false
        case .singleUnconfigured:
            return true
        case .uniqueConfiguration:
            return false
        }
    }

    func canAdd(
        descriptor: HomeWidgetDescriptor,
        configuration: HomeWidgetConfiguration,
        to layout: HomeLayout
    ) -> Bool {
        guard descriptor.isAvailable else {
            return false
        }

        let widgets = layout.orderedWidgets
        switch descriptor.duplicatePolicy {
        case .multiple:
            return true
        case .singleUnconfigured:
            if configuration.isEmpty {
                return widgets.contains { $0.kind == descriptor.kind && $0.configuration.isEmpty } == false
            }

            return widgets.contains { $0.kind == descriptor.kind && $0.configuration == configuration } == false
        case .uniqueConfiguration:
            guard configuration.isEmpty == false else {
                return false
            }

            return widgets.contains { $0.kind == descriptor.kind && $0.configuration == configuration } == false
        }
    }

    private func unavailableDescriptor(for kind: HomeWidgetKind) -> HomeWidgetDescriptor {
        HomeWidgetDescriptor(
            kind: kind,
            displayName: kind.rawValue,
            iconSystemName: "questionmark.square.dashed",
            module: .future,
            supportedSizes: [.large],
            defaultSize: .large,
            availability: .unavailable("This widget is not available in this version of the app.")
        )
    }
}
