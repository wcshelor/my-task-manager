import CoreData
import SwiftUI

struct TaskListView: View {
    @Environment(\.scenePhase) private var scenePhase

    private enum Destination: Hashable {
        case newTask
        case existingTask(UUID)
    }

    private enum SheetDestination: String, Identifiable {
        case quickAdd
        case detailedCreate

        var id: String { rawValue }
    }

    @StateObject private var viewModel: TaskListViewModel
    @State private var path: [Destination] = []
    @State private var presentedSheet: SheetDestination?
    @State private var newTaskDraft = MyTaskFormData()
    @State private var searchText = ""
    @State private var sortMode: TaskListSortMode = .createdDate
    @State private var groupMode: TaskListGroupMode = .none

    init(taskRepository: any TaskRepository) {
        _viewModel = StateObject(
            wrappedValue: TaskListViewModel(taskRepository: taskRepository)
        )
    }

    private var reservedTaskIDs: Set<UUID> {
        Set(viewModel.tasks.map(\.id))
    }

    private var filteredTasks: [MyTask] {
        TaskListOrganizer.filteredTasks(from: viewModel.tasks, searchText: searchText)
    }

    private var sortedTasks: [MyTask] {
        TaskListOrganizer.sortedTasks(filteredTasks, by: sortMode)
    }

    private var groupedSections: [TaskListSection] {
        TaskListOrganizer.groupedSections(
            from: filteredTasks,
            groupMode: groupMode,
            sortMode: sortMode
        )
    }

    private var shouldShowQuickAddBar: Bool {
        #if os(iOS)
        true
        #else
        false
        #endif
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Tasks")
                        .font(.title2)

                    Spacer()

                    if shouldShowQuickAddBar == false {
                        Button("New Task") {
                            path.append(.newTask)
                        }
                    }
                }

                if shouldShowQuickAddBar {
                    Text("Quick Add is optimized for fast phone capture. Open any task for full editing.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if viewModel.tasks.isEmpty == false {
                    ViewThatFits {
                        HStack(spacing: 12) {
                            sortPicker
                            groupPicker
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            sortPicker
                            groupPicker
                        }
                    }
                }

                if viewModel.tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: "checklist",
                        description: Text("Create a task to get started.")
                    )
                } else if filteredTasks.isEmpty {
                    ContentUnavailableView(
                        "No Matching Tasks",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term.")
                    )
                } else {
                    List {
                        if groupMode == .none {
                            ForEach(sortedTasks) { task in
                                taskRow(for: task)
                            }
                        } else {
                            ForEach(groupedSections) { section in
                                Section {
                                    ForEach(section.tasks) { task in
                                        taskRow(for: task)
                                    }
                                } header: {
                                    Text(section.title)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .padding()
            .searchable(text: $searchText, prompt: "Search title, notes, or tags")
            .task {
                viewModel.loadTasksIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }

                viewModel.handleSceneDidBecomeActive()
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: .NSPersistentStoreRemoteChange
                )
            ) { _ in
                guard scenePhase == .active else {
                    return
                }

                viewModel.loadTasks()
            }
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Quick Add") {
                            presentQuickAdd()
                        }

                        Button("Detailed Task") {
                            presentDetailedCreate()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                #endif
            }
            .sheet(item: $presentedSheet) { destination in
                NavigationStack {
                    switch destination {
                    case .quickAdd:
                        TaskQuickAddView(
                            initialFormData: newTaskDraft,
                            reservedTaskIDs: reservedTaskIDs
                        ) { task in
                            viewModel.saveTask(task)
                        } onOpenDetailedCreate: { draft in
                            newTaskDraft = draft
                            presentedSheet = .detailedCreate
                        }

                    case .detailedCreate:
                        TaskFormView(
                            mode: .create,
                            initialFormData: newTaskDraft,
                            reservedTaskIDs: reservedTaskIDs
                        ) { task in
                            viewModel.saveTask(task)
                        }
                    }
                }
                .macSheetFrame(minWidth: 500, minHeight: 640)
            }
            .safeAreaInset(edge: .bottom) {
                if shouldShowQuickAddBar {
                    Button {
                        presentQuickAdd()
                    } label: {
                        Label("Quick Add Task", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .background(.thinMaterial)
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .newTask:
                    TaskFormView(
                        mode: .create,
                        reservedTaskIDs: reservedTaskIDs
                    ) { task in
                        viewModel.saveTask(task)
                    }

                case .existingTask(let taskID):
                    if let task = viewModel.tasks.task(withID: taskID) {
                        TaskFormView(
                            mode: .edit(originalTaskID: task.id),
                            initialFormData: MyTaskFormData(task: task),
                            reservedTaskIDs: reservedTaskIDs
                        ) { updatedTask in
                            viewModel.saveTask(updatedTask, replacingTaskWithID: task.id)
                        } onDelete: {
                            viewModel.deleteTask(withID: task.id)
                        }
                    } else {
                        ContentUnavailableView(
                            "Task Not Found",
                            systemImage: "exclamationmark.triangle",
                            description: Text("This task is no longer available.")
                        )
                    }
                }
            }
        }
    }

    private var sortPicker: some View {
        Picker(selection: $sortMode) {
            ForEach(TaskListSortMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        } label: {
            Label("Sort: \(sortMode.shortLabel)", systemImage: "arrow.up.arrow.down")
        }
        .pickerStyle(.menu)
    }

    private var groupPicker: some View {
        Picker(selection: $groupMode) {
            ForEach(TaskListGroupMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        } label: {
            Label("Group: \(groupMode.displayName)", systemImage: "square.grid.2x2")
        }
        .pickerStyle(.menu)
    }

    private func taskRow(for task: MyTask) -> some View {
        NavigationLink(value: Destination.existingTask(task.id)) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: taskStatusIconName(for: task))
                    .foregroundStyle(taskStatusIconColor(for: task))
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(task.isDone ? .secondary : .primary)
                        .strikethrough(task.isDone)
                        .lineLimit(2)

                    if let notes = task.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    if let metadataSummary = metadataSummary(for: task) {
                        Text(metadataSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if task.status == .completed {
                Button("Reopen") {
                    viewModel.reopenTask(withID: task.id)
                }
                .tint(.blue)
            } else if task.status != .scheduled && task.status != .archived {
                Button("Complete") {
                    viewModel.markTaskCompleted(withID: task.id)
                }
                .tint(.green)

                Button("Archive") {
                    viewModel.archiveTask(withID: task.id)
                }
                .tint(.orange)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                viewModel.deleteTask(withID: task.id)
            }
        }
    }

    private func presentQuickAdd() {
        newTaskDraft = MyTaskFormData()
        presentedSheet = .quickAdd
    }

    private func presentDetailedCreate() {
        newTaskDraft = MyTaskFormData()
        presentedSheet = .detailedCreate
    }

    private func taskStatusIconName(for task: MyTask) -> String {
        switch task.status {
        case .inbox:
            return "tray.fill"
        case .active:
            return "circle"
        case .scheduled:
            return "calendar.badge.clock"
        case .completed:
            return "checkmark.circle.fill"
        case .archived:
            return "archivebox.fill"
        }
    }

    private func taskStatusIconColor(for task: MyTask) -> Color {
        switch task.status {
        case .inbox:
            return .blue
        case .active:
            return .secondary
        case .scheduled:
            return .orange
        case .completed:
            return .green
        case .archived:
            return .secondary
        }
    }

    private func metadataSummary(for task: MyTask) -> String? {
        var items: [String] = []

        switch task.status {
        case .inbox:
            items.append("Inbox")
        case .scheduled:
            items.append("Scheduled")
        case .archived:
            items.append("Archived")
        case .active, .completed:
            break
        }

        if let dueDate = task.dueDate {
            items.append(dueDateSummary(for: task, dueDate: dueDate))
        }

        if let estimatedMinutes = task.estimatedMinutes {
            items.append("\(estimatedMinutes)m")
        }

        if let priority = task.priority {
            items.append(priority.displayName)
        }

        return items.isEmpty ? nil : items.joined(separator: " • ")
    }

    private func dueDateSummary(for task: MyTask, dueDate: Date) -> String {
        switch TaskListOrganizer.dueDateCategory(for: task) {
        case .overdue:
            return "Overdue"
        case .today:
            return "Due Today \(dueDate.formatted(date: .omitted, time: .shortened))"
        case .upcoming, .later:
            return "Due \(dueDate.formatted(date: .abbreviated, time: .shortened))"
        case .noDueDate:
            return "No Due Date"
        }
    }
}

#Preview {
    TaskListView(taskRepository: AppContainer.makePreview().taskRepository)
}
