import Foundation
import Testing
@testable import task_manager

struct MyTaskTests {
    @Test func cleanedTitleTrimsWhitespace() {
        #expect(MyTask.cleanedTitle(from: "  Buy milk  ") == "Buy milk")
    }

    @Test func cleanedTitleRejectsBlankInput() {
        #expect(MyTask.cleanedTitle(from: " \n\t ") == nil)
    }

    @Test func newTaskInitializerStartsInInboxWithDefaults() {
        let task = MyTask(newTitle: "Read book")

        #expect(task?.title == "Read book")
        #expect(task?.status == .open)
        #expect(task?.tags == [])
        #expect(task?.completedAt == nil)
        #expect(task?.updatedAt == task?.createdAt)
    }

    @Test func cleanedEstimatedMinutesAcceptQuarterHourMultiples() {
        for estimatedMinutes in [15, 30, 45, 60] {
            #expect(MyTask.cleanedEstimatedMinutes(estimatedMinutes) == estimatedMinutes)
        }
    }

    @Test func cleanedEstimatedMinutesRejectInvalidValuesAndAllowsNil() {
        for estimatedMinutes in [10, 20, 37, 0, -15] {
            #expect(MyTask.cleanedEstimatedMinutes(estimatedMinutes) == nil)
        }

        #expect(MyTask.cleanedEstimatedMinutes(nil) == nil)
    }

    @Test func estimatedMinutesSetterPreservesQuarterHourInvariant() {
        var task = MyTask(title: "Prepare workshop", estimatedMinutes: 45)

        task.estimatedMinutes = 20
        #expect(task.estimatedMinutes == nil)

        task.estimatedMinutes = 60
        #expect(task.estimatedMinutes == 60)
    }

    @Test func taskStoresEnumBackedFieldsAndCleansOptionalValues() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let updatedAt = Date(timeIntervalSince1970: 2_000)
        let dueDate = Date(timeIntervalSince1970: 3_000)
        let projectID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174321")!
        let task = MyTask(
            title: "Prepare workshop",
            notes: "  Review outline  ",
            status: .scheduled,
            estimatedMinutes: 45,
            dueDate: dueDate,
            priority: .urgent,
            energyLevel: .high,
            workMode: .deepWork,
            projectID: projectID,
            taskGroup: " Launch ",
            tags: [" work ", "", "planning "],
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        #expect(task.notes == "Review outline")
        #expect(task.status == .scheduled)
        #expect(task.estimatedMinutes == 45)
        #expect(task.dueDate == dueDate)
        #expect(task.priority == .urgent)
        #expect(task.energyLevel == .high)
        #expect(task.workMode == .deepWork)
        #expect(task.projectID == projectID)
        #expect(task.taskGroup == "Launch")
        #expect(task.tags == ["work", "planning"])
        #expect(task.createdAt == createdAt)
        #expect(task.updatedAt == updatedAt)
        #expect(task.completedAt == nil)
    }

    @Test func projectTaskSummaryCalculatesProgressFromUnarchivedTasks() {
        let project = Project(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!,
            name: "Launch"
        )
        let otherProjectID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174222")!
        let completedTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174001")!,
            title: "Done",
            status: .done,
            projectID: project.id,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let openTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174002")!,
            title: "Open",
            status: .open,
            projectID: project.id,
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        let archivedTask = MyTask(
            title: "Archived",
            status: .archived,
            projectID: project.id
        )
        let otherProjectTask = MyTask(
            title: "Other project",
            status: .open,
            projectID: otherProjectID
        )

        let summary = project.taskSummary(from: [
            otherProjectTask,
            archivedTask,
            openTask,
            completedTask,
        ])

        #expect(summary.openTasks.map(\.title) == ["Done", "Open"])
        #expect(summary.openTaskCount == 2)
        #expect(summary.doneActiveTaskCount == 1)
        #expect(summary.incompleteActiveTaskCount == 1)
        #expect(summary.progressFraction == 0.5)
        #expect(summary.progressSummary == "1/2 tasks complete")
    }

    @Test func projectTaskSummarySelectsNextActionByDueDatePriorityAndCreationDate() {
        let project = Project(name: "Launch")
        let sharedDueDate = Date(timeIntervalSince1970: 10_000)
        let lowPriorityTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174001")!,
            title: "Soon low",
            status: .open,
            dueDate: sharedDueDate,
            priority: .low,
            projectID: project.id,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let highPriorityTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174002")!,
            title: "Soon high",
            status: .open,
            dueDate: sharedDueDate,
            priority: .high,
            projectID: project.id,
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        let noDueUrgentTask = MyTask(
            id: UUID(uuidString: "123E4567-E89B-12D3-A456-426614174003")!,
            title: "No due urgent",
            status: .open,
            priority: .urgent,
            projectID: project.id,
            createdAt: Date(timeIntervalSince1970: 3_000)
        )

        let summary = project.taskSummary(from: [
            noDueUrgentTask,
            lowPriorityTask,
            highPriorityTask,
        ])

        #expect(summary.nextAction == highPriorityTask)
        #expect(summary.nextActions().map(\.title) == ["Soon high", "Soon low", "No due urgent"])
    }

    @Test func projectTaskSummaryExcludesCompletedAndArchivedTasksFromNextAction() {
        let project = Project(name: "Launch")
        let completedTask = MyTask(
            title: "Already done",
            status: .done,
            dueDate: Date(timeIntervalSince1970: 1_000),
            priority: .urgent,
            projectID: project.id
        )
        let archivedTask = MyTask(
            title: "Archived",
            status: .archived,
            dueDate: Date(timeIntervalSince1970: 2_000),
            priority: .urgent,
            projectID: project.id
        )
        let openTask = MyTask(
            title: "Still open",
            status: .open,
            dueDate: Date(timeIntervalSince1970: 3_000),
            priority: .low,
            projectID: project.id
        )

        let summary = project.taskSummary(from: [completedTask, archivedTask, openTask])

        #expect(summary.openTaskCount == 2)
        #expect(summary.doneActiveTaskCount == 1)
        #expect(summary.nextAction == openTask)
        #expect(project.taskSummary(from: [completedTask, archivedTask]).nextAction == nil)
    }

    @Test func captureItemMarksProcessedAndArchived() {
        let processedAt = Date(timeIntervalSince1970: 1_000)
        let taskID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        var capture = CaptureItem(title: "Look up paper")

        #expect(capture.isPendingReview == true)

        capture.markProcessed(at: processedAt, convertedTaskID: taskID)

        #expect(capture.isPendingReview == false)
        #expect(capture.processedAt == processedAt)
        #expect(capture.convertedTaskID == taskID)

        var archivedCapture = CaptureItem(title: "Old thought")
        archivedCapture.archive(at: processedAt)

        #expect(archivedCapture.isPendingReview == false)
        #expect(archivedCapture.archivedAt == processedAt)
    }

    @Test func projectItemStoresMaybeAndNoteMetadata() {
        let projectID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174111")!
        let reviewAfter = Date(timeIntervalSince1970: 5_000)
        let maybe = ProjectItem(
            projectID: projectID,
            kind: .maybe,
            title: " Explore coding methods ",
            notes: "  Ask advisor  ",
            source: "  Meeting  ",
            pressure: .becomingRelevant,
            reviewAfter: reviewAfter
        )
        let note = ProjectItem(projectID: projectID, kind: .note, title: "Advisor likes concise drafts")

        #expect(maybe.title == "Explore coding methods")
        #expect(maybe.notes == "Ask advisor")
        #expect(maybe.source == "Meeting")
        #expect(maybe.pressure == .becomingRelevant)
        #expect(maybe.reviewAfter == reviewAfter)
        #expect(note.kind == .note)
    }
}
