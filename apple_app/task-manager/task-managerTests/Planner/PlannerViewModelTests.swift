import Foundation
import Testing
@testable import task_manager

@MainActor
struct PlannerViewModelTests {
    @Test func loadIfNeededAutomaticallyChecksCalendarAccessBeforeSkippingReads() async {
        let taskRepository = FakeTaskRepository(tasks: [
            MyTask(title: "Write brief", priority: .high)
        ])
        let permissionProvider = FakeCalendarPermissionProvider(currentStatus: .notDetermined)
        let listingService = FakeCalendarListingService(result: .success([
            ReadableCalendar(
                id: "work",
                title: "Work",
                allowsContentModifications: true,
                isExcludedBySettings: false
            )
        ]))
        let reader = FakeCalendarReader(result: .success([
            CalendarEventSnapshot(
                identifier: "busy-1",
                title: "Focus",
                start: Date(timeIntervalSince1970: 1_000),
                end: Date(timeIntervalSince1970: 2_000),
                isAllDay: false,
                calendarTitle: "Work"
            )
        ]))
        let viewModel = PlannerViewModel(
            taskRepository: taskRepository,
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: permissionProvider,
            calendarListingService: listingService,
            calendarReader: reader,
            calendarWriter: FakeCalendarWriter(),
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 50_000) }
        )

        await viewModel.loadIfNeeded()

        #expect(permissionProvider.requestCallCount == 1)
        #expect(viewModel.permissionStatus == .notDetermined)
        #expect(viewModel.tasks.count == 1)
        #expect(viewModel.calendars.isEmpty)
        #expect(viewModel.calendarEvents.isEmpty)
        #expect(listingService.fetchCallCount == 0)
        #expect(reader.fetchCallCount == 0)
    }

    @Test func loadIfNeededAutomaticallyRequestsCalendarAccessAndLoadsCalendarDataOnGrant() async {
        let permissionProvider = FakeCalendarPermissionProvider(
            currentStatus: .notDetermined,
            requestedStatus: .fullAccessGranted
        )
        let listingService = FakeCalendarListingService(result: .success([
            ReadableCalendar(
                id: "personal",
                title: "Personal",
                allowsContentModifications: true,
                isExcludedBySettings: false
            )
        ]))
        let expectedEvent = CalendarEventSnapshot(
            identifier: "meeting-1",
            title: "Design Review",
            start: Date(timeIntervalSince1970: 1_710_032_400),
            end: Date(timeIntervalSince1970: 1_710_036_000),
            isAllDay: false,
            calendarTitle: "Personal"
        )
        let reader = FakeCalendarReader(result: .success([expectedEvent]))
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = makeUTCGregorianCalendar()
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: permissionProvider,
            calendarListingService: listingService,
            calendarReader: reader,
            calendarWriter: FakeCalendarWriter(),
            calendar: calendar,
            nowProvider: { now }
        )

        await viewModel.loadIfNeeded()

        let expectedDayStart = calendar.startOfDay(for: now)
        let expectedDayEnd = calendar.date(byAdding: .day, value: 1, to: expectedDayStart)
            ?? expectedDayStart.addingTimeInterval(86_400)

        #expect(permissionProvider.requestCallCount == 1)
        #expect(viewModel.permissionStatus == .fullAccessGranted)
        #expect(viewModel.calendars == listingService.calendars)
        #expect(viewModel.calendarEvents == [expectedEvent])
        #expect(reader.requestedWindows == [DateInterval(start: expectedDayStart, end: expectedDayEnd)])
    }

    @Test func requestCalendarAccessLoadsCalendarsAndSelectedDayEventsOnGrant() async {
        let permissionProvider = FakeCalendarPermissionProvider(
            currentStatus: .notDetermined,
            requestedStatus: .fullAccessGranted
        )
        let listingService = FakeCalendarListingService(result: .success([
            ReadableCalendar(
                id: "personal",
                title: "Personal",
                allowsContentModifications: true,
                isExcludedBySettings: false
            )
        ]))
        let expectedEvent = CalendarEventSnapshot(
            identifier: "meeting-1",
            title: "Design Review",
            start: Date(timeIntervalSince1970: 1_710_032_400),
            end: Date(timeIntervalSince1970: 1_710_036_000),
            isAllDay: false,
            calendarTitle: "Personal"
        )
        let reader = FakeCalendarReader(result: .success([expectedEvent]))
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = makeUTCGregorianCalendar()
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: permissionProvider,
            calendarListingService: listingService,
            calendarReader: reader,
            calendarWriter: FakeCalendarWriter(),
            calendar: calendar,
            nowProvider: { now }
        )

        await viewModel.requestCalendarAccess()

        let expectedDayStart = calendar.startOfDay(for: now)
        let expectedDayEnd = calendar.date(byAdding: .day, value: 1, to: expectedDayStart)
            ?? expectedDayStart.addingTimeInterval(86_400)

        #expect(permissionProvider.requestCallCount == 1)
        #expect(viewModel.permissionStatus == .fullAccessGranted)
        #expect(viewModel.calendars == listingService.calendars)
        #expect(viewModel.calendarEvents == [expectedEvent])
        #expect(reader.requestedWindows == [DateInterval(start: expectedDayStart, end: expectedDayEnd)])
    }

    @Test func selectingWriteCalendarPersistsIdentifierBackedSelection() async {
        let settingsRepository = FakeSettingsRepository()
        let listingService = FakeCalendarListingService(result: .success([
            ReadableCalendar(
                id: "planner",
                title: "Planner",
                allowsContentModifications: true,
                isExcludedBySettings: false
            )
        ]))
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: settingsRepository,
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: listingService,
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: FakeCalendarWriter()
        )

        await viewModel.loadIfNeeded()
        viewModel.selectWriteCalendar(withID: "planner")

        #expect(viewModel.selectedWriteCalendarIdentifier == "planner")
        #expect(viewModel.selectedWriteCalendarTitle == "Planner")
        #expect(settingsRepository.settings.writeCalendarIdentifier == "planner")
        #expect(settingsRepository.settings.writeCalendarTitle == "Planner")
    }

    @Test func observedCalendarStoreChangeRefreshesPlannerDataWhileObservationIsEnabled() async {
        let calendar = makeUTCGregorianCalendar()
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let dayStart = calendar.startOfDay(for: now)
        let initialEvent = CalendarEventSnapshot(
            identifier: "meeting-1",
            title: "Initial Review",
            start: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart)!,
            end: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: dayStart)!,
            isAllDay: false,
            calendarTitle: "Work"
        )
        let updatedEvent = CalendarEventSnapshot(
            identifier: "meeting-2",
            title: "Updated Review",
            start: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: dayStart)!,
            end: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!,
            isAllDay: false,
            calendarTitle: "Work"
        )
        let listingService = FakeCalendarListingService(result: .success([
            ReadableCalendar(
                id: "work",
                title: "Work",
                allowsContentModifications: true,
                isExcludedBySettings: false
            )
        ]))
        let reader = FakeCalendarReader(result: .success([initialEvent]))
        let changeObserver = FakeCalendarChangeObserver()
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: listingService,
            calendarReader: reader,
            calendarWriter: FakeCalendarWriter(),
            calendarChangeObserver: changeObserver,
            calendar: calendar,
            nowProvider: { now }
        )

        await viewModel.loadIfNeeded()
        viewModel.setCalendarStoreChangeObservationEnabled(true)
        reader.result = .success([updatedEvent])

        await changeObserver.triggerChange()

        #expect(changeObserver.observeCallCount == 1)
        #expect(reader.fetchCallCount == 2)
        #expect(viewModel.calendarEvents == [updatedEvent])
    }

    @Test func disablingCalendarStoreObservationStopsAutomaticRefreshes() async {
        let calendar = makeUTCGregorianCalendar()
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let dayStart = calendar.startOfDay(for: now)
        let initialEvent = CalendarEventSnapshot(
            identifier: "meeting-1",
            title: "Initial Review",
            start: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart)!,
            end: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: dayStart)!,
            isAllDay: false,
            calendarTitle: "Work"
        )
        let updatedEvent = CalendarEventSnapshot(
            identifier: "meeting-2",
            title: "Updated Review",
            start: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: dayStart)!,
            end: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart)!,
            isAllDay: false,
            calendarTitle: "Work"
        )
        let reader = FakeCalendarReader(result: .success([initialEvent]))
        let changeObserver = FakeCalendarChangeObserver()
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: reader,
            calendarWriter: FakeCalendarWriter(),
            calendarChangeObserver: changeObserver,
            calendar: calendar,
            nowProvider: { now }
        )

        await viewModel.loadIfNeeded()
        viewModel.setCalendarStoreChangeObservationEnabled(true)
        viewModel.setCalendarStoreChangeObservationEnabled(false)
        reader.result = .success([updatedEvent])

        await changeObserver.triggerChange()

        #expect(changeObserver.invalidateCallCount == 1)
        #expect(reader.fetchCallCount == 1)
        #expect(viewModel.calendarEvents == [initialEvent])
    }

    @Test func acceptedScheduledBlocksRemainVisibleAndHideMirroredWriteCalendarEvents() async {
        let task = MyTask(
            title: "Deep Work",
            estimatedMinutes: 60,
            priority: .high,
            workMode: .deepWork
        )
        let calendar = makeUTCGregorianCalendar()
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let dayStart = calendar.startOfDay(for: now)
        let mirroredStart = calendar.date(byAdding: .hour, value: 9, to: dayStart)!
        let mirroredEnd = calendar.date(byAdding: .minute, value: 60, to: mirroredStart)!
        let scheduledBlock = ScheduledBlock(
            taskID: task.id,
            start: mirroredStart,
            end: mirroredEnd,
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "write-event-1",
            calendarTitle: "Important",
            eventTitleSnapshot: "Task: \(task.title)"
        )
        let mirroredEvent = CalendarEventSnapshot(
            identifier: "write-event-1",
            title: "Task: \(task.title)",
            start: mirroredStart,
            end: mirroredEnd,
            isAllDay: false,
            calendarTitle: "Important"
        )
        let externalEvent = CalendarEventSnapshot(
            identifier: "meeting-1",
            title: "Design Review",
            start: calendar.date(byAdding: .hour, value: 13, to: dayStart)!,
            end: calendar.date(byAdding: .hour, value: 14, to: dayStart)!,
            isAllDay: false,
            calendarTitle: "Work"
        )
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [task]),
            scheduledBlockRepository: FakeScheduledBlockRepository(blocks: [scheduledBlock]),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([mirroredEvent, externalEvent])),
            calendarWriter: FakeCalendarWriter(),
            calendar: calendar,
            nowProvider: { now }
        )

        await viewModel.loadIfNeeded()

        #expect(viewModel.timelineEntries.contains { entry in
            guard case .scheduledBlock(let item) = entry else {
                return false
            }

            return item.block.id == scheduledBlock.id
        })
        #expect(viewModel.timelineEntries.contains { entry in
            guard case .calendarEvent(let event) = entry else {
                return false
            }

            return event.identifier == externalEvent.identifier
        })
        #expect(viewModel.timelineEntries.contains { entry in
            guard case .calendarEvent(let event) = entry else {
                return false
            }

            return event.identifier == mirroredEvent.identifier
        } == false)
    }

    @Test func generatePlanUsesRealEngineAndRefreshesTheSuggestedDayTimeline() async {
        let focusTask = MyTask(
            title: "Deep Work Block",
            estimatedMinutes: 90,
            priority: .urgent,
            workMode: .deepWork,
            tags: ["focus"]
        )
        let errandTask = MyTask(
            title: "Pick up groceries",
            estimatedMinutes: 30,
            priority: .low,
            workMode: .errand,
            tags: ["home"]
        )
        let taskRepository = FakeTaskRepository(tasks: [focusTask, errandTask])
        let permissionProvider = FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted)
        let listingService = FakeCalendarListingService(result: .success([]))
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = makeUTCGregorianCalendar()
        let planningWindow = PlannerHorizon.tomorrow.planningWindow(relativeTo: now, calendar: calendar)
        let overnightBlocker = CalendarEventSnapshot(
            identifier: "sleep",
            title: "Busy",
            start: planningWindow.start,
            end: planningWindow.start.addingTimeInterval(9 * 3_600),
            isAllDay: false,
            calendarTitle: "Personal"
        )
        let reader = FakeCalendarReader(result: .success([overnightBlocker]))
        let settingsRepository = FakeSettingsRepository(
            settings: AppSettings(
                excludedReadCalendarTitles: [],
                writeCalendarTitle: "Important",
                minimumGapMinutes: 15,
                defaultAssumedDurationMinutes: 30,
                plannerSuggestionCap: 1
            )
        )
        let viewModel = PlannerViewModel(
            taskRepository: taskRepository,
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: settingsRepository,
            calendarPermissionProvider: permissionProvider,
            calendarListingService: listingService,
            calendarReader: reader,
            calendarWriter: FakeCalendarWriter(),
            calendar: calendar,
            nowProvider: { now },
            selectedPlanningHorizon: .tomorrow
        )

        await viewModel.generatePlan()

        let expectedSelectedDay = calendar.startOfDay(for: planningWindow.start)
        let expectedDayEnd = calendar.date(byAdding: .day, value: 1, to: expectedSelectedDay)
            ?? expectedSelectedDay.addingTimeInterval(86_400)

        #expect(viewModel.suggestionItems.count == 1)
        #expect(viewModel.suggestionItems.first?.taskTitle == focusTask.title)
        #expect(viewModel.selectedDay == expectedSelectedDay)
        #expect(reader.requestedWindows == [
            planningWindow,
            DateInterval(start: expectedSelectedDay, end: expectedDayEnd)
        ])
    }

    @Test func generatePlanForSelectedTimeRangeUsesExactSlotWindowAndKeepsSlotContext() async throws {
        let focusTask = MyTask(
            title: "Deep Work Block",
            estimatedMinutes: 120,
            priority: .urgent,
            workMode: .deepWork,
            tags: ["focus"]
        )
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = makeUTCGregorianCalendar()
        let dayStart = calendar.startOfDay(for: now)
        let slotStart = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: dayStart)!
        let slotEnd = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: dayStart)!
        let selectedSlot = try #require(
            PlannerSelectedTimeRange(start: slotStart, end: slotEnd)
        )
        let reader = FakeCalendarReader(result: .success([]))
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [focusTask]),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(
                settings: AppSettings(
                    excludedReadCalendarTitles: [],
                    writeCalendarTitle: "Important",
                    minimumGapMinutes: 15,
                    defaultAssumedDurationMinutes: 30,
                    plannerSuggestionCap: 1
                )
            ),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: reader,
            calendarWriter: FakeCalendarWriter(),
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.updateSelectedTimeRange(selectedSlot)

        await viewModel.generatePlanForSelectedTimeRange()

        let suggestion = try #require(viewModel.suggestionItems.first)

        #expect(reader.requestedWindows == [selectedSlot.interval])
        #expect(suggestion.interval == selectedSlot.interval)
        #expect(viewModel.selectedTimeRange == selectedSlot)
        #expect(viewModel.lastGeneratedRequestWindow == .selectedTimeRange(selectedSlot))
        #expect(viewModel.hasGeneratedSuggestionsForSelectedTimeRange)
        #expect(viewModel.selectedSlotSuggestionItems == [suggestion])
    }

    @Test func slotBasedGenerationKeepsQuarterHourAlignmentFromTimelineSelection() async throws {
        let task = MyTask(
            title: "Draft roadmap",
            estimatedMinutes: 45,
            priority: .high,
            workMode: .deepWork
        )
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = makeUTCGregorianCalendar()
        let selectedSlot = PlannerTimelineGrid.selectedRange(
            anchorSlotIndex: 37,
            currentSlotIndex: 39,
            on: calendar.startOfDay(for: now),
            calendar: calendar
        )
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [task]),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: FakeCalendarWriter(),
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.updateSelectedTimeRange(selectedSlot)

        await viewModel.generatePlanForSelectedTimeRange()

        let suggestion = try #require(viewModel.suggestionItems.first)
        let suggestionDurationMinutes = Int(suggestion.interval.duration / 60)

        #expect(selectedSlot.durationMinutes.isMultiple(of: TaskDurationRules.minutesIncrement))
        #expect(suggestion.interval.start == selectedSlot.start)
        #expect(suggestion.interval.end == selectedSlot.end)
        #expect(suggestionDurationMinutes.isMultiple(of: TaskDurationRules.minutesIncrement))
    }

    @Test func changingSelectedTimeRangeUpdatesSlotSuggestionContext() async throws {
        let task = MyTask(
            title: "Draft roadmap",
            estimatedMinutes: 45,
            priority: .high,
            workMode: .deepWork
        )
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = makeUTCGregorianCalendar()
        let dayStart = calendar.startOfDay(for: now)
        let firstSelection = try #require(
            PlannerSelectedTimeRange(
                start: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart)!,
                end: calendar.date(bySettingHour: 9, minute: 45, second: 0, of: dayStart)!
            )
        )
        let secondSelection = try #require(
            PlannerSelectedTimeRange(
                start: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: dayStart)!,
                end: calendar.date(bySettingHour: 11, minute: 45, second: 0, of: dayStart)!
            )
        )
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [task]),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: FakeCalendarWriter(),
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.updateSelectedTimeRange(firstSelection)
        await viewModel.generatePlanForSelectedTimeRange()

        #expect(viewModel.hasGeneratedSuggestionsForSelectedTimeRange)
        #expect(viewModel.selectedSlotSuggestionItems.count == 1)
        #expect(viewModel.timelineEntries.contains { entry in
            if case .suggestion = entry {
                return true
            }

            return false
        })

        viewModel.updateSelectedTimeRange(secondSelection)

        #expect(viewModel.hasGeneratedSuggestionsForSelectedTimeRange == false)
        #expect(viewModel.selectedSlotSuggestionItems.isEmpty)
        #expect(viewModel.suggestionItems.isEmpty)
        #expect(viewModel.timelineEntries.contains { entry in
            if case .suggestion = entry {
                return true
            }

            return false
        } == false)
    }

    @Test func clearingSelectedTimeRangeRemovesTransientSlotSuggestionsFromTimeline() async throws {
        let task = MyTask(
            title: "Draft roadmap",
            estimatedMinutes: 45,
            priority: .high,
            workMode: .deepWork
        )
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = makeUTCGregorianCalendar()
        let dayStart = calendar.startOfDay(for: now)
        let selectedSlot = try #require(
            PlannerSelectedTimeRange(
                start: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: dayStart)!,
                end: calendar.date(bySettingHour: 15, minute: 45, second: 0, of: dayStart)!
            )
        )
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [task]),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: FakeCalendarWriter(),
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.updateSelectedTimeRange(selectedSlot)
        await viewModel.generatePlanForSelectedTimeRange()

        #expect(viewModel.suggestionItems.count == 1)

        viewModel.clearSelectedTimeRange()

        #expect(viewModel.selectedTimeRange == nil)
        #expect(viewModel.suggestionItems.isEmpty)
        #expect(viewModel.hasGeneratedSuggestionsForSelectedTimeRange == false)
        #expect(viewModel.timelineEntries.contains { entry in
            if case .suggestion = entry {
                return true
            }

            return false
        } == false)
    }

    @Test func generatePlanWithoutFullAccessRecordsHelpfulErrorAndSkipsReads() async {
        let permissionProvider = FakeCalendarPermissionProvider(currentStatus: .notDetermined)
        let listingService = FakeCalendarListingService(result: .success([]))
        let reader = FakeCalendarReader(result: .success([]))
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [
                MyTask(title: "Draft weekly review", priority: .medium)
            ]),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: permissionProvider,
            calendarListingService: listingService,
            calendarReader: reader,
            calendarWriter: FakeCalendarWriter(),
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 1_710_000_000) }
        )

        await viewModel.generatePlan()

        #expect(viewModel.suggestionItems.isEmpty)
        #expect(viewModel.errorMessage == "Grant full Calendar access before generating a plan.")
        #expect(listingService.fetchCallCount == 0)
        #expect(reader.fetchCallCount == 0)
    }

    @Test func generatePlanReportsWhenNoSuggestionsFit() async {
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: FakeCalendarWriter(),
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 1_710_000_000) }
        )

        await viewModel.generatePlan()

        #expect(viewModel.suggestionItems.isEmpty)
        #expect(viewModel.errorMessage == "No suggestions fit the selected planning window and filters.")
    }

    @Test func acceptingSlotGeneratedSuggestionPersistsLinkedBlockWritesCalendarEventAndRefreshesUI() async throws {
        let focusTask = MyTask(
            title: "Write architecture notes",
            estimatedMinutes: 45,
            priority: .high,
            workMode: .deepWork,
            tags: ["focus", "work"]
        )
        let adminTask = MyTask(
            title: "Expense report",
            estimatedMinutes: 30,
            priority: .low,
            workMode: .shallowAdmin,
            tags: ["admin"]
        )
        let taskRepository = FakeTaskRepository(tasks: [focusTask, adminTask])
        let scheduledBlockRepository = FakeScheduledBlockRepository()
        let writerResult = CalendarWriteResult(
            eventIdentifier: "event-123",
            calendarTitle: "Important",
            eventTitle: "Task: \(focusTask.title)",
            writtenAt: Date(timeIntervalSince1970: 1_710_000_900)
        )
        let calendarWriter = FakeCalendarWriter(
            validatedCalendarTitle: "Important",
            createEventResult: .success(writerResult)
        )
        let viewModel = PlannerViewModel(
            taskRepository: taskRepository,
            scheduledBlockRepository: scheduledBlockRepository,
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: calendarWriter,
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 1_710_000_000) }
        )
        let selectedSlot = try #require(
            PlannerSelectedTimeRange(
                start: Date(timeIntervalSince1970: 1_710_003_600),
                end: Date(timeIntervalSince1970: 1_710_006_300)
            )
        )

        viewModel.filterState.workMode = .deepWork
        viewModel.setSelectedTag("focus", isEnabled: true)
        viewModel.updateSelectedTimeRange(selectedSlot)

        await viewModel.generatePlanForSelectedTimeRange()

        #expect(viewModel.suggestionItems.count == 1)
        #expect(viewModel.suggestionItems.first?.taskTitle == focusTask.title)

        let suggestionID = try #require(viewModel.suggestionItems.first?.id)
        await viewModel.acceptSuggestion(withID: suggestionID)

        let savedBlock = try #require(scheduledBlockRepository.blocks.first)
        let savedTask = try #require(try taskRepository.task(withID: focusTask.id))

        #expect(viewModel.suggestionItems.isEmpty)
        #expect(calendarWriter.validateWriteCalendarCallCount == 1)
        #expect(calendarWriter.createEventCallCount == 1)
        #expect(savedBlock.status == .accepted)
        #expect(savedBlock.calendarLinkState == .linked)
        #expect(savedBlock.calendarEventIdentifier == "event-123")
        #expect(savedBlock.calendarTitle == "Important")
        #expect(savedBlock.eventTitleSnapshot == "Task: \(focusTask.title)")
        #expect(savedBlock.interval == selectedSlot.interval)
        #expect(savedTask.status == .scheduled)
        #expect(viewModel.selectedTimeRange == nil)
    }

    @Test func acceptSuggestionFailsClearlyWithoutCalendarAccessAndLeavesSuggestionTransient() async throws {
        let task = MyTask(
            title: "Draft roadmap",
            estimatedMinutes: 60,
            priority: .high,
            workMode: .deepWork
        )
        let permissionProvider = FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted)
        let blockRepository = FakeScheduledBlockRepository()
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [task]),
            scheduledBlockRepository: blockRepository,
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: permissionProvider,
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: FakeCalendarWriter(),
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 1_710_000_000) }
        )

        await viewModel.generatePlan()

        permissionProvider.currentStatusValue = .denied
        let suggestionID = try #require(viewModel.suggestionItems.first?.id)
        await viewModel.acceptSuggestion(withID: suggestionID)

        #expect(viewModel.suggestionItems.count == 1)
        #expect(blockRepository.blocks.isEmpty)
        #expect(viewModel.errorMessage?.contains("Unable to accept suggestion") == true)
    }

    @Test func acceptSuggestionRollsBackPendingBlockWhenCalendarWriteFails() async throws {
        let task = MyTask(
            title: "Draft roadmap",
            estimatedMinutes: 60,
            priority: .high,
            workMode: .deepWork
        )
        let blockRepository = FakeScheduledBlockRepository()
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [task]),
            scheduledBlockRepository: blockRepository,
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: FakeCalendarWriter(
                createEventResult: .failure(CalendarWriteError.saveFailed("Calendar backend exploded"))
            ),
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 1_710_000_000) }
        )

        await viewModel.generatePlan()

        let suggestionID = try #require(viewModel.suggestionItems.first?.id)
        await viewModel.acceptSuggestion(withID: suggestionID)

        #expect(viewModel.suggestionItems.count == 1)
        #expect(blockRepository.blocks.isEmpty)
        #expect(viewModel.errorMessage?.contains("Calendar backend exploded") == true)
    }

    @Test func editingAcceptedBlockUpdatesItsIntervalAndCalendarEvent() async throws {
        let task = MyTask(
            title: "Deep Work Block",
            estimatedMinutes: 60,
            priority: .high,
            workMode: .deepWork
        )
        let originalBlock = ScheduledBlock(
            taskID: task.id,
            start: Date(timeIntervalSince1970: 1_710_003_600),
            end: Date(timeIntervalSince1970: 1_710_007_200),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-123",
            calendarTitle: "Important",
            eventTitleSnapshot: "Task: \(task.title)"
        )
        let updatedWriteResult = CalendarWriteResult(
            eventIdentifier: "event-123",
            calendarTitle: "Important",
            eventTitle: "Task: \(task.title)",
            writtenAt: Date(timeIntervalSince1970: 1_710_008_000)
        )
        let writer = FakeCalendarWriter(updateEventResult: .success(updatedWriteResult))
        let repository = FakeScheduledBlockRepository(blocks: [originalBlock])
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [task]),
            scheduledBlockRepository: repository,
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: writer,
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 1_710_000_000) }
        )
        let editedStart = Date(timeIntervalSince1970: 1_710_004_500)
        let editedEnd = Date(timeIntervalSince1970: 1_710_008_100)

        await viewModel.editAcceptedBlock(
            withID: originalBlock.id,
            start: editedStart,
            end: editedEnd
        )

        let savedBlock = try #require(repository.blocks.first)

        #expect(writer.updateEventCallCount == 1)
        #expect(savedBlock.start == editedStart)
        #expect(savedBlock.end == editedEnd)
        #expect(savedBlock.calendarLinkState == .linked)
        #expect(savedBlock.lastSyncedAt == updatedWriteResult.writtenAt)
    }

    @Test func reschedulingAcceptedBlockToSelectedTimeRangeUpdatesTheLinkedEvent() async throws {
        let task = MyTask(
            title: "Deep Work Block",
            estimatedMinutes: 60,
            priority: .high,
            workMode: .deepWork
        )
        let originalBlock = ScheduledBlock(
            taskID: task.id,
            start: Date(timeIntervalSince1970: 1_710_003_600),
            end: Date(timeIntervalSince1970: 1_710_007_200),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-123",
            calendarTitle: "Important",
            eventTitleSnapshot: "Task: \(task.title)"
        )
        let calendar = makeUTCGregorianCalendar()
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let dayStart = calendar.startOfDay(for: now)
        let selectedSlot = try #require(
            PlannerSelectedTimeRange(
                start: calendar.date(bySettingHour: 16, minute: 0, second: 0, of: dayStart)!,
                end: calendar.date(bySettingHour: 17, minute: 0, second: 0, of: dayStart)!
            )
        )
        let writer = FakeCalendarWriter(
            updateEventResult: .success(
                CalendarWriteResult(
                    eventIdentifier: "event-123",
                    calendarTitle: "Important",
                    eventTitle: "Task: \(task.title)",
                    writtenAt: Date(timeIntervalSince1970: 1_710_009_000)
                )
            )
        )
        let repository = FakeScheduledBlockRepository(blocks: [originalBlock])
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [task]),
            scheduledBlockRepository: repository,
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: writer,
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.updateSelectedTimeRange(selectedSlot)

        await viewModel.rescheduleAcceptedBlockToSelectedTimeRange(withID: originalBlock.id)

        let savedBlock = try #require(repository.blocks.first)

        #expect(writer.updateEventCallCount == 1)
        #expect(savedBlock.interval == selectedSlot.interval)
        #expect(viewModel.selectedTimeRange == nil)
    }

    @Test func cancelingAcceptedBlockDeletesItsCalendarEventAndPreservesCanceledHistory() async throws {
        let task = MyTask(
            title: "Deep Work Block",
            status: .scheduled,
            estimatedMinutes: 60,
            priority: .high,
            workMode: .deepWork
        )
        let block = ScheduledBlock(
            taskID: task.id,
            start: Date(timeIntervalSince1970: 1_710_003_600),
            end: Date(timeIntervalSince1970: 1_710_007_200),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-123",
            calendarTitle: "Important",
            eventTitleSnapshot: "Task: \(task.title)"
        )
        let writer = FakeCalendarWriter()
        let taskRepository = FakeTaskRepository(tasks: [task])
        let repository = FakeScheduledBlockRepository(blocks: [block])
        let viewModel = PlannerViewModel(
            taskRepository: taskRepository,
            scheduledBlockRepository: repository,
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: writer,
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 1_710_000_000) }
        )

        await viewModel.cancelAcceptedBlock(withID: block.id)

        let savedBlock = try #require(repository.blocks.first)
        let savedTask = try #require(try taskRepository.task(withID: task.id))

        #expect(writer.deleteEventCallCount == 1)
        #expect(savedBlock.status == .canceled)
        #expect(savedBlock.calendarLinkState == .notWritten)
        #expect(savedBlock.calendarEventIdentifier == nil)
        #expect(savedTask.status == .active)
    }

    @Test func deletingAcceptedBlockDeletesItsCalendarEventAndRemovesTheRecord() async throws {
        let task = MyTask(
            title: "Deep Work Block",
            status: .scheduled,
            estimatedMinutes: 60,
            priority: .high,
            workMode: .deepWork
        )
        let block = ScheduledBlock(
            taskID: task.id,
            start: Date(timeIntervalSince1970: 1_710_003_600),
            end: Date(timeIntervalSince1970: 1_710_007_200),
            status: .accepted,
            calendarLinkState: .linked,
            calendarEventIdentifier: "event-123",
            calendarTitle: "Important",
            eventTitleSnapshot: "Task: \(task.title)"
        )
        let writer = FakeCalendarWriter()
        let taskRepository = FakeTaskRepository(tasks: [task])
        let repository = FakeScheduledBlockRepository(blocks: [block])
        let viewModel = PlannerViewModel(
            taskRepository: taskRepository,
            scheduledBlockRepository: repository,
            settingsRepository: FakeSettingsRepository(),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: writer,
            calendar: makeUTCGregorianCalendar(),
            nowProvider: { Date(timeIntervalSince1970: 1_710_000_000) }
        )

        await viewModel.deleteAcceptedBlock(withID: block.id)

        let savedTask = try #require(try taskRepository.task(withID: task.id))

        #expect(writer.deleteEventCallCount == 1)
        #expect(repository.blocks.isEmpty)
        #expect(savedTask.status == .active)
    }

    @Test func rejectingSlotGeneratedSuggestionAvoidsImmediateRegenerationOfTheSameSuggestion() async throws {
        let task = MyTask(
            title: "Draft roadmap",
            estimatedMinutes: 60,
            priority: .high,
            workMode: .deepWork
        )
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let calendar = makeUTCGregorianCalendar()
        let dayStart = calendar.startOfDay(for: now)
        let selectedSlot = try #require(
            PlannerSelectedTimeRange(
                start: calendar.date(bySettingHour: 13, minute: 0, second: 0, of: dayStart)!,
                end: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: dayStart)!
            )
        )
        let viewModel = PlannerViewModel(
            taskRepository: FakeTaskRepository(tasks: [task]),
            scheduledBlockRepository: FakeScheduledBlockRepository(),
            settingsRepository: FakeSettingsRepository(
                settings: AppSettings(
                    excludedReadCalendarTitles: [],
                    writeCalendarTitle: "Important",
                    minimumGapMinutes: 15,
                    defaultAssumedDurationMinutes: 30,
                    plannerSuggestionCap: 1
                )
            ),
            calendarPermissionProvider: FakeCalendarPermissionProvider(currentStatus: .fullAccessGranted),
            calendarListingService: FakeCalendarListingService(result: .success([])),
            calendarReader: FakeCalendarReader(result: .success([])),
            calendarWriter: FakeCalendarWriter(),
            calendar: calendar,
            nowProvider: { now }
        )

        viewModel.updateSelectedTimeRange(selectedSlot)

        await viewModel.generatePlanForSelectedTimeRange()
        let initialSuggestionID = try #require(viewModel.suggestionItems.first?.id)
        let initialInterval = viewModel.suggestionItems.first?.interval

        viewModel.rejectSuggestion(withID: initialSuggestionID)

        #expect(viewModel.suggestionItems.isEmpty)
        #expect(viewModel.lastGeneratedRequestWindow == .selectedTimeRange(selectedSlot))
        #expect(viewModel.hasGeneratedSuggestionsForSelectedTimeRange)

        await viewModel.generatePlanForSelectedTimeRange()

        #expect(initialInterval != nil)
        #expect(viewModel.suggestionItems.isEmpty)
        #expect(viewModel.errorMessage == "No suggestions fit the selected slot and filters.")
    }
}

@MainActor
private final class FakeTaskRepository: TaskRepository {
    private(set) var tasks: [MyTask]

    init(tasks: [MyTask] = []) {
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

    init(blocks: [ScheduledBlock] = []) {
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

@MainActor
private final class FakeSettingsRepository: SettingsRepository {
    var settings: AppSettings

    init(settings: AppSettings = .mvpDefault) {
        self.settings = settings
    }

    func loadSettings() throws -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) throws {
        self.settings = settings
    }
}

@MainActor
private final class FakeCalendarPermissionProvider: CalendarPermissionProviding {
    var currentStatusValue: CalendarPermissionStatus
    var requestedStatus: CalendarPermissionStatus?
    private(set) var requestCallCount = 0

    init(
        currentStatus: CalendarPermissionStatus,
        requestedStatus: CalendarPermissionStatus? = nil
    ) {
        self.currentStatusValue = currentStatus
        self.requestedStatus = requestedStatus
    }

    func currentStatus() -> CalendarPermissionStatus {
        currentStatusValue
    }

    func requestFullAccess() async -> CalendarPermissionStatus {
        requestCallCount += 1

        if let requestedStatus {
            currentStatusValue = requestedStatus
        }

        return currentStatusValue
    }
}

@MainActor
private final class FakeCalendarListingService: CalendarListing {
    var result: Result<[ReadableCalendar], Error>
    private(set) var fetchCallCount = 0

    init(result: Result<[ReadableCalendar], Error>) {
        self.result = result
    }

    var calendars: [ReadableCalendar] {
        (try? result.get()) ?? []
    }

    func fetchReadableCalendars() async throws -> [ReadableCalendar] {
        fetchCallCount += 1
        return try result.get()
    }
}

@MainActor
private final class FakeCalendarReader: CalendarReading {
    var result: Result<[CalendarEventSnapshot], Error>
    private(set) var fetchCallCount = 0
    private(set) var requestedWindows: [DateInterval] = []

    init(result: Result<[CalendarEventSnapshot], Error>) {
        self.result = result
    }

    func fetchEvents(in window: DateInterval) async throws -> [CalendarEventSnapshot] {
        fetchCallCount += 1
        requestedWindows.append(window)
        return try result.get()
    }
}

@MainActor
private final class FakeCalendarWriter: CalendarWriting {
    var validatedCalendarTitle: String
    var createEventResult: Result<CalendarWriteResult, Error>
    var updateEventResult: Result<CalendarWriteResult, Error>
    var deleteEventResult: Result<Void, Error>
    private(set) var validateWriteCalendarCallCount = 0
    private(set) var createEventCallCount = 0
    private(set) var updateEventCallCount = 0
    private(set) var deleteEventCallCount = 0

    init(
        validatedCalendarTitle: String = "Important",
        createEventResult: Result<CalendarWriteResult, Error> = .success(
            CalendarWriteResult(
                eventIdentifier: "fake-event",
                calendarTitle: "Important",
                eventTitle: "Task: Fake"
            )
        ),
        updateEventResult: Result<CalendarWriteResult, Error>? = nil,
        deleteEventResult: Result<Void, Error> = .success(())
    ) {
        self.validatedCalendarTitle = validatedCalendarTitle
        self.createEventResult = createEventResult
        self.updateEventResult = updateEventResult ?? createEventResult
        self.deleteEventResult = deleteEventResult
    }

    func validateWriteCalendar() async throws -> String {
        validateWriteCalendarCallCount += 1
        return validatedCalendarTitle
    }

    func createEvent(for block: ScheduledBlock, task: MyTask) async throws -> CalendarWriteResult {
        createEventCallCount += 1
        return try createEventResult.get()
    }

    func updateEvent(for block: ScheduledBlock, task: MyTask) async throws -> CalendarWriteResult {
        updateEventCallCount += 1
        return try updateEventResult.get()
    }

    func deleteEvent(for block: ScheduledBlock) async throws {
        deleteEventCallCount += 1
        _ = try deleteEventResult.get()
    }
}

@MainActor
private final class FakeCalendarChangeObserver: CalendarChangeObserving {
    private(set) var observeCallCount = 0
    private(set) var invalidateCallCount = 0
    private var onChange: (@MainActor @Sendable () -> Void)?

    func observeStoreChanges(
        _ onChange: @escaping @MainActor @Sendable () -> Void
    ) -> any CalendarChangeObservation {
        observeCallCount += 1
        self.onChange = onChange
        return FakeCalendarChangeObservation { [weak self] in
            self?.invalidateCallCount += 1
            self?.onChange = nil
        }
    }

    func triggerChange() async {
        onChange?()
        await Task.yield()
        await Task.yield()
    }
}

private final class FakeCalendarChangeObservation: CalendarChangeObservation {
    private let onInvalidate: () -> Void
    private var isInvalidated = false

    init(onInvalidate: @escaping () -> Void) {
        self.onInvalidate = onInvalidate
    }

    func invalidate() {
        guard isInvalidated == false else {
            return
        }

        isInvalidated = true
        onInvalidate()
    }

    deinit {
        invalidate()
    }
}

private func makeUTCGregorianCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
    return calendar
}
