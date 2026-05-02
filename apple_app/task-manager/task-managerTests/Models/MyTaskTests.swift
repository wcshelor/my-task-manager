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
        #expect(task?.status == .inbox)
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
        let task = MyTask(
            title: "Prepare workshop",
            notes: "  Review outline  ",
            status: .scheduled,
            estimatedMinutes: 45,
            dueDate: dueDate,
            priority: .urgent,
            energyLevel: .high,
            workMode: .deepWork,
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
        #expect(task.taskGroup == "Launch")
        #expect(task.tags == ["work", "planning"])
        #expect(task.createdAt == createdAt)
        #expect(task.updatedAt == updatedAt)
        #expect(task.completedAt == nil)
    }
}
