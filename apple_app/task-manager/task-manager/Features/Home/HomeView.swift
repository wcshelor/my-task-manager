import Combine
import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum SheetDestination: Identifiable {
        case addWidget
        case customizeHome
        case inboxReview
        case promiseForm
        case promiseCheckIn(Promise)
        case routineBuilder
        case routineSession(UUID)
        case shoppingList
        case shoppingQuickAdd
        case health
        case musicPractice
        case fitness
        case peopleMemory
        case debriefs

        var id: String {
            switch self {
            case .addWidget:
                return "addWidget"
            case .customizeHome:
                return "customizeHome"
            case .inboxReview:
                return "inboxReview"
            case .promiseForm:
                return "promiseForm"
            case .promiseCheckIn(let promise):
                return "promiseCheckIn-\(promise.id.uuidString)"
            case .routineBuilder:
                return "routineBuilder"
            case .routineSession(let routineID):
                return "routineSession-\(routineID.uuidString)"
            case .shoppingList:
                return "shoppingList"
            case .shoppingQuickAdd:
                return "shoppingQuickAdd"
            case .health:
                return "health"
            case .musicPractice:
                return "musicPractice"
            case .fitness:
                return "fitness"
            case .peopleMemory:
                return "peopleMemory"
            case .debriefs:
                return "debriefs"
            }
        }
    }

    private enum NavigationDestination: Hashable {
        case tasks
        case planner
        case projects
        case project(UUID)
    }

    fileprivate struct PreviewDropTarget: Equatable {
        let widgetID: UUID
        let placement: HomeLayoutViewModel.WidgetDropPlacement
    }

    @StateObject private var viewModel: HomeExecutionViewModel
    @StateObject private var homeViewModel: HomeLayoutViewModel
    @State private var presentedSheet: SheetDestination?
    @State private var isShowingCaptureOverlay = false
    @State private var navigationPath: [NavigationDestination] = []
    @State private var isEditingHome = false
    @State private var draggingWidgetID: UUID?
    @State private var previewDropTarget: PreviewDropTarget?
    private let widgetRendererRegistry = HomeWidgetRendererRegistry.standard

    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository
    private let scheduledBlockRepository: any ScheduledBlockRepository
    private let settingsRepository: any SettingsRepository
    private let homeLayoutRepository: any HomeLayoutRepository
    private let calendarPermissionProvider: any CalendarPermissionProviding
    private let calendarListingService: any CalendarListing
    private let calendarReader: any CalendarReading
    private let calendarWriter: any CalendarWriting
    private let calendarReconciler: any CalendarReconciling
    private let calendarChangeObserver: any CalendarChangeObserving
    private let promiseRepository: any PromiseRepository
    private let shoppingRepository: any ShoppingRepository
    private let healthRepository: any HealthRepository
    private let musicPracticeRepository: any MusicPracticeRepository
    private let fitnessRepository: any FitnessRepository
    private let peopleMemoryRepository: any PeopleMemoryRepository
    private let debriefRepository: any DebriefRepository

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        scheduledBlockRepository: any ScheduledBlockRepository,
        settingsRepository: any SettingsRepository,
        homeLayoutRepository: any HomeLayoutRepository,
        calendarPermissionProvider: any CalendarPermissionProviding,
        calendarListingService: any CalendarListing,
        calendarReader: any CalendarReading,
        calendarWriter: any CalendarWriting,
        calendarReconciler: any CalendarReconciling,
        calendarChangeObserver: any CalendarChangeObserving,
        promiseRepository: any PromiseRepository,
        routineRepository: any RoutineRepository,
        shoppingRepository: any ShoppingRepository,
        healthRepository: any HealthRepository,
        musicPracticeRepository: any MusicPracticeRepository,
        fitnessRepository: any FitnessRepository,
        peopleMemoryRepository: any PeopleMemoryRepository,
        debriefRepository: any DebriefRepository
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
        self.scheduledBlockRepository = scheduledBlockRepository
        self.settingsRepository = settingsRepository
        self.homeLayoutRepository = homeLayoutRepository
        self.calendarPermissionProvider = calendarPermissionProvider
        self.calendarListingService = calendarListingService
        self.calendarReader = calendarReader
        self.calendarWriter = calendarWriter
        self.calendarReconciler = calendarReconciler
        self.calendarChangeObserver = calendarChangeObserver
        self.promiseRepository = promiseRepository
        self.shoppingRepository = shoppingRepository
        self.healthRepository = healthRepository
        self.musicPracticeRepository = musicPracticeRepository
        self.fitnessRepository = fitnessRepository
        self.peopleMemoryRepository = peopleMemoryRepository
        self.debriefRepository = debriefRepository
        _viewModel = StateObject(
            wrappedValue: HomeExecutionViewModel(
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                captureRepository: captureRepository,
                projectItemRepository: projectItemRepository,
                promiseRepository: promiseRepository,
                routineRepository: routineRepository,
                shoppingRepository: shoppingRepository,
                healthRepository: healthRepository,
                musicPracticeRepository: musicPracticeRepository,
                fitnessRepository: fitnessRepository,
                peopleMemoryRepository: peopleMemoryRepository,
                debriefRepository: debriefRepository,
                calendarPermissionProvider: calendarPermissionProvider,
                calendarReader: calendarReader
            )
        )
        _homeViewModel = StateObject(
            wrappedValue: HomeLayoutViewModel(
                homeLayoutRepository: homeLayoutRepository,
                settingsRepository: settingsRepository
            )
        )
    }

    private var isCompactWidth: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .topTrailing) {
                homeBoard
                    .disabled(isShowingCaptureOverlay)

                if isShowingCaptureOverlay {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            dismissCaptureOverlay()
                        }
                        .transition(.opacity)

                    captureOverlay
                        .padding(.top, 10)
                        .padding(.trailing, 16)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.94, anchor: .topTrailing)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(x: 18, y: -18)),
                                removal: .scale(scale: 0.96, anchor: .topTrailing)
                                    .combined(with: .opacity)
                            )
                        )
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditingHome ? "Done" : "Edit") {
                        isEditingHome.toggle()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isEditingHome {
                        Button {
                            presentedSheet = .customizeHome
                        } label: {
                            Label("Customize", systemImage: "slider.horizontal.3")
                        }
                    }

                    Button {
                        presentCaptureOverlay()
                    } label: {
                        Label("Capture", systemImage: "tray.and.arrow.down")
                    }

                    Button {
                        presentedSheet = .routineBuilder
                    } label: {
                        Label("New Routine", systemImage: "list.bullet.clipboard")
                    }

                    Button {
                        presentedSheet = .promiseForm
                    } label: {
                        Label("New Promise", systemImage: "hand.raised.fill")
                    }
                }
            }
            .sheet(item: $presentedSheet) { destination in
                NavigationStack {
                    switch destination {
                    case .addWidget:
                        AddHomeWidgetView(
                            viewModel: homeViewModel,
                            projects: viewModel.projects,
                            routines: viewModel.routineProgress.map(\.routine)
                        ) {
                            presentedSheet = nil
                        }
                    case .customizeHome:
                        HomeCustomizationView(viewModel: homeViewModel) {
                            presentedSheet = nil
                        }
                    case .inboxReview:
                        InboxReviewView(
                            taskRepository: taskRepository,
                            projectRepository: projectRepository,
                            captureRepository: captureRepository,
                            projectItemRepository: projectItemRepository,
                            shoppingRepository: shoppingRepository,
                            initialCaptures: viewModel.captures,
                            initialProjects: viewModel.projects,
                            onInboxChanged: {
                                viewModel.load()
                            }
                        ) {
                            viewModel.load()
                        }
                    case .promiseForm:
                        PromiseFormView { promise in
                            viewModel.savePromise(promise)
                            presentedSheet = nil
                        }
                    case .promiseCheckIn(let promise):
                        PromiseCheckInView(
                            promise: promise,
                            onResolve: { outcome, reflection in
                                viewModel.resolvePromise(
                                    withID: promise.id,
                                    outcome: outcome,
                                    reflection: reflection
                                )
                                presentedSheet = nil
                            },
                            onReset: { title, checkInAt in
                                viewModel.makeResetPromise(
                                    from: promise,
                                    title: title,
                                    checkInAt: checkInAt
                                )
                                presentedSheet = nil
                            }
                        )
                    case .routineBuilder:
                        RoutineBuilderView { routine in
                            viewModel.saveRoutine(routine)
                            presentedSheet = nil
                        }
                    case .routineSession(let routineID):
                        RoutineSessionView(
                            viewModel: viewModel,
                            registry: homeViewModel.registry,
                            taskRepository: taskRepository,
                            projectRepository: projectRepository,
                            captureRepository: captureRepository,
                            projectItemRepository: projectItemRepository,
                            scheduledBlockRepository: scheduledBlockRepository,
                            settingsRepository: settingsRepository,
                            calendarPermissionProvider: calendarPermissionProvider,
                            calendarListingService: calendarListingService,
                            calendarReader: calendarReader,
                            calendarWriter: calendarWriter,
                            calendarReconciler: calendarReconciler,
                            calendarChangeObserver: calendarChangeObserver,
                            promiseRepository: promiseRepository,
                            shoppingRepository: shoppingRepository,
                            healthRepository: healthRepository,
                            musicPracticeRepository: musicPracticeRepository,
                            fitnessRepository: fitnessRepository,
                            peopleMemoryRepository: peopleMemoryRepository,
                            routineID: routineID
                        )
                    case .shoppingList:
                        ShoppingListView(shoppingRepository: shoppingRepository) {
                            viewModel.load()
                        }
                    case .shoppingQuickAdd:
                        ShoppingQuickAddSheet(shoppingRepository: shoppingRepository) {
                            viewModel.load()
                            presentedSheet = nil
                        }
                    case .health:
                        HealthView(
                            healthRepository: healthRepository,
                            fitnessRepository: fitnessRepository
                        ) {
                            viewModel.load()
                        }
                    case .musicPractice:
                        MusicPracticeView(musicPracticeRepository: musicPracticeRepository) {
                            viewModel.load()
                        }
                    case .fitness:
                        FitnessView(fitnessRepository: fitnessRepository) {
                            viewModel.load()
                        }
                    case .peopleMemory:
                        PeopleMemoryView(peopleMemoryRepository: peopleMemoryRepository) {
                            viewModel.load()
                        }
                    case .debriefs:
                        DebriefListView(
                            debriefRepository: debriefRepository,
                            captureRepository: captureRepository,
                            calendarPermissionProvider: calendarPermissionProvider,
                            calendarReader: calendarReader
                        ) {
                            viewModel.load()
                        }
                    }
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .tasks:
                    TaskListView(
                        taskRepository: taskRepository,
                        projectRepository: projectRepository,
                        scheduledBlockRepository: scheduledBlockRepository,
                        calendarWriter: calendarWriter,
                        promiseRepository: promiseRepository
                    )
                case .planner:
                    plannerDestination
                case .projects:
                    ProjectsView(
                        taskRepository: taskRepository,
                        projectRepository: projectRepository,
                        captureRepository: captureRepository,
                        projectItemRepository: projectItemRepository
                    )
                case .project(let projectID):
                    ProjectDetailView(
                        projectID: projectID,
                        taskRepository: taskRepository,
                        projectRepository: projectRepository,
                        captureRepository: captureRepository,
                        projectItemRepository: projectItemRepository
                    )
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                viewModel.handleSceneDidBecomeActive()
                homeViewModel.load()
            }
            .task {
                viewModel.loadIfNeeded()
                homeViewModel.load()
            }
        }
    }

    private var plannerDestination: some View {
                PlannerView(
                    taskRepository: taskRepository,
                    scheduledBlockRepository: scheduledBlockRepository,
                    settingsRepository: settingsRepository,
                    calendarPermissionProvider: calendarPermissionProvider,
                    calendarListingService: calendarListingService,
                    calendarReader: calendarReader,
                    calendarWriter: calendarWriter,
                    calendarReconciler: calendarReconciler,
                    calendarChangeObserver: calendarChangeObserver,
                    promiseRepository: promiseRepository,
                    navigationTitle: "Plan the Day"
                )
    }

    private var homeBoard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: isCompactWidth ? 18 : 22) {
                header

                errorMessages

                if homeViewModel.widgets.isEmpty {
                    emptyHomeLayout
                } else {
                    ForEach(homeViewModel.widgets) { widget in
                        homeWidgetChrome(for: widget) {
                            widgetRendererRegistry.render(
                                widget: widget,
                                context: widgetRenderContext
                            )
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        presentedSheet = isEditingHome ? .customizeHome : .addWidget
                    } label: {
                        Label(isEditingHome ? "Customize Home" : "Add Widget", systemImage: isEditingHome ? "slider.horizontal.3" : "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)

                    if isEditingHome {
                        Button {
                            clearWidgetDragPreview()
                            homeViewModel.resetToDefaultLayout()
                            isEditingHome = false
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(isCompactWidth ? 16 : 20)
        }
        .onChange(of: isEditingHome) { _, isEditing in
            if isEditing == false {
                clearWidgetDragPreview()
            }
        }
        .onChange(of: homeViewModel.widgets.map(\.id)) { _, widgetIDs in
            if let draggingWidgetID, widgetIDs.contains(draggingWidgetID) == false {
                clearWidgetDragPreview()
                return
            }

            if let previewDropTarget, widgetIDs.contains(previewDropTarget.widgetID) == false {
                clearWidgetDragPreview()
            }
        }
    }

    @ViewBuilder
    private var errorMessages: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        }

        if let errorMessage = homeViewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private var emptyHomeLayout: some View {
        ContentUnavailableView(
            "Home Is Empty",
            systemImage: "square.grid.2x2",
            description: Text("Add widgets or reset to the default layout.")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    @ViewBuilder
    private func homeWidgetChrome<Content: View>(
        for widget: HomeWidgetInstance,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            insertionIndicator(
                isVisible: previewDropTarget?.widgetID == widget.id && previewDropTarget?.placement == .before
            )

            VStack(alignment: .leading, spacing: 8) {
                if isEditingHome {
                    HStack(spacing: 8) {
                        Label(
                            homeViewModel.descriptor(for: widget)?.displayName ?? widget.kind.rawValue,
                            systemImage: homeViewModel.descriptor(for: widget)?.iconSystemName ?? "square.grid.2x2"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                        Spacer()

                        if let alternateSize = homeViewModel.alternateSize(for: widget) {
                            Button {
                                homeViewModel.resizeWidget(withID: widget.id, to: alternateSize)
                            } label: {
                                Image(systemName: alternateSize == .large ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                            }
                            .buttonStyle(.bordered)
                        }

                        Button(role: .destructive) {
                            clearWidgetDragPreview()
                            homeViewModel.removeWidget(withID: widget.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onLongPressGesture {
                        isEditingHome = true
                    }
                    .onDrag {
                        draggingWidgetID = widget.id
                        previewDropTarget = nil
                        return NSItemProvider(object: widget.id.uuidString as NSString)
                    }
                    .accessibilityElement(children: .contain)
            }
            .padding(isEditingHome ? 10 : 14)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isEditingHome ? 0.12 : 0.08), lineWidth: 1)
            }
            .overlay {
                if isEditingHome {
                    GeometryReader { geometry in
                        Color.clear
                            .contentShape(Rectangle())
                            .onDrop(
                                of: [UTType.text],
                                delegate: HomeWidgetDropDelegate(
                                    targetWidgetID: widget.id,
                                    targetHeight: geometry.size.height,
                                    draggingWidgetID: $draggingWidgetID,
                                    previewDropTarget: $previewDropTarget,
                                    viewModel: homeViewModel,
                                    clearPreview: clearWidgetDragPreview
                                )
                            )
                    }
                }
            }
            .opacity(draggingWidgetID == widget.id ? 0.72 : 1)
            .scaleEffect(draggingWidgetID == widget.id ? 0.985 : 1)
            .shadow(
                color: Color.black.opacity(draggingWidgetID == widget.id ? 0.12 : 0.03),
                radius: draggingWidgetID == widget.id ? 20 : 12,
                y: draggingWidgetID == widget.id ? 8 : 3
            )

            insertionIndicator(
                isVisible: previewDropTarget?.widgetID == widget.id && previewDropTarget?.placement == .after
            )
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.84), value: previewDropTarget)
        .animation(.spring(response: 0.24, dampingFraction: 0.84), value: draggingWidgetID)
    }

    private func insertionIndicator(isVisible: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: isVisible ? 8 : 0)

            Capsule()
                .fill(Color.accentColor.opacity(isVisible ? 0.9 : 0))
                .frame(maxWidth: .infinity)
                .frame(height: isVisible ? 4 : 0)
                .padding(.horizontal, 18)

            Spacer()
                .frame(height: isVisible ? 8 : 0)
        }
        .accessibilityHidden(true)
    }

    private func clearWidgetDragPreview() {
        draggingWidgetID = nil
        previewDropTarget = nil
    }

    private var widgetRenderContext: HomeWidgetRenderContext {
        HomeWidgetRenderContext(
            execution: viewModel,
            descriptor: { kind in
                homeViewModel.registry.descriptor(for: kind)
            },
            perform: { action, widget in
                performWidgetAction(action, for: widget)
            },
            openProject: { projectID in
                navigationPath.append(.project(projectID))
            },
            openRoutine: { routineID in
                presentedSheet = .routineSession(routineID)
            },
            checkInPromise: { promise in
                presentedSheet = .promiseCheckIn(promise)
            },
            openShopping: {
                presentedSheet = .shoppingList
            },
            openHealth: {
                presentedSheet = .health
            },
            openMusicPractice: {
                presentedSheet = .musicPractice
            },
            openFitness: {
                presentedSheet = .fitness
            },
            openPeopleMemory: {
                presentedSheet = .peopleMemory
            }
        )
    }

    private func performWidgetAction(
        _ action: HomeWidgetDefaultAction,
        for widget: HomeWidgetInstance
    ) {
        switch action {
        case .openCapture:
            presentCaptureOverlay()
        case .reviewInbox:
            if viewModel.inboxSummary.count > 0 {
                presentedSheet = .inboxReview
            } else {
                presentCaptureOverlay()
            }
        case .openTasks:
            navigationPath.append(.tasks)
        case .openPlanner:
            navigationPath.append(.planner)
        case .openProjects:
            navigationPath.append(.projects)
        case .openConfiguredProject:
            if let projectID = widget.configuration.projectID {
                navigationPath.append(.project(projectID))
            }
        case .newPromise:
            presentedSheet = .promiseForm
        case .checkInDuePromise:
            if let promise = viewModel.duePromises.first {
                presentedSheet = .promiseCheckIn(promise)
            } else {
                presentedSheet = .promiseForm
            }
        case .newRoutine:
            presentedSheet = .routineBuilder
        case .openConfiguredRoutine:
            if let routineID = widget.configuration.routineID {
                presentedSheet = .routineSession(routineID)
            }
        case .openShopping:
            presentedSheet = .shoppingList
        case .quickAddShopping:
            presentedSheet = .shoppingQuickAdd
        case .openHealth:
            presentedSheet = .health
        case .openMusicPractice:
            presentedSheet = .musicPractice
        case .openFitness:
            presentedSheet = .fitness
        case .openPeopleMemory:
            presentedSheet = .peopleMemory
        case .openDebriefs:
            presentedSheet = .debriefs
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What needs to stay present?")
                .font(.title2.weight(.semibold))

            Text(Date().formatted(date: .complete, time: .omitted))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var captureOverlay: some View {
        CaptureQuickAddPopover(
            projects: viewModel.projects,
            onCancel: dismissCaptureOverlay
        ) { capture in
            viewModel.saveCapture(capture)
            dismissCaptureOverlay()
        }
    }

    private func presentCaptureOverlay() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isShowingCaptureOverlay = true
        }
    }

    private func dismissCaptureOverlay() {
        withAnimation(.easeOut(duration: 0.18)) {
            isShowingCaptureOverlay = false
        }
    }

}

private struct HomeWidgetDropDelegate: DropDelegate {
    let targetWidgetID: UUID
    let targetHeight: CGFloat
    @Binding var draggingWidgetID: UUID?
    @Binding var previewDropTarget: HomeView.PreviewDropTarget?
    let viewModel: HomeLayoutViewModel
    let clearPreview: () -> Void

    func dropEntered(info: DropInfo) {
        updatePreview(for: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updatePreview(for: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        guard previewDropTarget?.widgetID == targetWidgetID else {
            return
        }
        previewDropTarget = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingWidgetID else {
            clearPreview()
            return false
        }

        let placement = resolvedPlacement(for: info.location)
        let reorderedWidgets = viewModel.reorderedWidgets(
            movingID: draggingWidgetID,
            relativeTo: targetWidgetID,
            placement: placement
        )
        defer { clearPreview() }

        guard reorderedWidgets.map(\.id) != viewModel.widgets.map(\.id) else {
            return false
        }

        viewModel.moveWidget(
            withID: draggingWidgetID,
            relativeTo: targetWidgetID,
            placement: placement
        )
        return true
    }

    private func updatePreview(for info: DropInfo) {
        guard let draggingWidgetID, draggingWidgetID != targetWidgetID else {
            previewDropTarget = nil
            return
        }

        let placement = resolvedPlacement(for: info.location)
        let reorderedWidgets = viewModel.reorderedWidgets(
            movingID: draggingWidgetID,
            relativeTo: targetWidgetID,
            placement: placement
        )
        guard reorderedWidgets.map(\.id) != viewModel.widgets.map(\.id) else {
            previewDropTarget = nil
            return
        }

        previewDropTarget = HomeView.PreviewDropTarget(
            widgetID: targetWidgetID,
            placement: placement
        )
    }

    private func resolvedPlacement(for location: CGPoint) -> HomeLayoutViewModel.WidgetDropPlacement {
        location.y < targetHeight / 2 ? .before : .after
    }
}

private struct HomeCustomizationView: View {
    @ObservedObject var viewModel: HomeLayoutViewModel
    @Environment(\.dismiss) private var dismiss

    let onDone: () -> Void

    var body: some View {
        List {
            ForEach(viewModel.registry.modules, id: \.self) { module in
                Section(module.displayName) {
                    moduleSummary(for: module)

                    ForEach(descriptors(for: module)) { descriptor in
                        descriptorRow(descriptor)
                    }
                }
            }
        }
        .navigationTitle("Customize Home")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onDone()
                    dismiss()
                }
            }
        }
    }

    private func descriptors(for module: HomeWidgetModule) -> [HomeWidgetDescriptor] {
        let moduleDescriptor = viewModel.registry.moduleWidget(for: module).map { [$0] } ?? []
        return moduleDescriptor + viewModel.registry.featureWidgets(for: module)
    }

    private func moduleSummary(for module: HomeWidgetModule) -> some View {
        let descriptors = descriptors(for: module)
        let visibleCount = descriptors.filter { viewModel.isVisible($0) }.count

        return VStack(alignment: .leading, spacing: 4) {
            Text(module.displayName)
                .font(.headline)
            Text("\(visibleCount) visible of \(descriptors.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func descriptorRow(_ descriptor: HomeWidgetDescriptor) -> some View {
        HStack(spacing: 12) {
            Image(systemName: descriptor.iconSystemName)
                .foregroundStyle(descriptor.isAvailable ? Color.blue : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.displayName)
                    .foregroundStyle(descriptor.isAvailable ? Color.primary : Color.secondary)
                Text(customizationSubtitle(for: descriptor))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.supportsVisibilityToggle(descriptor) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: { viewModel.isVisible(descriptor) },
                        set: { viewModel.setVisibility($0, for: descriptor) }
                    )
                )
                .labelsHidden()
                .disabled(descriptor.isAvailable == false)
            } else {
                Text(stateLabel(for: descriptor))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func customizationSubtitle(for descriptor: HomeWidgetDescriptor) -> String {
        switch viewModel.visibilityState(for: descriptor) {
        case .visible:
            return "Visible on Home"
        case .hidden:
            return "Hidden by Home customization"
        case .added:
            return "Added on Home"
        case .available:
            return descriptor.requiresConfiguration ? "Add from gallery to configure" : "Available to add"
        case .planned:
            return descriptor.availability.message ?? "Planned"
        }
    }

    private func stateLabel(for descriptor: HomeWidgetDescriptor) -> String {
        switch viewModel.visibilityState(for: descriptor) {
        case .visible:
            return "Visible"
        case .hidden:
            return "Hidden"
        case .added:
            return "Added"
        case .available:
            return descriptor.isAvailable ? "Optional" : "Planned"
        case .planned:
            return "Planned"
        }
    }
}

private struct ShoppingQuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ShoppingListViewModel
    @State private var title = ""

    let onSave: () -> Void

    init(
        shoppingRepository: any ShoppingRepository,
        onSave: @escaping () -> Void
    ) {
        self.onSave = onSave
        _viewModel = StateObject(
            wrappedValue: ShoppingListViewModel(shoppingRepository: shoppingRepository)
        )
    }

    var body: some View {
        Form {
            Section("Item") {
                TextField("Add item", text: $title)
                    .submitLabel(.done)
                    .onSubmit(save)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Add Shopping Item")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    save()
                }
                .disabled(ShoppingItem.cleanedTitle(from: title) == nil)
            }
        }
    }

    private func save() {
        guard ShoppingItem.cleanedTitle(from: title) != nil else {
            return
        }

        viewModel.quickAdd(title: title)
        guard viewModel.errorMessage == nil else {
            return
        }

        onSave()
    }
}

struct HomeCalendarOverviewCard: View {
    let overview: HomeCalendarOverview
    let onPlanTheDay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Today’s Events", systemImage: "calendar.badge.clock")
                        .font(.headline)

                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let nextEvent = overview.nextEvent {
                    Text("Next \(nextEvent.start.formatted(date: .omitted, time: .shortened))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }

            if overview.events.isEmpty {
                Text("No calendar events on the books today.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(overview.events.prefix(3).enumerated()), id: \.offset) { _, event in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(event.isAllDay ? Color.blue : Color.orange)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title)
                                .font(.subheadline.weight(.medium))
                            Text(eventTimeLabel(for: event))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(event.calendarTitle)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }

                if overview.events.count > 3 {
                    Text("+ \(overview.events.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                onPlanTheDay()
            } label: {
                Label("Plan the Day", systemImage: "calendar.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(0.14), lineWidth: 1)
        )
    }

    private var summaryText: String {
        if overview.events.isEmpty {
            return "Your day is open so far."
        }

        if overview.allDayEvents.isEmpty {
            return overview.events.count == 1 ? "1 event scheduled today." : "\(overview.events.count) events scheduled today."
        }

        return "\(overview.events.count) events, including \(overview.allDayEvents.count) all-day."
    }

    private func eventTimeLabel(for event: CalendarEventSnapshot) -> String {
        if event.isAllDay {
            return "All day"
        }

        return "\(event.start.formatted(date: .omitted, time: .shortened)) - \(event.end.formatted(date: .omitted, time: .shortened))"
    }
}

struct HomeCalendarPermissionCard: View {
    let status: CalendarPermissionStatus

    var body: some View {
        if status != .fullAccessGranted {
            VStack(alignment: .leading, spacing: 6) {
                Label("Today’s Events", systemImage: "calendar.badge.exclamationmark")
                    .font(.headline)

                Text(copyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var copyText: String {
        switch status {
        case .notDetermined:
            return "Calendar access is pending, so today’s event overview is not available yet."
        case .fullAccessGranted:
            return ""
        case .writeOnlyGrantedButInsufficient, .denied, .restricted:
            return "Grant full Calendar access to show today’s event overview here."
        case .error(let message):
            return message
        }
    }
}

struct PromisePresenceBanner: View {
    @StateObject private var viewModel: PromisePresenceViewModel

    init(promiseRepository: any PromiseRepository) {
        _viewModel = StateObject(
            wrappedValue: PromisePresenceViewModel(promiseRepository: promiseRepository)
        )
    }

    var body: some View {
        if let promise = viewModel.activePromises.first {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.orange)
                Text(promise.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer()
                Text(promise.checkInAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .task {
                viewModel.load()
            }
        } else {
            EmptyView()
                .task {
                    viewModel.load()
                }
        }
    }
}

struct PromiseCard: View {
    let promise: Promise
    let isDue: Bool
    let onCheckIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(promise.title)
                        .font(.headline)
                    Text("Check in \(promise.checkInAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isDue ? "Check In" : "Open") {
                    onCheckIn()
                }
                .buttonStyle(.borderedProminent)
            }

            if let whyItMatters = promise.whyItMatters {
                Text(whyItMatters)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let expectedFriction = promise.expectedFriction {
                Label(expectedFriction, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PromiseStatView: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PromiseFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var startAt = Date()
    @State private var checkInAt = Date().addingTimeInterval(60 * 60)
    @State private var whyItMatters = ""
    @State private var expectedFriction = ""

    let onSave: (Promise) -> Void

    var body: some View {
        Form {
            Section("Promise") {
                TextField("Title", text: $title)
                TextField("Why it matters", text: $whyItMatters, axis: .vertical)
                TextField("Expected friction or excuse", text: $expectedFriction, axis: .vertical)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section("Timing") {
                DatePicker("Starts", selection: $startAt)
                DatePicker("Check In", selection: $checkInAt)
            }
        }
        .navigationTitle("New Promise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        Promise(
                            title: title,
                            notes: notes,
                            startAt: startAt,
                            checkInAt: checkInAt,
                            whyItMatters: whyItMatters,
                            expectedFriction: expectedFriction
                        )
                    )
                }
                .disabled(Promise.cleanedTitle(from: title) == nil)
            }
        }
    }
}

private struct PromiseCheckInView: View {
    @Environment(\.dismiss) private var dismiss

    let promise: Promise
    let onResolve: (PromiseOutcome, String?) -> Void
    let onReset: (String, Date) -> Void

    @State private var reflection = ""
    @State private var resetTitle = ""
    @State private var resetCheckInAt = Date().addingTimeInterval(60 * 60)

    var body: some View {
        Form {
            Section("Promise") {
                Text(promise.title)
                if let whyItMatters = promise.whyItMatters {
                    Text(whyItMatters)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Check In") {
                TextField("What happened?", text: $reflection, axis: .vertical)
                Button {
                    onResolve(.kept, reflection)
                } label: {
                    Label("Kept", systemImage: "checkmark.circle.fill")
                }
                Button {
                    onResolve(.missed, reflection)
                } label: {
                    Label("Missed", systemImage: "exclamationmark.circle.fill")
                }
            }

            Section("Reset") {
                TextField("Reset promise", text: $resetTitle)
                DatePicker("Check In", selection: $resetCheckInAt)
                Button {
                    onReset(resetTitle, resetCheckInAt)
                } label: {
                    Label("Create Reset Promise", systemImage: "arrow.clockwise")
                }
                .disabled(Promise.cleanedTitle(from: resetTitle) == nil)
            }
        }
        .navigationTitle("Check In")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            resetTitle = promise.title
        }
    }
}

private struct RoutineBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var notes = ""
    @State private var itemText = ""
    @State private var selectedWeekdays: Set<RoutineWeekday> = []

    let onSave: (Routine) -> Void

    var body: some View {
        Form {
            Section("Routine") {
                TextField("Name", text: $name)
                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section("Days") {
                Toggle("Daily", isOn: dailyBinding)
                if selectedWeekdays.isEmpty == false {
                    ForEach(RoutineWeekday.allCases, id: \.self) { weekday in
                        Toggle(weekday.shortName, isOn: weekdayBinding(for: weekday))
                    }
                }
            }

            Section("Items") {
                TextEditor(text: $itemText)
                    .frame(minHeight: 120)
                Text("One item per line")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("New Routine")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let routine = Routine(
                        newName: name,
                        itemTitles: itemText.components(separatedBy: .newlines),
                        activeWeekdays: Array(selectedWeekdays)
                    ) else {
                        return
                    }

                    var routineWithNotes = routine
                    routineWithNotes.notes = MyTask.cleanedOptionalText(from: notes)
                    onSave(routineWithNotes)
                }
                .disabled(Routine.cleanedName(from: name) == nil || cleanedItemTitles.isEmpty)
            }
        }
    }

    private var cleanedItemTitles: [String] {
        itemText.components(separatedBy: .newlines).compactMap(RoutineItem.cleanedTitle)
    }

    private var dailyBinding: Binding<Bool> {
        Binding(
            get: { selectedWeekdays.isEmpty },
            set: { isDaily in
                selectedWeekdays = isDaily ? [] : Set(RoutineWeekday.allCases)
            }
        )
    }

    private func weekdayBinding(for weekday: RoutineWeekday) -> Binding<Bool> {
        Binding(
            get: { selectedWeekdays.contains(weekday) },
            set: { isSelected in
                if isSelected {
                    selectedWeekdays.insert(weekday)
                } else {
                    selectedWeekdays.remove(weekday)
                }
            }
        )
    }
}

private struct RoutineSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HomeExecutionViewModel
    @State private var currentIndex = 0
    @State private var presentedLinkSheet: RoutineStepLinkSheet?
    @State private var pendingLinkStepID: UUID?
    @State private var isShowingLinkPicker = false

    let registry: HomeWidgetRegistry
    let taskRepository: any TaskRepository
    let projectRepository: any ProjectRepository
    let captureRepository: any CaptureRepository
    let projectItemRepository: any ProjectItemRepository
    let scheduledBlockRepository: any ScheduledBlockRepository
    let settingsRepository: any SettingsRepository
    let calendarPermissionProvider: any CalendarPermissionProviding
    let calendarListingService: any CalendarListing
    let calendarReader: any CalendarReading
    let calendarWriter: any CalendarWriting
    let calendarReconciler: any CalendarReconciling
    let calendarChangeObserver: any CalendarChangeObserving
    let promiseRepository: any PromiseRepository
    let shoppingRepository: any ShoppingRepository
    let healthRepository: any HealthRepository
    let musicPracticeRepository: any MusicPracticeRepository
    let fitnessRepository: any FitnessRepository
    let peopleMemoryRepository: any PeopleMemoryRepository
    let routineID: UUID

    var body: some View {
        Group {
            if let progress = viewModel.progress(for: routineID) {
                let steps = progress.routine.orderedItems
                let isFinished = steps.isEmpty || currentIndex >= steps.count

                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(progress.routine.name)
                            .font(.title3.weight(.semibold))

                        Text(progressText(totalCount: steps.count, isFinished: isFinished))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ProgressView(
                            value: Double(progress.completedCount + progress.skippedCount),
                            total: Double(max(progress.totalCount, 1))
                        )
                    }

                    Spacer()

                    if isFinished {
                        VStack(alignment: .center, spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 56))
                                .foregroundStyle(.green)

                            Text("Routine Complete")
                                .font(.title2.weight(.semibold))

                            Text("Completed \(progress.completedCount) · Skipped \(progress.skippedCount)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else if steps.indices.contains(currentIndex) {
                        let item = steps[currentIndex]
                        let state = progress.completionLog?.state(for: item.id) ?? .untouched

                        VStack(alignment: .leading, spacing: 14) {
                            Text(item.title)
                                .font(.title2.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if state != .untouched {
                                Text(stateLabel(for: state))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(state == .completed ? .green : .orange)
                            }
                        }
                        .padding(18)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        routineStepLinksSection(progress: progress, item: item)

                        HStack(spacing: 12) {
                            Button("Back") {
                                currentIndex = max(0, currentIndex - 1)
                            }
                            .buttonStyle(.bordered)
                            .disabled(currentIndex == 0)

                            Button("Skip") {
                                advance(stepID: item.id, state: .skipped, totalCount: steps.count)
                            }
                            .buttonStyle(.bordered)

                            Button(isLastStep(totalCount: steps.count) ? "Done" : "Next") {
                                advance(stepID: item.id, state: .completed, totalCount: steps.count)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("Routine")
                .navigationBarTitleDisplayMode(.inline)
                .confirmationDialog(
                    "Add Routine Link",
                    isPresented: $isShowingLinkPicker,
                    titleVisibility: .visible
                ) {
                    if moduleLinkDescriptors.isEmpty {
                        Button("No Available Module Links") {}
                            .disabled(true)
                    } else {
                        ForEach(moduleLinkDescriptors, id: \.kind) { descriptor in
                            Button(descriptor.displayName) {
                                addModuleLink(descriptor: descriptor)
                            }
                        }
                    }
                }
                .sheet(item: $presentedLinkSheet) { sheet in
                    NavigationStack {
                        switch sheet {
                        case .promiseCheckIn(let promise):
                            PromiseCheckInView(
                                promise: promise,
                                onResolve: { outcome, reflection in
                                    viewModel.resolvePromise(
                                        withID: promise.id,
                                        outcome: outcome,
                                        reflection: reflection
                                    )
                                    presentedLinkSheet = nil
                                },
                                onReset: { title, checkInAt in
                                    viewModel.makeResetPromise(
                                        from: promise,
                                        title: title,
                                        checkInAt: checkInAt
                                    )
                                    presentedLinkSheet = nil
                                }
                            )
                        case .promiseForm:
                            PromiseFormView { promise in
                                viewModel.savePromise(promise)
                                presentedLinkSheet = nil
                            }
                        case .routineBuilder:
                            RoutineBuilderView { routine in
                                viewModel.saveRoutine(routine)
                                presentedLinkSheet = nil
                            }
                        case .tasks:
                            TaskListView(
                                taskRepository: taskRepository,
                                projectRepository: projectRepository,
                                scheduledBlockRepository: scheduledBlockRepository,
                                calendarWriter: calendarWriter,
                                promiseRepository: promiseRepository
                            )
                        case .planner:
                            PlannerView(
                                taskRepository: taskRepository,
                                scheduledBlockRepository: scheduledBlockRepository,
                                settingsRepository: settingsRepository,
                                calendarPermissionProvider: calendarPermissionProvider,
                                calendarListingService: calendarListingService,
                                calendarReader: calendarReader,
                                calendarWriter: calendarWriter,
                                calendarReconciler: calendarReconciler,
                                calendarChangeObserver: calendarChangeObserver,
                                promiseRepository: promiseRepository,
                                navigationTitle: "Plan the Day"
                            )
                        case .projects:
                            ProjectsView(
                                taskRepository: taskRepository,
                                projectRepository: projectRepository,
                                captureRepository: captureRepository,
                                projectItemRepository: projectItemRepository
                            )
                        case .shoppingList:
                            ShoppingListView(shoppingRepository: shoppingRepository) {
                                viewModel.load()
                            }
                        case .health:
                            HealthView(
                                healthRepository: healthRepository,
                                fitnessRepository: fitnessRepository
                            ) {
                                viewModel.load()
                            }
                        case .musicPractice:
                            MusicPracticeView(musicPracticeRepository: musicPracticeRepository) {
                                viewModel.load()
                            }
                        case .fitness:
                            FitnessView(fitnessRepository: fitnessRepository) {
                                viewModel.load()
                            }
                        case .peopleMemory:
                            PeopleMemoryView(peopleMemoryRepository: peopleMemoryRepository) {
                                viewModel.load()
                            }
                        case .pvtTest:
                            PVTTestView { session in
                                do {
                                    try healthRepository.savePVTSession(session)
                                    viewModel.load()
                                    presentedLinkSheet = nil
                                } catch {
                                    viewModel.reportError("Unable to save PVT session: \(error.localizedDescription)")
                                }
                            }
                        case .unavailable(let title, let message):
                            RoutineLinkUnavailableView(title: title, message: message)
                        }
                    }
                }
                .onAppear {
                    alignCurrentIndex(with: progress)
                }
                .onChange(of: progress.completionLog) { _, _ in
                    alignCurrentIndex(with: progress)
                }
            } else {
                ContentUnavailableView(
                    "Routine Not Available",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This routine is no longer active today.")
                )
                .navigationTitle("Routine")
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func routineStepLinksSection(
        progress: HomeRoutineProgress,
        item: RoutineItem
    ) -> some View {
        let links = progress.routine.orderedStepLinks(for: item.id)

        VStack(alignment: .leading, spacing: 10) {
            Text("Routine Links")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if links.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        pendingLinkStepID = item.id
                        isShowingLinkPicker = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .padding(10)
                            .background(.quaternary.opacity(0.4), in: Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(links) { link in
                        RoutineStepLinkCard(
                            link: link,
                            iconSystemName: descriptor(for: link)?.iconSystemName,
                            onOpen: { open(link: link) },
                            onRemove: { remove(linkID: link.id, from: progress.routine) }
                        )
                    }

                    Button {
                        pendingLinkStepID = item.id
                        isShowingLinkPicker = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var moduleLinkDescriptors: [HomeWidgetDescriptor] {
        registry.availableRoutineModuleLinkDescriptors
    }

    private func progressText(totalCount: Int, isFinished: Bool) -> String {
        guard totalCount > 0 else {
            return "0 / 0"
        }

        let position = isFinished ? totalCount : min(currentIndex + 1, totalCount)
        return "\(position) / \(totalCount)"
    }

    private func stateLabel(for state: RoutineStepCompletionState) -> String {
        switch state {
        case .untouched:
            return ""
        case .completed:
            return "Completed"
        case .skipped:
            return "Skipped"
        }
    }

    private func isLastStep(totalCount: Int) -> Bool {
        currentIndex == totalCount - 1
    }

    private func advance(stepID: UUID, state: RoutineStepCompletionState, totalCount: Int) {
        viewModel.setRoutineItem(routineID: routineID, itemID: stepID, state: state)
        currentIndex = min(currentIndex + 1, totalCount)
    }

    private func alignCurrentIndex(with progress: HomeRoutineProgress) {
        let steps = progress.routine.orderedItems
        if currentIndex >= steps.count {
            return
        }

        if let firstUntouchedIndex = steps.firstIndex(where: {
            (progress.completionLog?.state(for: $0.id) ?? .untouched) == .untouched
        }) {
            currentIndex = max(currentIndex, firstUntouchedIndex)
        } else {
            currentIndex = steps.count
        }
    }

    private func addModuleLink(descriptor: HomeWidgetDescriptor) {
        guard let progress = viewModel.progress(for: routineID),
              let stepID = pendingLinkStepID else {
            return
        }

        let nextOrder = progress.routine.orderedStepLinks(for: stepID).count
        var updatedRoutine = progress.routine
        updatedRoutine.stepLinks.append(
            RoutineStepLink(
                routineStepID: stepID,
                kind: .moduleWidget,
                moduleWidgetKind: descriptor.kind,
                displayTitle: descriptor.displayName,
                displayOrder: nextOrder
            )
        )
        viewModel.saveRoutine(updatedRoutine, replacingRoutineWithID: updatedRoutine.id)
    }

    private func remove(linkID: UUID, from routine: Routine) {
        var updatedRoutine = routine
        updatedRoutine.stepLinks.removeAll { $0.id == linkID }
        updatedRoutine.stepLinks = reindexedLinks(updatedRoutine.stepLinks)
        viewModel.saveRoutine(updatedRoutine, replacingRoutineWithID: updatedRoutine.id)
    }

    private func reindexedLinks(_ links: [RoutineStepLink]) -> [RoutineStepLink] {
        let grouped = Dictionary(grouping: links, by: \.routineStepID)
        return grouped.values.flatMap { group in
            group
                .sorted {
                    if $0.displayOrder != $1.displayOrder {
                        return $0.displayOrder < $1.displayOrder
                    }

                    return $0.id.uuidString < $1.id.uuidString
                }
                .enumerated()
                .map { index, link in
                    RoutineStepLink(
                        id: link.id,
                        routineStepID: link.routineStepID,
                        kind: link.kind,
                        moduleWidgetKind: link.moduleWidgetKind,
                        displayTitle: link.displayTitle,
                        displayOrder: index
                    )
                }
        }
    }

    private func open(link: RoutineStepLink) {
        switch link.kind {
        case .pvtTest:
            presentedLinkSheet = .pvtTest
        case .promiseCheckIn:
            if let promise = viewModel.duePromises.first ?? viewModel.activePromises.first {
                presentedLinkSheet = .promiseCheckIn(promise)
            } else {
                presentedLinkSheet = .unavailable(
                    title: "No Active Promises",
                    message: "Create or start a promise first, then reopen this link from the routine step."
                )
            }
        case .moduleWidget:
            guard let descriptor = descriptor(for: link),
                  descriptor.isAvailable,
                  descriptor.isModuleWidget,
                  let action = descriptor.defaultAction else {
                presentedLinkSheet = .unavailable(
                    title: "Module Link Unavailable",
                    message: "This module link is no longer available in this version of the app."
                )
                return
            }

            openModuleAction(action)
        }
    }

    private func descriptor(for link: RoutineStepLink) -> HomeWidgetDescriptor? {
        guard link.kind == .moduleWidget,
              let widgetKind = link.moduleWidgetKind else {
            return nil
        }

        return registry.descriptor(for: widgetKind)
    }

    private func openModuleAction(_ action: HomeWidgetDefaultAction) {
        switch action {
        case .openTasks:
            presentedLinkSheet = .tasks
        case .openPlanner:
            presentedLinkSheet = .planner
        case .openProjects:
            presentedLinkSheet = .projects
        case .newPromise:
            presentedLinkSheet = .promiseForm
        case .newRoutine:
            presentedLinkSheet = .routineBuilder
        case .openShopping:
            presentedLinkSheet = .shoppingList
        case .openHealth:
            presentedLinkSheet = .health
        case .openMusicPractice:
            presentedLinkSheet = .musicPractice
        case .openFitness:
            presentedLinkSheet = .fitness
        case .openPeopleMemory:
            presentedLinkSheet = .peopleMemory
        case .openDebriefs:
            presentedLinkSheet = .unavailable(
                title: "Module Link Not Supported",
                message: "Debrief links are not available from routine steps yet."
            )
        case .openCapture,
             .reviewInbox,
             .openConfiguredProject,
             .checkInDuePromise,
             .openConfiguredRoutine,
             .quickAddShopping:
            presentedLinkSheet = .unavailable(
                title: "Module Link Not Supported",
                message: "This widget action cannot be opened from a routine link."
            )
        }
    }
}

private enum RoutineStepLinkSheet: Identifiable {
    case promiseCheckIn(Promise)
    case pvtTest
    case promiseForm
    case routineBuilder
    case tasks
    case planner
    case projects
    case shoppingList
    case health
    case musicPractice
    case fitness
    case peopleMemory
    case unavailable(title: String, message: String)

    var id: String {
        switch self {
        case .promiseCheckIn(let promise):
            return "promise-\(promise.id.uuidString)"
        case .pvtTest:
            return "pvt-test"
        case .promiseForm:
            return "promise-form"
        case .routineBuilder:
            return "routine-builder"
        case .tasks:
            return "tasks"
        case .planner:
            return "planner"
        case .projects:
            return "projects"
        case .shoppingList:
            return "shopping-list"
        case .health:
            return "health"
        case .musicPractice:
            return "music-practice"
        case .fitness:
            return "fitness"
        case .peopleMemory:
            return "people-memory"
        case .unavailable(let title, _):
            return "unavailable-\(title)"
        }
    }
}

private struct RoutineStepLinkCard: View {
    let link: RoutineStepLink
    let iconSystemName: String?
    let onOpen: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button {
                onOpen()
            } label: {
                HStack(spacing: 8) {
                    if let iconSystemName {
                        Image(systemName: iconSystemName)
                            .foregroundStyle(.secondary)
                    }

                    Text(link.displayTitle)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct RoutineLinkUnavailableView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: "rectangle.on.rectangle.slash",
            description: Text(message)
        )
        .navigationTitle("Routine Link")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct HomeInboxCard: View {
    let summary: HomeInboxSummary
    let onCapture: () -> Void
    let onReview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Inbox", systemImage: "tray.full.fill")
                        .font(.headline)

                    Text(summaryText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if summary.count > 0 {
                    Text("\(summary.count)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                }
            }

            HStack(spacing: 10) {
                Button {
                    onReview()
                } label: {
                    Label("Review", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(summary.count == 0)

                Button {
                    onCapture()
                } label: {
                    Label("Capture", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(inboxBackgroundColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(summary.count == 0 ? 0.08 : 0.18), lineWidth: 1)
        )
    }

    private var summaryText: String {
        guard summary.count > 0 else {
            return "Clear. New ideas can land here without becoming tasks yet."
        }

        var parts = ["\(summary.count) unprocessed capture\(summary.count == 1 ? "" : "s")"]
        if let oldestAgeLabel = summary.oldestAgeLabel {
            parts.append("oldest \(oldestAgeLabel)")
        }
        if summary.projectTaggedCount > 0 {
            parts.append("\(summary.projectTaggedCount) project-tagged")
        }

        return parts.joined(separator: " • ")
    }

    private var inboxBackgroundColor: Color {
        if summary.count >= 8 {
            return Color.orange.opacity(0.12)
        }

        if summary.count > 0 {
            return Color.blue.opacity(0.08)
        }

        return Color.primary.opacity(0.035)
    }
}

struct HomePinnedProjectCard: View {
    let summary: HomePinnedProjectSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(summary.project.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let projectSummary = summary.project.summary {
                Text(projectSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 10) {
                Label("\(summary.activeTaskCount)", systemImage: "checklist")
                Label("\(summary.projectItemCount)", systemImage: "sparkle.magnifyingglass")
                Text(summary.progressSummary)
                if let nextTask = summary.nextTask {
                    Text("Next: \(nextTask.title)")
                        .lineLimit(1)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct CaptureQuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTitleFocused: Bool
    @State private var title = ""
    @State private var selectedProjectID: UUID?

    let projects: [Project]
    let onSave: (CaptureItem) -> Void

    var body: some View {
        Form {
            Section("Capture") {
                TextField("Jot it down", text: $title, axis: .vertical)
                    .lineLimit(2...5)
                    .focused($isTitleFocused)

                if projects.isEmpty == false {
                    Picker("Project", selection: $selectedProjectID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(projects) { project in
                            Text(project.name).tag(project.id as UUID?)
                        }
                    }
                }
            }
        }
        .navigationTitle("Quick Capture")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let capture = CaptureItem(newTitle: title, projectID: selectedProjectID) else {
                        return
                    }

                    onSave(capture)
                }
                .disabled(CaptureItem.cleanedTitle(from: title) == nil)
            }
        }
        .onAppear {
            isTitleFocused = true
        }
    }
}

private struct CaptureQuickAddPopover: View {
    @FocusState private var isTitleFocused: Bool
    @State private var title = ""
    @State private var selectedProjectID: UUID?

    let projects: [Project]
    let onCancel: () -> Void
    let onSave: (CaptureItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Capture")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.subheadline.weight(.medium))
            }

            TextField("Jot it down", text: $title, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)
                .focused($isTitleFocused)

            if projects.isEmpty == false {
                Picker("Project", selection: $selectedProjectID) {
                    Text("None").tag(nil as UUID?)
                    ForEach(projects) { project in
                        Text(project.name).tag(project.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Spacer()
                Button {
                    guard let capture = CaptureItem(newTitle: title, projectID: selectedProjectID) else {
                        return
                    }

                    onSave(capture)
                } label: {
                    Label("Save", systemImage: "tray.and.arrow.down.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(CaptureItem.cleanedTitle(from: title) == nil)
            }
        }
        .padding(18)
        .frame(maxWidth: 360, alignment: .topLeading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 10)
        .onAppear {
            isTitleFocused = true
        }
    }
}

private enum InboxConversionMode: String, CaseIterable, Identifiable {
    case task
    case shopping
    case maybe
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .task:
            return "Task"
        case .shopping:
            return "Shopping"
        case .maybe:
            return "Maybe"
        case .note:
            return "Note"
        }
    }
}

@MainActor
final class InboxReviewViewModel: ObservableObject {
    @Published private(set) var captures: [CaptureItem]
    @Published private(set) var projects: [Project]
    @Published private(set) var errorMessage: String?
    @Published var selectedIndex = 0

    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository
    private let shoppingRepository: any ShoppingRepository
    private let nowProvider: @Sendable () -> Date

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        shoppingRepository: any ShoppingRepository,
        initialCaptures: [CaptureItem],
        initialProjects: [Project],
        nowProvider: @escaping @Sendable () -> Date = Date.init
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
        self.shoppingRepository = shoppingRepository
        self.captures = initialCaptures
        self.projects = initialProjects
        self.nowProvider = nowProvider
    }

    var currentCapture: CaptureItem? {
        guard captures.indices.contains(selectedIndex) else {
            return nil
        }

        return captures[selectedIndex]
    }

    func load() {
        do {
            captures = try captureRepository.fetchCaptures(
                includeProcessed: false,
                includeArchived: false
            )
            projects = try projectRepository.fetchProjects(includeArchived: false)
            selectedIndex = min(selectedIndex, max(captures.count - 1, 0))
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load inbox: \(error.localizedDescription)"
        }
    }

    func createProject(named name: String) -> Project? {
        guard let project = Project(newName: name) else {
            return nil
        }

        do {
            try projectRepository.saveProject(project, replacingProjectWithID: nil)
            projects = try projectRepository.fetchProjects(includeArchived: false)
            return project
        } catch {
            errorMessage = "Unable to create project: \(error.localizedDescription)"
            return nil
        }
    }

    func convertCurrentCaptureToTask(_ formData: MyTaskFormData) -> Bool {
        guard var capture = currentCapture, let task = formData.makeTask(savedAt: nowProvider()) else {
            return false
        }

        do {
            try taskRepository.saveTask(task, replacingTaskWithID: nil)
            capture.markProcessed(at: nowProvider(), convertedTaskID: task.id)
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to create task: \(error.localizedDescription)"
            return false
        }
    }

    func convertCurrentCaptureToProjectItem(
        kind: ProjectItemKind,
        title: String,
        notes: String?,
        projectID: UUID?,
        source: String?,
        pressure: ProjectItemPressure?,
        reviewAfter: Date?
    ) -> Bool {
        guard var capture = currentCapture, let projectID else {
            errorMessage = "Choose a project first."
            return false
        }

        guard ProjectItem.cleanedTitle(from: title) != nil else {
            errorMessage = "Enter a title."
            return false
        }

        do {
            let item = ProjectItem(
                projectID: projectID,
                kind: kind,
                title: title,
                notes: notes,
                source: source,
                pressure: kind == .maybe ? pressure : nil,
                reviewAfter: kind == .maybe ? reviewAfter : nil,
                createdAt: nowProvider()
            )
            try projectItemRepository.saveProjectItem(item, replacingProjectItemWithID: nil)
            capture.markProcessed(at: nowProvider(), convertedProjectItemID: item.id)
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to save project item: \(error.localizedDescription)"
            return false
        }
    }

    func convertCurrentCaptureToShoppingItem(_ formData: ShoppingItemFormData) -> Bool {
        guard var capture = currentCapture else {
            return false
        }

        let now = nowProvider()
        guard let item = formData.makeItem(createdAt: now, updatedAt: now) else {
            errorMessage = "Enter a shopping item title."
            return false
        }

        do {
            try shoppingRepository.saveShoppingItem(item, replacingItemWithID: nil)
            capture.markProcessed(at: now)
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to create shopping item: \(error.localizedDescription)"
            return false
        }
    }

    func archiveCurrentCapture() -> Bool {
        guard var capture = currentCapture else {
            return false
        }

        do {
            capture.archive(at: nowProvider())
            try captureRepository.saveCapture(capture, replacingCaptureWithID: capture.id)
            load()
            return true
        } catch {
            errorMessage = "Unable to archive capture: \(error.localizedDescription)"
            return false
        }
    }
}

struct InboxReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: InboxReviewViewModel
    @State private var mode: InboxConversionMode = .task
    @State private var taskFormData = MyTaskFormData()
    @State private var itemTitle = ""
    @State private var itemNotes = ""
    @State private var itemSource = ""
    @State private var itemPressure: ProjectItemPressure? = .noPressure
    @State private var itemHasReviewDate = false
    @State private var itemReviewAfter = Date()
    @State private var shoppingFormData = ShoppingItemFormData()
    @State private var selectedProjectID: UUID?
    @State private var newProjectName = ""
    @State private var showsTaskDetails = false
    @State private var showsItemDetails = false
    let onInboxChanged: () -> Void
    let onDone: () -> Void

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository,
        shoppingRepository: any ShoppingRepository,
        initialCaptures: [CaptureItem],
        initialProjects: [Project],
        onInboxChanged: @escaping () -> Void = {},
        onDone: @escaping () -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: InboxReviewViewModel(
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                captureRepository: captureRepository,
                projectItemRepository: projectItemRepository,
                shoppingRepository: shoppingRepository,
                initialCaptures: initialCaptures,
                initialProjects: initialProjects
            )
        )
        self.onInboxChanged = onInboxChanged
        self.onDone = onDone
    }

    var body: some View {
        Group {
            if let capture = viewModel.currentCapture {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        captureCard(capture)
                        Picker("Convert", selection: $mode) {
                            ForEach(InboxConversionMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        conversionForm(for: capture)

                        Button(role: .destructive) {
                            if viewModel.archiveCurrentCapture() {
                                onInboxChanged()
                                resetDrafts()
                            }
                        } label: {
                            Label("Archive Capture", systemImage: "archivebox")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "Inbox Clear",
                    systemImage: "tray",
                    description: Text("Captured thoughts are reviewed.")
                )
            }
        }
        .navigationTitle("Review Inbox")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    onInboxChanged()
                    onDone()
                    dismiss()
                }
            }
        }
        .onAppear {
            viewModel.load()
            resetDrafts()
        }
        .onChange(of: viewModel.currentCapture?.id) { _, _ in
            resetDrafts()
        }
        .onDisappear {
            onInboxChanged()
        }
    }

    private func captureCard(_ capture: CaptureItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(capture.title)
                .font(.title3.weight(.semibold))
            if let source = capture.source {
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(capture.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func conversionForm(for capture: CaptureItem) -> some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        }

        switch mode {
        case .task:
            taskConversionForm
        case .shopping:
            shoppingConversionForm
        case .maybe:
            projectItemConversionForm(kind: .maybe)
        case .note:
            projectItemConversionForm(kind: .note)
        }
    }

    private var taskConversionForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Essential Details")
                    .font(.headline)

                inboxLabeledField("Title") {
                    TextField("What needs to happen?", text: $taskFormData.title)
                        .textFieldStyle(.roundedBorder)
                }

                inboxLabeledField("Project") {
                    projectPicker(selection: $taskFormData.projectID, requiresProject: false)
                }

                inboxLabeledField("Duration") {
                    EstimatedDurationControl(estimatedMinutesText: $taskFormData.estimatedMinutesText)
                }
            }

            DisclosureGroup(isExpanded: $showsTaskDetails) {
                VStack(alignment: .leading, spacing: 14) {
                    inboxLabeledField("Notes") {
                        TextField("Optional context", text: $taskFormData.notesText, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...5)
                    }

                    DisclosureGroup("Schedule and Status") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Set Due Date", isOn: $taskFormData.hasDueDate)
                            if taskFormData.hasDueDate {
                                inboxLabeledField("Due") {
                                    DatePicker(
                                        "Due",
                                        selection: $taskFormData.dueDate,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .labelsHidden()
                                }
                            }

                            Picker("Status", selection: $taskFormData.status) {
                                ForEach(TaskStatus.allCases, id: \.self) { status in
                                    Text(status.displayName).tag(status)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }

                    DisclosureGroup("Planning Context") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Priority", selection: $taskFormData.priority) {
                                Text("None").tag(nil as PriorityLevel?)
                                ForEach(PriorityLevel.allCases, id: \.self) { priority in
                                    Text(priority.displayName).tag(priority as PriorityLevel?)
                                }
                            }

                            Picker("Energy", selection: $taskFormData.energyLevel) {
                                Text("None").tag(nil as EnergyLevel?)
                                ForEach(EnergyLevel.allCases, id: \.self) { energy in
                                    Text(energy.displayName).tag(energy as EnergyLevel?)
                                }
                            }

                            Picker("Mode", selection: $taskFormData.workMode) {
                                Text("None").tag(nil as WorkModeKind?)
                                ForEach(WorkModeKind.allCases, id: \.self) { workMode in
                                    Text(workMode.displayName).tag(workMode as WorkModeKind?)
                                }
                            }

                            inboxLabeledField("Tags") {
                                TextField("Comma-separated tags", text: $taskFormData.tagsText)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 10)
            } label: {
                Label("Detailed Task Info", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
            }

            Button {
                if viewModel.convertCurrentCaptureToTask(taskFormData) {
                    onInboxChanged()
                }
            } label: {
                Label("Create Task", systemImage: "checklist")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(taskFormData.validationMessage(reservedTaskIDs: []) != nil)
        }
    }

    private func projectItemConversionForm(kind: ProjectItemKind) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Essential Details")
                    .font(.headline)

                inboxLabeledField("Title") {
                    TextField("\(kind.displayName) title", text: $itemTitle)
                        .textFieldStyle(.roundedBorder)
                }

                inboxLabeledField("Project") {
                    projectPicker(selection: $selectedProjectID, requiresProject: true)
                }
            }

            DisclosureGroup(isExpanded: $showsItemDetails) {
                VStack(alignment: .leading, spacing: 14) {
                    inboxLabeledField("Notes") {
                        TextField("Optional context", text: $itemNotes, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...5)
                    }

                    inboxLabeledField("Source") {
                        TextField("Where did this come from?", text: $itemSource)
                            .textFieldStyle(.roundedBorder)
                    }

                    if kind == .maybe {
                        DisclosureGroup("Review Settings") {
                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Pressure", selection: $itemPressure) {
                                    Text("None").tag(nil as ProjectItemPressure?)
                                    ForEach(ProjectItemPressure.allCases, id: \.self) { pressure in
                                        Text(pressure.displayName).tag(pressure as ProjectItemPressure?)
                                    }
                                }

                                Toggle("Review Later", isOn: $itemHasReviewDate)
                                if itemHasReviewDate {
                                    inboxLabeledField("Review") {
                                        DatePicker(
                                            "Review",
                                            selection: $itemReviewAfter,
                                            displayedComponents: [.date]
                                        )
                                        .labelsHidden()
                                    }
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.top, 10)
            } label: {
                Label("Detailed \(kind.displayName) Info", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
            }

            Button {
                if viewModel.convertCurrentCaptureToProjectItem(
                    kind: kind,
                    title: itemTitle,
                    notes: itemNotes,
                    projectID: selectedProjectID,
                    source: itemSource,
                    pressure: itemPressure,
                    reviewAfter: itemHasReviewDate ? itemReviewAfter : nil
                ) {
                    onInboxChanged()
                }
            } label: {
                Label("Save \(kind.displayName)", systemImage: kind == .maybe ? "sparkle.magnifyingglass" : "note.text")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(ProjectItem.cleanedTitle(from: itemTitle) == nil || selectedProjectID == nil)
        }
    }

    private func inboxLabeledField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }

    private var shoppingConversionForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Item")
                    .font(.headline)

                TextField("Shopping item", text: $shoppingFormData.title)
                    .textFieldStyle(.roundedBorder)
                TextField("Notes", text: $shoppingFormData.notes, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Trip")
                    .font(.headline)

                shoppingSuggestionField(
                    title: "Category",
                    text: $shoppingFormData.category,
                    suggestions: ShoppingItemFieldSuggestions.categories
                )
                shoppingSuggestionField(
                    title: "Store Type",
                    text: $shoppingFormData.storeType,
                    suggestions: ShoppingItemFieldSuggestions.storeTypes
                )
                shoppingSuggestionField(
                    title: "Store",
                    text: $shoppingFormData.storeName,
                    suggestions: ShoppingItemFieldSuggestions.storeNames
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Priority")
                    .font(.headline)

                Picker("Urgency", selection: $shoppingFormData.urgency) {
                    ForEach(ShoppingUrgency.allCases, id: \.self) { urgency in
                        Text(urgency.displayName).tag(urgency)
                    }
                }

                Picker("Necessity", selection: $shoppingFormData.necessity) {
                    ForEach(ShoppingNecessity.allCases, id: \.self) { necessity in
                        Text(necessity.displayName).tag(necessity)
                    }
                }
            }

            Button {
                if viewModel.convertCurrentCaptureToShoppingItem(shoppingFormData) {
                    onInboxChanged()
                }
            } label: {
                Label("Add Shopping Item", systemImage: "cart")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(ShoppingItem.cleanedTitle(from: shoppingFormData.title) == nil)
        }
    }

    private func shoppingSuggestionField(
        title: String,
        text: Binding<String>,
        suggestions: [String]
    ) -> some View {
        HStack {
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)

            Menu {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        text.wrappedValue = suggestion
                    }
                }
            } label: {
                Image(systemName: "text.badge.plus")
            }
            .accessibilityLabel("\(title) Suggestions")
        }
    }

    private func projectPicker(selection: Binding<UUID?>, requiresProject: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(requiresProject ? "Project Required" : "Project", selection: selection) {
                if requiresProject == false {
                    Text("None").tag(nil as UUID?)
                }
                ForEach(viewModel.projects) { project in
                    Text(project.name).tag(project.id as UUID?)
                }
            }

            HStack(spacing: 8) {
                TextField("New project", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
                Button("Create") {
                    if let project = viewModel.createProject(named: newProjectName) {
                        selection.wrappedValue = project.id
                        newProjectName = ""
                    }
                }
                .disabled(Project.cleanedName(from: newProjectName) == nil)
            }
        }
    }

    private func resetDrafts() {
        guard let capture = viewModel.currentCapture else {
            return
        }

        taskFormData = MyTaskFormData(
            title: capture.title,
            projectID: capture.projectID
        )
        itemTitle = capture.title
        itemNotes = capture.notes ?? ""
        itemSource = capture.source ?? ""
        selectedProjectID = capture.projectID
        shoppingFormData = ShoppingItemFormData(
            title: capture.title,
            notes: capture.notes ?? ""
        )
        showsTaskDetails = false
        showsItemDetails = false
    }
}

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published private(set) var projects: [Project] = []
    @Published private(set) var tasks: [MyTask] = []
    @Published private(set) var captures: [CaptureItem] = []
    @Published private(set) var projectItems: [ProjectItem] = []
    @Published private(set) var errorMessage: String?

    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
    }

    func load() {
        do {
            projects = try projectRepository.fetchProjects(includeArchived: false)
            tasks = try taskRepository.fetchTasks()
            captures = try captureRepository.fetchCaptures(includeProcessed: false, includeArchived: false)
            projectItems = try projectItemRepository.fetchProjectItems(includeArchived: false)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load projects: \(error.localizedDescription)"
        }
    }

    func saveProject(_ project: Project, replacingProjectWithID originalID: UUID? = nil) {
        do {
            try projectRepository.saveProject(project, replacingProjectWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save project: \(error.localizedDescription)"
        }
    }
}

struct ProjectsView: View {
    @StateObject private var viewModel: ProjectsViewModel
    @State private var isProjectFormPresented = false

    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository

    init(
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
        _viewModel = StateObject(
            wrappedValue: ProjectsViewModel(
                taskRepository: taskRepository,
                projectRepository: projectRepository,
                captureRepository: captureRepository,
                projectItemRepository: projectItemRepository
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                if viewModel.projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder",
                        description: Text("Create a project for larger work that needs its own context.")
                    )
                } else {
                    ForEach(viewModel.projects) { project in
                        NavigationLink {
                            ProjectDetailView(
                                projectID: project.id,
                                taskRepository: taskRepository,
                                projectRepository: projectRepository,
                                captureRepository: captureRepository,
                                projectItemRepository: projectItemRepository
                            )
                        } label: {
                            ProjectListRow(
                                project: project,
                                taskSummary: project.taskSummary(from: viewModel.tasks),
                                itemCount: viewModel.projectItems.filter { $0.projectID == project.id }.count
                            )
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isProjectFormPresented = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isProjectFormPresented) {
                NavigationStack {
                    ProjectFormView { project in
                        viewModel.saveProject(project)
                        isProjectFormPresented = false
                    }
                }
            }
            .task {
                viewModel.load()
            }
            .onAppear {
                viewModel.load()
            }
        }
    }
}

private struct ProjectListRow: View {
    let project: Project
    let taskSummary: ProjectTaskSummary
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(project.name)
                    .font(.body.weight(.semibold))
                if project.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            if let summary = project.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text("\(taskSummary.progressSummary) • \(itemCount) project items")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let nextAction = taskSummary.nextAction {
                Text("Next: \(nextAction.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProjectDetailView: View {
    private enum SheetDestination: Identifiable {
        case capture
        case task
        case maybe
        case note
        case editProject(Project)

        var id: String {
            switch self {
            case .capture:
                return "capture"
            case .task:
                return "task"
            case .maybe:
                return "maybe"
            case .note:
                return "note"
            case .editProject(let project):
                return "edit-\(project.id.uuidString)"
            }
        }
    }

    let projectID: UUID
    private let taskRepository: any TaskRepository
    private let projectRepository: any ProjectRepository
    private let captureRepository: any CaptureRepository
    private let projectItemRepository: any ProjectItemRepository

    @State private var project: Project?
    @State private var tasks: [MyTask] = []
    @State private var captures: [CaptureItem] = []
    @State private var projectItems: [ProjectItem] = []
    @State private var errorMessage: String?
    @State private var sheetDestination: SheetDestination?

    init(
        projectID: UUID,
        taskRepository: any TaskRepository,
        projectRepository: any ProjectRepository,
        captureRepository: any CaptureRepository,
        projectItemRepository: any ProjectItemRepository
    ) {
        self.projectID = projectID
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
        self.captureRepository = captureRepository
        self.projectItemRepository = projectItemRepository
    }

    private var projectTasks: [MyTask] {
        projectTaskSummary?.activeTasks ?? []
    }

    private var nextTasks: [MyTask] {
        projectTaskSummary?.nextActions(limit: 3) ?? []
    }

    private var projectTaskSummary: ProjectTaskSummary? {
        project?.taskSummary(from: tasks)
    }

    private var maybes: [ProjectItem] {
        projectItems.filter { $0.projectID == projectID && $0.kind == .maybe && $0.isArchived == false }
    }

    private var notes: [ProjectItem] {
        projectItems.filter { $0.projectID == projectID && $0.kind == .note && $0.isArchived == false }
    }

    var body: some View {
        Group {
            if let project {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        overview(project)
                        taskSection(title: "Next Tasks", tasks: nextTasks)
                        taskSection(title: "All Tasks", tasks: projectTasks)
                        itemSection(title: "Maybes", items: maybes, emptyText: "No maybe items yet.")
                        itemSection(title: "Notes", items: notes, emptyText: "No project notes yet.")
                    }
                    .padding()
                }
                .navigationTitle(project.name)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Menu {
                            Button("Capture") { sheetDestination = .capture }
                            Button("Task") { sheetDestination = .task }
                            Button("Maybe") { sheetDestination = .maybe }
                            Button("Note") { sheetDestination = .note }
                        } label: {
                            Label("Add", systemImage: "plus")
                        }

                        Button {
                            sheetDestination = .editProject(project)
                        } label: {
                            Label("Edit Project", systemImage: "slider.horizontal.3")
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Project Not Found",
                    systemImage: "folder.badge.questionmark",
                    description: Text(errorMessage ?? "This project is no longer available.")
                )
            }
        }
        .sheet(item: $sheetDestination) { destination in
            NavigationStack {
                switch destination {
                case .capture:
                    CaptureQuickAddView(
                        projects: project.map { [$0] } ?? []
                    ) { capture in
                        var projectCapture = capture
                        projectCapture.projectID = projectID
                        saveCapture(projectCapture)
                        sheetDestination = nil
                    }
                case .task:
                    TaskFormView(
                        mode: .create,
                        initialFormData: MyTaskFormData(projectID: projectID),
                        projects: project.map { [$0] } ?? []
                    ) { task in
                        saveTask(task)
                        sheetDestination = nil
                    }
                case .maybe:
                    ProjectItemFormView(projectID: projectID, kind: .maybe) { item in
                        saveProjectItem(item)
                        sheetDestination = nil
                    }
                case .note:
                    ProjectItemFormView(projectID: projectID, kind: .note) { item in
                        saveProjectItem(item)
                        sheetDestination = nil
                    }
                case .editProject(let project):
                    ProjectFormView(initialProject: project) { updatedProject in
                        saveProject(updatedProject, replacingProjectWithID: project.id)
                        sheetDestination = nil
                    }
                }
            }
        }
        .task {
            load()
        }
        .onAppear {
            load()
        }
    }

    private func overview(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(project.isPinned ? "Pinned" : "Project", systemImage: project.isPinned ? "pin.fill" : "folder")
                    .font(.headline)
                Spacer()
                Button(project.isPinned ? "Unpin" : "Pin") {
                    var updatedProject = project
                    updatedProject.isPinned.toggle()
                    updatedProject.updatedAt = .now
                    saveProject(updatedProject, replacingProjectWithID: project.id)
                }
                .buttonStyle(.bordered)
            }

            if let summary = project.summary {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let taskSummary = projectTaskSummary {
                Text(taskSummary.progressSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let nextAction = taskSummary.nextAction {
                    Text("Next: \(nextAction.title)")
                        .font(.footnote.weight(.medium))
                        .lineLimit(2)
                }
            }

            HStack {
                ProjectMetricView(title: "Tasks", value: projectTaskSummary?.activeTaskCount ?? projectTasks.count)
                ProjectMetricView(title: "Done", value: projectTaskSummary?.completedActiveTaskCount ?? 0)
                ProjectMetricView(title: "Maybes", value: maybes.count)
                ProjectMetricView(title: "Notes", value: notes.count)
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private func taskSection(title: String, tasks: [MyTask]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if tasks.isEmpty {
                Text("No tasks here yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(tasks) { task in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.status == .completed ? .green : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.subheadline.weight(.medium))
                            if let dueDate = task.dueDate {
                                Text("Due \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func itemSection(title: String, items: [ProjectItem], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            if items.isEmpty {
                Text(emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                        if let notes = item.notes {
                            Text(notes)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if item.kind == .maybe, let pressure = item.pressure {
                            Text(pressure.displayName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func load() {
        do {
            project = try projectRepository.project(withID: projectID)
            tasks = try taskRepository.fetchTasks()
            captures = try captureRepository.fetchCaptures(includeProcessed: false, includeArchived: false)
            projectItems = try projectItemRepository.fetchProjectItems(for: projectID, includeArchived: false)
            errorMessage = nil
        } catch {
            errorMessage = "Unable to load project: \(error.localizedDescription)"
        }
    }

    private func saveProject(_ project: Project, replacingProjectWithID originalID: UUID?) {
        do {
            try projectRepository.saveProject(project, replacingProjectWithID: originalID)
            load()
        } catch {
            errorMessage = "Unable to save project: \(error.localizedDescription)"
        }
    }

    private func saveTask(_ task: MyTask) {
        do {
            try taskRepository.saveTask(task, replacingTaskWithID: nil)
            load()
        } catch {
            errorMessage = "Unable to save task: \(error.localizedDescription)"
        }
    }

    private func saveCapture(_ capture: CaptureItem) {
        do {
            try captureRepository.saveCapture(capture, replacingCaptureWithID: nil)
            load()
        } catch {
            errorMessage = "Unable to save capture: \(error.localizedDescription)"
        }
    }

    private func saveProjectItem(_ item: ProjectItem) {
        do {
            try projectItemRepository.saveProjectItem(item, replacingProjectItemWithID: nil)
            load()
        } catch {
            errorMessage = "Unable to save project item: \(error.localizedDescription)"
        }
    }
}

private struct ProjectMetricView: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProjectFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var summary: String
    @State private var isPinned: Bool
    let initialProject: Project?
    let onSave: (Project) -> Void

    init(initialProject: Project? = nil, onSave: @escaping (Project) -> Void) {
        self.initialProject = initialProject
        self.onSave = onSave
        _name = State(initialValue: initialProject?.name ?? "")
        _summary = State(initialValue: initialProject?.summary ?? "")
        _isPinned = State(initialValue: initialProject?.isPinned ?? false)
    }

    var body: some View {
        Form {
            Section("Project") {
                TextField("Name", text: $name)
                TextField("Summary", text: $summary, axis: .vertical)
                Toggle("Pin to Home", isOn: $isPinned)
            }
        }
        .navigationTitle(initialProject == nil ? "New Project" : "Edit Project")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let now = Date()
                    let project = Project(
                        id: initialProject?.id ?? UUID(),
                        name: name,
                        summary: summary,
                        isPinned: isPinned,
                        isArchived: initialProject?.isArchived ?? false,
                        createdAt: initialProject?.createdAt ?? now,
                        updatedAt: now
                    )
                    onSave(project)
                }
                .disabled(Project.cleanedName(from: name) == nil)
            }
        }
    }
}

private struct ProjectItemFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var source = ""
    @State private var pressure: ProjectItemPressure? = .noPressure
    @State private var hasReviewDate = false
    @State private var reviewAfter = Date()

    let projectID: UUID
    let kind: ProjectItemKind
    let onSave: (ProjectItem) -> Void

    var body: some View {
        Form {
            Section(kind.displayName) {
                TextField("Title", text: $title)
                TextField("Notes", text: $notes, axis: .vertical)
                TextField("Source", text: $source)
            }
            if kind == .maybe {
                Section("Review") {
                    Picker("Pressure", selection: $pressure) {
                        Text("None").tag(nil as ProjectItemPressure?)
                        ForEach(ProjectItemPressure.allCases, id: \.self) { pressure in
                            Text(pressure.displayName).tag(pressure as ProjectItemPressure?)
                        }
                    }
                    Toggle("Review Later", isOn: $hasReviewDate)
                    if hasReviewDate {
                        DatePicker("Review", selection: $reviewAfter, displayedComponents: [.date])
                    }
                }
            }
        }
        .navigationTitle("New \(kind.displayName)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(
                        ProjectItem(
                            projectID: projectID,
                            kind: kind,
                            title: title,
                            notes: notes,
                            source: source,
                            pressure: kind == .maybe ? pressure : nil,
                            reviewAfter: kind == .maybe && hasReviewDate ? reviewAfter : nil
                        )
                    )
                }
                .disabled(ProjectItem.cleanedTitle(from: title) == nil)
            }
        }
    }
}

#Preview {
    let container = AppContainer.makePreview()
    HomeView(
        taskRepository: container.taskRepository,
        projectRepository: container.projectRepository,
        captureRepository: container.captureRepository,
        projectItemRepository: container.projectItemRepository,
        scheduledBlockRepository: container.scheduledBlockRepository,
        settingsRepository: container.settingsRepository,
        homeLayoutRepository: container.homeLayoutRepository,
        calendarPermissionProvider: container.calendarPermissionProvider,
        calendarListingService: container.calendarListingService,
        calendarReader: container.calendarReader,
        calendarWriter: container.calendarWriter,
        calendarReconciler: container.calendarReconciler,
        calendarChangeObserver: container.calendarChangeObserver,
        promiseRepository: container.promiseRepository,
        routineRepository: container.routineRepository,
        shoppingRepository: container.shoppingRepository,
        healthRepository: container.healthRepository,
        musicPracticeRepository: container.musicPracticeRepository,
        fitnessRepository: container.fitnessRepository,
        peopleMemoryRepository: container.peopleMemoryRepository,
        debriefRepository: container.debriefRepository
    )
}
