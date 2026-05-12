import Foundation
import SwiftData

struct AppContainer {
    let modelContainer: ModelContainer
    let taskRepository: any TaskRepository
    let projectRepository: any ProjectRepository
    let captureRepository: any CaptureRepository
    let projectItemRepository: any ProjectItemRepository
    let scheduledBlockRepository: any ScheduledBlockRepository
    let settingsRepository: any SettingsRepository
    let homeLayoutRepository: any HomeLayoutRepository
    let promiseRepository: any PromiseRepository
    let routineRepository: any RoutineRepository
    let shoppingRepository: any ShoppingRepository
    let healthRepository: any HealthRepository
    let musicPracticeRepository: any MusicPracticeRepository
    let calendarPermissionProvider: any CalendarPermissionProviding
    let calendarListingService: any CalendarListing
    let calendarReader: any CalendarReading
    let calendarWriter: any CalendarWriting
    let calendarReconciler: any CalendarReconciling
    let calendarChangeObserver: any CalendarChangeObserving

    static func makeLive() throws -> AppContainer {
        let modelContainer = try ModelContainerFactory.makeDefaultContainer()
        let taskRepository = SwiftDataTaskRepository(modelContainer: modelContainer)
        let projectRepository = SwiftDataProjectRepository(modelContainer: modelContainer)
        let captureRepository = SwiftDataCaptureRepository(modelContainer: modelContainer)
        let projectItemRepository = SwiftDataProjectItemRepository(modelContainer: modelContainer)
        let scheduledBlockRepository = SwiftDataScheduledBlockRepository(
            modelContainer: modelContainer
        )
        let settingsRepository = SwiftDataSettingsRepository(
            modelContainer: modelContainer
        )
        let homeLayoutRepository = SwiftDataHomeLayoutRepository(
            modelContainer: modelContainer
        )
        let promiseRepository = SwiftDataPromiseRepository(modelContainer: modelContainer)
        let routineRepository = SwiftDataRoutineRepository(modelContainer: modelContainer)
        let shoppingRepository = SwiftDataShoppingRepository(modelContainer: modelContainer)
        let healthRepository = SwiftDataHealthRepository(modelContainer: modelContainer)
        let musicPracticeRepository = SwiftDataMusicPracticeRepository(modelContainer: modelContainer)
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
        _ = try homeLayoutRepository.loadLayout()

        #if DEBUG
        try seedDevelopmentTasksIfNeeded(taskRepository: taskRepository)
        #endif

        return AppContainer(
            modelContainer: modelContainer,
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            captureRepository: captureRepository,
            projectItemRepository: projectItemRepository,
            scheduledBlockRepository: scheduledBlockRepository,
            settingsRepository: settingsRepository,
            homeLayoutRepository: homeLayoutRepository,
            promiseRepository: promiseRepository,
            routineRepository: routineRepository,
            shoppingRepository: shoppingRepository,
            healthRepository: healthRepository,
            musicPracticeRepository: musicPracticeRepository,
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
        let projectRepository = SwiftDataProjectRepository(modelContainer: modelContainer)
        let captureRepository = SwiftDataCaptureRepository(modelContainer: modelContainer)
        let projectItemRepository = SwiftDataProjectItemRepository(modelContainer: modelContainer)
        let scheduledBlockRepository = SwiftDataScheduledBlockRepository(
            modelContainer: modelContainer
        )
        let settingsRepository = SwiftDataSettingsRepository(
            modelContainer: modelContainer
        )
        let homeLayoutRepository = SwiftDataHomeLayoutRepository(
            modelContainer: modelContainer
        )
        let promiseRepository = SwiftDataPromiseRepository(modelContainer: modelContainer)
        let routineRepository = SwiftDataRoutineRepository(modelContainer: modelContainer)
        let shoppingRepository = SwiftDataShoppingRepository(modelContainer: modelContainer)
        let healthRepository = SwiftDataHealthRepository(modelContainer: modelContainer)
        let musicPracticeRepository = SwiftDataMusicPracticeRepository(modelContainer: modelContainer)
        let calendarPermissionProvider = StubCalendarPermissionService()
        let calendarListingService = StubCalendarListingService()
        let calendarReader = StubCalendarReader()
        let calendarWriter = StubCalendarWriter()
        let calendarReconciler = StubCalendarReconciler()
        let calendarChangeObserver = StubCalendarChangeObserver()

        _ = try? settingsRepository.loadSettings()
        _ = try? homeLayoutRepository.loadLayout()

        for task in seedTasks {
            try? taskRepository.saveTask(task, replacingTaskWithID: nil)
        }

        seedPreviewProjectsAndCaptures(
            projectRepository: projectRepository,
            captureRepository: captureRepository,
            projectItemRepository: projectItemRepository,
            taskRepository: taskRepository
        )
        seedPreviewPromisesAndRoutines(
            promiseRepository: promiseRepository,
            routineRepository: routineRepository
        )

        return AppContainer(
            modelContainer: modelContainer,
            taskRepository: taskRepository,
            projectRepository: projectRepository,
            captureRepository: captureRepository,
            projectItemRepository: projectItemRepository,
            scheduledBlockRepository: scheduledBlockRepository,
            settingsRepository: settingsRepository,
            homeLayoutRepository: homeLayoutRepository,
            promiseRepository: promiseRepository,
            routineRepository: routineRepository,
            shoppingRepository: shoppingRepository,
            healthRepository: healthRepository,
            musicPracticeRepository: musicPracticeRepository,
            calendarPermissionProvider: calendarPermissionProvider,
            calendarListingService: calendarListingService,
            calendarReader: calendarReader,
            calendarWriter: calendarWriter,
            calendarReconciler: calendarReconciler,
            calendarChangeObserver: calendarChangeObserver
        )
    }

    @MainActor
    private static func seedPreviewProjectsAndCaptures(
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        taskRepository: any TaskRepository
    ) {
        let now = Date()
        let thesis = Project(
            name: "Master's Thesis",
            summary: "Research, writing, advisor follow-up, and paper leads.",
            isPinned: true,
            createdAt: now.addingTimeInterval(-86_400 * 5)
        )
        try? projectRepository.saveProject(thesis, replacingProjectWithID: nil)
        try? captureRepository.saveCapture(
            CaptureItem(
                title: "Ask advisor about methods framing",
                projectID: thesis.id,
                source: "Quick capture",
                createdAt: now.addingTimeInterval(-3_600)
            ),
            replacingCaptureWithID: nil
        )
        try? captureRepository.saveCapture(
            CaptureItem(
                title: "Look up the paper Jamie mentioned",
                source: "Conversation",
                createdAt: now.addingTimeInterval(-7_200)
            ),
            replacingCaptureWithID: nil
        )
        try? projectItemRepository.saveProjectItem(
            ProjectItem(
                projectID: thesis.id,
                kind: .maybe,
                title: "Explore discourse analysis angle",
                pressure: .useful,
                createdAt: now.addingTimeInterval(-86_400)
            ),
            replacingProjectItemWithID: nil
        )
        try? projectItemRepository.saveProjectItem(
            ProjectItem(
                projectID: thesis.id,
                kind: .note,
                title: "Advisor prefers tighter research questions",
                createdAt: now.addingTimeInterval(-86_400 * 2)
            ),
            replacingProjectItemWithID: nil
        )

        if var task = try? taskRepository.fetchTasks().first {
            task.projectID = thesis.id
            try? taskRepository.saveTask(task, replacingTaskWithID: task.id)
        }
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
