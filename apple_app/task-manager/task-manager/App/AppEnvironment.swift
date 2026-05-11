import Foundation

final class AppEnvironment {
    let container: AppContainer

    var taskRepository: any TaskRepository {
        container.taskRepository
    }

    var projectRepository: any ProjectRepository {
        container.projectRepository
    }

    var captureRepository: any CaptureRepository {
        container.captureRepository
    }

    var projectItemRepository: any ProjectItemRepository {
        container.projectItemRepository
    }

    var scheduledBlockRepository: any ScheduledBlockRepository {
        container.scheduledBlockRepository
    }

    var settingsRepository: any SettingsRepository {
        container.settingsRepository
    }

    var homeLayoutRepository: any HomeLayoutRepository {
        container.homeLayoutRepository
    }

    var promiseRepository: any PromiseRepository {
        container.promiseRepository
    }

    var routineRepository: any RoutineRepository {
        container.routineRepository
    }

    var shoppingRepository: any ShoppingRepository {
        container.shoppingRepository
    }

    var healthRepository: any HealthRepository {
        container.healthRepository
    }

    var calendarPermissionProvider: any CalendarPermissionProviding {
        container.calendarPermissionProvider
    }

    var calendarListingService: any CalendarListing {
        container.calendarListingService
    }

    var calendarReader: any CalendarReading {
        container.calendarReader
    }

    var calendarWriter: any CalendarWriting {
        container.calendarWriter
    }

    var calendarReconciler: any CalendarReconciling {
        container.calendarReconciler
    }

    var calendarChangeObserver: any CalendarChangeObserving {
        container.calendarChangeObserver
    }

    init(container: AppContainer) {
        self.container = container
    }
}
