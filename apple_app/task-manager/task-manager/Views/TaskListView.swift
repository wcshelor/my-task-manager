import SwiftUI

struct TaskListView: View {
    private enum Destination: Hashable {
        case newTask
        case existingTask(UUID)
    }

    @State private var tasks = MyTask.sampleTasks
    @State private var path: [Destination] = []

    private var reservedTaskIDs: Set<UUID> {
        Set(tasks.map(\.id))
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

                List {
                    ForEach(tasks) { task in
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
                .listStyle(.plain)
            }
            .padding()
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .newTask:
                    TaskFormView(
                        mode: .create,
                        reservedTaskIDs: reservedTaskIDs
                    ) { task in
                        tasks.saveTask(task)
                    }

                case .existingTask(let taskID):
                    if let task = tasks.task(withID: taskID) {
                        TaskFormView(
                            mode: .edit(originalTaskID: task.id),
                            initialFormData: MyTaskFormData(task: task),
                            reservedTaskIDs: reservedTaskIDs
                        ) { updatedTask in
                            tasks.saveTask(updatedTask, replacingTaskWithID: task.id)
                        } onDelete: {
                            tasks.deleteTask(withID: task.id)
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
}

#Preview {
    TaskListView()
}
