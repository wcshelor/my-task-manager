import SwiftUI

struct TaskListView: View {
    private enum Destination: Hashable {
        case newTask
        case existingTask(UUID)
    }

    @StateObject private var viewModel: TaskListViewModel
    @State private var path: [Destination] = []
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

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Tasks")
                        .font(.title2)

                    Spacer()

                    Button("New Task") {
                        path.append(.newTask)
                    }
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
            HStack(spacing: 12) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? .green : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .foregroundStyle(task.isDone ? .secondary : .primary)
                        .strikethrough(task.isDone)

                    Text(task.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }
}

#Preview {
    TaskListView(taskRepository: AppContainer.makePreview().taskRepository)
}
