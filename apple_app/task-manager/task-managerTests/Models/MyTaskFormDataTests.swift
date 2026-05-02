import Foundation
import Testing
@testable import task_manager

struct MyTaskFormDataTests {
    @Test func initFromTaskCopiesAllEditableFields() {
        let taskID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        let createdAt = Date(timeIntervalSince1970: 1_234)
        let completedAt = Date(timeIntervalSince1970: 1_300)
        let dueDate = Date(timeIntervalSince1970: 1_500)
        let task = MyTask(
            id: taskID,
            title: "Finish report",
            notes: "Send the draft",
            status: .completed,
            estimatedMinutes: 30,
            dueDate: dueDate,
            priority: .urgent,
            energyLevel: .high,
            workMode: .deepWork,
            taskGroup: "Launch",
            tags: ["work", "writing"],
            createdAt: createdAt,
            updatedAt: Date(timeIntervalSince1970: 1_260),
            completedAt: completedAt
        )

        let formData = MyTaskFormData(task: task)

        #expect(formData.idText == taskID.uuidString)
        #expect(formData.title == "Finish report")
        #expect(formData.notesText == "Send the draft")
        #expect(formData.status == .completed)
        #expect(formData.isCompleted == true)
        #expect(formData.estimatedMinutesText == "30")
        #expect(formData.hasDueDate == true)
        #expect(formData.dueDate == dueDate)
        #expect(formData.priority == .urgent)
        #expect(formData.energyLevel == .high)
        #expect(formData.workMode == .deepWork)
        #expect(formData.taskGroupText == "Launch")
        #expect(formData.tagsText == "work, writing")
        #expect(formData.createdAt == createdAt)
        #expect(formData.completedAt == completedAt)
    }

    @Test func makeTaskBuildsTaskFromFormFields() {
        let savedAt = Date(timeIntervalSince1970: 2_000)
        let dueDate = Date(timeIntervalSince1970: 3_000)
        let formData = MyTaskFormData(
            idText: "123E4567-E89B-12D3-A456-426614174000",
            title: "  Finish report  ",
            notesText: "  Send final copy  ",
            status: .scheduled,
            estimatedMinutesText: "45",
            hasDueDate: true,
            dueDate: dueDate,
            priority: .high,
            energyLevel: .medium,
            workMode: .creative,
            taskGroupText: " Launch ",
            tagsText: "work, writing",
            createdAt: Date(timeIntervalSince1970: 1_234)
        )

        let task = formData.makeTask(savedAt: savedAt)

        #expect(task?.id == UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000"))
        #expect(task?.title == "Finish report")
        #expect(task?.notes == "Send final copy")
        #expect(task?.status == .scheduled)
        #expect(task?.estimatedMinutes == 45)
        #expect(task?.dueDate == dueDate)
        #expect(task?.priority == .high)
        #expect(task?.energyLevel == .medium)
        #expect(task?.workMode == .creative)
        #expect(task?.taskGroup == "Launch")
        #expect(task?.tags == ["work", "writing"])
        #expect(task?.createdAt == Date(timeIntervalSince1970: 1_234))
        #expect(task?.updatedAt == savedAt)
        #expect(task?.completedAt == nil)
    }

    @Test func makeTaskRejectsInvalidID() {
        let formData = MyTaskFormData(idText: "not-a-uuid", title: "Read")

        #expect(formData.makeTask() == nil)
        #expect(formData.canSave == false)
    }

    @Test func makeTaskRejectsBlankTitle() {
        let formData = MyTaskFormData(title: "   ")

        #expect(formData.makeTask() == nil)
        #expect(formData.validationMessage == "Enter a task title.")
    }

    @Test func estimatedMinutesValidationRejectsNonQuarterHourValues() {
        for invalidMinutes in ["10", "20", "37"] {
            let formData = MyTaskFormData(title: "Read", estimatedMinutesText: invalidMinutes)

            #expect(formData.makeTask() == nil)
            #expect(
                formData.validationMessage
                    == "Estimated minutes must be a positive multiple of 15."
            )
        }
    }

    @Test func commaSeparatedTagsAreParsedAndTrimmed() {
        let formData = MyTaskFormData(
            title: "Read",
            tagsText: " home, errands , , deep work "
        )

        let task = formData.makeTask(savedAt: Date(timeIntervalSince1970: 4_000))

        #expect(task?.tags == ["home", "errands", "deep work"])
    }

    @Test func newTasksUseDefaultValuesOnInitialSave() {
        let savedAt = Date(timeIntervalSince1970: 5_000)
        let formData = MyTaskFormData(title: "Plan week")

        let task = formData.makeTask(savedAt: savedAt)

        #expect(task?.status == .inbox)
        #expect(task?.notes == nil)
        #expect(task?.estimatedMinutes == nil)
        #expect(task?.dueDate == nil)
        #expect(task?.priority == nil)
        #expect(task?.energyLevel == nil)
        #expect(task?.workMode == nil)
        #expect(task?.taskGroup == nil)
        #expect(task?.tags == [])
        #expect(task?.createdAt == savedAt)
        #expect(task?.updatedAt == savedAt)
        #expect(task?.completedAt == nil)
    }

    @Test func estimatedDurationTogglePreservesNoDurationAndDefaultsToThirtyMinutes() {
        var formData = MyTaskFormData(title: "Plan week")

        #expect(formData.hasEstimatedDuration == false)
        #expect(formData.estimatedMinutesText.isEmpty)

        formData.hasEstimatedDuration = true

        #expect(formData.hasEstimatedDuration == true)
        #expect(formData.estimatedMinutesSelection == 30)
        #expect(formData.estimatedMinutesText == "30")

        formData.hasEstimatedDuration = false

        #expect(formData.hasEstimatedDuration == false)
        #expect(formData.estimatedMinutesText.isEmpty)
    }

    @Test func estimatedDurationSelectionSnapsToQuarterHourSteps() {
        var formData = MyTaskFormData(title: "Read")

        formData.hasEstimatedDuration = true
        formData.estimatedMinutesSelection = 45
        #expect(formData.estimatedMinutesText == "45")

        formData.estimatedMinutesSelection = 1
        #expect(formData.estimatedMinutesSelection == 15)
        #expect(formData.estimatedMinutesDisplayText == "15 min")
    }

    @Test func estimatedDurationDisplayFallsBackToDefaultStepForInvalidStoredMinutes() {
        let formData = MyTaskFormData(title: "Read", estimatedMinutesText: "20")

        #expect(formData.hasEstimatedDuration == true)
        #expect(formData.estimatedMinutesSelection == 30)
        #expect(formData.estimatedMinutesDisplayText == "30 min")
    }

    @Test func validationRejectsDuplicateIDForAnotherTask() {
        let duplicateID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        let formData = MyTaskFormData(
            idText: duplicateID.uuidString,
            title: "Finish report"
        )

        let message = formData.validationMessage(reservedTaskIDs: [duplicateID])

        #expect(message == "Task ID must be unique.")
        #expect(formData.canSave(reservedTaskIDs: [duplicateID]) == false)
    }

    @Test func validationAllowsOriginalIDDuringEdit() {
        let existingID = UUID(uuidString: "123E4567-E89B-12D3-A456-426614174000")!
        let formData = MyTaskFormData(
            idText: existingID.uuidString,
            title: "Finish report"
        )

        let message = formData.validationMessage(
            reservedTaskIDs: [existingID],
            originalTaskID: existingID
        )

        #expect(message == nil)
        #expect(
            formData.canSave(
                reservedTaskIDs: [existingID],
                originalTaskID: existingID
            )
        )
    }

    @Test func generateNewIDReplacesTheCurrentID() {
        var formData = MyTaskFormData(idText: "123E4567-E89B-12D3-A456-426614174000")

        formData.generateNewID()

        #expect(formData.idText != "123E4567-E89B-12D3-A456-426614174000")
        #expect(UUID(uuidString: formData.idText) != nil)
    }
}
