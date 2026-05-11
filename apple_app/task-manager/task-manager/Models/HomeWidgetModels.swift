import Foundation

nonisolated enum HomeWidgetModule: String, Codable, CaseIterable, Sendable {
    case capture
    case tasks
    case planner
    case projects
    case promises
    case routines

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
        }
    }
}

nonisolated enum HomeWidgetKind: String, Codable, CaseIterable, Sendable {
    case inbox
    case calendarOverview
    case pinnedProjects
    case promises
    case routines
    case promiseHistory
    case tasksModule
    case plannerModule
    case projectsModule
    case promisesModule
    case routinesModule
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
    static let currentVersion = 1

    var version: Int
    var widgets: [HomeWidgetInstance]

    init(
        version: Int = Self.currentVersion,
        widgets: [HomeWidgetInstance]
    ) {
        self.version = max(1, version)
        self.widgets = Self.normalizedWidgets(widgets)
    }

    static let defaultLayout = HomeLayout(
        widgets: [
            HomeWidgetInstance(kind: .inbox, size: .large, sortOrder: 0),
            HomeWidgetInstance(kind: .pinnedProjects, size: .large, sortOrder: 1),
            HomeWidgetInstance(kind: .calendarOverview, size: .large, sortOrder: 2),
            HomeWidgetInstance(kind: .promises, size: .large, sortOrder: 3),
            HomeWidgetInstance(kind: .routines, size: .large, sortOrder: 4),
            HomeWidgetInstance(kind: .promiseHistory, size: .large, sortOrder: 5),
        ]
    )

    var orderedWidgets: [HomeWidgetInstance] {
        Self.normalizedWidgets(widgets)
    }

    func normalized(using registry: HomeWidgetRegistry = .standard) -> HomeLayout {
        let normalized = orderedWidgets
            .filter { registry.descriptor(for: $0.kind) != nil }
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

        return HomeLayout(version: version, widgets: normalized)
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

nonisolated struct HomeWidgetDescriptor: Identifiable, Equatable, Sendable {
    var id: HomeWidgetKind { kind }

    let kind: HomeWidgetKind
    let displayName: String
    let module: HomeWidgetModule
    let supportedSizes: [HomeWidgetSize]
    let defaultSize: HomeWidgetSize
    let requiresConfiguration: Bool
    let isModuleWidget: Bool
    let isAvailable: Bool

    init(
        kind: HomeWidgetKind,
        displayName: String,
        module: HomeWidgetModule,
        supportedSizes: [HomeWidgetSize],
        defaultSize: HomeWidgetSize,
        requiresConfiguration: Bool = false,
        isModuleWidget: Bool = false,
        isAvailable: Bool = true
    ) {
        self.kind = kind
        self.displayName = displayName
        self.module = module
        self.supportedSizes = supportedSizes
        self.defaultSize = supportedSizes.contains(defaultSize)
            ? defaultSize
            : supportedSizes.first ?? .large
        self.requiresConfiguration = requiresConfiguration
        self.isModuleWidget = isModuleWidget
        self.isAvailable = isAvailable
    }
}

nonisolated struct HomeWidgetRegistry: Equatable, Sendable {
    let descriptors: [HomeWidgetDescriptor]

    static let standard = HomeWidgetRegistry(
        descriptors: [
            HomeWidgetDescriptor(
                kind: .inbox,
                displayName: "Inbox",
                module: .capture,
                supportedSizes: [.small, .large],
                defaultSize: .large
            ),
            HomeWidgetDescriptor(
                kind: .tasksModule,
                displayName: "Tasks",
                module: .tasks,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .plannerModule,
                displayName: "Planner",
                module: .planner,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .calendarOverview,
                displayName: "Today's Events",
                module: .planner,
                supportedSizes: [.small, .large],
                defaultSize: .large
            ),
            HomeWidgetDescriptor(
                kind: .projectsModule,
                displayName: "Projects",
                module: .projects,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .pinnedProjects,
                displayName: "Pinned Projects",
                module: .projects,
                supportedSizes: [.small, .large],
                defaultSize: .large
            ),
            HomeWidgetDescriptor(
                kind: .promisesModule,
                displayName: "Promises",
                module: .promises,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .promises,
                displayName: "Active Promises",
                module: .promises,
                supportedSizes: [.small, .large],
                defaultSize: .large
            ),
            HomeWidgetDescriptor(
                kind: .promiseHistory,
                displayName: "Promise History",
                module: .promises,
                supportedSizes: [.small, .large],
                defaultSize: .large
            ),
            HomeWidgetDescriptor(
                kind: .routinesModule,
                displayName: "Routines",
                module: .routines,
                supportedSizes: [.small, .large],
                defaultSize: .small,
                isModuleWidget: true
            ),
            HomeWidgetDescriptor(
                kind: .routines,
                displayName: "Today's Routines",
                module: .routines,
                supportedSizes: [.small, .large],
                defaultSize: .large
            ),
        ]
    )

    var modules: [HomeWidgetModule] {
        HomeWidgetModule.allCases.filter { module in
            descriptors.contains { $0.module == module && $0.isAvailable }
        }
    }

    func descriptor(for kind: HomeWidgetKind) -> HomeWidgetDescriptor? {
        descriptors.first { $0.kind == kind && $0.isAvailable }
    }

    func moduleWidget(for module: HomeWidgetModule) -> HomeWidgetDescriptor? {
        descriptors.first {
            $0.module == module && $0.isModuleWidget && $0.isAvailable
        }
    }

    func featureWidgets(for module: HomeWidgetModule) -> [HomeWidgetDescriptor] {
        descriptors.filter {
            $0.module == module && $0.isModuleWidget == false && $0.isAvailable
        }
    }
}
