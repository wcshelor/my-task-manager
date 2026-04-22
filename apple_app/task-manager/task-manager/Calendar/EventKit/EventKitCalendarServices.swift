import Foundation

enum CalendarReadError: LocalizedError, Equatable {
    case fullAccessRequired(CalendarPermissionStatus)
    case invalidWindow

    var errorDescription: String? {
        switch self {
        case .fullAccessRequired(let status):
            return "Full Calendar access is required to read events. Current status: \(status)."
        case .invalidWindow:
            return "Calendar read windows must have a positive duration."
        }
    }
}

enum CalendarWriteError: LocalizedError, Equatable {
    case fullAccessRequired(CalendarPermissionStatus)
    case missingWriteCalendar(String)
    case ambiguousWriteCalendar(String)
    case writeCalendarNotWritable(String)
    case missingLinkedEventIdentifier
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .fullAccessRequired(let status):
            return "Full Calendar access is required before accepted suggestions can be written. Current status: \(status)."
        case .missingWriteCalendar(let calendarTitle):
            return "The configured write calendar \"\(calendarTitle)\" could not be found."
        case .ambiguousWriteCalendar(let calendarTitle):
            return "Multiple calendars are named \"\(calendarTitle)\". Rename the write calendar so the app can target one calendar safely."
        case .writeCalendarNotWritable(let calendarTitle):
            return "The configured write calendar \"\(calendarTitle)\" does not allow event changes."
        case .missingLinkedEventIdentifier:
            return "The scheduled block is missing its linked calendar event identifier."
        case .saveFailed(let message):
            return message
        }
    }
}

@MainActor
final class EventKitCalendarPermissionService: CalendarPermissionProviding {
    private let eventStore: any CalendarEventStore

    init(eventStore: any CalendarEventStore) {
        self.eventStore = eventStore
    }

    func currentStatus() -> CalendarPermissionStatus {
        mapPermissionStatus(eventStore.authorizationStatus())
    }

    func requestFullAccess() async -> CalendarPermissionStatus {
        do {
            let granted = try await eventStore.requestFullAccess()
            if granted {
                return .fullAccessGranted
            }

            return currentStatus()
        } catch {
            return .error(error.localizedDescription)
        }
    }
}

@MainActor
final class EventKitCalendarListingService: CalendarListing {
    private let eventStore: any CalendarEventStore
    private let settingsRepository: any SettingsRepository

    init(
        eventStore: any CalendarEventStore,
        settingsRepository: any SettingsRepository
    ) {
        self.eventStore = eventStore
        self.settingsRepository = settingsRepository
    }

    func fetchReadableCalendars() async throws -> [ReadableCalendar] {
        try requireFullAccess(from: eventStore)

        let excludedTitles = Set(try settingsRepository.loadSettings().excludedReadCalendarTitles)

        return eventStore.fetchEventCalendars().map { calendar in
            ReadableCalendar(
                id: calendar.id,
                title: calendar.title,
                allowsContentModifications: calendar.allowsContentModifications,
                isExcludedBySettings: excludedTitles.contains(calendar.title)
            )
        }
    }
}

@MainActor
final class EventKitCalendarReader: CalendarReading {
    private let eventStore: any CalendarEventStore
    private let settingsRepository: any SettingsRepository

    init(
        eventStore: any CalendarEventStore,
        settingsRepository: any SettingsRepository
    ) {
        self.eventStore = eventStore
        self.settingsRepository = settingsRepository
    }

    func fetchEvents(in window: DateInterval) async throws -> [CalendarEventSnapshot] {
        guard window.duration > 0 else {
            throw CalendarReadError.invalidWindow
        }

        try requireFullAccess(from: eventStore)

        let excludedTitles = Set(try settingsRepository.loadSettings().excludedReadCalendarTitles)
        let includedCalendarIdentifiers = Set(
            eventStore.fetchEventCalendars()
                .filter { excludedTitles.contains($0.title) == false }
                .map(\.id)
        )

        return eventStore.fetchEvents(
            in: window,
            calendarIdentifiers: includedCalendarIdentifiers
        )
        .compactMap { event in
            guard event.end > event.start else {
                return nil
            }

            return CalendarEventSnapshot(
                identifier: event.identifier,
                title: normalizedEventTitle(event.title),
                start: event.start,
                end: event.end,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendarTitle
            )
        }
        .sorted { lhs, rhs in
            if lhs.start != rhs.start {
                return lhs.start < rhs.start
            }

            if lhs.end != rhs.end {
                return lhs.end < rhs.end
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

@MainActor
final class EventKitCalendarWriter: CalendarWriting {
    private let eventStore: any CalendarEventStore
    private let settingsRepository: any SettingsRepository

    init(
        eventStore: any CalendarEventStore,
        settingsRepository: any SettingsRepository
    ) {
        self.eventStore = eventStore
        self.settingsRepository = settingsRepository
    }

    func validateWriteCalendar() async throws -> String {
        try resolvedWriteCalendar().title
    }

    func createEvent(for block: ScheduledBlock, task: MyTask) async throws -> CalendarWriteResult {
        let writeCalendar = try resolvedWriteCalendar()
        let eventTitle = plannerEventTitle(for: task)
        let savedEvent = try saveEvent(
            EventStoreEventMutationRequest(
                identifier: nil,
                title: eventTitle,
                start: block.start,
                end: block.end,
                isAllDay: block.isAllDay,
                calendarIdentifier: writeCalendar.id
            ),
            writeCalendarTitle: writeCalendar.title
        )

        return CalendarWriteResult(
            eventIdentifier: savedEvent.identifier,
            calendarTitle: savedEvent.calendarTitle,
            eventTitle: eventTitle
        )
    }

    func updateEvent(for block: ScheduledBlock, task: MyTask) async throws -> CalendarWriteResult {
        let writeCalendar = try resolvedWriteCalendar()
        let eventTitle = plannerEventTitle(for: task)
        let savedEvent = try saveEvent(
            EventStoreEventMutationRequest(
                identifier: try requireEventIdentifier(from: block),
                title: eventTitle,
                start: block.start,
                end: block.end,
                isAllDay: block.isAllDay,
                calendarIdentifier: writeCalendar.id
            ),
            writeCalendarTitle: writeCalendar.title
        )

        return CalendarWriteResult(
            eventIdentifier: savedEvent.identifier,
            calendarTitle: savedEvent.calendarTitle,
            eventTitle: eventTitle
        )
    }

    func deleteEvent(for block: ScheduledBlock) async throws {
        try requireFullAccessForWriting(from: eventStore)

        do {
            try eventStore.deleteEvent(withIdentifier: requireEventIdentifier(from: block))
        } catch let error as EventStoreMutationError {
            throw mapWriteError(error, writeCalendarTitle: block.calendarTitle)
        } catch {
            throw CalendarWriteError.saveFailed(error.localizedDescription)
        }
    }

    private func resolvedWriteCalendar() throws -> EventStoreCalendarDescriptor {
        try requireFullAccessForWriting(from: eventStore)

        let settings = try settingsRepository.loadSettings()
        let calendars = eventStore.fetchEventCalendars()
        guard let writeCalendar = try resolveConfiguredWriteCalendar(
            from: settings,
            calendars: calendars
        ) else {
            throw CalendarWriteError.saveFailed(
                "Choose a write calendar in Planner before writing calendar events."
            )
        }

        if settings.writeCalendarIdentifier != writeCalendar.id
            || settings.writeCalendarTitle != writeCalendar.title {
            var updatedSettings = settings
            updatedSettings.writeCalendarIdentifier = writeCalendar.id
            updatedSettings.writeCalendarTitle = writeCalendar.title
            try settingsRepository.saveSettings(updatedSettings)
        }

        return writeCalendar
    }

    private func resolveConfiguredWriteCalendar(
        from settings: AppSettings,
        calendars: [EventStoreCalendarDescriptor]
    ) throws -> EventStoreCalendarDescriptor? {
        let configuredIdentifier = settings.writeCalendarIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if configuredIdentifier.isEmpty == false {
            guard let writeCalendar = calendars.first(where: { $0.id == configuredIdentifier }) else {
                throw CalendarWriteError.missingWriteCalendar(
                    configuredWriteCalendarLabel(from: settings)
                )
            }

            guard writeCalendar.allowsContentModifications else {
                throw CalendarWriteError.writeCalendarNotWritable(
                    configuredWriteCalendarLabel(from: settings)
                )
            }

            return writeCalendar
        }

        let configuredTitle = settings.writeCalendarTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard configuredTitle.isEmpty == false else {
            return nil
        }

        let matchingCalendars = calendars.filter { descriptor in
            descriptor.title == configuredTitle
        }

        guard matchingCalendars.isEmpty == false else {
            throw CalendarWriteError.missingWriteCalendar(configuredTitle)
        }

        guard matchingCalendars.count == 1 else {
            throw CalendarWriteError.ambiguousWriteCalendar(configuredTitle)
        }

        let writeCalendar = matchingCalendars[0]
        guard writeCalendar.allowsContentModifications else {
            throw CalendarWriteError.writeCalendarNotWritable(configuredTitle)
        }

        return writeCalendar
    }

    private func configuredWriteCalendarLabel(from settings: AppSettings) -> String {
        let configuredTitle = settings.writeCalendarTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if configuredTitle.isEmpty == false {
            return configuredTitle
        }

        let configuredIdentifier = settings.writeCalendarIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if configuredIdentifier.isEmpty == false {
            return configuredIdentifier
        }

        return "selected calendar"
    }

    private func requireEventIdentifier(from block: ScheduledBlock) throws -> String {
        guard
            let eventIdentifier = block.calendarEventIdentifier?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            eventIdentifier.isEmpty == false
        else {
            throw CalendarWriteError.missingLinkedEventIdentifier
        }

        return eventIdentifier
    }

    private func saveEvent(
        _ request: EventStoreEventMutationRequest,
        writeCalendarTitle: String
    ) throws -> (identifier: String, calendarTitle: String) {
        do {
            let savedEvent = try eventStore.saveEvent(request)
            guard
                let identifier = savedEvent.identifier?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                identifier.isEmpty == false
            else {
                throw CalendarWriteError.saveFailed(
                    "Calendar event was created without a stable identifier."
                )
            }

            return (identifier: identifier, calendarTitle: savedEvent.calendarTitle)
        } catch let error as EventStoreMutationError {
            throw mapWriteError(error, writeCalendarTitle: writeCalendarTitle)
        } catch let error as CalendarWriteError {
            throw error
        } catch {
            throw CalendarWriteError.saveFailed(error.localizedDescription)
        }
    }

    private func mapWriteError(
        _ error: EventStoreMutationError,
        writeCalendarTitle: String?
    ) -> CalendarWriteError {
        switch error {
        case .calendarNotFound:
            return .missingWriteCalendar(writeCalendarTitle ?? "Unknown")
        case .eventNotFound:
            return .missingLinkedEventIdentifier
        case .invalidDateRange:
            return .saveFailed(error.localizedDescription)
        case .saveFailed(let message):
            return .saveFailed("Unable to save the calendar event: \(message)")
        }
    }
}

@MainActor
final class EventKitCalendarReconciler: CalendarReconciling {
    private let eventStore: any CalendarEventStore
    private let scheduledBlockRepository: any ScheduledBlockRepository
    private let taskRepository: any TaskRepository
    private let nowProvider: @Sendable () -> Date

    init(
        eventStore: any CalendarEventStore,
        scheduledBlockRepository: any ScheduledBlockRepository,
        taskRepository: any TaskRepository,
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.eventStore = eventStore
        self.scheduledBlockRepository = scheduledBlockRepository
        self.taskRepository = taskRepository
        self.nowProvider = nowProvider
    }

    func reconcileScheduledBlocks() async throws -> ReconciliationReport {
        try requireFullAccess(from: eventStore)

        var report = ReconciliationReport.empty
        var touchedTaskIDs: Set<UUID> = []
        let scheduledBlocks = try scheduledBlockRepository.fetchScheduledBlocks()

        for block in scheduledBlocks {
            guard block.status == .accepted else {
                continue
            }

            guard let eventIdentifier = normalizedEventIdentifier(from: block) else {
                if block.calendarLinkState == .identifierStale {
                    continue
                }

                var updatedBlock = block
                updatedBlock.calendarLinkState = .identifierStale
                updatedBlock.updatedAt = nowProvider()
                updatedBlock.lastSyncedAt = updatedBlock.updatedAt
                updatedBlock.syncErrorMessage = "This accepted block is missing its linked calendar event identifier."
                try scheduledBlockRepository.saveScheduledBlock(
                    updatedBlock,
                    replacingBlockWithID: updatedBlock.id
                )
                report.issues.append(
                    ReconciliationIssue(
                        blockID: updatedBlock.id,
                        message: updatedBlock.syncErrorMessage ?? "Missing linked event identifier."
                    )
                )
                continue
            }

            guard let event = eventStore.fetchEvent(withIdentifier: eventIdentifier) else {
                if block.calendarLinkState == .deletedExternally
                    && block.status == .deletedExternally {
                    continue
                }

                var updatedBlock = block
                updatedBlock.status = .deletedExternally
                updatedBlock.calendarLinkState = .deletedExternally
                updatedBlock.updatedAt = nowProvider()
                updatedBlock.lastSyncedAt = updatedBlock.updatedAt
                updatedBlock.syncErrorMessage = "The linked calendar event was deleted outside the app."
                try scheduledBlockRepository.saveScheduledBlock(
                    updatedBlock,
                    replacingBlockWithID: updatedBlock.id
                )
                report.deletedBlockCount += 1
                touchedTaskIDs.insert(updatedBlock.taskID)
                continue
            }

            let normalizedEventTitle = normalizedSnapshotTitle(event.title)
            let didMoveExternally =
                block.start != event.start
                || block.end != event.end
                || block.isAllDay != event.isAllDay
                || block.calendarTitle != event.calendarTitle
                || normalizedSnapshotTitle(block.eventTitleSnapshot) != normalizedEventTitle
            let needsStateRepair =
                didMoveExternally == false
                && (block.calendarLinkState == .identifierStale || block.calendarLinkState == .syncError)

            guard didMoveExternally || needsStateRepair else {
                continue
            }

            var updatedBlock = block
            updatedBlock.start = event.start
            updatedBlock.end = event.end
            updatedBlock.isAllDay = event.isAllDay
            updatedBlock.calendarTitle = event.calendarTitle
            updatedBlock.eventTitleSnapshot = normalizedEventTitle
            updatedBlock.updatedAt = nowProvider()
            updatedBlock.lastSyncedAt = updatedBlock.updatedAt
            updatedBlock.syncErrorMessage = nil
            updatedBlock.calendarLinkState = didMoveExternally ? .movedExternally : .linked
            try scheduledBlockRepository.saveScheduledBlock(
                updatedBlock,
                replacingBlockWithID: updatedBlock.id
            )

            if didMoveExternally {
                report.movedBlockCount += 1
            } else {
                report.reconciledBlockCount += 1
            }
        }

        for taskID in touchedTaskIDs {
            try syncTaskSchedulingStatus(for: taskID)
        }

        return report
    }

    private func normalizedEventIdentifier(from block: ScheduledBlock) -> String? {
        let identifier = block.calendarEventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let identifier, identifier.isEmpty == false else {
            return nil
        }

        return identifier
    }

    private func syncTaskSchedulingStatus(for taskID: UUID) throws {
        guard var task = try taskRepository.task(withID: taskID) else {
            return
        }

        let scheduledBlocks = try scheduledBlockRepository.fetchScheduledBlocks(for: taskID)
        let hasActiveBlock = scheduledBlocks.contains(where: \.isActivelyScheduled)
        let syncDate = nowProvider()

        if hasActiveBlock {
            guard task.status != .scheduled || task.completedAt != nil else {
                return
            }

            task.status = .scheduled
            task.completedAt = nil
            task.updatedAt = syncDate
            try taskRepository.saveTask(task, replacingTaskWithID: task.id)
            return
        }

        guard task.status == .scheduled else {
            return
        }

        task.status = .active
        task.updatedAt = syncDate
        try taskRepository.saveTask(task, replacingTaskWithID: task.id)
    }
}

private func requireFullAccess(from eventStore: any CalendarEventStore) throws {
    let status = mapPermissionStatus(eventStore.authorizationStatus())
    guard status == .fullAccessGranted else {
        throw CalendarReadError.fullAccessRequired(status)
    }
}

private func requireFullAccessForWriting(from eventStore: any CalendarEventStore) throws {
    let status = mapPermissionStatus(eventStore.authorizationStatus())
    guard status == .fullAccessGranted else {
        throw CalendarWriteError.fullAccessRequired(status)
    }
}

private func mapPermissionStatus(
    _ status: EventStoreAuthorizationStatus
) -> CalendarPermissionStatus {
    switch status {
    case .notDetermined:
        return .notDetermined
    case .fullAccess:
        return .fullAccessGranted
    case .writeOnly:
        return .writeOnlyGrantedButInsufficient
    case .denied:
        return .denied
    case .restricted:
        return .restricted
    case .unknown:
        return .error("Unknown Calendar authorization status.")
    }
}

private func plannerEventTitle(for task: MyTask) -> String {
    "Task: \(task.title)"
}

private func normalizedSnapshotTitle(_ title: String?) -> String {
    normalizedEventTitle(title)
}
