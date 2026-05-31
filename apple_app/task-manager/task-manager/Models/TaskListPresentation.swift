import Foundation

enum TaskListSortMode: String, CaseIterable, Identifiable {
    case createdDate
    case title
    case dueDate
    case estimatedMinutes
    case priority
    case status

    var id: Self { self }

    var displayName: String {
        switch self {
        case .createdDate:
            return "Created Date"
        case .title:
            return "Title"
        case .dueDate:
            return "Due Date"
        case .estimatedMinutes:
            return "Estimated Minutes"
        case .priority:
            return "Priority"
        case .status:
            return "Status"
        }
    }

    var shortLabel: String {
        switch self {
        case .createdDate:
            return "Created"
        case .estimatedMinutes:
            return "Minutes"
        default:
            return displayName
        }
    }
}

enum TaskListGroupMode: String, CaseIterable, Identifiable {
    case none
    case status
    case priority
    case dueDateCategory
    case workMode
    case taskGroup

    var id: Self { self }

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .status:
            return "Status"
        case .priority:
            return "Priority"
        case .dueDateCategory:
            return "Due Date"
        case .workMode:
            return "Work Mode"
        case .taskGroup:
            return "Task Group"
        }
    }
}

enum TaskDueDateCategory: String, CaseIterable, Hashable {
    case overdue
    case today
    case upcoming
    case later
    case noDueDate

    var displayName: String {
        switch self {
        case .overdue:
            return "Overdue"
        case .today:
            return "Today"
        case .upcoming:
            return "Upcoming"
        case .later:
            return "Later"
        case .noDueDate:
            return "No Due Date"
        }
    }
}

struct TaskListSection: Identifiable, Equatable {
    let id: String
    let title: String
    let tasks: [MyTask]
}

enum TaskListOrganizer {
    private enum GroupKey: Hashable {
        case status(TaskStatus)
        case priority(PriorityLevel?)
        case dueDateCategory(TaskDueDateCategory)
        case workMode(WorkModeKind?)
        case taskGroup(String?)
    }

    static func filteredTasks(
        from tasks: [MyTask],
        searchText: String
    ) -> [MyTask] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedQuery.isEmpty == false else {
            return tasks
        }

        return tasks.filter { task in
            task.title.localizedCaseInsensitiveContains(trimmedQuery)
                || (task.notes?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
                || (task.taskGroup?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
                || task.tags.contains { $0.localizedCaseInsensitiveContains(trimmedQuery) }
        }
    }

    static func sortedTasks(
        _ tasks: [MyTask],
        by sortMode: TaskListSortMode
    ) -> [MyTask] {
        tasks.sorted { leftTask, rightTask in
            compare(leftTask, rightTask, by: sortMode) == .orderedAscending
        }
    }

    static func groupedSections(
        from tasks: [MyTask],
        groupMode: TaskListGroupMode,
        sortMode: TaskListSortMode,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [TaskListSection] {
        guard groupMode != .none else {
            return []
        }

        let groupedTasks = Dictionary(grouping: tasks) { task in
            groupKey(
                for: task,
                groupMode: groupMode,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }

        let orderedKeys = orderedGroupKeys(for: groupMode)
        let sectionKeys = orderedKeys.isEmpty
            ? groupedTasks.keys.sorted { leftKey, rightKey in
                compareGroupKeys(leftKey, rightKey)
            }
            : orderedKeys

        return sectionKeys.compactMap { key in
            makeSection(for: key, groupedTasks: groupedTasks, sortMode: sortMode)
        }
    }

    static func dueDateCategory(
        for task: MyTask,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> TaskDueDateCategory {
        guard let dueDate = task.dueDate else {
            return .noDueDate
        }

        let startOfToday = calendar.startOfDay(for: referenceDate)
        let startOfUpcomingWindow = calendar.date(byAdding: .day, value: 8, to: startOfToday)
            ?? startOfToday

        if dueDate < startOfToday {
            return .overdue
        }

        if calendar.isDate(dueDate, inSameDayAs: referenceDate) {
            return .today
        }

        if dueDate < startOfUpcomingWindow {
            return .upcoming
        }

        return .later
    }

    private static func groupKey(
        for task: MyTask,
        groupMode: TaskListGroupMode,
        referenceDate: Date,
        calendar: Calendar
    ) -> GroupKey {
        switch groupMode {
        case .none:
            return .status(task.status)
        case .status:
            return .status(task.status)
        case .priority:
            return .priority(task.priority)
        case .dueDateCategory:
            return .dueDateCategory(
                dueDateCategory(for: task, referenceDate: referenceDate, calendar: calendar)
            )
        case .workMode:
            return .workMode(task.workMode)
        case .taskGroup:
            return .taskGroup(task.taskGroup)
        }
    }

    private static func makeSection(
        for key: GroupKey,
        groupedTasks: [GroupKey: [MyTask]],
        sortMode: TaskListSortMode
    ) -> TaskListSection? {
        guard let tasksInGroup = groupedTasks[key], tasksInGroup.isEmpty == false else {
            return nil
        }

        return TaskListSection(
            id: sectionID(for: key),
            title: sectionTitle(for: key),
            tasks: sortedTasks(tasksInGroup, by: sortMode)
        )
    }

    private static func orderedGroupKeys(
        for groupMode: TaskListGroupMode
    ) -> [GroupKey] {
        switch groupMode {
        case .none:
            return []
        case .status:
            return TaskStatus.sectionOrder.map(GroupKey.status)
        case .priority:
            return PriorityLevel.sectionOrder.map { GroupKey.priority($0) } + [.priority(nil)]
        case .dueDateCategory:
            return TaskDueDateCategory.sectionOrder.map(GroupKey.dueDateCategory)
        case .workMode:
            let workModeKeys = WorkModeKind.allCases.map(GroupKey.workMode)
            return workModeKeys + [.workMode(nil)]
        case .taskGroup:
            return []
        }
    }

    private static func sectionID(for key: GroupKey) -> String {
        switch key {
        case .status(let status):
            return "status-\(status.rawValue)"
        case .priority(let priority):
            return "priority-\(priority?.rawValue ?? "none")"
        case .dueDateCategory(let category):
            return "due-\(category.rawValue)"
        case .workMode(let workMode):
            return "workmode-\(workMode?.rawValue ?? "none")"
        case .taskGroup(let taskGroup):
            return "taskgroup-\(taskGroup ?? "none")"
        }
    }

    private static func sectionTitle(for key: GroupKey) -> String {
        switch key {
        case .status(let status):
            return status.displayName
        case .priority(let priority):
            return priority?.displayName ?? "No Priority"
        case .dueDateCategory(let category):
            return category.displayName
        case .workMode(let workMode):
            return workMode?.displayName ?? "No Work Mode"
        case .taskGroup(let taskGroup):
            return taskGroup ?? "No Task Group"
        }
    }

    private static func compareGroupKeys(_ leftKey: GroupKey, _ rightKey: GroupKey) -> Bool {
        sectionTitle(for: leftKey).localizedCaseInsensitiveCompare(sectionTitle(for: rightKey))
            == .orderedAscending
    }

    private static func compare(
        _ leftTask: MyTask,
        _ rightTask: MyTask,
        by sortMode: TaskListSortMode
    ) -> ComparisonResult {
        switch sortMode {
        case .createdDate:
            return firstNonEqualComparison(
                compareValues(leftTask.createdAt, rightTask.createdAt),
                compareTitles(leftTask.title, rightTask.title),
                compareValues(leftTask.id.uuidString, rightTask.id.uuidString)
            )

        case .title:
            return firstNonEqualComparison(
                compareTitles(leftTask.title, rightTask.title),
                compareValues(leftTask.createdAt, rightTask.createdAt),
                compareValues(leftTask.id.uuidString, rightTask.id.uuidString)
            )

        case .dueDate:
            return firstNonEqualComparison(
                compareOptionalValues(leftTask.dueDate, rightTask.dueDate),
                compareTitles(leftTask.title, rightTask.title),
                compareValues(leftTask.createdAt, rightTask.createdAt),
                compareValues(leftTask.id.uuidString, rightTask.id.uuidString)
            )

        case .estimatedMinutes:
            return firstNonEqualComparison(
                compareOptionalValues(leftTask.estimatedMinutes, rightTask.estimatedMinutes),
                compareTitles(leftTask.title, rightTask.title),
                compareValues(leftTask.createdAt, rightTask.createdAt),
                compareValues(leftTask.id.uuidString, rightTask.id.uuidString)
            )

        case .priority:
            return firstNonEqualComparison(
                compareOptionalValues(leftTask.priority?.sortRank, rightTask.priority?.sortRank),
                compareTitles(leftTask.title, rightTask.title),
                compareValues(leftTask.createdAt, rightTask.createdAt),
                compareValues(leftTask.id.uuidString, rightTask.id.uuidString)
            )

        case .status:
            return firstNonEqualComparison(
                compareValues(leftTask.status.sortRank, rightTask.status.sortRank),
                compareTitles(leftTask.title, rightTask.title),
                compareValues(leftTask.createdAt, rightTask.createdAt),
                compareValues(leftTask.id.uuidString, rightTask.id.uuidString)
            )
        }
    }

    private static func firstNonEqualComparison(
        _ comparisons: ComparisonResult...
    ) -> ComparisonResult {
        comparisons.first { $0 != .orderedSame } ?? .orderedSame
    }

    private static func compareTitles(
        _ leftTitle: String,
        _ rightTitle: String
    ) -> ComparisonResult {
        let comparison = leftTitle.localizedCaseInsensitiveCompare(rightTitle)

        if comparison != .orderedSame {
            return comparison
        }

        return compareValues(leftTitle, rightTitle)
    }

    private static func compareValues<T: Comparable>(
        _ leftValue: T,
        _ rightValue: T
    ) -> ComparisonResult {
        if leftValue < rightValue {
            return .orderedAscending
        }

        if leftValue > rightValue {
            return .orderedDescending
        }

        return .orderedSame
    }

    private static func compareOptionalValues<T: Comparable>(
        _ leftValue: T?,
        _ rightValue: T?
    ) -> ComparisonResult {
        switch (leftValue, rightValue) {
        case let (left?, right?):
            return compareValues(left, right)
        case (.some, .none):
            return .orderedAscending
        case (.none, .some):
            return .orderedDescending
        case (.none, .none):
            return .orderedSame
        }
    }
}

private extension TaskStatus {
    static let sectionOrder: [TaskStatus] = [
        .open,
        .scheduled,
        .done,
        .archived,
    ]

    var sortRank: Int {
        Self.sectionOrder.firstIndex(of: self) ?? Self.sectionOrder.count
    }
}

private extension PriorityLevel {
    static let sectionOrder: [PriorityLevel] = [
        .urgent,
        .high,
        .medium,
        .low,
    ]

    var sortRank: Int {
        Self.sectionOrder.firstIndex(of: self) ?? Self.sectionOrder.count
    }
}

private extension TaskDueDateCategory {
    static let sectionOrder: [TaskDueDateCategory] = [
        .overdue,
        .today,
        .upcoming,
        .later,
        .noDueDate,
    ]
}
