import Foundation
import SwiftData

struct AppContainer {
    let modelContainer: ModelContainer
    let taskRepository: any TaskRepository
    let scheduledBlockRepository: any ScheduledBlockRepository
    let settingsRepository: any SettingsRepository
    let promiseRepository: any PromiseRepository
    let routineRepository: any RoutineRepository
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
        let promiseRepository = SwiftDataPromiseRepository(modelContainer: modelContainer)
        let routineRepository = SwiftDataRoutineRepository(modelContainer: modelContainer)
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
            promiseRepository: promiseRepository,
            routineRepository: routineRepository,
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
        let promiseRepository = SwiftDataPromiseRepository(modelContainer: modelContainer)
        let routineRepository = SwiftDataRoutineRepository(modelContainer: modelContainer)
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

        seedPreviewPromisesAndRoutines(
            promiseRepository: promiseRepository,
            routineRepository: routineRepository
        )

        return AppContainer(
            modelContainer: modelContainer,
            taskRepository: taskRepository,
            scheduledBlockRepository: scheduledBlockRepository,
            settingsRepository: settingsRepository,
            promiseRepository: promiseRepository,
            routineRepository: routineRepository,
            calendarPermissionProvider: calendarPermissionProvider,
            calendarListingService: calendarListingService,
            calendarReader: calendarReader,
            calendarWriter: calendarWriter,
            calendarReconciler: calendarReconciler,
            calendarChangeObserver: calendarChangeObserver
        )
    }

    @MainActor
    private static func seedPreviewPromisesAndRoutines(
        promiseRepository: any PromiseRepository,
        routineRepository: any RoutineRepository
    ) {
        let now = Date()
        try? promiseRepository.savePromise(
            Promise(
                title: "No weed until 6 PM",
                notes: "Keep the promise simple and visible.",
                startAt: now.addingTimeInterval(-60 * 30),
                checkInAt: now.addingTimeInterval(60 * 90),
                whyItMatters: "I want proof that I can trust my own word.",
                expectedFriction: "Boredom around late afternoon"
            ),
            replacingPromiseWithID: nil
        )

        try? routineRepository.saveRoutine(
            Routine(
                name: "Evening Reset",
                activeWeekdays: [],
                items: [
                    RoutineItem(title: "Clear kitchen", position: 0),
                    RoutineItem(title: "Set tomorrow's first task", position: 1),
                    RoutineItem(title: "Plug in phone away from bed", position: 2),
                ]
            ),
            replacingRoutineWithID: nil
        )
    }
}
