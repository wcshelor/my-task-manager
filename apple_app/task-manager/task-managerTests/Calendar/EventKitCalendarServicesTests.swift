import Foundation
import Testing
@testable import task_manager

@MainActor
struct EventKitCalendarServicesTests {
    @Test func permissionServiceMapsCurrentStatuses() {
        let writeOnlyStore = FakeCalendarEventStore(authorizationStatus: .writeOnly)
        let fullAccessStore = FakeCalendarEventStore(authorizationStatus: .fullAccess)

        let writeOnlyService = EventKitCalendarPermissionService(eventStore: writeOnlyStore)
        let fullAccessService = EventKitCalendarPermissionService(eventStore: fullAccessStore)

        #expect(writeOnlyService.currentStatus() == .writeOnlyGrantedButInsufficient)
        #expect(fullAccessService.currentStatus() == .fullAccessGranted)
    }

    @Test func permissionServiceReflectsGrantedAccessAfterRequest() async {
        let store = FakeCalendarEventStore(authorizationStatus: .notDetermined)
        store.requestResult = .success(true)
        store.authorizationStatusAfterRequest = .fullAccess
        let service = EventKitCalendarPermissionService(eventStore: store)

        let status = await service.requestFullAccess()

        #expect(status == .fullAccessGranted)
        #expect(store.requestFullAccessCallCount == 1)
    }

    @Test func calendarListingUsesSettingsToMarkExcludedCalendars() async throws {
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.calendars = [
            EventStoreCalendarDescriptor(
                id: "birthdays",
                title: "Birthdays",
                allowsContentModifications: false
            ),
            EventStoreCalendarDescriptor(
                id: "work",
                title: "Work",
                allowsContentModifications: true
            ),
        ]
        let settingsRepository = FakeSettingsRepository(
            settings: AppSettings(
                excludedReadCalendarTitles: ["Birthdays"],
                writeCalendarTitle: "Important",
                minimumGapMinutes: 15,
                defaultAssumedDurationMinutes: 30,
                plannerSuggestionCap: 5
            )
        )
        let service = EventKitCalendarListingService(
            eventStore: store,
            settingsRepository: settingsRepository
        )

        let calendars = try await service.fetchReadableCalendars()

        #expect(calendars.count == 2)
        #expect(calendars[0].title == "Birthdays")
        #expect(calendars[0].isExcludedBySettings == true)
        #expect(calendars[1].title == "Work")
        #expect(calendars[1].isExcludedBySettings == false)
    }

    @Test func calendarReaderFiltersExcludedCalendarsAndNormalizesTitles() async throws {
        let untitledStart = Date(timeIntervalSince1970: 1_000)
        let reviewStart = Date(timeIntervalSince1970: 2_000)
        let birthdaysStart = Date(timeIntervalSince1970: 3_000)
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.calendars = [
            EventStoreCalendarDescriptor(
                id: "birthdays",
                title: "Birthdays",
                allowsContentModifications: false
            ),
            EventStoreCalendarDescriptor(
                id: "work",
                title: "Work",
                allowsContentModifications: true
            ),
        ]
        store.events = [
            EventStoreEventDescriptor(
                identifier: "work-1",
                calendarIdentifier: "calendar",
                title: "  Weekly Review  ",
                start: reviewStart,
                end: reviewStart.addingTimeInterval(1_800),
                isAllDay: false,
                calendarTitle: "Work"
            ),
            EventStoreEventDescriptor(
                identifier: "work-2",
                calendarIdentifier: "calendar",
                title: "   ",
                start: untitledStart,
                end: untitledStart.addingTimeInterval(900),
                isAllDay: false,
                calendarTitle: "Work"
            ),
            EventStoreEventDescriptor(
                identifier: "bad-interval",
                calendarIdentifier: "calendar",
                title: "Broken Event",
                start: reviewStart,
                end: reviewStart,
                isAllDay: false,
                calendarTitle: "Work"
            ),
            EventStoreEventDescriptor(
                identifier: "birthday-1",
                calendarIdentifier: "calendar",
                title: "Birthday Dinner",
                start: birthdaysStart,
                end: birthdaysStart.addingTimeInterval(3_600),
                isAllDay: false,
                calendarTitle: "Birthdays"
            ),
        ]
        let settingsRepository = FakeSettingsRepository(
            settings: AppSettings(
                excludedReadCalendarTitles: ["Birthdays"],
                writeCalendarTitle: "Important",
                minimumGapMinutes: 15,
                defaultAssumedDurationMinutes: 30,
                plannerSuggestionCap: 5
            )
        )
        let service = EventKitCalendarReader(
            eventStore: store,
            settingsRepository: settingsRepository
        )

        let events = try await service.fetchEvents(
            in: DateInterval(
                start: Date(timeIntervalSince1970: 500),
                end: Date(timeIntervalSince1970: 5_000)
            )
        )

        #expect(store.lastRequestedCalendarIdentifiers == ["work"])
        #expect(events.count == 2)
        #expect(events[0].identifier == "work-2")
        #expect(events[0].title == "Untitled Event")
        #expect(events[1].identifier == "work-1")
        #expect(events[1].title == "Weekly Review")
        #expect(events.allSatisfy { $0.calendarTitle == "Work" })
    }

    @Test func calendarReaderRejectsInsufficientPermission() async {
        let store = FakeCalendarEventStore(authorizationStatus: .denied)
        let settingsRepository = FakeSettingsRepository(settings: .mvpDefault)
        let service = EventKitCalendarReader(
            eventStore: store,
            settingsRepository: settingsRepository
        )

        await #expect(throws: CalendarReadError.fullAccessRequired(.denied)) {
            try await service.fetchEvents(
                in: DateInterval(
                    start: Date(timeIntervalSince1970: 0),
                    end: Date(timeIntervalSince1970: 60)
                )
            )
        }
    }

    @Test func calendarWriterUsesTasksCalendarEvenWhenAnotherCalendarWasConfigured() async throws {
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.calendars = [
            EventStoreCalendarDescriptor(
                id: "important",
                title: "Important",
                allowsContentModifications: true
            ),
            EventStoreCalendarDescriptor(
                id: "tasks",
                title: "Tasks",
                allowsContentModifications: true
            )
        ]
        let settingsRepository = FakeSettingsRepository(
            settings: makeConfiguredSettings(
                writeCalendarIdentifier: "important",
                writeCalendarTitle: "Important"
            )
        )
        let service = EventKitCalendarWriter(
            eventStore: store,
            settingsRepository: settingsRepository
        )

        let calendarTitle = try await service.validateWriteCalendar()

        #expect(calendarTitle == "Tasks")
        #expect(settingsRepository.settings.writeCalendarIdentifier == "tasks")
        #expect(settingsRepository.settings.writeCalendarTitle == "Tasks")
    }

    @Test func calendarWriterRejectsMissingWriteCalendar() async {
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.calendars = [
            EventStoreCalendarDescriptor(
                id: "work",
                title: "Work",
                allowsContentModifications: true
            )
        ]
        let service = EventKitCalendarWriter(
            eventStore: store,
            settingsRepository: FakeSettingsRepository(
                settings: makeConfiguredSettings(
                    writeCalendarIdentifier: "important",
                    writeCalendarTitle: "Important"
                )
            )
        )

        await #expect(throws: CalendarWriteError.missingWriteCalendar("Tasks")) {
            try await service.validateWriteCalendar()
        }
    }

    @Test func calendarWriterMigratesTasksTitleSelectionToIdentifier() async throws {
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.calendars = [
            EventStoreCalendarDescriptor(
                id: "tasks",
                title: "Tasks",
                allowsContentModifications: true
            )
        ]
        let settingsRepository = FakeSettingsRepository(
            settings: makeConfiguredSettings(writeCalendarTitle: "Tasks")
        )
        let service = EventKitCalendarWriter(
            eventStore: store,
            settingsRepository: settingsRepository
        )

        let calendarTitle = try await service.validateWriteCalendar()

        #expect(calendarTitle == "Tasks")
        #expect(settingsRepository.settings.writeCalendarIdentifier == "tasks")
        #expect(settingsRepository.settings.writeCalendarTitle == "Tasks")
    }

    @Test func calendarWriterCreatesEventInConfiguredCalendarWithConsistentTitle() async throws {
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.calendars = [
            EventStoreCalendarDescriptor(
                id: "tasks",
                title: "Tasks",
                allowsContentModifications: true
            )
        ]
        store.saveEventResult = .success(
            EventStoreEventDescriptor(
                identifier: "event-123",
                calendarIdentifier: "calendar",
                title: "Task: Draft roadmap",
                start: Date(timeIntervalSince1970: 1_000),
                end: Date(timeIntervalSince1970: 2_800),
                isAllDay: false,
                calendarTitle: "Tasks"
            )
        )
        let service = EventKitCalendarWriter(
            eventStore: store,
            settingsRepository: FakeSettingsRepository(
                settings: makeConfiguredSettings(
                    writeCalendarIdentifier: "tasks",
                    writeCalendarTitle: "Tasks"
                )
            )
        )
        let task = MyTask(title: "Draft roadmap", estimatedMinutes: 30)
        let block = ScheduledBlock(
            taskID: task.id,
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_800),
            status: .accepted,
            calendarLinkState: .writePending
        )

        let writeResult = try await service.createEvent(for: block, task: task)

        #expect(store.savedRequests.count == 1)
        #expect(store.savedRequests[0].calendarIdentifier == "tasks")
        #expect(store.savedRequests[0].title == "Task: Draft roadmap")
        #expect(writeResult.eventIdentifier == "event-123")
        #expect(writeResult.calendarTitle == "Tasks")
        #expect(writeResult.eventTitle == "Task: Draft roadmap")
    }

    @Test func calendarWriterUpdatesExistingLinkedEvent() async throws {
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.calendars = [
            EventStoreCalendarDescriptor(
                id: "tasks",
                title: "Tasks",
                allowsContentModifications: true
            )
        ]
        store.saveEventResult = .success(
            EventStoreEventDescriptor(
                identifier: "event-123",
                calendarIdentifier: "calendar",
                title: "Task: Draft roadmap",
                start: Date(timeIntervalSince1970: 2_000),
                end: Date(timeIntervalSince1970: 3_800),
                isAllDay: false,
                calendarTitle: "Tasks"
            )
        )
        let service = EventKitCalendarWriter(
            eventStore: store,
            settingsRepository: FakeSettingsRepository(
                settings: makeConfiguredSettings(
                    writeCalendarIdentifier: "tasks",
                    writeCalendarTitle: "Tasks"
                )
            )
        )
        let task = MyTask(title: "Draft roadmap", estimatedMinutes: 30)
        let block = ScheduledBlock(
            taskID: task.id,
            start: Date(timeIntervalSince1970: 2_000),
            end: Date(timeIntervalSince1970: 3_800),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-123",
            calendarTitle: "Tasks"
        )

        let writeResult = try await service.updateEvent(for: block, task: task)

        #expect(store.savedRequests.count == 1)
        #expect(store.savedRequests[0].identifier == "event-123")
        #expect(writeResult.eventIdentifier == "event-123")
    }

    @Test func calendarWriterDeletesLinkedEventByIdentifier() async throws {
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.events = [
            EventStoreEventDescriptor(
                identifier: "event-123",
                calendarIdentifier: "calendar",
                title: "Task: Draft roadmap",
                start: Date(timeIntervalSince1970: 2_000),
                end: Date(timeIntervalSince1970: 3_800),
                isAllDay: false,
                calendarTitle: "Important"
            )
        ]
        let service = EventKitCalendarWriter(
            eventStore: store,
            settingsRepository: FakeSettingsRepository(
                settings: makeConfiguredSettings(
                    writeCalendarIdentifier: "important",
                    writeCalendarTitle: "Important"
                )
            )
        )
        let block = ScheduledBlock(
            taskID: UUID(),
            start: Date(timeIntervalSince1970: 2_000),
            end: Date(timeIntervalSince1970: 3_800),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-123",
            calendarTitle: "Important"
        )

        try await service.deleteEvent(for: block)

        #expect(store.deletedEventIdentifiers == ["event-123"])
    }

    @Test func reconcilerUpdatesAcceptedBlockWhenEventMovesExternally() async throws {
        let task = MyTask(
            title: "Draft roadmap",
            status: .scheduled,
            estimatedMinutes: 30,
            priority: .high
        )
        let originalBlock = ScheduledBlock(
            taskID: task.id,
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_800),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-123",
            calendarTitle: "Important",
            eventTitleSnapshot: "Task: Draft roadmap"
        )
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        store.events = [
            EventStoreEventDescriptor(
                identifier: "event-123",
                calendarIdentifier: "calendar",
                title: "Task: Draft roadmap",
                start: Date(timeIntervalSince1970: 4_000),
                end: Date(timeIntervalSince1970: 5_800),
                isAllDay: false,
                calendarTitle: "Important"
            )
        ]
        let blockRepository = FakeScheduledBlockRepository(blocks: [originalBlock])
        let taskRepository = FakeTaskRepository(tasks: [task])
        let reconciler = EventKitCalendarReconciler(
            eventStore: store,
            scheduledBlockRepository: blockRepository,
            taskRepository: taskRepository,
            nowProvider: { Date(timeIntervalSince1970: 9_000) }
        )

        let report = try await reconciler.reconcileScheduledBlocks()
        let savedBlock = try #require(blockRepository.blocks.first)

        #expect(report.movedBlockCount == 1)
        #expect(savedBlock.start == Date(timeIntervalSince1970: 4_000))
        #expect(savedBlock.end == Date(timeIntervalSince1970: 5_800))
        #expect(savedBlock.calendarLinkState == .movedExternally)
    }

    @Test func reconcilerMarksAcceptedBlockDeletedWhenLinkedEventIsGone() async throws {
        let task = MyTask(
            title: "Draft roadmap",
            status: .scheduled,
            estimatedMinutes: 30,
            priority: .high
        )
        let block = ScheduledBlock(
            taskID: task.id,
            start: Date(timeIntervalSince1970: 1_000),
            end: Date(timeIntervalSince1970: 2_800),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-123",
            calendarTitle: "Important",
            eventTitleSnapshot: "Task: Draft roadmap"
        )
        let store = FakeCalendarEventStore(authorizationStatus: .fullAccess)
        let blockRepository = FakeScheduledBlockRepository(blocks: [block])
        let taskRepository = FakeTaskRepository(tasks: [task])
        let reconciler = EventKitCalendarReconciler(
            eventStore: store,
            scheduledBlockRepository: blockRepository,
            taskRepository: taskRepository,
            nowProvider: { Date(timeIntervalSince1970: 9_000) }
        )

        let report = try await reconciler.reconcileScheduledBlocks()
        let savedBlock = try #require(blockRepository.blocks.first)
        let savedTask = try #require(try taskRepository.task(withID: task.id))

        #expect(report.deletedBlockCount == 1)
        #expect(savedBlock.status == .deletedExternally)
        #expect(savedBlock.calendarLinkState == .deletedExternally)
        #expect(savedTask.status == .open)
    }
}

@MainActor
private final class FakeCalendarEventStore: CalendarEventStore {
    var authorizationStatusValue: EventStoreAuthorizationStatus
    var authorizationStatusAfterRequest: EventStoreAuthorizationStatus?
    var requestResult: Result<Bool, Error> = .success(false)
    var saveEventResult: Result<EventStoreEventDescriptor, Error>?
    var deleteEventError: Error?
    var calendars: [EventStoreCalendarDescriptor] = []
    var events: [EventStoreEventDescriptor] = []
    private(set) var savedRequests: [EventStoreEventMutationRequest] = []
    private(set) var deletedEventIdentifiers: [String] = []
    private(set) var requestFullAccessCallCount = 0
    private(set) var lastRequestedCalendarIdentifiers: Set<String>?

    init(authorizationStatus: EventStoreAuthorizationStatus) {
        self.authorizationStatusValue = authorizationStatus
    }

    func authorizationStatus() -> EventStoreAuthorizationStatus {
        authorizationStatusValue
    }

    func requestFullAccess() async throws -> Bool {
        requestFullAccessCallCount += 1

        if let authorizationStatusAfterRequest {
            authorizationStatusValue = authorizationStatusAfterRequest
        }

        return try requestResult.get()
    }

    func fetchEventCalendars() -> [EventStoreCalendarDescriptor] {
        calendars
    }

    func fetchEvent(withIdentifier identifier: String) -> EventStoreEventDescriptor? {
        events.first { $0.identifier == identifier }
    }

    func fetchEvents(
        in window: DateInterval,
        calendarIdentifiers: Set<String>?
    ) -> [EventStoreEventDescriptor] {
        lastRequestedCalendarIdentifiers = calendarIdentifiers

        return events.filter { event in
            guard event.end > window.start, event.start < window.end else {
                return false
            }

            guard let calendarIdentifiers else {
                return true
            }

            let calendarID = calendars.first(where: { $0.title == event.calendarTitle })?.id
            return calendarID.map(calendarIdentifiers.contains) ?? false
        }
    }

    func saveEvent(_ request: EventStoreEventMutationRequest) throws -> EventStoreEventDescriptor {
        savedRequests.append(request)

        if let saveEventResult {
            return try saveEventResult.get()
        }

        let savedEvent = EventStoreEventDescriptor(
            identifier: request.identifier ?? "saved-\(savedRequests.count)",
            calendarIdentifier: "calendar",
            title: request.title,
            start: request.start,
            end: request.end,
            isAllDay: request.isAllDay,
            calendarTitle: calendars.first(where: { $0.id == request.calendarIdentifier })?.title ?? "Unknown"
        )

        if let identifier = savedEvent.identifier,
            let existingIndex = events.firstIndex(where: { $0.identifier == identifier }) {
            events[existingIndex] = savedEvent
        } else {
            events.append(savedEvent)
        }

        return savedEvent
    }

    func deleteEvent(withIdentifier identifier: String) throws {
        deletedEventIdentifiers.append(identifier)

        if let deleteEventError {
            throw deleteEventError
        }

        if events.contains(where: { $0.identifier == identifier }) == false {
            throw EventStoreMutationError.eventNotFound(identifier)
        }

        events.removeAll { $0.identifier == identifier }
    }
}

@MainActor
private final class FakeSettingsRepository: SettingsRepository {
    var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func loadSettings() throws -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) throws {
        self.settings = settings
    }
}

private func makeConfiguredSettings(
    writeCalendarIdentifier: String = "",
    writeCalendarTitle: String = ""
) -> AppSettings {
    AppSettings(
        excludedReadCalendarTitles: [],
        writeCalendarIdentifier: writeCalendarIdentifier,
        writeCalendarTitle: writeCalendarTitle,
        minimumGapMinutes: 15,
        defaultAssumedDurationMinutes: 30,
        plannerSuggestionCap: 5
    )
}

@MainActor
private final class FakeTaskRepository: TaskRepository {
    private(set) var tasks: [MyTask]

    init(tasks: [MyTask]) {
        self.tasks = tasks
    }

    func fetchTasks() throws -> [MyTask] {
        tasks
    }

    func task(withID id: UUID) throws -> MyTask? {
        tasks.first { $0.id == id }
    }

    func saveTask(_ task: MyTask, replacingTaskWithID originalID: UUID?) throws {
        tasks.saveTask(task, replacingTaskWithID: originalID)
    }

    func deleteTask(withID id: UUID) throws {
        tasks.deleteTask(withID: id)
    }
}

@MainActor
private final class FakeScheduledBlockRepository: ScheduledBlockRepository {
    private(set) var blocks: [ScheduledBlock]

    init(blocks: [ScheduledBlock]) {
        self.blocks = blocks
    }

    func fetchScheduledBlocks() throws -> [ScheduledBlock] {
        blocks
    }

    func fetchScheduledBlocks(for taskID: UUID) throws -> [ScheduledBlock] {
        blocks.filter { $0.taskID == taskID }
    }

    func saveScheduledBlock(_ block: ScheduledBlock, replacingBlockWithID originalID: UUID?) throws {
        if let originalID, let existingIndex = blocks.firstIndex(where: { $0.id == originalID }) {
            blocks[existingIndex] = block
            return
        }

        if let existingIndex = blocks.firstIndex(where: { $0.id == block.id }) {
            blocks[existingIndex] = block
            return
        }

        blocks.append(block)
    }

    func deleteScheduledBlock(withID id: UUID) throws {
        blocks.removeAll { $0.id == id }
    }
}
