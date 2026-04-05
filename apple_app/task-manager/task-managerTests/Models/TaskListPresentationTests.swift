import Foundation
import Testing
@testable import task_manager

struct TaskListPresentationTests {
    private let calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private var referenceDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 4, day: 4, hour: 12))!
    }

    @Test func searchMatchesTitle() {
        let tasks = [
            makeTask(id: 1, title: "Plan sprint"),
            makeTask(id: 2, title: "Buy groceries"),
        ]

        let results = TaskListOrganizer.filteredTasks(from: tasks, searchText: "sprint")

        #expect(results.map(\.title) == ["Plan sprint"])
    }

    @Test func searchMatchesNotes() {
        let tasks = [
            makeTask(id: 1, title: "Review PR", notes: "Follow up with design"),
            makeTask(id: 2, title: "Walk dog"),
        ]

        let results = TaskListOrganizer.filteredTasks(from: tasks, searchText: "design")

        #expect(results.map(\.title) == ["Review PR"])
    }

    @Test func searchMatchesTags() {
        let tasks = [
            makeTask(id: 1, title: "Deep work block", tags: ["focus", "writing"]),
            makeTask(id: 2, title: "Invoices", tags: ["finance"]),
        ]

        let results = TaskListOrganizer.filteredTasks(from: tasks, searchText: "writ")

        #expect(results.map(\.title) == ["Deep work block"])
    }

    @Test func searchIsCaseInsensitiveAndTrimsWhitespace() {
        let tasks = [
            makeTask(id: 1, title: "Focus Session"),
            makeTask(id: 2, title: "Email cleanup"),
        ]

        let results = TaskListOrganizer.filteredTasks(from: tasks, searchText: "  focus  ")

        #expect(results.map(\.title) == ["Focus Session"])
    }

    @Test func sortingByDueDatePlacesNilValuesLast() {
        let tasks = [
            makeTask(id: 1, title: "No due date", dueDate: nil),
            makeTask(id: 2, title: "Later", dueDate: date(daysFromReference: 5)),
            makeTask(id: 3, title: "Sooner", dueDate: date(daysFromReference: 1)),
        ]

        let results = TaskListOrganizer.sortedTasks(tasks, by: .dueDate)

        #expect(results.map(\.title) == ["Sooner", "Later", "No due date"])
    }

    @Test func sortingByPriorityUsesExplicitPriorityOrder() {
        let tasks = [
            makeTask(id: 1, title: "Low", priority: .low),
            makeTask(id: 2, title: "Urgent", priority: .urgent),
            makeTask(id: 3, title: "No Priority", priority: nil),
            makeTask(id: 4, title: "Medium", priority: .medium),
            makeTask(id: 5, title: "High", priority: .high),
        ]

        let results = TaskListOrganizer.sortedTasks(tasks, by: .priority)

        #expect(results.map(\.title) == ["Urgent", "High", "Medium", "Low", "No Priority"])
    }

    @Test func groupingByStatusCreatesExpectedSections() {
        let tasks = [
            makeTask(id: 1, title: "Inbox item", status: .inbox),
            makeTask(id: 2, title: "Done item", status: .completed),
            makeTask(id: 3, title: "Active item", status: .active),
        ]

        let sections = TaskListOrganizer.groupedSections(
            from: tasks,
            groupMode: .status,
            sortMode: .createdDate,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Inbox", "Active", "Completed"])
    }

    @Test func groupingByPriorityCreatesExpectedSections() {
        let tasks = [
            makeTask(id: 1, title: "No priority", priority: nil),
            makeTask(id: 2, title: "High priority", priority: .high),
            makeTask(id: 3, title: "Urgent priority", priority: .urgent),
        ]

        let sections = TaskListOrganizer.groupedSections(
            from: tasks,
            groupMode: .priority,
            sortMode: .createdDate,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Urgent", "High", "No Priority"])
    }

    @Test func groupingByDueDateCategoryPlacesTasksIntoExpectedBuckets() {
        let tasks = [
            makeTask(id: 1, title: "Overdue", dueDate: date(daysFromReference: -1)),
            makeTask(id: 2, title: "Today", dueDate: referenceDate),
            makeTask(id: 3, title: "Upcoming", dueDate: date(daysFromReference: 3)),
            makeTask(id: 4, title: "Later", dueDate: date(daysFromReference: 10)),
            makeTask(id: 5, title: "No due date", dueDate: nil),
        ]

        let sections = TaskListOrganizer.groupedSections(
            from: tasks,
            groupMode: .dueDateCategory,
            sortMode: .createdDate,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Overdue", "Today", "Upcoming", "Later", "No Due Date"])
        #expect(sections.flatMap(\.tasks).map(\.title) == ["Overdue", "Today", "Upcoming", "Later", "No due date"])
    }

    @Test func groupedSectionsStillSortTasksWithinEachSection() {
        let tasks = [
            makeTask(id: 1, title: "Second active", status: .active, dueDate: date(daysFromReference: 4)),
            makeTask(id: 2, title: "First active", status: .active, dueDate: date(daysFromReference: 1)),
            makeTask(id: 3, title: "No date active", status: .active, dueDate: nil),
            makeTask(id: 4, title: "Scheduled first", status: .scheduled, dueDate: date(daysFromReference: 2)),
            makeTask(id: 5, title: "Scheduled later", status: .scheduled, dueDate: date(daysFromReference: 6)),
        ]

        let sections = TaskListOrganizer.groupedSections(
            from: tasks,
            groupMode: .status,
            sortMode: .dueDate,
            referenceDate: referenceDate,
            calendar: calendar
        )

        #expect(sections.map(\.title) == ["Active", "Scheduled"])
        #expect(sections[0].tasks.map(\.title) == ["First active", "Second active", "No date active"])
        #expect(sections[1].tasks.map(\.title) == ["Scheduled first", "Scheduled later"])
    }

    private func makeTask(
        id: Int,
        title: String,
        notes: String? = nil,
        status: TaskStatus = .active,
        estimatedMinutes: Int? = nil,
        dueDate: Date? = nil,
        priority: PriorityLevel? = nil,
        workMode: WorkModeKind? = nil,
        tags: [String] = []
    ) -> MyTask {
        let createdAt = Date(timeIntervalSince1970: TimeInterval(1_000 + id))

        return MyTask(
            id: UUID(uuidString: String(format: "123E4567-E89B-12D3-A456-426614174%03d", id))!,
            title: title,
            notes: notes,
            status: status,
            estimatedMinutes: estimatedMinutes,
            dueDate: dueDate,
            priority: priority,
            workMode: workMode,
            tags: tags,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private func date(daysFromReference dayOffset: Int) -> Date {
        calendar.date(byAdding: .day, value: dayOffset, to: referenceDate)!
    }
}
