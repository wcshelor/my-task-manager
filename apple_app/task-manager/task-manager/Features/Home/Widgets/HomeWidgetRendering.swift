import SwiftUI

@MainActor
struct HomeWidgetRenderContext {
    let execution: HomeExecutionViewModel
    let descriptor: (HomeWidgetKind) -> HomeWidgetDescriptor?
    let perform: (HomeWidgetDefaultAction, HomeWidgetInstance) -> Void
    let openProject: (UUID) -> Void
    let openRoutine: (UUID) -> Void
    let checkInPromise: (Promise) -> Void
    let openShopping: () -> Void
    let openHealth: () -> Void
}

@MainActor
struct AnyHomeWidgetRenderer {
    let kind: HomeWidgetKind
    private let renderBody: (HomeWidgetInstance, HomeWidgetRenderContext) -> AnyView

    init<Content: View>(
        kind: HomeWidgetKind,
        @ViewBuilder render: @escaping (HomeWidgetInstance, HomeWidgetRenderContext) -> Content
    ) {
        self.kind = kind
        self.renderBody = { widget, context in
            AnyView(render(widget, context))
        }
    }

    func render(
        widget: HomeWidgetInstance,
        context: HomeWidgetRenderContext
    ) -> AnyView {
        renderBody(widget, context)
    }
}

@MainActor
struct HomeWidgetRendererRegistry {
    private let renderers: [HomeWidgetKind: AnyHomeWidgetRenderer]

    init(renderers: [AnyHomeWidgetRenderer]) {
        self.renderers = Dictionary(uniqueKeysWithValues: renderers.map { ($0.kind, $0) })
    }

    func render(
        widget: HomeWidgetInstance,
        context: HomeWidgetRenderContext
    ) -> AnyView {
        guard let renderer = renderers[widget.kind],
              context.descriptor(widget.kind)?.isAvailable == true else {
            return AnyView(HomeUnavailableWidgetCard(descriptor: context.descriptor(widget.kind)))
        }

        return renderer.render(widget: widget, context: context)
    }

    static let standard = HomeWidgetRendererRegistry(
        renderers: [
            AnyHomeWidgetRenderer(kind: .inbox) { widget, context in
                if widget.size == .small {
                    HomeSmallButtonWidget(
                        title: "Inbox",
                        systemImage: context.descriptor(widget.kind)?.iconSystemName ?? "tray.full.fill",
                        value: "\(context.execution.inboxSummary.count)",
                        detail: context.execution.inboxSummary.oldestAgeLabel.map { "oldest \($0)" } ?? "clear",
                        actionTitle: context.execution.inboxSummary.count > 0 ? "Review" : "Capture"
                    ) {
                        context.perform(
                            context.execution.inboxSummary.count > 0 ? .reviewInbox : .openCapture,
                            widget
                        )
                    }
                } else {
                    HomeInboxCard(
                        summary: context.execution.inboxSummary,
                        onCapture: { context.perform(.openCapture, widget) },
                        onReview: { context.perform(.reviewInbox, widget) }
                    )
                }
            },
            AnyHomeWidgetRenderer(kind: .quickCapture) { widget, context in
                HomeActionWidget(
                    title: "Quick Capture",
                    systemImage: "tray.and.arrow.down",
                    value: widget.size == .small ? "New" : "Capture what is on your mind before choosing where it belongs.",
                    actionTitle: "Capture"
                ) {
                    context.perform(.openCapture, widget)
                }
            },
            AnyHomeWidgetRenderer(kind: .tasksModule) { widget, context in
                HomeModuleRenderer.render(
                    widget: widget,
                    title: "Tasks",
                    systemImage: "checklist",
                    detail: "\(context.execution.activeTaskCount) active",
                    action: "Open Tasks",
                    perform: { context.perform(.openTasks, widget) }
                )
            },
            AnyHomeWidgetRenderer(kind: .plannerModule) { widget, context in
                HomeModuleRenderer.render(
                    widget: widget,
                    title: "Planner",
                    systemImage: "calendar",
                    detail: context.execution.plannerSummary,
                    action: "Plan the Day",
                    perform: { context.perform(.openPlanner, widget) }
                )
            },
            AnyHomeWidgetRenderer(kind: .projectsModule) { widget, context in
                HomeModuleRenderer.render(
                    widget: widget,
                    title: "Projects",
                    systemImage: "folder.fill",
                    detail: "\(context.execution.projects.count) active",
                    action: "Open Projects",
                    perform: { context.perform(.openProjects, widget) }
                )
            },
            AnyHomeWidgetRenderer(kind: .promisesModule) { widget, context in
                HomeModuleRenderer.render(
                    widget: widget,
                    title: "Promises",
                    systemImage: "hand.raised.fill",
                    detail: "\(context.execution.activePromises.count) active",
                    action: "New Promise",
                    perform: { context.perform(.newPromise, widget) }
                )
            },
            AnyHomeWidgetRenderer(kind: .routinesModule) { widget, context in
                HomeModuleRenderer.render(
                    widget: widget,
                    title: "Routines",
                    systemImage: "checklist.checked",
                    detail: "\(context.execution.routineProgress.count) today",
                    action: "New Routine",
                    perform: { context.perform(.newRoutine, widget) }
                )
            },
            AnyHomeWidgetRenderer(kind: .shoppingModule) { widget, context in
                HomeModuleRenderer.render(
                    widget: widget,
                    title: "Shopping",
                    systemImage: "cart.fill",
                    detail: "\(context.execution.activeShoppingItemCount) needed",
                    action: "Open Shopping",
                    perform: { context.perform(.openShopping, widget) }
                )
            },
            AnyHomeWidgetRenderer(kind: .healthModule) { widget, context in
                HomeModuleRenderer.render(
                    widget: widget,
                    title: "Health",
                    systemImage: "heart.text.square",
                    detail: context.execution.healthSummary.detail,
                    action: "Open Health",
                    perform: { context.perform(.openHealth, widget) }
                )
            },
            AnyHomeWidgetRenderer(kind: .calendarOverview) { widget, context in
                HomeCalendarRenderer.render(widget: widget, context: context)
            },
            AnyHomeWidgetRenderer(kind: .planTheDay) { widget, context in
                HomeModuleRenderer.render(
                    widget: widget,
                    title: "Plan the Day",
                    systemImage: "calendar.badge.plus",
                    detail: context.execution.plannerSummary,
                    action: "Open Planner",
                    perform: { context.perform(.openPlanner, widget) }
                )
            },
            AnyHomeWidgetRenderer(kind: .nextEvent) { widget, context in
                HomeNextEventRenderer.render(widget: widget, context: context)
            },
            AnyHomeWidgetRenderer(kind: .pinnedProjects) { widget, context in
                HomeProjectsRenderer.renderPinnedProjects(widget: widget, context: context)
            },
            AnyHomeWidgetRenderer(kind: .projectNextTask) { widget, context in
                HomeProjectsRenderer.renderProjectNextTask(widget: widget, context: context)
            },
            AnyHomeWidgetRenderer(kind: .promises) { widget, context in
                HomePromisesRenderer.renderActivePromises(widget: widget, context: context)
            },
            AnyHomeWidgetRenderer(kind: .duePromiseCheckIn) { widget, context in
                HomePromisesRenderer.renderDuePromise(widget: widget, context: context)
            },
            AnyHomeWidgetRenderer(kind: .routines) { widget, context in
                HomeRoutinesRenderer.renderRoutines(widget: widget, context: context)
            },
            AnyHomeWidgetRenderer(kind: .currentRoutineStep) { widget, context in
                HomeRoutinesRenderer.renderCurrentStep(widget: widget, context: context)
            },
            AnyHomeWidgetRenderer(kind: .promiseHistory) { _, context in
                HomePromiseHistoryWidget(execution: context.execution)
            },
        ]
    )
}

private enum HomeModuleRenderer {
    @ViewBuilder
    static func render(
        widget: HomeWidgetInstance,
        title: String,
        systemImage: String,
        detail: String,
        action: String,
        perform: @escaping () -> Void
    ) -> some View {
        if widget.size == .small {
            Button(action: perform) {
                HomeSmallStaticWidget(
                    title: title,
                    systemImage: systemImage,
                    value: detail.components(separatedBy: " ").first ?? "Open",
                    detail: action
                )
            }
            .buttonStyle(.plain)
        } else {
            Button(action: perform) {
                HomeModuleWidgetCard(
                    title: title,
                    systemImage: systemImage,
                    detail: detail,
                    action: action
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private enum HomeCalendarRenderer {
    @ViewBuilder
    static func render(
        widget: HomeWidgetInstance,
        context: HomeWidgetRenderContext
    ) -> some View {
        if widget.size == .small {
            HomeSmallButtonWidget(
                title: "Events",
                systemImage: "calendar.badge.clock",
                value: "\(context.execution.calendarOverview?.events.count ?? 0)",
                detail: context.execution.plannerSummary,
                actionTitle: "Plan"
            ) {
                context.perform(.openPlanner, widget)
            }
        } else if let overview = context.execution.calendarOverview {
            HomeCalendarOverviewCard(
                overview: overview,
                onPlanTheDay: { context.perform(.openPlanner, widget) }
            )
        } else if let status = context.execution.calendarPermissionStatus {
            HomeCalendarPermissionCard(status: status)
        }
    }
}

private enum HomeNextEventRenderer {
    static func render(
        widget: HomeWidgetInstance,
        context: HomeWidgetRenderContext
    ) -> some View {
        let nextEvent = context.execution.calendarOverview?.nextEvent
        return HomeActionWidget(
            title: "Next Event",
            systemImage: "calendar.badge.clock",
            value: nextEvent.map { event in
                "\(event.title) at \(event.start.formatted(date: .omitted, time: .shortened))"
            } ?? "No upcoming event",
            actionTitle: "Plan"
        ) {
            context.perform(.openPlanner, widget)
        }
    }
}

private enum HomeProjectsRenderer {
    @ViewBuilder
    static func renderPinnedProjects(
        widget: HomeWidgetInstance,
        context: HomeWidgetRenderContext
    ) -> some View {
        if widget.size == .small {
            Button {
                context.perform(.openProjects, widget)
            } label: {
                HomeSmallStaticWidget(
                    title: "Pinned",
                    systemImage: "pin.fill",
                    value: "\(context.execution.pinnedProjectSummaries.count)",
                    detail: "Open"
                )
            }
            .buttonStyle(.plain)
        } else if context.execution.pinnedProjectSummaries.isEmpty {
            HomeUnavailableWidgetCard(
                title: "No Pinned Projects",
                systemImage: "pin",
                message: "Pin a project to keep it visible here."
            )
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Label("Pinned Projects", systemImage: "pin.fill")
                    .font(.headline)

                ForEach(context.execution.pinnedProjectSummaries) { summary in
                    Button {
                        context.openProject(summary.project.id)
                    } label: {
                        HomePinnedProjectCard(summary: summary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    static func renderProjectNextTask(
        widget: HomeWidgetInstance,
        context: HomeWidgetRenderContext
    ) -> some View {
        if let projectID = widget.configuration.projectID,
           let summary = context.execution.projectSummary(for: projectID) {
            HomeActionWidget(
                title: summary.project.name,
                systemImage: "folder.badge.gearshape",
                value: summary.nextTask?.title ?? "No next task",
                actionTitle: "Open"
            ) {
                context.openProject(projectID)
            }
        } else {
            HomeUnavailableWidgetCard(
                title: "Project Not Selected",
                systemImage: "folder.badge.questionmark",
                message: "Configure this widget with a project."
            )
        }
    }
}

private enum HomePromisesRenderer {
    @ViewBuilder
    static func renderActivePromises(
        widget: HomeWidgetInstance,
        context: HomeWidgetRenderContext
    ) -> some View {
        if widget.size == .small {
            HomeSmallButtonWidget(
                title: "Promises",
                systemImage: "hand.raised.fill",
                value: "\(context.execution.activePromises.count)",
                detail: "\(context.execution.duePromises.count) due",
                actionTitle: "New"
            ) {
                context.perform(.newPromise, widget)
            }
        } else {
            HomePromiseListWidget(
                execution: context.execution,
                onNewPromise: { context.perform(.newPromise, widget) },
                onCheckIn: context.checkInPromise
            )
        }
    }

    @ViewBuilder
    static func renderDuePromise(
        widget: HomeWidgetInstance,
        context: HomeWidgetRenderContext
    ) -> some View {
        if let promise = context.execution.duePromises.first {
            HomeActionWidget(
                title: "Due Promise",
                systemImage: "hand.raised.square",
                value: promise.title,
                actionTitle: "Check In"
            ) {
                context.checkInPromise(promise)
            }
        } else {
            HomeActionWidget(
                title: "Due Promise",
                systemImage: "hand.raised.square",
                value: "Nothing due",
                actionTitle: "New"
            ) {
                context.perform(.newPromise, widget)
            }
        }
    }
}

private enum HomeRoutinesRenderer {
    @ViewBuilder
    static func renderRoutines(
        widget: HomeWidgetInstance,
        context: HomeWidgetRenderContext
    ) -> some View {
        if widget.size == .small {
            HomeSmallButtonWidget(
                title: "Routines",
                systemImage: "checklist.checked",
                value: context.execution.routineProgressSummary,
                detail: "\(context.execution.routineProgress.count) today",
                actionTitle: "New"
            ) {
                context.perform(.newRoutine, widget)
            }
        } else {
            HomeRoutineListWidget(
                execution: context.execution,
                onNewRoutine: { context.perform(.newRoutine, widget) },
                onOpenRoutine: context.openRoutine
            )
        }
    }

    @ViewBuilder
    static func renderCurrentStep(
        widget: HomeWidgetInstance,
        context: HomeWidgetRenderContext
    ) -> some View {
        if let routineID = widget.configuration.routineID,
           let progress = context.execution.progress(for: routineID) {
            HomeActionWidget(
                title: progress.routine.name,
                systemImage: progress.isComplete ? "checkmark.circle.fill" : "figure.walk.motion",
                value: progress.currentItem?.title ?? "Complete for today",
                actionTitle: progress.actionLabel
            ) {
                context.openRoutine(routineID)
            }
        } else {
            HomeUnavailableWidgetCard(
                title: "Routine Not Selected",
                systemImage: "list.bullet.clipboard",
                message: "Configure this widget with an active routine."
            )
        }
    }
}

struct HomeModuleWidgetCard: View {
    let title: String
    let systemImage: String
    let detail: String
    let action: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(action)
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.blue)
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HomeSmallButtonWidget: View {
    let title: String
    let systemImage: String
    let value: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .lineLimit(1)

            Button(actionTitle, action: action)
                .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HomeSmallStaticWidget: View {
    let title: String
    let systemImage: String
    let value: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(.primary)
        }
        .padding(12)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct HomeActionWidget: View {
    let title: String
    let systemImage: String
    let value: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Text(actionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct HomeUnavailableWidgetCard: View {
    let title: String
    let systemImage: String
    let message: String

    init(descriptor: HomeWidgetDescriptor?) {
        self.title = descriptor?.displayName ?? "Unavailable Widget"
        self.systemImage = descriptor?.iconSystemName ?? "questionmark.square.dashed"
        self.message = descriptor?.availability.message ?? "This widget is not available in this version of the app."
    }

    init(title: String, systemImage: String, message: String) {
        self.title = title
        self.systemImage = systemImage
        self.message = message
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
}

struct HomePromiseListWidget: View {
    @ObservedObject var execution: HomeExecutionViewModel
    let onNewPromise: () -> Void
    let onCheckIn: (Promise) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Promises", systemImage: "hand.raised.fill")
                    .font(.headline)
                Spacer()
                Button {
                    onNewPromise()
                } label: {
                    Label("New Promise", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if execution.activePromises.isEmpty {
                ContentUnavailableView(
                    "No Active Promises",
                    systemImage: "hand.raised",
                    description: Text("Make one clear promise when you want your word to stay visible.")
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(execution.activePromises) { promise in
                    PromiseCard(
                        promise: promise,
                        isDue: execution.duePromises.contains { $0.id == promise.id },
                        onCheckIn: {
                            onCheckIn(promise)
                        }
                    )
                }
            }
        }
    }
}

struct HomeRoutineListWidget: View {
    @ObservedObject var execution: HomeExecutionViewModel
    let onNewRoutine: () -> Void
    let onOpenRoutine: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Routines", systemImage: "checklist.checked")
                    .font(.headline)
                Spacer()
                Button {
                    onNewRoutine()
                } label: {
                    Label("New Routine", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            if execution.routineProgress.isEmpty {
                ContentUnavailableView(
                    "No Routines Today",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Create a routine with daily or weekday timing.")
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(execution.routineProgress) { progress in
                    Button {
                        onOpenRoutine(progress.routine.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: progress.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(progress.isComplete ? .green : .secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(progress.routine.name)
                                    .font(.body.weight(.medium))
                                Text(progress.progressLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            Text(progress.actionLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(progress.isComplete ? Color.secondary : Color.blue)
                        }
                        .padding(12)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct HomePromiseHistoryWidget: View {
    @ObservedObject var execution: HomeExecutionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Promise History", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            HStack(spacing: 12) {
                PromiseStatView(title: "Kept", value: execution.keptCount, color: .green)
                PromiseStatView(title: "Missed", value: execution.missedCount, color: .orange)
            }

            ForEach(execution.promiseHistory.prefix(5)) { promise in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: promise.outcome == .kept ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(promise.outcome == .kept ? .green : .orange)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(promise.title)
                            .font(.subheadline.weight(.medium))
                        if let resolvedAt = promise.resolvedAt {
                            Text(resolvedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
