import SwiftData

struct AppContainer {
    let modelContainer: ModelContainer
    let taskRepository: any TaskRepository
    let scheduledBlockRepository: any ScheduledBlockRepository
    let settingsRepository: any SettingsRepository
    let calendarPermissionProvider: any CalendarPermissionProviding
    let calendarListingService: any CalendarListing
    let calendarReader: any CalendarReading
    let calendarWriter: any CalendarWriting
    let calendarReconciler: any CalendarReconciling

    static func makeLive() throws -> AppContainer {
        let modelContainer = try ModelContainerFactory.makeDefaultContainer()
        let taskRepository = SwiftDataTaskRepository(modelContainer: modelContainer)
        let scheduledBlockRepository = SwiftDataScheduledBlockRepository(
            modelContainer: modelContainer
        )
        let settingsRepository = SwiftDataSettingsRepository(
            modelContainer: modelContainer
        )
        let calendarEventStore = EventKitCalendarEventStore()
        let calendarPermissionProvider = EventKitCalendarPermissionService(
            eventStore: calendarEventStore
        )
        let calendarListingService = EventKitCalendarListingService(
            eventStore: calendarEventStore,
            settingsRepository: settingsRepository
        )
        let calendarReader = EventKitCalendarReader(
            eventStore: calendarEventStore,
            settingsRepository: settingsRepository
        )
        let calendarWriter = EventKitCalendarWriter(
            eventStore: calendarEventStore,
            settingsRepository: settingsRepository
        )
        let calendarReconciler = EventKitCalendarReconciler(
            eventStore: calendarEventStore,
            scheduledBlockRepository: scheduledBlockRepository,
            taskRepository: taskRepository
        )

        _ = try settingsRepository.loadSettings()

        return AppContainer(
            modelContainer: modelContainer,
            taskRepository: taskRepository,
            scheduledBlockRepository: scheduledBlockRepository,
            settingsRepository: settingsRepository,
            calendarPermissionProvider: calendarPermissionProvider,
            calendarListingService: calendarListingService,
            calendarReader: calendarReader,
            calendarWriter: calendarWriter,
            calendarReconciler: calendarReconciler
        )
    }

    static func makePreview(
        seedTasks: [MyTask] = MyTask.sampleTasks
    ) -> AppContainer {
        let modelContainer = try! ModelContainerFactory.makeInMemoryContainer()
        let taskRepository = SwiftDataTaskRepository(modelContainer: modelContainer)
        let scheduledBlockRepository = SwiftDataScheduledBlockRepository(
            modelContainer: modelContainer
        )
        let settingsRepository = SwiftDataSettingsRepository(
            modelContainer: modelContainer
        )
        let calendarPermissionProvider = StubCalendarPermissionService()
        let calendarListingService = StubCalendarListingService()
        let calendarReader = StubCalendarReader()
        let calendarWriter = StubCalendarWriter()
        let calendarReconciler = StubCalendarReconciler()

        _ = try? settingsRepository.loadSettings()

        for task in seedTasks {
            try? taskRepository.saveTask(task, replacingTaskWithID: nil)
        }

        return AppContainer(
            modelContainer: modelContainer,
            taskRepository: taskRepository,
            scheduledBlockRepository: scheduledBlockRepository,
            settingsRepository: settingsRepository,
            calendarPermissionProvider: calendarPermissionProvider,
            calendarListingService: calendarListingService,
            calendarReader: calendarReader,
            calendarWriter: calendarWriter,
            calendarReconciler: calendarReconciler
        )
    }
}
