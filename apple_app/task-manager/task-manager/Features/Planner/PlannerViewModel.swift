import Combine
import Foundation

@MainActor
final class PlannerViewModel: ObservableObject {
    @Published private(set) var permissionStatus: CalendarPermissionStatus
    @Published private(set) var settings: AppSettings
    @Published private(set) var calendars: [ReadableCalendar] = []
    @Published private(set) var calendarEvents: [CalendarEventSnapshot] = []
    @Published private(set) var scheduledBlocks: [ScheduledBlock] = []
    @Published private(set) var tasks: [MyTask] = []
    @Published private(set) var suggestionItems: [PlannerSuggestionItem] = []
    @Published private(set) var activeSuggestionOperationIDs: Set<UUID> = []
    @Published private(set) var activeScheduledBlockOperationIDs: Set<UUID> = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var reconciliationNotice: String?
    @Published private(set) var isLoading = false
    @Published private(set) var selectedDay: Date
    @Published private(set) var selectedTimeRange: PlannerSelectedTimeRange?
    @Published var selectedPlanningHorizon: PlannerHorizon
    @Published var filterState: PlannerFilterState
    @Published private(set) var lastGeneratedRequestWindow: PlannerRequestWindow?

    private let taskRepository: any TaskRepository
    private let scheduledBlockRepository: any ScheduledBlockRepository
    private let settingsRepository: any SettingsRepository
    private let calendarPermissionProvider: any CalendarPermissionProviding
    private let calendarListingService: any CalendarListing
    private let calendarReader: any CalendarReading
    private let calendarWriter: any CalendarWriting
    private let calendarReconciler: (any CalendarReconciling)?
    private let calendarChangeObserver: (any CalendarChangeObserving)?
    private let plannerEngine: PlannerEngine
    private let calendar: Calendar
    private let nowProvider: @Sendable () -> Date
    private var hasLoaded = false
    private var rejectedSuggestionFingerprints: Set<SuggestionFingerprint> = []
    private var calendarStoreChangeObservation: (any CalendarChangeObservation)?
    private var isCalendarStoreObservationEnabled = false
    private var isRefreshingObservedCalendarStoreChange = false
    private var hasPendingObservedCalendarStoreChange = false

    init(
        taskRepository: any TaskRepository,
        scheduledBlockRepository: any ScheduledBlockRepository,
        settingsRepository: any SettingsRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing,
        calendarReader: any CalendarReading,
        calendarWriter: any CalendarWriting,
        calendarReconciler: (any CalendarReconciling)? = nil,
        calendarChangeObserver: (any CalendarChangeObserving)? = nil,
        plannerEngine: PlannerEngine = PlannerEngine(),
        calendar: Calendar = .current,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        selectedPlanningHorizon: PlannerHorizon = .restOfToday,
        filterState: PlannerFilterState = PlannerFilterState()
    ) {
        self.taskRepository = taskRepository
        self.scheduledBlockRepository = scheduledBlockRepository
        self.settingsRepository = settingsRepository
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarListingService = calendarListingService
        self.calendarReader = calendarReader
        self.calendarWriter = calendarWriter
        self.calendarReconciler = calendarReconciler
        self.calendarChangeObserver = calendarChangeObserver
        self.plannerEngine = plannerEngine
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.selectedDay = calendar.startOfDay(for: nowProvider())
        self.selectedPlanningHorizon = selectedPlanningHorizon
        self.filterState = filterState
        self.permissionStatus = calendarPermissionProvider.currentStatus()
        self.settings = .mvpDefault
    }

    var visibleDayInterval: DateInterval {
        let start = calendar.startOfDay(for: selectedDay)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    var selectedPlanningWindow: DateInterval {
        activePlanningRequestWindow.planningWindow(relativeTo: nowProvider(), calendar: calendar)
    }

    var selectedHorizonPlanningWindow: DateInterval {
        PlannerRequestWindow.horizon(selectedPlanningHorizon)
            .planningWindow(relativeTo: nowProvider(), calendar: calendar)
    }

    var activePlanningRequestWindow: PlannerRequestWindow {
        if let selectedTimeRange {
            return .selectedTimeRange(selectedTimeRange)
        }

        return .horizon(selectedPlanningHorizon)
    }

    var timelineCalendar: Calendar {
        calendar
    }

    var timelineEntries: [PlannerTimelineEntry] {
        let scheduledBlockItems = visibleScheduledBlockItems
        let mirroredScheduledEventIdentifiers = Set(
            scheduledBlockItems.compactMap(\.block.calendarEventIdentifier)
        )
        let eventEntries = calendarEvents
            .filter { event in
                guard let identifier = event.identifier else {
                    return true
                }

                return mirroredScheduledEventIdentifiers.contains(identifier) == false
            }
            .map(PlannerTimelineEntry.calendarEvent)
        let scheduledEntries = scheduledBlockItems.map(PlannerTimelineEntry.scheduledBlock)
        let suggestionEntries = visibleSuggestionItems.map(PlannerTimelineEntry.suggestion)

        return (eventEntries + scheduledEntries + suggestionEntries).sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay {
                return lhs.isAllDay && rhs.isAllDay == false
            }

            if lhs.start != rhs.start {
                return lhs.start < rhs.start
            }

            if lhs.end != rhs.end {
                return lhs.end < rhs.end
            }

            switch (lhs, rhs) {
            case (.calendarEvent, .suggestion):
                return true
            case (.suggestion, .calendarEvent):
                return false
            case (.calendarEvent, .scheduledBlock):
                return true
            case (.scheduledBlock, .calendarEvent):
                return false
            case (.scheduledBlock, .suggestion):
                return true
            case (.suggestion, .scheduledBlock):
                return false
            default:
                return lhs.id < rhs.id
            }
        }
    }

    var availableTags: [String] {
        Array(Set(tasks.flatMap(\.tags))).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    var availableWorkModes: [WorkModeKind] {
        WorkModeKind.allCases
    }

    var writableCalendars: [ReadableCalendar] {
        calendars.filter(\.allowsContentModifications)
    }

    var selectedWriteCalendarIdentifier: String {
        settings.writeCalendarIdentifier
    }

    var selectedWriteCalendarTitle: String? {
        if let matchedCalendar = writableCalendars.first(where: {
            $0.id == settings.writeCalendarIdentifier
        }) {
            return matchedCalendar.title
        }

        guard settings.writeCalendarTitle.isEmpty == false else {
            return nil
        }

        return settings.writeCalendarTitle
    }

    var visibleSuggestionItems: [PlannerSuggestionItem] {
        suggestionItems.filter { $0.interval.overlaps(visibleDayInterval) }
    }

    var selectedSlotSuggestionItems: [PlannerSuggestionItem] {
        guard let selectedTimeRange,
            lastGeneratedRequestWindow == .selectedTimeRange(selectedTimeRange) else {
            return []
        }

        return suggestionItems.filter { $0.interval.overlaps(selectedTimeRange.interval) }
    }

    var hasGeneratedSuggestionsForSelectedTimeRange: Bool {
        guard let selectedTimeRange else {
            return false
        }

        return lastGeneratedRequestWindow == .selectedTimeRange(selectedTimeRange)
    }

    var visibleScheduledBlockItems: [PlannerScheduledBlockItem] {
        scheduledBlocks
            .filter(\.isActivelyScheduled)
            .filter { $0.interval.overlaps(visibleDayInterval) }
            .map { block in
                PlannerScheduledBlockItem(
                    block: block,
                    taskTitle: taskTitle(for: block)
                )
            }
    }

    func loadIfNeeded() async {
        guard hasLoaded == false else {
            return
        }

        await refresh()
    }

    func refresh() async {
        permissionStatus = calendarPermissionProvider.currentStatus()
        hasLoaded = true
        errorMessage = nil
        reconciliationNotice = nil

        loadTasks()
        loadScheduledBlocks()
        loadSettings()

        guard permissionStatus == .fullAccessGranted else {
            calendars = []
            calendarEvents = []
            return
        }

        await refreshCalendarData()
    }

    func handleSceneDidBecomeActive() async {
        guard hasLoaded else {
            return
        }

        await refresh()
    }

    func setCalendarStoreChangeObservationEnabled(_ isEnabled: Bool) {
        guard isCalendarStoreObservationEnabled != isEnabled else {
            return
        }

        isCalendarStoreObservationEnabled = isEnabled

        if isEnabled {
            guard calendarStoreChangeObservation == nil else {
                return
            }

            calendarStoreChangeObservation = calendarChangeObserver?.observeStoreChanges { [weak self] in
                self?.queueObservedCalendarStoreChangeRefresh()
            }
            return
        }

        hasPendingObservedCalendarStoreChange = false
        calendarStoreChangeObservation?.invalidate()
        calendarStoreChangeObservation = nil
    }

    func requestCalendarAccess() async {
        let requestedStatus = await calendarPermissionProvider.requestFullAccess()
        permissionStatus = requestedStatus

        if case .error(let message) = requestedStatus {
            calendars = []
            calendarEvents = []
            recordError(message)
            hasLoaded = true
            return
        }

        await refresh()
    }

    func selectWriteCalendar(withID calendarID: String) {
        errorMessage = nil

        guard calendarID.isEmpty == false else {
            return
        }

        guard let selectedCalendar = writableCalendars.first(where: { $0.id == calendarID }) else {
            recordError("The selected write calendar is no longer available.")
            return
        }

        do {
            var updatedSettings = settings
            updatedSettings.writeCalendarIdentifier = selectedCalendar.id
            updatedSettings.writeCalendarTitle = selectedCalendar.title
            try settingsRepository.saveSettings(updatedSettings)
            settings = updatedSettings
        } catch {
            recordError("Unable to save calendar settings: \(error.localizedDescription)")
        }
    }

    func goToPreviousDay() async {
        await selectDay(
            calendar.date(byAdding: .day, value: -1, to: selectedDay)
                ?? selectedDay.addingTimeInterval(-86_400)
        )
    }

    func goToNextDay() async {
        await selectDay(
            calendar.date(byAdding: .day, value: 1, to: selectedDay)
                ?? selectedDay.addingTimeInterval(86_400)
        )
    }

    func goToToday() async {
        clearSelectedTimeRange()
        selectedDay = calendar.startOfDay(for: nowProvider())
        await refreshCalendarDataIfPermitted()
    }

    func generatePlan() async {
        await generateSuggestions(for: .horizon(selectedPlanningHorizon))
    }

    func generatePlanForSelectedTimeRange() async {
        guard let selectedTimeRange else {
            return
        }

        await generateSuggestions(for: .selectedTimeRange(selectedTimeRange))
    }

    private func generateSuggestions(for requestWindow: PlannerRequestWindow) async {
        errorMessage = nil
        loadTasks()

        guard permissionStatus == .fullAccessGranted else {
            recordError("Grant full Calendar access before generating a plan.")
            return
        }

        do {
            let settings = try settingsRepository.loadSettings()
            let scheduledBlocks = try scheduledBlockRepository.fetchScheduledBlocks()
            let planningWindow = requestWindow.planningWindow(
                relativeTo: nowProvider(),
                calendar: calendar
            )
            let planningEvents = try await calendarReader.fetchEvents(in: planningWindow)
            let constraints = PlannerConstraints(
                planningWindow: planningWindow,
                now: nowProvider(),
                minimumGapMinutes: settings.minimumGapMinutes,
                defaultAssumedDurationMinutes: settings.defaultAssumedDurationMinutes,
                suggestionCap: settings.plannerSuggestionCap,
                priorityEmphasis: filterState.priorityEmphasis
            )
            let output = plannerEngine.makePlan(
                tasks: filteredTasks(),
                calendarEvents: planningEvents,
                scheduledBlocks: scheduledBlocks,
                constraints: constraints,
                rejectedSuggestions: rejectedSuggestionFingerprints
            )

            suggestionItems = output.suggestions.map { PlannerSuggestionItem(candidate: $0) }
            lastGeneratedRequestWindow = requestWindow
            self.scheduledBlocks = scheduledBlocks

            guard suggestionItems.isEmpty == false else {
                recordError(noSuggestionsMessage(for: requestWindow))
                return
            }

            if case .horizon = requestWindow,
                let firstSuggestion = suggestionItems.first {
                selectedTimeRange = nil
                selectedDay = calendar.startOfDay(for: firstSuggestion.interval.start)
                await refreshCalendarDataIfPermitted()
            }
        } catch {
            suggestionItems = []
            lastGeneratedRequestWindow = nil
            recordError("Unable to generate plan: \(error.localizedDescription)")
        }
    }

    func acceptSuggestion(withID id: UUID) async {
        guard let suggestionIndex = suggestionItems.firstIndex(where: { $0.id == id }) else {
            return
        }

        guard activeSuggestionOperationIDs.insert(id).inserted else {
            return
        }

        errorMessage = nil
        suggestionItems[suggestionIndex].decision = .accepted
        let suggestion = suggestionItems[suggestionIndex]

        defer {
            activeSuggestionOperationIDs.remove(id)
        }

        do {
            permissionStatus = calendarPermissionProvider.currentStatus()
            guard permissionStatus == .fullAccessGranted else {
                throw CalendarWriteError.fullAccessRequired(permissionStatus)
            }

            let writeCalendarTitle = try await calendarWriter.validateWriteCalendar()
            guard var task = try taskRepository.task(withID: suggestion.taskID) else {
                throw PlannerAcceptanceError.taskNotFound(suggestion.taskID)
            }

            let acceptedAt = nowProvider()
            var block = ScheduledBlock(
                taskID: suggestion.taskID,
                start: suggestion.interval.start,
                end: suggestion.interval.end,
                status: .accepted,
                calendarLinkState: .writePending,
                calendarTitle: writeCalendarTitle,
                createdAt: acceptedAt,
                updatedAt: acceptedAt
            )

            try scheduledBlockRepository.saveScheduledBlock(block, replacingBlockWithID: nil)

            let writeResult: CalendarWriteResult
            do {
                writeResult = try await calendarWriter.createEvent(for: block, task: task)
            } catch {
                try? scheduledBlockRepository.deleteScheduledBlock(withID: block.id)
                throw error
            }

            block.calendarLinkState = .linked
            block.calendarEventIdentifier = writeResult.eventIdentifier
            block.calendarTitle = writeResult.calendarTitle
            block.eventTitleSnapshot = writeResult.eventTitle
            block.updatedAt = writeResult.writtenAt
            block.lastSyncedAt = writeResult.writtenAt
            block.syncErrorMessage = nil

            do {
                try scheduledBlockRepository.saveScheduledBlock(
                    block,
                    replacingBlockWithID: block.id
                )
            } catch {
                try? await calendarWriter.deleteEvent(for: block)
                try? scheduledBlockRepository.deleteScheduledBlock(withID: block.id)
                throw error
            }

            var taskStatusWarning: String?
            if task.status != .scheduled || task.completedAt != nil {
                task.status = .scheduled
                task.updatedAt = writeResult.writtenAt
                task.completedAt = nil

                do {
                    try taskRepository.saveTask(task, replacingTaskWithID: task.id)
                } catch {
                    taskStatusWarning =
                        "Accepted block saved, but the task status could not be updated: \(error.localizedDescription)"
                }
            }

            clearTransientSuggestions()
            clearSelectedTimeRange()
            selectedDay = calendar.startOfDay(for: block.start)
            await refresh()

            if let taskStatusWarning {
                recordError(taskStatusWarning)
            }
        } catch {
            if let currentIndex = suggestionItems.firstIndex(where: { $0.id == id }) {
                suggestionItems[currentIndex].decision = .pending
            }

            recordError("Unable to accept suggestion: \(error.localizedDescription)")
        }
    }

    func editAcceptedBlock(
        withID id: UUID,
        start: Date,
        end: Date
    ) async {
        guard end > start else {
            recordError("Scheduled blocks must end after they start.")
            return
        }

        await updateAcceptedBlockInterval(
            withID: id,
            start: start,
            end: end,
            failurePrefix: "Unable to update scheduled block"
        )
    }

    func rescheduleAcceptedBlockToSelectedTimeRange(withID id: UUID) async {
        guard let selectedTimeRange else {
            recordError("Select an open slot before rescheduling a scheduled block.")
            return
        }

        await updateAcceptedBlockInterval(
            withID: id,
            start: selectedTimeRange.start,
            end: selectedTimeRange.end,
            failurePrefix: "Unable to reschedule scheduled block"
        )
    }

    func cancelAcceptedBlock(withID id: UUID) async {
        guard activeScheduledBlockOperationIDs.insert(id).inserted else {
            return
        }

        defer {
            activeScheduledBlockOperationIDs.remove(id)
        }

        errorMessage = nil

        do {
            permissionStatus = calendarPermissionProvider.currentStatus()
            guard permissionStatus == .fullAccessGranted else {
                throw CalendarWriteError.fullAccessRequired(permissionStatus)
            }

            guard let originalBlock = try currentScheduledBlock(withID: id) else {
                throw PlannerScheduledBlockLifecycleError.blockNotFound(id)
            }

            let syncDate = nowProvider()
            var canceledBlock = originalBlock
            canceledBlock.status = .canceled
            canceledBlock.calendarLinkState = .notWritten
            canceledBlock.calendarEventIdentifier = nil
            canceledBlock.updatedAt = syncDate
            canceledBlock.lastSyncedAt = syncDate
            canceledBlock.syncErrorMessage = nil

            try scheduledBlockRepository.saveScheduledBlock(
                canceledBlock,
                replacingBlockWithID: canceledBlock.id
            )

            do {
                try await deleteLinkedEventIfPresent(for: originalBlock)
            } catch {
                try? scheduledBlockRepository.saveScheduledBlock(
                    originalBlock,
                    replacingBlockWithID: originalBlock.id
                )
                throw error
            }

            try syncTaskSchedulingStatus(for: originalBlock.taskID, at: syncDate)
            clearTransientSuggestions()
            clearSelectedTimeRange()
            await refresh()
        } catch {
            recordError("Unable to cancel scheduled block: \(error.localizedDescription)")
        }
    }

    func deleteAcceptedBlock(withID id: UUID) async {
        guard activeScheduledBlockOperationIDs.insert(id).inserted else {
            return
        }

        defer {
            activeScheduledBlockOperationIDs.remove(id)
        }

        errorMessage = nil

        do {
            permissionStatus = calendarPermissionProvider.currentStatus()
            guard permissionStatus == .fullAccessGranted else {
                throw CalendarWriteError.fullAccessRequired(permissionStatus)
            }

            guard let block = try currentScheduledBlock(withID: id) else {
                throw PlannerScheduledBlockLifecycleError.blockNotFound(id)
            }

            try scheduledBlockRepository.deleteScheduledBlock(withID: block.id)

            do {
                try await deleteLinkedEventIfPresent(for: block)
            } catch {
                try? scheduledBlockRepository.saveScheduledBlock(
                    block,
                    replacingBlockWithID: nil
                )
                throw error
            }

            try syncTaskSchedulingStatus(for: block.taskID, at: nowProvider())
            clearTransientSuggestions()
            clearSelectedTimeRange()
            await refresh()
        } catch {
            recordError("Unable to delete scheduled block: \(error.localizedDescription)")
        }
    }

    func rejectSuggestion(withID id: UUID) {
        guard let rejectedSuggestion = suggestionItems.first(where: { $0.id == id }) else {
            return
        }

        rejectedSuggestionFingerprints.insert(rejectedSuggestion.candidate.fingerprint)
        suggestionItems.removeAll { $0.id == id }
    }

    func setSelectedTag(_ tag: String, isEnabled: Bool) {
        if isEnabled {
            filterState.selectedTags.insert(tag)
        } else {
            filterState.selectedTags.remove(tag)
        }
    }

    func updateSelectedTimeRange(_ selectedTimeRange: PlannerSelectedTimeRange?) {
        let didChangeSelection = self.selectedTimeRange != selectedTimeRange
        self.selectedTimeRange = selectedTimeRange

        if didChangeSelection {
            discardSelectedSlotSuggestionsIfNeeded()
        }
    }

    func clearSelectedTimeRange() {
        selectedTimeRange = nil
        discardSelectedSlotSuggestionsIfNeeded()
    }

    private func selectDay(_ day: Date) async {
        clearSelectedTimeRange()
        selectedDay = calendar.startOfDay(for: day)
        await refreshCalendarDataIfPermitted()
    }

    private func queueObservedCalendarStoreChangeRefresh() {
        guard isCalendarStoreObservationEnabled else {
            return
        }

        hasPendingObservedCalendarStoreChange = true

        guard isRefreshingObservedCalendarStoreChange == false else {
            return
        }

        Task { @MainActor [weak self] in
            await self?.drainObservedCalendarStoreChangeRefreshQueue()
        }
    }

    private func drainObservedCalendarStoreChangeRefreshQueue() async {
        guard isRefreshingObservedCalendarStoreChange == false else {
            return
        }

        isRefreshingObservedCalendarStoreChange = true
        defer {
            isRefreshingObservedCalendarStoreChange = false
        }

        while hasPendingObservedCalendarStoreChange {
            hasPendingObservedCalendarStoreChange = false

            guard isCalendarStoreObservationEnabled, hasLoaded else {
                continue
            }

            permissionStatus = calendarPermissionProvider.currentStatus()
            guard permissionStatus == .fullAccessGranted else {
                calendars = []
                calendarEvents = []
                continue
            }

            await refresh()
        }
    }

    private func refreshCalendarDataIfPermitted() async {
        guard permissionStatus == .fullAccessGranted else {
            return
        }

        await refreshCalendarData()
    }

    private func refreshCalendarData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let reconciliationReport =
                try await calendarReconciler?.reconcileScheduledBlocks() ?? .empty
            loadScheduledBlocks()
            loadTasks()
            calendars = try await calendarListingService.fetchReadableCalendars()
            try syncWriteCalendarSelectionIfNeeded(using: calendars)
            calendarEvents = try await calendarReader.fetchEvents(in: visibleDayInterval)
            applyReconciliationReport(reconciliationReport)
        } catch {
            calendars = []
            calendarEvents = []
            recordError(error.localizedDescription)
        }
    }

    private func loadSettings() {
        do {
            settings = try settingsRepository.loadSettings()
        } catch {
            settings = .mvpDefault
            recordError("Unable to load settings: \(error.localizedDescription)")
        }
    }

    private func loadTasks() {
        do {
            tasks = try taskRepository.fetchTasks()
        } catch {
            tasks = []
            recordError("Unable to load tasks: \(error.localizedDescription)")
        }
    }

    private func loadScheduledBlocks() {
        do {
            scheduledBlocks = try scheduledBlockRepository.fetchScheduledBlocks()
        } catch {
            scheduledBlocks = []
            recordError("Unable to load scheduled blocks: \(error.localizedDescription)")
        }
    }

    private func syncWriteCalendarSelectionIfNeeded(
        using calendars: [ReadableCalendar]
    ) throws {
        var updatedSettings = settings

        if updatedSettings.writeCalendarIdentifier.isEmpty {
            let matchingCalendars = calendars.filter { calendar in
                calendar.allowsContentModifications
                    && calendar.title == updatedSettings.writeCalendarTitle
            }

            if matchingCalendars.count == 1 {
                updatedSettings.writeCalendarIdentifier = matchingCalendars[0].id
                updatedSettings.writeCalendarTitle = matchingCalendars[0].title
            }
        } else if let selectedCalendar = calendars.first(where: {
            $0.id == updatedSettings.writeCalendarIdentifier
        }) {
            updatedSettings.writeCalendarTitle = selectedCalendar.title
        }

        guard updatedSettings != settings else {
            return
        }

        try settingsRepository.saveSettings(updatedSettings)
        settings = updatedSettings
    }

    private func currentScheduledBlock(withID id: UUID) throws -> ScheduledBlock? {
        try scheduledBlockRepository.fetchScheduledBlocks().first { $0.id == id }
    }

    private func updateAcceptedBlockInterval(
        withID id: UUID,
        start: Date,
        end: Date,
        failurePrefix: String
    ) async {
        guard activeScheduledBlockOperationIDs.insert(id).inserted else {
            return
        }

        defer {
            activeScheduledBlockOperationIDs.remove(id)
        }

        errorMessage = nil

        do {
            permissionStatus = calendarPermissionProvider.currentStatus()
            guard permissionStatus == .fullAccessGranted else {
                throw CalendarWriteError.fullAccessRequired(permissionStatus)
            }

            guard let originalBlock = try currentScheduledBlock(withID: id) else {
                throw PlannerScheduledBlockLifecycleError.blockNotFound(id)
            }

            guard let task = try taskRepository.task(withID: originalBlock.taskID) else {
                throw PlannerAcceptanceError.taskNotFound(originalBlock.taskID)
            }

            var updatedBlock = originalBlock
            updatedBlock.start = start
            updatedBlock.end = end
            updatedBlock.updatedAt = nowProvider()

            let writeResult = try await calendarWriter.updateEvent(for: updatedBlock, task: task)
            updatedBlock.calendarLinkState = .linked
            updatedBlock.calendarEventIdentifier = writeResult.eventIdentifier
            updatedBlock.calendarTitle = writeResult.calendarTitle
            updatedBlock.eventTitleSnapshot = writeResult.eventTitle
            updatedBlock.updatedAt = writeResult.writtenAt
            updatedBlock.lastSyncedAt = writeResult.writtenAt
            updatedBlock.syncErrorMessage = nil

            do {
                try scheduledBlockRepository.saveScheduledBlock(
                    updatedBlock,
                    replacingBlockWithID: updatedBlock.id
                )
            } catch {
                _ = try? await calendarWriter.updateEvent(for: originalBlock, task: task)
                throw error
            }

            clearTransientSuggestions()
            clearSelectedTimeRange()
            selectedDay = calendar.startOfDay(for: updatedBlock.start)
            await refresh()
        } catch {
            recordError("\(failurePrefix): \(error.localizedDescription)")
        }
    }

    private func deleteLinkedEventIfPresent(for block: ScheduledBlock) async throws {
        guard normalizedEventIdentifier(from: block) != nil else {
            return
        }

        do {
            try await calendarWriter.deleteEvent(for: block)
        } catch CalendarWriteError.missingLinkedEventIdentifier {
            return
        }
    }

    private func normalizedEventIdentifier(from block: ScheduledBlock) -> String? {
        let identifier = block.calendarEventIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let identifier, identifier.isEmpty == false else {
            return nil
        }

        return identifier
    }

    private func syncTaskSchedulingStatus(
        for taskID: UUID,
        at date: Date
    ) throws {
        guard var task = try taskRepository.task(withID: taskID) else {
            return
        }

        let scheduledBlocks = try scheduledBlockRepository.fetchScheduledBlocks(for: taskID)
        let hasActiveBlock = scheduledBlocks.contains(where: \.isActivelyScheduled)

        if hasActiveBlock {
            guard task.status != .scheduled || task.completedAt != nil else {
                return
            }

            task.status = .scheduled
            task.completedAt = nil
            task.updatedAt = date
            try taskRepository.saveTask(task, replacingTaskWithID: task.id)
            return
        }

        guard task.status == .scheduled else {
            return
        }

        task.status = .active
        task.updatedAt = date
        try taskRepository.saveTask(task, replacingTaskWithID: task.id)
    }

    private func clearTransientSuggestions() {
        suggestionItems = []
        lastGeneratedRequestWindow = nil
    }

    private func discardSelectedSlotSuggestionsIfNeeded() {
        guard case .selectedTimeRange = lastGeneratedRequestWindow else {
            return
        }

        clearTransientSuggestions()
        errorMessage = nil
    }

    private func applyReconciliationReport(_ report: ReconciliationReport) {
        reconciliationNotice = report.summaryText

        guard report.hasMaterialChanges else {
            return
        }

        clearTransientSuggestions()
    }

    private func filteredTasks() -> [MyTask] {
        tasks.filter { task in
            if let selectedWorkMode = filterState.workMode, task.workMode != selectedWorkMode {
                return false
            }

            if filterState.selectedTags.isEmpty == false
                && Set(task.tags).isDisjoint(with: filterState.selectedTags) {
                return false
            }

            return true
        }
    }

    private func noSuggestionsMessage(for requestWindow: PlannerRequestWindow) -> String {
        switch requestWindow {
        case .selectedTimeRange:
            return "No suggestions fit the selected slot and filters."
        case .horizon:
            return "No suggestions fit the selected planning window and filters."
        }
    }

    private func recordError(_ message: String) {
        guard message.isEmpty == false else {
            return
        }

        if let errorMessage, errorMessage.isEmpty == false {
            self.errorMessage = "\(errorMessage)\n\(message)"
        } else {
            errorMessage = message
        }
    }

    private func taskTitle(for block: ScheduledBlock) -> String {
        if let task = tasks.first(where: { $0.id == block.taskID }) {
            return task.title
        }

        if let eventTitleSnapshot = block.eventTitleSnapshot,
            eventTitleSnapshot.isEmpty == false {
            return eventTitleSnapshot
        }

        return "Scheduled Task"
    }
}

private enum PlannerAcceptanceError: LocalizedError {
    case taskNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .taskNotFound(let taskID):
            return "The task for suggestion \(taskID.uuidString) could not be found."
        }
    }
}

private enum PlannerScheduledBlockLifecycleError: LocalizedError {
    case blockNotFound(UUID)

    var errorDescription: String? {
        switch self {
        case .blockNotFound(let blockID):
            return "The scheduled block \(blockID.uuidString) could not be found."
        }
    }
}

private extension ReconciliationReport {
    var hasMaterialChanges: Bool {
        movedBlockCount > 0 || deletedBlockCount > 0 || issues.isEmpty == false
    }

    var summaryText: String? {
        var parts: [String] = []

        if movedBlockCount > 0 {
            parts.append(
                movedBlockCount == 1
                    ? "1 accepted block was updated from Calendar changes."
                    : "\(movedBlockCount) accepted blocks were updated from Calendar changes."
            )
        }

        if deletedBlockCount > 0 {
            parts.append(
                deletedBlockCount == 1
                    ? "1 linked block was deleted outside the app."
                    : "\(deletedBlockCount) linked blocks were deleted outside the app."
            )
        }

        if issues.isEmpty == false {
            parts.append(
                issues.count == 1
                    ? "1 block needs manual review."
                    : "\(issues.count) blocks need manual review."
            )
        }

        guard parts.isEmpty == false else {
            return nil
        }

        return parts.joined(separator: "\n")
    }
}

private extension DateInterval {
    func overlaps(_ other: DateInterval) -> Bool {
        end > other.start && start < other.end
    }
}
