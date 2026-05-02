import Foundation
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
    let calendarChangeObserver: any CalendarChangeObserving

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
        let calendarChangeObserver = calendarEventStore

        _ = try settingsRepository.loadSettings()

        #if DEBUG
        try seedDevelopmentTasksIfNeeded(taskRepository: taskRepository)
        #endif

        return AppContainer(
            modelContainer: modelContainer,
            taskRepository: taskRepository,
            scheduledBlockRepository: scheduledBlockRepository,
            settingsRepository: settingsRepository,
            calendarPermissionProvider: calendarPermissionProvider,
            calendarListingService: calendarListingService,
            calendarReader: calendarReader,
            calendarWriter: calendarWriter,
            calendarReconciler: calendarReconciler,
            calendarChangeObserver: calendarChangeObserver
        )
    }

    #if DEBUG
    private static func seedDevelopmentTasksIfNeeded(
        taskRepository: any TaskRepository
    ) throws {
        let seedKey = "com.camp.task-manager.dev.seeded-realistic-test-tasks.v1"
        guard UserDefaults.standard.bool(forKey: seedKey) == false else {
            return
        }

        let existingTasks = try taskRepository.fetchTasks()
        let existingTitles = Set(existingTasks.map { $0.title.lowercased() })

        for task in MyTask.sampleTasks where existingTitles.contains(task.title.lowercased()) == false {
            try taskRepository.saveTask(task, replacingTaskWithID: nil)
        }

        UserDefaults.standard.set(true, forKey: seedKey)
    }
    #endif

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
        let calendarChangeObserver = StubCalendarChangeObserver()

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
            calendarReconciler: calendarReconciler,
            calendarChangeObserver: calendarChangeObserver
        )
    }
}
