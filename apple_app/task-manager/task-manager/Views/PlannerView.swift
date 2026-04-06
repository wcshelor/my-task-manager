import SwiftUI

struct PlannerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: PlannerViewModel
    @State private var isHorizonPlanSheetPresented = false
    @State private var scheduledBlockEditDraft: PlannerScheduledBlockEditDraft?
    @State private var scheduledBlockAlert: PlannerScheduledBlockAlert?

    init(
        taskRepository: any TaskRepository,
        scheduledBlockRepository: any ScheduledBlockRepository,
        settingsRepository: any SettingsRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing,
        calendarReader: any CalendarReading,
        calendarWriter: any CalendarWriting,
        calendarReconciler: any CalendarReconciling
    ) {
        _viewModel = StateObject(
            wrappedValue: PlannerViewModel(
                taskRepository: taskRepository,
                scheduledBlockRepository: scheduledBlockRepository,
                settingsRepository: settingsRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarListingService: calendarListingService,
                calendarReader: calendarReader,
                calendarWriter: calendarWriter,
                calendarReconciler: calendarReconciler
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PlannerOverviewCard(
                        permissionStatus: viewModel.permissionStatus,
                        readableCalendarCount: viewModel.calendars.count,
                        selectedDay: viewModel.selectedDay,
                        visibleDayInterval: viewModel.visibleDayInterval,
                        activePlanningRequestWindow: viewModel.activePlanningRequestWindow,
                        activePlanningWindow: viewModel.selectedPlanningWindow,
                        filterState: viewModel.filterState,
                        suggestionCount: viewModel.suggestionItems.count,
                        isLoading: viewModel.isLoading,
                        onRequestAccess: {
                            Task {
                                await viewModel.requestCalendarAccess()
                            }
                        },
                        onRefresh: {
                            Task {
                                await viewModel.refresh()
                            }
                        },
                        onGeneratePlan: {
                            isHorizonPlanSheetPresented = true
                        }
                    )

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let reconciliationNotice = viewModel.reconciliationNotice {
                        Text(reconciliationNotice)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PlannerDayNavigationCard(
                        selectedDay: viewModel.selectedDay,
                        onPreviousDay: {
                            Task {
                                await viewModel.goToPreviousDay()
                            }
                        },
                        onToday: {
                            Task {
                                await viewModel.goToToday()
                            }
                        },
                        onNextDay: {
                            Task {
                                await viewModel.goToNextDay()
                            }
                        }
                    )

                    PlannerDayCalendarSection(
                        permissionStatus: viewModel.permissionStatus,
                        isLoading: viewModel.isLoading,
                        selectedDay: viewModel.selectedDay,
                        calendar: viewModel.timelineCalendar,
                        visibleDayInterval: viewModel.visibleDayInterval,
                        timelineEntries: viewModel.timelineEntries,
                        selectedTimeRange: viewModel.selectedTimeRange,
                        selectedSlotSuggestionItems: viewModel.selectedSlotSuggestionItems,
                        activeSuggestionOperationIDs: viewModel.activeSuggestionOperationIDs,
                        onSelectionChange: { selection in
                            viewModel.updateSelectedTimeRange(selection)
                        },
                        onClearSelection: {
                            viewModel.clearSelectedTimeRange()
                        },
                        onAcceptSuggestion: { suggestionID in
                            Task {
                                await viewModel.acceptSuggestion(withID: suggestionID)
                            }
                        },
                        onRejectSuggestion: { suggestionID in
                            viewModel.rejectSuggestion(withID: suggestionID)
                        }
                    )

                    if let selectedTimeRange = viewModel.selectedTimeRange {
                        PlannerSlotPlanningCard(
                            viewModel: viewModel,
                            selectedTimeRange: selectedTimeRange,
                            suggestionItems: viewModel.selectedSlotSuggestionItems,
                            hasGeneratedSuggestions: viewModel.hasGeneratedSuggestionsForSelectedTimeRange,
                            activeSuggestionOperationIDs: viewModel.activeSuggestionOperationIDs,
                            onGenerateSuggestions: {
                                Task {
                                    await viewModel.generatePlanForSelectedTimeRange()
                                }
                            },
                            onClearSelection: {
                                viewModel.clearSelectedTimeRange()
                            },
                            onAcceptSuggestion: { suggestionID in
                                Task {
                                    await viewModel.acceptSuggestion(withID: suggestionID)
                                }
                            },
                            onRejectSuggestion: { suggestionID in
                                viewModel.rejectSuggestion(withID: suggestionID)
                            }
                        )
                    }

                    PlannerTimelineSection(
                        permissionStatus: viewModel.permissionStatus,
                        isLoading: viewModel.isLoading,
                        timelineEntries: viewModel.timelineEntries,
                        activeSuggestionOperationIDs: viewModel.activeSuggestionOperationIDs,
                        activeScheduledBlockOperationIDs: viewModel.activeScheduledBlockOperationIDs,
                        selectedTimeRange: viewModel.selectedTimeRange,
                        onAcceptSuggestion: { suggestionID in
                            Task {
                                await viewModel.acceptSuggestion(withID: suggestionID)
                            }
                        },
                        onRejectSuggestion: { suggestionID in
                            viewModel.rejectSuggestion(withID: suggestionID)
                        },
                        onEditScheduledBlock: { blockID in
                            scheduledBlockEditDraft = makeScheduledBlockEditDraft(for: blockID)
                        },
                        onRescheduleScheduledBlock: { blockID in
                            Task {
                                await viewModel.rescheduleAcceptedBlockToSelectedTimeRange(withID: blockID)
                            }
                        },
                        onCancelScheduledBlock: { blockID in
                            scheduledBlockAlert = PlannerScheduledBlockAlert(
                                blockID: blockID,
                                action: .cancel
                            )
                        },
                        onDeleteScheduledBlock: { blockID in
                            scheduledBlockAlert = PlannerScheduledBlockAlert(
                                blockID: blockID,
                                action: .delete
                            )
                        }
                    )
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Planner")
        }
        .sheet(isPresented: $isHorizonPlanSheetPresented) {
            HorizonPlanSheet(viewModel: viewModel)
        }
        .sheet(item: $scheduledBlockEditDraft) { draft in
            PlannerScheduledBlockEditSheet(
                draft: draft,
                isSaving: viewModel.activeScheduledBlockOperationIDs.contains(draft.blockID),
                onSave: { updatedDraft in
                    scheduledBlockEditDraft = nil
                    Task {
                        await viewModel.editAcceptedBlock(
                            withID: updatedDraft.blockID,
                            start: updatedDraft.start,
                            end: updatedDraft.end
                        )
                    }
                },
                onCancel: {
                    scheduledBlockEditDraft = nil
                }
            )
        }
        .alert(item: $scheduledBlockAlert) { alert in
            switch alert.action {
            case .cancel:
                return Alert(
                    title: Text("Cancel Scheduled Block?"),
                    message: Text("This removes the linked calendar event and keeps the block as canceled history."),
                    primaryButton: .destructive(Text("Cancel Block")) {
                        Task {
                            await viewModel.cancelAcceptedBlock(withID: alert.blockID)
                        }
                    },
                    secondaryButton: .cancel()
                )
            case .delete:
                return Alert(
                    title: Text("Delete Scheduled Block?"),
                    message: Text("This removes the linked calendar event and deletes the block record."),
                    primaryButton: .destructive(Text("Delete Block")) {
                        Task {
                            await viewModel.deleteAcceptedBlock(withID: alert.blockID)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await viewModel.handleSceneDidBecomeActive()
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private func makeScheduledBlockEditDraft(
        for blockID: UUID
    ) -> PlannerScheduledBlockEditDraft? {
        guard let block = viewModel.scheduledBlocks.first(where: { $0.id == blockID }) else {
            return nil
        }

        return PlannerScheduledBlockEditDraft(
            blockID: block.id,
            title: viewModel.visibleScheduledBlockItems.first(where: { $0.block.id == blockID })?.taskTitle
                ?? "Scheduled Task",
            originalInterval: block.interval,
            start: block.start,
            end: block.end
        )
    }
}

private struct PlannerOverviewCard: View {
    let permissionStatus: CalendarPermissionStatus
    let readableCalendarCount: Int
    let selectedDay: Date
    let visibleDayInterval: DateInterval
    let activePlanningRequestWindow: PlannerRequestWindow
    let activePlanningWindow: DateInterval
    let filterState: PlannerFilterState
    let suggestionCount: Int
    let isLoading: Bool
    let onRequestAccess: () -> Void
    let onRefresh: () -> Void
    let onGeneratePlan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendar Planner")
                        .font(.title2.weight(.semibold))

                    Text(permissionStatus.detailText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(permissionStatus.displayTitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(permissionStatus.tintColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(permissionStatus.tintColor.opacity(0.12), in: Capsule())
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    PlannerMetricLabel("Visible Day")
                    Text(selectedDay.formatted(date: .complete, time: .omitted))
                }

                GridRow {
                    PlannerMetricLabel("Visible Period")
                    Text(visibleDayInterval.dayLabel)
                }

                GridRow {
                    PlannerMetricLabel("Plan Target")
                    Text("\(activePlanningRequestWindow.title) • \(activePlanningWindow.planningLabel)")
                }

                GridRow {
                    PlannerMetricLabel("Filters")
                    Text(filterState.summaryText)
                }

                GridRow {
                    PlannerMetricLabel("Calendars")
                    Text(
                        permissionStatus == .fullAccessGranted
                        ? "\(readableCalendarCount) readable"
                        : "Waiting for access"
                    )
                }

                GridRow {
                    PlannerMetricLabel("Draft Suggestions")
                    Text(suggestionCount == 0 ? "None yet" : "\(suggestionCount) in memory")
                }
            }

            HStack(spacing: 12) {
                Button("Plan by Horizon") {
                    onGeneratePlan()
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)

                Button("Request Calendar Access") {
                    onRequestAccess()
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || permissionStatus == .fullAccessGranted)

                Button("Refresh") {
                    onRefresh()
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }

            Text(planningHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var planningHint: String {
        switch activePlanningRequestWindow {
        case .selectedTimeRange:
            return "Selected-slot planning is active below. Use the secondary horizon flow when you want broader suggestions."
        case .horizon(let horizon):
            return "Primary flow: drag across open time in the day timeline, then fill that slot. Horizon planning is still available for \(horizon.title.lowercased())."
        }
    }
}

private struct PlannerMetricLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.callout.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

private struct PlannerDayNavigationCard: View {
    let selectedDay: Date
    let onPreviousDay: () -> Void
    let onToday: () -> Void
    let onNextDay: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Day Timeline")
                    .font(.headline)

                Text(selectedDay.formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: onPreviousDay) {
                    Label("Previous Day", systemImage: "chevron.left")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)

                Button("Today", action: onToday)
                    .buttonStyle(.bordered)

                Button(action: onNextDay) {
                    Label("Next Day", systemImage: "chevron.right")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct PlannerDayCalendarSection: View {
    let permissionStatus: CalendarPermissionStatus
    let isLoading: Bool
    let selectedDay: Date
    let calendar: Calendar
    let visibleDayInterval: DateInterval
    let timelineEntries: [PlannerTimelineEntry]
    let selectedTimeRange: PlannerSelectedTimeRange?
    let selectedSlotSuggestionItems: [PlannerSuggestionItem]
    let activeSuggestionOperationIDs: Set<UUID>
    let onSelectionChange: (PlannerSelectedTimeRange?) -> Void
    let onClearSelection: () -> Void
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    @State private var activeSelectionAnchor: CGPoint?

    private let timelineMetrics = PlannerDayTimelineMetrics()

    private var layout: PlannerDayCalendarLayout {
        PlannerDayCalendarLayout(
            dayInterval: visibleDayInterval,
            entries: timelineEntries
        )
    }

    private var shouldShowSelectionOverlay: Bool {
        guard selectedTimeRange != nil else {
            return false
        }

        return selectedSlotSuggestionItems.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Calendar")
                    .font(.headline)

                Spacer()

                if let selectedTimeRange {
                    Text("Fill \(selectedTimeRange.interval.timelineLabel)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12), in: Capsule())

                    Button("Clear", action: onClearSelection)
                        .buttonStyle(.borderless)
                        .font(.caption)
                } else {
                    Text("Drag across open time to plan a slot")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Updating day calendar…")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if permissionStatus != .fullAccessGranted {
                ContentUnavailableView(
                    "Calendar Access Required",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Grant full Calendar access to render busy time and generated suggestions in the day calendar.")
                )
                .frame(maxWidth: .infinity)
            } else {
                if layout.allDayEntries.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All Day")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        ForEach(layout.allDayEntries, id: \.id) { entry in
                            PlannerAllDayEntryChip(entry: entry)
                        }
                    }
                }

                GeometryReader { geometry in
                    let contentSize = CGSize(
                        width: geometry.size.width,
                        height: timelineMetrics.totalHeight
                    )

                    ScrollView(.vertical, showsIndicators: true) {
                        dayCalendarCanvas(totalWidth: contentSize.width)
                            .frame(
                                width: contentSize.width,
                                height: contentSize.height,
                                alignment: .topLeading
                            )
                    }
                }
                .frame(height: min(timelineMetrics.totalHeight, 520))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.2), value: timelineEntries.map(\.id))
                .animation(.easeInOut(duration: 0.15), value: selectedTimeRange)
            }
        }
    }

    private var occupiedIntervals: [DateInterval] {
        timelineEntries
            .filter { $0.isAllDay == false }
            .map { DateInterval(start: $0.start, end: $0.end) }
    }

    private func dayCalendarCanvas(totalWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            dayGridBackground(totalWidth: totalWidth)

            Color.clear
                .frame(width: totalWidth, height: timelineMetrics.totalHeight)
                .contentShape(Rectangle())
                .gesture(
                    selectionGesture(
                        in: CGSize(
                            width: totalWidth,
                            height: timelineMetrics.totalHeight
                        )
                    )
                )

            if let selectedTimeRange, shouldShowSelectionOverlay {
                let metrics = selectionMetrics(
                    for: selectedTimeRange,
                    totalWidth: totalWidth
                )

                PlannerDaySelectionBlock(selectedTimeRange: selectedTimeRange)
                    .frame(width: metrics.width, height: metrics.height)
                    .offset(x: metrics.x, y: metrics.y)
                    .allowsHitTesting(false)
            }

            ForEach(layout.timedEntries) { item in
                let metrics = blockMetrics(
                    for: item,
                    totalWidth: totalWidth
                )

                PlannerDayCalendarBlock(
                    entry: item.entry,
                    isProcessingSuggestion: item.entry.suggestionID.map(activeSuggestionOperationIDs.contains) ?? false,
                    onAcceptSuggestion: onAcceptSuggestion,
                    onRejectSuggestion: onRejectSuggestion
                )
                    .frame(width: metrics.width, height: metrics.height)
                    .offset(x: metrics.x, y: metrics.y)
            }
        }
    }

    private func selectionGesture(in contentSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if activeSelectionAnchor == nil {
                    activeSelectionAnchor = value.startLocation
                }

                guard let anchorPoint = activeSelectionAnchor else {
                    return
                }

                let selection = PlannerTimelineGrid.selectedRange(
                    anchorPoint: anchorPoint,
                    currentPoint: value.location,
                    in: contentSize,
                    metrics: timelineMetrics,
                    day: selectedDay,
                    calendar: calendar,
                    occupiedIntervals: occupiedIntervals
                )
                onSelectionChange(selection)
            }
            .onEnded { value in
                defer {
                    activeSelectionAnchor = nil
                }

                guard let anchorPoint = activeSelectionAnchor else {
                    return
                }

                let selection = PlannerTimelineGrid.selectedRange(
                    anchorPoint: anchorPoint,
                    currentPoint: value.location,
                    in: contentSize,
                    metrics: timelineMetrics,
                    day: selectedDay,
                    calendar: calendar,
                    occupiedIntervals: occupiedIntervals
                )
                onSelectionChange(selection)
            }
    }

    private func dayGridBackground(totalWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color.primary.opacity(0.025),
                    Color.primary.opacity(0.045)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 1, height: timelineMetrics.timedAreaHeight)
                .offset(x: timelineMetrics.contentStartX - 6, y: timelineMetrics.topInset)

            ForEach(0...PlannerTimelineGrid.slotsPerDay, id: \.self) { slotBoundary in
                Rectangle()
                    .fill(slotBoundary.isMultiple(of: PlannerTimelineGrid.slotsPerHour)
                        ? Color.primary.opacity(0.12)
                        : Color.primary.opacity(0.05))
                    .frame(
                        width: max(totalWidth - timelineMetrics.contentStartX, 0),
                        height: slotBoundary.isMultiple(of: PlannerTimelineGrid.slotsPerHour) ? 1 : 0.5
                    )
                    .offset(
                        x: timelineMetrics.contentStartX,
                        y: timelineMetrics.topInset + CGFloat(slotBoundary) * timelineMetrics.slotHeight
                    )
            }

            ForEach(0..<24, id: \.self) { hour in
                Text(hourLabel(for: hour))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: timelineMetrics.timeColumnWidth, alignment: .trailing)
                    .offset(
                        x: 0,
                        y: timelineMetrics.topInset + CGFloat(hour) * timelineMetrics.hourHeight - 7
                    )
            }
        }
    }

    private func hourLabel(for hour: Int) -> String {
        let normalizedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let meridiem = hour < 12 ? "AM" : "PM"
        return "\(normalizedHour) \(meridiem)"
    }

    private func blockMetrics(
        for item: PlannerDayCalendarLayoutItem,
        totalWidth: CGFloat
    ) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let usableWidth = max(totalWidth - timelineMetrics.timeColumnWidth - 16, 0)
        let laneCount = max(item.laneCount, 1)
        let columnWidth = max(
            (usableWidth - (CGFloat(laneCount - 1) * timelineMetrics.laneSpacing)) / CGFloat(laneCount),
            0
        )
        let dayStart = visibleDayInterval.start
        let minutesFromStart = max(item.entry.start.timeIntervalSince(dayStart) / 60, 0)
        let durationMinutes = max(item.entry.end.timeIntervalSince(item.entry.start) / 60, 0)

        return (
            x: timelineMetrics.timeColumnWidth + timelineMetrics.contentLeadingInset
                + CGFloat(item.laneIndex) * (columnWidth + timelineMetrics.laneSpacing),
            y: timelineMetrics.topInset + CGFloat(minutesFromStart / 60) * timelineMetrics.hourHeight,
            width: columnWidth,
            height: max(CGFloat(durationMinutes / 60) * timelineMetrics.hourHeight, 28)
        )
    }

    private func selectionMetrics(
        for selectedTimeRange: PlannerSelectedTimeRange,
        totalWidth: CGFloat
    ) -> (x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let startSlotIndex = PlannerTimelineGrid.slotIndex(
            for: selectedTimeRange.start,
            on: selectedDay,
            calendar: calendar
        )
        let slotCount = max(selectedTimeRange.durationMinutes / PlannerTimelineGrid.slotMinutes, 1)

        return (
            x: timelineMetrics.contentStartX + 2,
            y: timelineMetrics.topInset + CGFloat(startSlotIndex) * timelineMetrics.slotHeight,
            width: max(totalWidth - timelineMetrics.contentStartX - 4, 0),
            height: CGFloat(slotCount) * timelineMetrics.slotHeight
        )
    }
}

private struct PlannerTimelineSection: View {
    let permissionStatus: CalendarPermissionStatus
    let isLoading: Bool
    let timelineEntries: [PlannerTimelineEntry]
    let activeSuggestionOperationIDs: Set<UUID>
    let activeScheduledBlockOperationIDs: Set<UUID>
    let selectedTimeRange: PlannerSelectedTimeRange?
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void
    let onEditScheduledBlock: (UUID) -> Void
    let onRescheduleScheduledBlock: (UUID) -> Void
    let onCancelScheduledBlock: (UUID) -> Void
    let onDeleteScheduledBlock: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agenda")
                .font(.headline)

            if isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading calendar events…")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if permissionStatus != .fullAccessGranted {
                ContentUnavailableView(
                    "Calendar Access Required",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Grant full Calendar access to load busy time into the planner.")
                )
                .frame(maxWidth: .infinity)
            } else if timelineEntries.isEmpty {
                ContentUnavailableView(
                    "No Events or Suggestions",
                    systemImage: "calendar",
                    description: Text("This day is currently open. Select a time range to fill a slot, or use the secondary horizon planner.")
                )
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(timelineEntries) { entry in
                        PlannerTimelineRow(
                            entry: entry,
                            isProcessingSuggestion: entry.suggestionID.map(activeSuggestionOperationIDs.contains) ?? false,
                            isProcessingScheduledBlock: entry.scheduledBlockID.map(activeScheduledBlockOperationIDs.contains) ?? false,
                            selectedTimeRange: selectedTimeRange,
                            onAcceptSuggestion: onAcceptSuggestion,
                            onRejectSuggestion: onRejectSuggestion,
                            onEditScheduledBlock: onEditScheduledBlock,
                            onRescheduleScheduledBlock: onRescheduleScheduledBlock,
                            onCancelScheduledBlock: onCancelScheduledBlock,
                            onDeleteScheduledBlock: onDeleteScheduledBlock
                        )
                    }
                }
            }
        }
    }
}

private struct PlannerAllDayEntryChip: View {
    let entry: PlannerTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.dayCalendarTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(entry.dayCalendarBadge)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(entry.dayCalendarTint.opacity(0.14), in: Capsule())
            }

            Text(entry.dayCalendarSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(entry.dayCalendarTint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PlannerTimelineRow: View {
    let entry: PlannerTimelineEntry
    let isProcessingSuggestion: Bool
    let isProcessingScheduledBlock: Bool
    let selectedTimeRange: PlannerSelectedTimeRange?
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void
    let onEditScheduledBlock: (UUID) -> Void
    let onRescheduleScheduledBlock: (UUID) -> Void
    let onCancelScheduledBlock: (UUID) -> Void
    let onDeleteScheduledBlock: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(primaryTimeLabel)
                    .font(.subheadline.weight(.medium))

                if let secondaryTimeLabel {
                    Text(secondaryTimeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 84, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 4)

            entryContent
        }
    }

    @ViewBuilder
    private var entryContent: some View {
        switch entry {
        case .calendarEvent(let event):
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(event.title)
                        .font(.headline)

                    Spacer()

                    Text(event.calendarTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }

                Text(event.timelineLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(entry.rowTint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

        case .scheduledBlock(let block):
            PlannerScheduledBlockCard(
                block: block,
                selectedTimeRange: selectedTimeRange,
                isProcessing: isProcessingScheduledBlock,
                onEdit: onEditScheduledBlock,
                onReschedule: onRescheduleScheduledBlock,
                onCancel: onCancelScheduledBlock,
                onDelete: onDeleteScheduledBlock
            )

        case .suggestion(let suggestion):
            PlannerSuggestionCard(
                suggestion: suggestion,
                isProcessingSuggestion: isProcessingSuggestion,
                onAcceptSuggestion: onAcceptSuggestion,
                onRejectSuggestion: onRejectSuggestion
            )
        }
    }

    private var primaryTimeLabel: String {
        switch entry {
        case .calendarEvent(let event):
            return event.isAllDay ? "All Day" : event.start.formatted(date: .omitted, time: .shortened)
        case .scheduledBlock(let block):
            return block.interval.start.formatted(date: .omitted, time: .shortened)
        case .suggestion(let suggestion):
            return suggestion.interval.start.formatted(date: .omitted, time: .shortened)
        }
    }

    private var secondaryTimeLabel: String? {
        switch entry {
        case .calendarEvent(let event):
            return event.isAllDay ? nil : event.end.formatted(date: .omitted, time: .shortened)
        case .scheduledBlock(let block):
            return block.interval.end.formatted(date: .omitted, time: .shortened)
        case .suggestion(let suggestion):
            return suggestion.interval.end.formatted(date: .omitted, time: .shortened)
        }
    }

    private var accentColor: Color {
        entry.rowTint
    }
}

private struct PlannerDayCalendarBlock: View {
    let entry: PlannerTimelineEntry
    let isProcessingSuggestion: Bool
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.dayCalendarTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)

                Text(entry.dayCalendarTimeRange)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(entry.dayCalendarBadge)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(entry.dayCalendarTint.opacity(0.16), in: Capsule())
                    .fixedSize()

                Spacer(minLength: 0)
            }
            .padding(.trailing, suggestionID == nil ? 0 : 52)

            if let suggestionID {
                PlannerSuggestionInlineActionStrip(
                    suggestionID: suggestionID,
                    isProcessing: isProcessingSuggestion,
                    onAcceptSuggestion: onAcceptSuggestion,
                    onRejectSuggestion: onRejectSuggestion
                )
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(entry.dayCalendarFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(entry.dayCalendarStroke, lineWidth: 1)
        )
    }

    private var suggestionID: UUID? {
        entry.suggestionID
    }
}

private struct PlannerDaySelectionBlock: View {
    let selectedTimeRange: PlannerSelectedTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.orange)

            Text(selectedTimeRange.interval.timelineLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
        )
    }
}

private struct PlannerSlotPlanningCard: View {
    @ObservedObject var viewModel: PlannerViewModel
    let selectedTimeRange: PlannerSelectedTimeRange
    let suggestionItems: [PlannerSuggestionItem]
    let hasGeneratedSuggestions: Bool
    let activeSuggestionOperationIDs: Set<UUID>
    let onGenerateSuggestions: () -> Void
    let onClearSelection: () -> Void
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fill \(selectedTimeRange.interval.timelineLabel)")
                        .font(.headline)

                    Text("\(selectedTimeRange.durationMinutes) minutes available")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clear", action: onClearSelection)
                    .buttonStyle(.borderless)
                    .font(.caption)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Work Mode")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Picker("Work Mode", selection: selectedWorkModeBinding) {
                        Text("Any").tag(nil as WorkModeKind?)

                        ForEach(viewModel.availableWorkModes, id: \.self) { workMode in
                            Text(workMode.displayName).tag(Optional(workMode))
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Priority")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    Picker("Priority Emphasis", selection: selectedPriorityEmphasisBinding) {
                        ForEach(PlannerPriorityEmphasis.allCases) { emphasis in
                            Text(emphasis.title).tag(emphasis)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Spacer()

                Button("Get Suggestions", action: onGenerateSuggestions)
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isLoading || viewModel.permissionStatus != .fullAccessGranted)
            }

            if viewModel.availableTags.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.availableTags, id: \.self) { tag in
                                PlannerFilterTagChip(
                                    title: tag,
                                    isSelected: viewModel.filterState.selectedTags.contains(tag)
                                ) {
                                    let isEnabled = viewModel.filterState.selectedTags.contains(tag) == false
                                    viewModel.setSelectedTag(tag, isEnabled: isEnabled)
                                }
                            }
                        }
                    }
                }
            }

            Text(slotStatusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if hasGeneratedSuggestions {
                if suggestionItems.isEmpty {
                    Text("No suggestions fit this selected slot with the current filters.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(suggestionItems.count == 1 ? "Suggestion" : "Suggestions")
                            .font(.subheadline.weight(.medium))

                        ForEach(suggestionItems) { suggestion in
                            PlannerSuggestionCard(
                                suggestion: suggestion,
                                isProcessingSuggestion: activeSuggestionOperationIDs.contains(suggestion.id),
                                onAcceptSuggestion: onAcceptSuggestion,
                                onRejectSuggestion: onRejectSuggestion
                            )
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private var selectedWorkModeBinding: Binding<WorkModeKind?> {
        Binding {
            viewModel.filterState.workMode
        } set: { workMode in
            viewModel.filterState.workMode = workMode
        }
    }

    private var selectedPriorityEmphasisBinding: Binding<PlannerPriorityEmphasis> {
        Binding {
            viewModel.filterState.priorityEmphasis
        } set: { emphasis in
            viewModel.filterState.priorityEmphasis = emphasis
        }
    }

    private var slotStatusText: String {
        if hasGeneratedSuggestions {
            return "Suggestions stay inside this exact \(selectedTimeRange.interval.timelineLabel) window and continue to use the current planner fit rules. Accept or reject them inline on the calendar or from the list below."
        }

        return "Select the slot first, add light constraints second, then ask the planner to fill exactly this window."
    }
}

private struct PlannerScheduledBlockCard: View {
    let block: PlannerScheduledBlockItem
    let selectedTimeRange: PlannerSelectedTimeRange?
    let isProcessing: Bool
    let onEdit: (UUID) -> Void
    let onReschedule: (UUID) -> Void
    let onCancel: (UUID) -> Void
    let onDelete: (UUID) -> Void

    private var canRescheduleToSelection: Bool {
        guard let selectedTimeRange else {
            return false
        }

        return selectedTimeRange.interval != block.interval
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(block.taskTitle)
                    .font(.headline)

                Spacer()

                Text(block.block.linkStateBadgeTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(block.block.linkStateTint.opacity(0.14), in: Capsule())
            }

            Text(block.interval.timelineLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let stateMessage = block.block.linkStateMessage {
                Text(stateMessage)
                    .font(.caption)
                    .foregroundStyle(block.block.linkStateTint)
            }

            ViewThatFits {
                HStack(spacing: 10) {
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 8) {
                    actionButtons
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(block.block.linkStateTint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button("Edit") {
            onEdit(block.id)
        }
        .buttonStyle(.bordered)
        .disabled(isProcessing)

        Button("Move to Selected Slot") {
            onReschedule(block.id)
        }
        .buttonStyle(.bordered)
        .disabled(isProcessing || canRescheduleToSelection == false)

        Button("Cancel", role: .destructive) {
            onCancel(block.id)
        }
        .buttonStyle(.bordered)
        .disabled(isProcessing)

        Button("Delete", role: .destructive) {
            onDelete(block.id)
        }
        .buttonStyle(.bordered)
        .disabled(isProcessing)
    }
}

private struct PlannerScheduledBlockEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PlannerScheduledBlockEditDraft

    let isSaving: Bool
    let onSave: (PlannerScheduledBlockEditDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: PlannerScheduledBlockEditDraft,
        isSaving: Bool,
        onSave: @escaping (PlannerScheduledBlockEditDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Block") {
                    Text(draft.title)
                        .font(.headline)

                    Text(draft.originalInterval.timelineLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Timing") {
                    DatePicker(
                        "Start",
                        selection: $draft.start,
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    DatePicker(
                        "End",
                        selection: $draft.end,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                if let validationMessage = draft.validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Scheduled Block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(isSaving || draft.validationMessage != nil)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 280)
    }
}

private struct PlannerSuggestionCard: View {
    let suggestion: PlannerSuggestionItem
    let isProcessingSuggestion: Bool
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.taskTitle)
                        .font(.headline)

                    Text(suggestion.interval.timelineLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(suggestionBadgeTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.18), in: Capsule())
            }

            Text(suggestion.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    onAcceptSuggestion(suggestion.id)
                } label: {
                    Label("Accept", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .tint(.gray)
                .disabled(isProcessingSuggestion)

                Button(role: .destructive) {
                    onRejectSuggestion(suggestion.id)
                } label: {
                    Label("Reject", systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(isProcessingSuggestion)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var suggestionBadgeTitle: String {
        if isProcessingSuggestion {
            return "Saving..."
        }

        switch suggestion.decision {
        case .pending:
            return "Suggestion"
        case .accepted:
            return "Accepted"
        }
    }
}

private struct PlannerSuggestionInlineActionStrip: View {
    let suggestionID: UUID
    let isProcessing: Bool
    let onAcceptSuggestion: (UUID) -> Void
    let onRejectSuggestion: (UUID) -> Void

    var body: some View {
        Group {
            if isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.7), in: Circle())
            } else {
                HStack(spacing: 6) {
                    inlineActionButton(
                        systemName: "checkmark.circle.fill",
                        tint: .green,
                        accessibilityLabel: "Accept suggestion"
                    ) {
                        onAcceptSuggestion(suggestionID)
                    }

                    inlineActionButton(
                        systemName: "xmark.circle.fill",
                        tint: .red,
                        accessibilityLabel: "Reject suggestion"
                    ) {
                        onRejectSuggestion(suggestionID)
                    }
                }
            }
        }
        .padding(8)
    }

    private func inlineActionButton(
        systemName: String,
        tint: Color,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.72), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PlannerFilterTagChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.08),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}

private struct HorizonPlanSheet: View {
    @ObservedObject var viewModel: PlannerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Calendar Access") {
                    Text(viewModel.permissionStatus.displayTitle)
                        .font(.headline)
                        .foregroundStyle(viewModel.permissionStatus.tintColor)

                    Text(viewModel.permissionStatus.detailText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if viewModel.permissionStatus != .fullAccessGranted {
                        Button("Request Calendar Access") {
                            Task {
                                await viewModel.requestCalendarAccess()
                            }
                        }
                        .disabled(viewModel.isLoading)
                    }
                }

                Section("Planning Horizon") {
                    Picker("Window", selection: $viewModel.selectedPlanningHorizon) {
                        ForEach(PlannerHorizon.allCases) { horizon in
                            Text(horizon.title).tag(horizon)
                        }
                    }

                    Text(viewModel.selectedHorizonPlanningWindow.planningLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Task Filters") {
                    Picker("Work Mode", selection: selectedWorkModeBinding) {
                        Text("Any").tag(nil as WorkModeKind?)

                        ForEach(viewModel.availableWorkModes, id: \.self) { workMode in
                            Text(workMode.displayName).tag(Optional(workMode))
                        }
                    }

                    Picker("Priority Emphasis", selection: selectedPriorityEmphasisBinding) {
                        ForEach(PlannerPriorityEmphasis.allCases) { emphasis in
                            Text(emphasis.title).tag(emphasis)
                        }
                    }

                    if viewModel.availableTags.isEmpty {
                        Text("No task tags are available yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.availableTags, id: \.self) { tag in
                            Toggle(tag, isOn: tagBinding(for: tag))
                        }
                    }

                    Text("These filters shape the first-pass planner ranking for transient suggestions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Plan by Horizon")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Generate") {
                        Task {
                            await viewModel.generatePlan()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.permissionStatus != .fullAccessGranted)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    private var selectedWorkModeBinding: Binding<WorkModeKind?> {
        Binding {
            viewModel.filterState.workMode
        } set: { workMode in
            viewModel.filterState.workMode = workMode
        }
    }

    private var selectedPriorityEmphasisBinding: Binding<PlannerPriorityEmphasis> {
        Binding {
            viewModel.filterState.priorityEmphasis
        } set: { emphasis in
            viewModel.filterState.priorityEmphasis = emphasis
        }
    }

    private func tagBinding(for tag: String) -> Binding<Bool> {
        Binding {
            viewModel.filterState.selectedTags.contains(tag)
        } set: { isEnabled in
            viewModel.setSelectedTag(tag, isEnabled: isEnabled)
        }
    }
}

private struct PlannerScheduledBlockEditDraft: Identifiable {
    let blockID: UUID
    let title: String
    let originalInterval: DateInterval
    var start: Date
    var end: Date

    var id: UUID {
        blockID
    }

    var validationMessage: String? {
        guard end > start else {
            return "End time must be after the start time."
        }

        return nil
    }
}

private struct PlannerScheduledBlockAlert: Identifiable {
    enum Action {
        case cancel
        case delete
    }

    let blockID: UUID
    let action: Action

    var id: String {
        "\(blockID.uuidString)-\(action)"
    }
}

private extension CalendarPermissionStatus {
    var displayTitle: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .fullAccessGranted:
            return "Full Access Granted"
        case .writeOnlyGrantedButInsufficient:
            return "Write-Only Access"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .error:
            return "Error"
        }
    }

    var detailText: String {
        switch self {
        case .notDetermined:
            return "The planner needs full Calendar access before it can read busy time."
        case .fullAccessGranted:
            return "Real calendar events are shown as busy time, and accepted suggestions are written into the configured write calendar."
        case .writeOnlyGrantedButInsufficient:
            return "Write-only permission is not enough for planner reads. Full access is required."
        case .denied:
            return "Calendar access is denied. Update the app’s Calendar permission in System Settings."
        case .restricted:
            return "Calendar access is restricted on this Mac."
        case .error(let message):
            return message
        }
    }

    var tintColor: Color {
        switch self {
        case .fullAccessGranted:
            return .green
        case .notDetermined:
            return .secondary
        case .writeOnlyGrantedButInsufficient, .restricted:
            return .orange
        case .denied, .error:
            return .red
        }
    }
}

private extension PlannerTimelineEntry {
    var suggestionID: UUID? {
        switch self {
        case .calendarEvent:
            return nil
        case .scheduledBlock:
            return nil
        case .suggestion(let item):
            return item.id
        }
    }

    var scheduledBlockID: UUID? {
        switch self {
        case .scheduledBlock(let item):
            return item.id
        case .calendarEvent, .suggestion:
            return nil
        }
    }

    var dayCalendarTitle: String {
        switch self {
        case .calendarEvent(let event):
            return event.title
        case .scheduledBlock(let item):
            return item.taskTitle
        case .suggestion(let suggestion):
            return suggestion.taskTitle
        }
    }

    var dayCalendarSubtitle: String {
        switch self {
        case .calendarEvent(let event):
            return event.calendarTitle
        case .scheduledBlock(let item):
            return item.block.calendarTitle ?? "Accepted scheduled block"
        case .suggestion(let suggestion):
            return suggestion.explanation
        }
    }

    var dayCalendarBadge: String {
        switch self {
        case .calendarEvent(let event):
            return event.calendarTitle
        case .scheduledBlock(let item):
            return item.block.linkStateBadgeTitle
        case .suggestion:
            return "Suggestion"
        }
    }

    var dayCalendarTint: Color {
        switch self {
        case .calendarEvent:
            return .blue
        case .scheduledBlock(let item):
            return item.block.linkStateTint
        case .suggestion:
            return .gray
        }
    }

    var dayCalendarFill: Color {
        switch self {
        case .calendarEvent:
            return dayCalendarTint.opacity(0.14)
        case .scheduledBlock:
            return dayCalendarTint.opacity(0.18)
        case .suggestion:
            return dayCalendarTint.opacity(0.1)
        }
    }

    var dayCalendarStroke: Color {
        switch self {
        case .calendarEvent:
            return dayCalendarTint.opacity(0.28)
        case .scheduledBlock:
            return dayCalendarTint.opacity(0.36)
        case .suggestion:
            return dayCalendarTint.opacity(0.24)
        }
    }

    var rowTint: Color {
        switch self {
        case .calendarEvent:
            return .blue
        case .scheduledBlock(let item):
            return item.block.linkStateTint
        case .suggestion:
            return .gray
        }
    }

    var dayCalendarTimeRange: String {
        switch self {
        case .calendarEvent(let event):
            return event.isAllDay ? "All day" : event.interval.timelineLabel
        case .scheduledBlock(let item):
            return item.interval.timelineLabel
        case .suggestion(let suggestion):
            return suggestion.interval.timelineLabel
        }
    }
}

private extension ScheduledBlock {
    var linkStateBadgeTitle: String {
        switch calendarLinkState {
        case .linked:
            return calendarTitle ?? "Scheduled"
        case .movedExternally:
            return "Moved in Calendar"
        case .syncError:
            return "Sync Error"
        case .identifierStale:
            return "Missing Link"
        case .deletedExternally:
            return "Deleted Externally"
        case .writePending:
            return "Syncing"
        case .notWritten:
            return "Canceled"
        }
    }

    var linkStateMessage: String? {
        switch calendarLinkState {
        case .movedExternally:
            return "The linked calendar event was changed outside the app. This block now mirrors the calendar copy."
        case .syncError, .identifierStale:
            return syncErrorMessage
        case .deletedExternally:
            return "The linked calendar event was deleted outside the app."
        case .linked, .writePending, .notWritten:
            return nil
        }
    }

    var linkStateTint: Color {
        switch calendarLinkState {
        case .linked, .writePending:
            return .mint
        case .movedExternally:
            return .orange
        case .syncError, .identifierStale, .deletedExternally:
            return .red
        case .notWritten:
            return .gray
        }
    }
}

private extension PlannerFilterState {
    var summaryText: String {
        let workModeText = workMode?.displayName ?? "Any work mode"
        let tagsText: String

        if selectedTags.isEmpty {
            tagsText = "Any tags"
        } else {
            tagsText = selectedTags.sorted().joined(separator: ", ")
        }

        return "\(workModeText) • \(priorityEmphasis.title) • \(tagsText)"
    }
}

private extension DateInterval {
    var dayLabel: String {
        "\(start.formatted(date: .abbreviated, time: .omitted)) • 12:00 AM – 11:59 PM"
    }

    var planningLabel: String {
        let startLabel = start.formatted(date: .abbreviated, time: .shortened)
        let endLabel = end.formatted(date: .abbreviated, time: .shortened)
        return "\(startLabel) – \(endLabel)"
    }

    var timelineLabel: String {
        let startLabel = start.formatted(date: .omitted, time: .shortened)
        let endLabel = end.formatted(date: .omitted, time: .shortened)
        return "\(startLabel) – \(endLabel)"
    }
}

private extension CalendarEventSnapshot {
    var timelineLabel: String {
        if isAllDay {
            return "All-day calendar event"
        }

        return interval.timelineLabel
    }
}

private struct PlannerDayCalendarLayout {
    let allDayEntries: [PlannerTimelineEntry]
    let timedEntries: [PlannerDayCalendarLayoutItem]

    init(
        dayInterval: DateInterval,
        entries: [PlannerTimelineEntry]
    ) {
        let visibleEntries = entries.filter { entry in
            entry.isAllDay || entry.end > dayInterval.start && entry.start < dayInterval.end
        }

        allDayEntries = visibleEntries.filter(\.isAllDay)

        let sortedTimedEntries = visibleEntries
            .filter { $0.isAllDay == false }
            .sorted { lhs, rhs in
                if lhs.start != rhs.start {
                    return lhs.start < rhs.start
                }

                if lhs.end != rhs.end {
                    return lhs.end < rhs.end
                }

                return lhs.id < rhs.id
            }

        var laidOutEntries: [PlannerDayCalendarLayoutItem] = []
        var cluster: [PlannerTimelineEntry] = []
        var clusterEnd: Date?

        for entry in sortedTimedEntries {
            if let currentClusterEnd = clusterEnd, entry.start < currentClusterEnd {
                cluster.append(entry)
                if entry.end > currentClusterEnd {
                    clusterEnd = entry.end
                }
            } else {
                laidOutEntries += Self.layoutCluster(cluster)
                cluster = [entry]
                clusterEnd = entry.end
            }
        }

        laidOutEntries += Self.layoutCluster(cluster)
        timedEntries = laidOutEntries
    }

    private static func layoutCluster(
        _ cluster: [PlannerTimelineEntry]
    ) -> [PlannerDayCalendarLayoutItem] {
        guard cluster.isEmpty == false else {
            return []
        }

        var laneEnds: [Date] = []
        var assignments: [(entry: PlannerTimelineEntry, laneIndex: Int)] = []

        for entry in cluster {
            if let laneIndex = laneEnds.firstIndex(where: { $0 <= entry.start }) {
                laneEnds[laneIndex] = entry.end
                assignments.append((entry: entry, laneIndex: laneIndex))
            } else {
                laneEnds.append(entry.end)
                assignments.append((entry: entry, laneIndex: laneEnds.count - 1))
            }
        }

        let laneCount = max(laneEnds.count, 1)
        return assignments.map { assignment in
            PlannerDayCalendarLayoutItem(
                entry: assignment.entry,
                laneIndex: assignment.laneIndex,
                laneCount: laneCount
            )
        }
    }
}

private struct PlannerDayCalendarLayoutItem: Identifiable {
    let entry: PlannerTimelineEntry
    let laneIndex: Int
    let laneCount: Int

    var id: String {
        entry.id
    }
}

#Preview("Planner Loaded") {
    let previewContainer = AppContainer.makePreview(
        seedTasks: [
            MyTask(
                title: "Write project update",
                estimatedMinutes: 45,
                priority: .high,
                workMode: .shallowAdmin,
                tags: ["work", "writing"]
            ),
            MyTask(
                title: "Deep work on planner engine",
                estimatedMinutes: 90,
                priority: .urgent,
                workMode: .deepWork,
                tags: ["work", "planning"]
            ),
            MyTask(
                title: "Grocery run",
                estimatedMinutes: 30,
                priority: .medium,
                workMode: .errand,
                tags: ["home"]
            ),
        ]
    )

    PlannerView(
        taskRepository: previewContainer.taskRepository,
        scheduledBlockRepository: previewContainer.scheduledBlockRepository,
        settingsRepository: previewContainer.settingsRepository,
        calendarPermissionProvider: StubCalendarPermissionService(status: .fullAccessGranted),
        calendarListingService: StubCalendarListingService(
            calendars: [
                ReadableCalendar(
                    id: "work",
                    title: "Work",
                    allowsContentModifications: true,
                    isExcludedBySettings: false
                ),
                ReadableCalendar(
                    id: "personal",
                    title: "Personal",
                    allowsContentModifications: true,
                    isExcludedBySettings: false
                ),
            ]
        ),
        calendarReader: StubCalendarReader(
            events: [
                CalendarEventSnapshot(
                    identifier: "standup",
                    title: "Team Standup",
                    start: Date.now.addingTimeInterval(60 * 60),
                    end: Date.now.addingTimeInterval(90 * 60),
                    isAllDay: false,
                    calendarTitle: "Work"
                ),
                CalendarEventSnapshot(
                    identifier: "lunch",
                    title: "Lunch",
                    start: Date.now.addingTimeInterval(4 * 60 * 60),
                    end: Date.now.addingTimeInterval(5 * 60 * 60),
                    isAllDay: false,
                    calendarTitle: "Personal"
                ),
            ]
        ),
        calendarWriter: StubCalendarWriter(),
        calendarReconciler: StubCalendarReconciler()
    )
}
