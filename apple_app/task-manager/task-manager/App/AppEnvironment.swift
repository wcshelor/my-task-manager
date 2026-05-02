import Foundation

final class AppEnvironment {
    let container: AppContainer

    var taskRepository: any TaskRepository {
        container.taskRepository
    }

    var scheduledBlockRepository: any ScheduledBlockRepository {
        container.scheduledBlockRepository
    }

    var settingsRepository: any SettingsRepository {
        container.settingsRepository
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
